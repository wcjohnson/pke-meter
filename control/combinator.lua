local class = require("lib.core.class").class

local lib = {}

---@class PkeMeter.Combinator
---@field public thing_id int64
---@field public range_squared? number The square of the range (in Factorio map units/tiles) that this combinator can detect ghosts in. If not provided, reaches whole surface.
local Combinator = class("PkeMeter.Combinator")
lib.Combinator = Combinator

function Combinator:new(thing_id)
	local obj = {
		thing_id = thing_id,
		range_squared = nil,
	}
	return setmetatable(obj, self)
end

---@param thing_id int64
---@return PkeMeter.Combinator?
function lib.get_combinator(thing_id)
	if thing_id == nil then return nil end
	return storage.combinators[thing_id]
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

return lib
