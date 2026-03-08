---@diagnostic disable: undefined-global, undefined-field, undefined-doc-name

local events = require("lib.core.event")

---@alias PkeMeter.LogisticNetworkId integer
---@alias PkeMeter.DestroyRegistrationNumber integer

---@class PkeMeter.TrackedGhost
---@field unit_number integer
---@field logistic_network_ids PkeMeter.LogisticNetworkId[]
---@field item_name string?
---@field destroy_registration_number PkeMeter.DestroyRegistrationNumber

---@class PkeMeter.Storage
---@field tracked_ghosts_by_unit table<integer, PkeMeter.TrackedGhost>
---@field unit_by_destroy_registration table<PkeMeter.DestroyRegistrationNumber, integer>

---@return PkeMeter.Storage
local function get_pke_storage()
	if not storage.pke_meter then
		storage.pke_meter = {
			tracked_ghosts_by_unit = {},
			unit_by_destroy_registration = {},
		}
	end
	return storage.pke_meter
end

---@param entity LuaEntity?
---@return LuaEntity?
local function get_supported_ghost_entity(entity)
	if not (entity and entity.valid) then return nil end
	if entity.name ~= "entity-ghost" then return nil end
	if not entity.unit_number then return nil end
	return entity
end

---@param ghost LuaEntity
---@return string?
local function resolve_item_name_for_ghost(ghost)
	local ghost_prototype = ghost.ghost_prototype
	if not ghost_prototype then return nil end

	local place_items = ghost_prototype.items_to_place_this
	local first_item = place_items and place_items[1]
	if not first_item then return nil end
	return first_item.name
end

---@param ghost LuaEntity
---@return PkeMeter.LogisticNetworkId[]
local function find_candidate_network_ids(ghost)
	local ids = {}
	local networks = ghost.surface.find_logistic_networks_by_construction_area(
		ghost.position,
		ghost.force
	)

	for i = 1, #networks do
		local network_id = networks[i].network_id
		if network_id then
			ids[#ids + 1] = network_id
		end
	end

	return ids
end

---@param ghost LuaEntity
local function track_ghost(ghost)
	local ghost_entity = get_supported_ghost_entity(ghost)
	if not ghost_entity then return end

	local unit_number = ghost_entity.unit_number
	if not unit_number then return end

	local pke = get_pke_storage()
	local previous = pke.tracked_ghosts_by_unit[unit_number]
	if previous then
		pke.unit_by_destroy_registration[previous.destroy_registration_number] = nil
	end

	local destroy_registration_number = script.register_on_object_destroyed(ghost_entity)
	pke.tracked_ghosts_by_unit[unit_number] = {
		unit_number = unit_number,
		logistic_network_ids = find_candidate_network_ids(ghost_entity),
		item_name = resolve_item_name_for_ghost(ghost_entity),
		destroy_registration_number = destroy_registration_number,
	}
	pke.unit_by_destroy_registration[destroy_registration_number] = unit_number
end

---@param registration_number PkeMeter.DestroyRegistrationNumber
local function untrack_ghost_by_registration(registration_number)
	local pke = get_pke_storage()
	local unit_number = pke.unit_by_destroy_registration[registration_number]
	if not unit_number then return end

	pke.unit_by_destroy_registration[registration_number] = nil
	pke.tracked_ghosts_by_unit[unit_number] = nil
end

---@param event_data EventData.on_built_entity|EventData.on_robot_built_entity|EventData.script_raised_built|EventData.script_raised_revive
local function on_ghost_built(event_data)
	track_ghost(event_data.created_entity or event_data.entity)
end

---@param event_data EventData.on_object_destroyed
local function on_object_destroyed(event_data)
	untrack_ghost_by_registration(event_data.registration_number)
end

---@param _reset_data Core.ResetData
local function on_startup(_reset_data)
	get_pke_storage()
end

events.bind("on_startup", on_startup)
events.bind(
	{
		defines.events.on_built_entity,
		defines.events.on_robot_built_entity,
		defines.events.script_raised_built,
		defines.events.script_raised_revive,
	},
	on_ghost_built
)
events.bind(defines.events.on_object_destroyed, on_object_destroyed)
