local class = require("lib.core.class").class
local event = require("lib.core.event")
local signal_lib = require("lib.core.signal")
local strace = require("lib.core.strace")

local lib = {}

---@class PkeMeter.Combinator
---@field public thing_id int64
---@field public surface_index SurfaceIndex The index of the surface this combinator is on.
---@field public pos MapPosition The position of the combinator on the surface.
---@field public force_index uint8 Index of the LuaForce owning the combinator.
---@field public logistic_network_id LogisticNetworkId? The ID of the logistic network this combinator is in.
---@field public deferred_update? 1|2 When present, indicates that this combinator has a deferred update scheduled.
---@field public ghost_set {[UnitNumber]: LuaEntity} Ghosts by unit number.
local Combinator = class("PkeMeter.Combinator")
lib.Combinator = Combinator

function Combinator:new(thing_id)
	local obj = {
		thing_id = thing_id,
		ghost_set = {},
	}
	return setmetatable(obj, self)
end

function Combinator:destroy()
	local surface = get_surface_by_index(self.surface_index)
	if surface then surface:remove_combinator(self) end
	strace.trace("Combinator:destroy: destroying combinator", self.thing_id)
	storage.combinators[self.thing_id] = nil
end

function Combinator:set_surface_index(surface_index)
	if self.surface_index == surface_index then return end
	self.surface_index = surface_index
	local surface = get_or_create_surface_by_index(surface_index)
	surface:add_combinator(self)
	self:defer_update(2)
	strace.trace(
		"Combinator:set_surface_index: set surface index",
		self.thing_id,
		surface_index
	)
end

function Combinator:update_logistic_network_id()
	local surface = game.get_surface(self.surface_index)
	if not surface then return end
	local ln =
		surface.find_logistic_network_by_position(self.pos, self.force_index)
	local ln_id = ln and ln.network_id
	if ln_id ~= self.logistic_network_id then
		self.logistic_network_id = ln_id
		strace.trace(
			"Combinator:update_logistic_network_id: updated logistic network ID",
			self.thing_id,
			ln_id
		)
		self:defer_update(2)
	end
end

---@param ghost ValidEntityWithUnitNumber
function Combinator:add_ghost(ghost)
	local un = ghost.unit_number
	if self.ghost_set[un] then return end
	local surface = game.get_surface(self.surface_index)
	if not surface then return end
	local lns = surface.find_logistic_networks_by_construction_area(
		ghost.position,
		self.force_index
	)
	for _, ln in pairs(lns) do
		if ln.network_id == self.logistic_network_id then
			self.ghost_set[un] = ghost
			self:defer_update(1)
			strace.trace(
				"Combinator:add_ghost: added ghost",
				self.thing_id,
				un,
				ghost.name
			)
			return
		end
	end
	strace.trace(
		"Combinator:add_ghost: ghost not in same logistic network",
		self.thing_id,
		un,
		ghost.name,
		self.logistic_network_id
	)
end

---@param unit_number UnitNumber
function Combinator:remove_ghost_by_unit_number(unit_number)
	if self.ghost_set[unit_number] then
		self.ghost_set[unit_number] = nil
		self:defer_update(1)
		strace.trace(
			"Combinator:remove_ghost_by_unit_number: removed ghost",
			self.thing_id,
			unit_number
		)
	end
end

---@param level 1|2
function Combinator:defer_update(level)
	local current_level = self.deferred_update or 0
	if current_level >= level then return end
	if current_level == 0 then
		event.dynamic_subtick_trigger("pke-meter-combinator-update", "update", self)
	end
	self.deferred_update = level
end

function Combinator:perform_deferred_update()
	if self.deferred_update == 1 then
		strace.trace(
			"Combinator:perform_deferred_update: updating signals",
			self.thing_id
		)
		self:update_signals()
	elseif self.deferred_update == 2 then
		strace.trace(
			"Combinator:perform_deferred_update: FULL UPDATE",
			self.thing_id
		)
		self:update_logistic_network_id()
		self:update_ghosts()
		self:update_signals()
	end
	self.deferred_update = nil
end

