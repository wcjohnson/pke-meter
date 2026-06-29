local class = require("lib.core.class").class

local lib = {}

---@class PkeMeter.Surface
---@field public index int
---@field public combinator_set {[int64]: true}
local Surface = class("PkeMeter.Surface")
lib.Surface = Surface

function Surface:new(index)
	local obj = {
		index = index,
		combinator_set = {},
	}
	return setmetatable(obj, self)
end

---@param index int
---@return PkeMeter.Surface?
function lib.get_surface_by_index(index)
	if index == nil then return nil end
	return storage.surfaces[index]
end

return lib
