local events = require("lib.core.event")

---@class (exact) PkeMeter.Storage
---@field public combinators {[int64]: PkeMeter.Combinator}
---@field public surfaces {[SurfaceIndex]: PkeMeter.Surface}
---@field public ghost_surfaces {[UnitNumber]: SurfaceIndex}
storage = {}

local function init_storage_key(key, value)
	if value == nil then value = {} end
	if storage[key] == nil then storage[key] = value end
end

function init_storage()
	init_storage_key("combinators")
	init_storage_key("surfaces")
	init_storage_key("ghost_surfaces")
end

-- Initialize storage on startup
events.bind("on_startup", init_storage, true)
