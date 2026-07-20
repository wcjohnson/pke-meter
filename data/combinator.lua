---@diagnostic disable: unresolved-require

local data_util = require("lib.core.data-util")
local things_registration = require("__0-things__.client.client") --[[@as things.client]]

--------------------------------------------------------------------------------
-- Combinator entity
--------------------------------------------------------------------------------
local sprite_path = "__pke-meter__/graphics/combinator.png"
local icon_path = "__pke-meter__/graphics/combinator-icon.png"

---@type data.ConstantCombinatorPrototype
local combinator = data_util.copy_prototype(
	data.raw["constant-combinator"]["constant-combinator"],
	"pke-meter-combinator"
)
combinator.minable = { mining_time = 0.5, result = "pke-meter-combinator" }
---@diagnostic disable-next-line: need-check-nil
combinator.sprites.east.layers[1].filename = sprite_path
combinator.sprites.west.layers[1].filename = sprite_path
---@diagnostic disable-next-line: need-check-nil
combinator.sprites.north.layers[1].filename = sprite_path
combinator.sprites.south.layers[1].filename = sprite_path
combinator.icon = icon_path

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
item.stack_size = 10
item.icon = icon_path

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
		{ type = "item", name = "electronic-circuit", amount = 10 },
		{ type = "item", name = "copper-cable", amount = 5 },
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
