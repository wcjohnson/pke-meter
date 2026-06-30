local class = require("lib.core.class").class
local event = require("lib.core.event")
local tlib = require("lib.core.table")
local pos_lib = require("lib.core.math.pos")
local strace = require("lib.core.strace")

local pos_get = pos_lib.pos_get

local lib = {}

---@class (exact) PkeMeter.Surface
---@field public index SurfaceIndex
---@field public combinators PkeMeter.Combinator[] Combinators on this surface.
---@field public ghost_set {[UnitNumber]: LuaEntity} Ghosts by unit number.
local Surface = class("PkeMeter.Surface")
lib.Surface = Surface

function Surface:new(index)
	local obj = {
		index = index,
		combinators = {},
		ghost_set = {},
	}
	return setmetatable(obj, self)
end

function Surface:get_ghost_set() return self.ghost_set end

---@param comb PkeMeter.Combinator
function Surface:add_combinator(comb)
	table.insert(self.combinators, comb)
	strace.trace(
		"Surface:add_combinator: added combinator",
		self.index,
		comb.thing_id
	)
	-- Associate existing ghosts with this combinator.
	comb:defer_update(2)
end

---@param comb PkeMeter.Combinator
function Surface:remove_combinator(comb)
	local removed_comb_id = comb.thing_id
	tlib.filter_in_place(
		self.combinators,
		function(c) return c.thing_id ~= removed_comb_id end
	)
	strace.trace(
		"Surface:remove_combinator: removed combinator",
		self.index,
		removed_comb_id
	)
end

---@param entity ValidEntityWithUnitNumber
function Surface:add_ghost(entity)
	local unit_number = entity.unit_number
	if self.ghost_set[unit_number] then return end
	strace.trace(
		"Surface:add_ghost: adding ghost",
		self.index,
		unit_number,
		entity.name
	)
	self.ghost_set[unit_number] = entity
	storage.ghost_surfaces[unit_number] = self.index

	for _, comb in pairs(self.combinators) do
		comb:add_ghost(entity)
	end

	script.register_on_object_destroyed(entity)
end

---@param unit_number UnitNumber
function Surface:remove_ghost_by_unit_number(unit_number)
	if not self.ghost_set[unit_number] then return end
	strace.trace(
		"Surface:remove_ghost_by_unit_number: removing ghost",
		self.index,
		unit_number
	)

	for _, comb in pairs(self.combinators) do
		comb:remove_ghost_by_unit_number(unit_number)
	end

	self.ghost_set[unit_number] = nil
end

---@param unit_number UnitNumber
function Surface:update_proxy_by_unit_number(unit_number)
	if not self.ghost_set[unit_number] then return end

	strace.trace(
		"Surface:update_proxy_by_unit_number: updating proxy",
		self.index,
		unit_number
	)

	for _, comb in pairs(self.combinators) do
		comb:update_proxy_by_unit_number(unit_number)
	end
end

function Surface:add_roboport(entity)
	-- Grug-brained strategy: arbitrary merging of logistics networks may happen
	-- so we just have to rebuild
	for _, comb in pairs(self.combinators) do
		comb:defer_update(2)
	end
end

function Surface:remove_roboport(entity)
	-- Grug-brained strategy: arbitrary splitting of logistics networks may happen
	-- so we just have to rebuild
	for _, comb in pairs(self.combinators) do
		comb:defer_update(2)
	end
end

function Surface:full_scan()
	local surface = game.get_surface(self.index)
	if not surface then return end
	strace.trace("Surface:full_scan: scanning surface", self.index)
	local entities = surface.find_entities_filtered({
		type = { "entity-ghost", "tile-ghost", "item-request-proxy" },
	})
	for _, entity in pairs(entities) do
		self:add_ghost(entity)
	end
end

function Surface:destroy()
	for unit_number in pairs(self.ghost_set) do
		storage.ghost_surfaces[unit_number] = nil
	end

	self.ghost_set = {}
	storage.surfaces[self.index] = nil
end