---@param unit_number UnitNumber
function Combinator:update_proxy_by_unit_number(unit_number)
	if not self.ghost_set[unit_number] then return end
	self:defer_update(1)
end

function Combinator:update_ghosts()
	self.ghost_set = {}
	local surface = get_surface_by_index(self.surface_index)
	if not surface then return end
	local candidates = surface:get_ghost_set()
	for _, ghost in pairs(candidates) do
		if ghost.valid then self:add_ghost(ghost) end
	end
end

---@type {[string]: ItemToPlace}
local _itpt_cache = {}

---@param ghost ValidEntityWithUnitNumber Entity or tile ghost
---@return ItemToPlace? The first item to place this ghost, or nil if none.
local function get_items_to_place_this(ghost)
	local cached = _itpt_cache[ghost.ghost_name]
	if cached ~= nil then return cached end
	local ghost_proto = ghost.ghost_prototype
	local itpt = ghost_proto.items_to_place_this
	local it = itpt and itpt[1]
	_itpt_cache[ghost.ghost_name] = it
	return it
end

function Combinator:update_signals()
	local _, thing = remote.call("things-metadata-v1", "get", self.thing_id)
	if (not thing) or not thing.entity then return end

	local entity = thing.entity --[[@as LuaEntity]]
	local behavior = entity.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior?]]
	if not behavior then return end

	local surface = get_surface_by_index(self.surface_index)
	if not surface then return end

	-- Generate signals from the ghost_set
	---@type SignalCounts
	local signal_counts = {}
	for unit_number, ghost in pairs(self.ghost_set) do
		if not ghost.valid then
			self.ghost_set[unit_number] = nil
			surface:remove_ghost_by_unit_number(unit_number)
			goto continue
		end

		if ghost.type == "entity-ghost" or ghost.type == "tile-ghost" then
			-- TODO: cache items_to_place_this?
			local quality = ghost.quality
			local it = get_items_to_place_this(ghost)
			if it then
				local key = signal_lib.encode_signal_key(it.name, "item", quality)
				signal_counts[key] = (signal_counts[key] or 0) + (it.count or 1)
			end
		elseif ghost.type == "item-request-proxy" then
			for _, iqc in pairs(ghost.item_requests) do
				local key = signal_lib.encode_signal_key(iqc.name, "item", iqc.quality)
				signal_counts[key] = (signal_counts[key] or 0) + (iqc.count or 1)
			end
		end

		::continue::
	end

	strace.trace(
		"Combinator:update_signals: updating signals",
		self.thing_id,
		signal_counts
	)

	-- Send signals to the combinator's control behavior
	local signals, counts = signal_lib.spread_signal_counts(signal_counts)
	signal_lib.apply_simple_cccb(behavior, signals, counts)
end

event.register_dynamic_handler(
	"pke-meter-combinator-update",
	---@param comb PkeMeter.Combinator
	function(name, comb) comb:perform_deferred_update() end
)

---@param thing_id int64
---@return PkeMeter.Combinator?
function get_combinator(thing_id)
	if thing_id == nil then return nil end
	return storage.combinators[thing_id]
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------
---@param thing_id int64
---@param entity LuaEntity
local function make_real_combinator(thing_id, entity)
	if not get_combinator(thing_id) then
		local combinator = Combinator:new(thing_id)
		combinator.pos = entity.position
		combinator.force_index = entity.force.index
		storage.combinators[thing_id] = combinator
		combinator:set_surface_index(entity.surface.index)
	end
end

---@param thing_id int64
local function destroy_combinator(thing_id)
	local combinator = get_combinator(thing_id)
	if combinator then combinator:destroy() end
end

event.bind(
	"pke-meter-on_initialized",
	---@param thing things.EventData.on_initialized
	function(thing)
		if thing.status == "real" then
			make_real_combinator(thing.id, thing.entity --[[@as LuaEntity]])
		end
	end
)

event.bind(
	"pke-meter-on_status",
	---@param ev things.EventData.on_status
	function(ev)
		local new_status = ev.new_status
		if new_status == "real" then
			make_real_combinator(ev.thing.id, ev.thing.entity --[[@as LuaEntity]])
		else
			destroy_combinator(ev.thing.id)
		end
	end
)

return lib
