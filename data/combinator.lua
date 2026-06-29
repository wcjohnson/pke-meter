local data_util = require("lib.core.data-util")
local things_registration = require("__0-things__.registration") --[[@as things.lib.Registration]]

--------------------------------------------------------------------------------
-- Combinator entity
-------------------------------------------------------------------------------

---@type data.ConstantCombinatorPrototype
local combinator = data_util.copy_prototype(
	data.raw["constant-combinator"]["constant-combinator"],
	"pke-meter-combinator"
)

data:extend({
	combinator,
})

things_registration.register({
	name = "pke-meter-combinator",
	intercept_construction = true,
})