---@param index SurfaceIndex
---@return PkeMeter.Surface?
function get_surface_by_index(index)
	if index == nil then return nil end
	return storage.surfaces[index]
end

---@param index SurfaceIndex
---@return PkeMeter.Surface
function get_or_create_surface_by_index(index)
	local surface = storage.surfaces[index]
	if not surface then
		local game_surface = game.get_surface(index)
		if not game_surface then
			error("Game surface with index " .. index .. " does not exist.")
		end
		strace.trace("get_or_create_surface_by_index: creating new surface", index)
		surface = Surface:new(index)
		surface:full_scan()
		storage.surfaces[index] = surface
	end
	return surface
end

--------------------------------------------------------------------------------
-- GHOST LIFECYCLE
--------------------------------------------------------------------------------

-- Item-request-proxies.
event.bind(
	defines.events.on_script_trigger_effect,
	---@param ev EventData.on_script_trigger_effect
	function(ev)
		if ev.effect_id ~= "item-request-proxy" then return end

		local entity = ev.source_entity
		if not entity then return end

		local surface = get_surface_by_index(entity.surface.index)
		if not surface then return end

		surface:add_ghost(entity)

		-- Register for proxy item updates.
		remote.call(
			"item-request-proxy-events",
			"register_item_request_proxy_updated",
			entity.unit_number
		)
	end
)

event.bind("item-request-proxy-updated", function(ev)
	local unit_number = ev.unit_number
	local surface_index = storage.ghost_surfaces[unit_number]
	if not surface_index then return end
	local surface = get_surface_by_index(surface_index)
	if not surface then return end
	surface:update_proxy_by_unit_number(unit_number)
end)

-- General construction
---@param ev EventData.script_raised_built|EventData.script_raised_revive|EventData.on_built_entity|EventData.on_robot_built_entity|EventData.on_space_platform_built_entity
local function handle_generic_built(ev)
	local entity = ev.entity
	local surface = get_surface_by_index(entity.surface.index)
	if not surface then return end

	if entity.type == "roboport" then
		surface:add_roboport(entity)
		return
	end

	local is_ghost = (
		entity.type == "entity-ghost" or entity.type == "tile-ghost"
	)
	if not is_ghost then return end

	surface:add_ghost(entity)
end

event.bind(defines.events.on_built_entity, handle_generic_built)
event.bind(defines.events.on_robot_built_entity, handle_generic_built)
event.bind(defines.events.on_space_platform_built_entity, handle_generic_built)
event.bind(defines.events.script_raised_built, handle_generic_built)
event.bind(defines.events.script_raised_revive, handle_generic_built)

local function handle_generic_destroyed(ev)
	local entity = ev.entity
	if entity.type ~= "roboport" then return end
	local surface = get_surface_by_index(entity.surface.index)
	if not surface then return end
	surface:remove_roboport(entity)
end

event.bind(defines.events.on_player_mined_entity, handle_generic_destroyed)
event.bind(defines.events.on_robot_mined_entity, handle_generic_destroyed)
event.bind(
	defines.events.on_space_platform_mined_entity,
	handle_generic_destroyed
)
event.bind(defines.events.script_raised_destroy, handle_generic_destroyed)

local ENTITY_TARGET_TYPE = defines.target_type.entity

-- Ghost destruction.
event.bind(
	defines.events.on_object_destroyed,
	---@param ev EventData.on_object_destroyed
	function(ev)
		if ev.type ~= ENTITY_TARGET_TYPE then return end
		local unit_number = ev.useful_id
		local surface_index = storage.ghost_surfaces[unit_number]
		if not surface_index then return end
		storage.ghost_surfaces[unit_number] = nil
		local surface = get_surface_by_index(surface_index)
		if not surface then return end
		surface:remove_ghost_by_unit_number(unit_number)
	end
)

-- Surface destruction.
event.bind(
	defines.events.on_surface_deleted,
	---@param ev EventData.on_surface_deleted
	function(ev)
		local surface_index = ev.surface_index
		local surface = get_surface_by_index(surface_index)
		if not surface then return end
		surface:destroy()
	end
)

return lib
