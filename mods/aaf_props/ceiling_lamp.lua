-- Connected nodebox: arms reach toward neighbouring lamps, so one node makes single lamps and bars

local GROUP = "aaf_props_ceiling_lamp"
local ON_TIME = {10, 20}
local OFF_TIME = {1, 2}

local function lamp_box()
	return {
		type = "connected",
		fixed = {-6/32, 12/32, -6/32, 6/32, 16/32, 6/32},
		connect_left = {-16/32, 12/32, -6/32, -6/32, 16/32, 6/32},
		connect_right = {6/32, 12/32, -6/32, 16/32, 16/32, 6/32},
		connect_front = {-6/32, 12/32, -16/32, 6/32, 16/32, -6/32},
		connect_back = {-6/32, 12/32, 6/32, 6/32, 16/32, 16/32},
	}
end

local function lamp_tiles(bottom)
	return {
		"aaf_props_ceiling_lamp_top.png", bottom or "aaf_props_ceiling_lamp_bottom.png",
		"aaf_props_ceiling_lamp_left.png", "aaf_props_ceiling_lamp_right.png",
		"aaf_props_ceiling_lamp_back.png", "aaf_props_ceiling_lamp_front.png",
	}
end

local function register_lamp(name, description, light, extra)
	local def = {
		description = description,
		drawtype = "nodebox",
		paramtype = "light",
		sunlight_propagates = true,
		light_source = light,
		tiles = lamp_tiles(),
		node_box = lamp_box(),
		selection_box = lamp_box(),
		walkable = false,
		connects_to = {"group:" .. GROUP},
		is_ground_content = false,
		groups = {cracky = 1, [GROUP] = 1},
	}
	for k, v in pairs(extra or {}) do
		def[k] = v
	end
	core.register_node("aaf_props:" .. name, def)
end

register_lamp("ceiling_lamp", "Ceiling lamp (bright)", 14)
register_lamp("ceiling_lamp_dim", "Ceiling lamp (dim)", 10)

-- Flickering: the lit and the dark variant swap with a node timer
local LIT = "aaf_props:ceiling_lamp_flicker"
local DARK = "aaf_props:ceiling_lamp_flicker_off"

local function start_timer(pos, range)
	core.get_node_timer(pos):start(range[1] + math.random() * (range[2] - range[1]))
end

local function flicker(pos)
	local node = core.get_node(pos)
	if node.name == LIT then
		node.name = DARK
		core.swap_node(pos, node)
		start_timer(pos, OFF_TIME)
	else
		node.name = LIT
		core.swap_node(pos, node)
		start_timer(pos, ON_TIME)
	end
	return false
end

register_lamp("ceiling_lamp_flicker", "Ceiling lamp (flickering)", 10, {
	on_construct = function(pos)
		start_timer(pos, ON_TIME)
	end,
	on_timer = flicker,
})
register_lamp("ceiling_lamp_flicker_off", "Ceiling lamp (flickering, off)", 0, {
	tiles = lamp_tiles("aaf_props_ceiling_lamp_off_bottom.png"),
	drop = LIT,
	groups = {cracky = 1, [GROUP] = 1, not_in_creative_inventory = 1},
	on_timer = flicker,
})

-- Schematics do not run on_construct, so make sure every flickering lamp has a timer
core.register_lbm({
	name = "aaf_props:ceiling_lamp_flicker_timer",
	nodenames = {LIT, DARK},
	run_at_every_load = true,
	action = function(pos)
		if not core.get_node_timer(pos):is_started() then
			start_timer(pos, ON_TIME)
		end
	end,
})
