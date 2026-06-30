---@diagnostic disable: unresolved-require

local data_util = require("lib.core.data-util")
local things_registration = require("__0-things__.registration") --[[@as things.lib.Registration]]

--------------------------------------------------------------------------------
-- Combinator entity
--------------------------------------------------------------------------------

---@type data.ConstantCombinatorPrototype
local combinator = data_util.copy_prototype(
	data.raw["constant-combinator"]["constant-combinator"],
	"pke-meter-combinator"
)
combinator.minable = { mining_time = 0.5, result = "pke-meter-combinator" }

data:extend({
	combinator,
	{ type = "custom-event", name = "pke-meter-on_initialized" },
	{ type = "custom-event", name = "pke-meter-on_status" },
})

things_registration.register({
	name = "pke-meter-combinator",
	intercept_construction = true,
	custom_events = {
		on_initialized = "pke-meter-on_initialized",
		on_status = "pke-meter-on_status",
	},
})

--------------------------------------------------------------------------------
-- Combinator item
--------------------------------------------------------------------------------

---@type data.ItemPrototype
local item = data_util.copy_prototype(
	data.raw.item["constant-combinator"],
	"pke-meter-combinator"
)
item.place_result = "pke-meter-combinator"

data:extend({ item })

--------------------------------------------------------------------------------
-- Combinator recipe
--------------------------------------------------------------------------------

---@type data.RecipePrototype
local recipe = {
	type = "recipe",
	name = "pke-meter-combinator",
	hidden = false,
	enabled = false,
	energy_required = 30,
	ingredients = {
		{ type = "item", name = "electronic-circuit", amount = 8 },
		{ type = "item", name = "copper-cable", amount = 16 },
	},
	results = {
		{ type = "item", name = "pke-meter-combinator", amount = 1 },
	},
}

data:extend({ recipe })

--------------------------------------------------------------------------------
-- Combinator tech
--------------------------------------------------------------------------------
data_util.unlock_recipe_with_technology(
	"pke-meter-combinator",
	"advanced-combinators"
)
