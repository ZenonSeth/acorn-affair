local fill = aaf_utils.fill

core.register_node("aaf_world:floor", {
	description = "Floor",
	tiles = {fill("#5a4632")},
	is_ground_content = false,
	groups = {cracky = 1},
})

-- Wide textures span this many nodes, aligned to the world so neighbours line up
local WORLD_SCALE = 8

local function world_tile(name)
	return {name = name, align_style = "world", scale = WORLD_SCALE}
end

core.register_node("aaf_world:floor_wood", {
	description = "Floor (old planks)",
	-- dark sides: the floor edge shows from outside the room, below the one-way walls
	tiles = {world_tile("aaf_world_floor_wood.png"), fill("#1c1a18"), fill("#1c1a18")},
	is_ground_content = false,
	groups = {cracky = 1},
})

-- Rugs repeat every 2x2 nodes, aligned to even world coordinates; the _x / _z variants start on odd x / z
local RUG = "aaf_world_rug.png"
local RUG_VARIANTS = {
	{"", "", RUG},
	{"_x", ", starting on odd x", "[combine:64x64:-32,0=" .. RUG .. ":32,0=" .. RUG},
	{"_z", ", starting on odd z", "[combine:64x64:0,-32=" .. RUG .. ":0,32=" .. RUG},
}

for _, v in ipairs(RUG_VARIANTS) do
	core.register_node("aaf_world:floor_wood_rug" .. v[1], {
		description = "Floor (old planks) with a rug" .. v[2],
		tiles = {world_tile("aaf_world_floor_wood.png"), fill("#1c1a18"), fill("#1c1a18")},
		overlay_tiles = {{name = v[3], align_style = "world", scale = 2}, "", ""},
		is_ground_content = false,
		groups = {cracky = 1},
	})
end

-- One-way wall: only the front (-Z at param2 0) is drawn, culled from behind, so the camera sees through from outside
local function one_way_wall(name, description, front)
	front.backface_culling = true
	core.register_node(name, {
		description = description,
		drawtype = "nodebox",
		node_box = {type = "regular"},
		paramtype = "light",
		paramtype2 = "4dir",
		sunlight_propagates = true,
		use_texture_alpha = "clip",
		tiles = {"blank.png", "blank.png", "blank.png", "blank.png", "blank.png", front},
		is_ground_content = false,
		groups = {cracky = 1},
	})
end

one_way_wall("aaf_world:wall", "Wall (placeholder)", {name = fill("#3b3f4a")})
one_way_wall("aaf_world:wallpaper", "Wall (striped wallpaper)", world_tile("aaf_world_wallpaper.png"))
-- Per node, so the chair rail stays at the top of the bottom row
one_way_wall("aaf_world:wall_panel", "Wall (wood panelling, bottom row)", {name = "aaf_world_wall_panel.png"})

-- Fills spaces that are never meant to be seen (rooms behind deco doors); black under any light
core.register_node("aaf_world:void", {
	description = "Void (pure black)",
	tiles = {fill("#000000")},
	is_ground_content = false,
	groups = {cracky = 1},
})

-- Outside: the brick ground floor under each building, street and trees
local BRICK = world_tile("aaf_world_brick.png")
local COPING = "aaf_world_coping.png"
local GROUND_SIDE = fill("#1c1c1e")

core.register_node("aaf_world:brick", {
	description = "Brick (ground floor outside)",
	tiles = {COPING, BRICK, BRICK},
	is_ground_content = false,
	groups = {cracky = 1},
})

-- Brick with a painted front (-Z at param2 0) facing the street
local function brick_front(name, description, front, light)
	core.register_node(name, {
		description = description,
		paramtype2 = "4dir",
		tiles = {COPING, BRICK, BRICK, BRICK, BRICK, front},
		light_source = light,
		is_ground_content = false,
		groups = {cracky = 1},
	})
end

brick_front("aaf_world:brick_window", "Brick with a dark street window", "aaf_world_street_window.png")
brick_front("aaf_world:brick_window_lit", "Brick with a lit street window", "aaf_world_street_window_lit.png", 4)
-- Double door, 2x2; seen from the street, l is on the left
for _, part in ipairs({"bl", "br", "tl", "tr"}) do
	brick_front("aaf_world:street_door_" .. part, "Street double door (" .. part .. ")",
		"aaf_world_street_door_" .. part .. ".png")
end

-- Facade shell: brick only on the street side(s), black elsewhere (roof included)
local BLACK = fill("#000000")

core.register_node("aaf_world:facade", {
	description = "Brick facade (brick front, black elsewhere)",
	paramtype2 = "4dir",
	tiles = {BLACK, BLACK, BLACK, BLACK, BLACK, BRICK},
	is_ground_content = false,
	groups = {cracky = 1},
})

-- Outer corner: brick on the front (-Z at param2 0) and the left (-X at param2 0)
core.register_node("aaf_world:facade_corner", {
	description = "Brick facade, outer corner (brick front and left)",
	paramtype2 = "4dir",
	tiles = {BLACK, BLACK, BLACK, BRICK, BLACK, BRICK},
	is_ground_content = false,
	groups = {cracky = 1},
})

core.register_node("aaf_world:sidewalk", {
	description = "Sidewalk",
	tiles = {world_tile("aaf_world_sidewalk.png"), GROUND_SIDE, GROUND_SIDE},
	is_ground_content = false,
	groups = {cracky = 1},
})

core.register_node("aaf_world:road", {
	description = "Road",
	tiles = {world_tile("aaf_world_road.png"), GROUND_SIDE, GROUND_SIDE},
	is_ground_content = false,
	groups = {cracky = 1},
})

core.register_node("aaf_world:tree_pit", {
	description = "Sidewalk tree pit (trunk goes on top)",
	tiles = {"aaf_world_tree_pit.png", GROUND_SIDE, GROUND_SIDE},
	is_ground_content = false,
	groups = {cracky = 1},
})

core.register_node("aaf_world:leaves", {
	description = "Leaves",
	drawtype = "allfaces_optional",
	tiles = {"aaf_world_leaves.png"},
	use_texture_alpha = "clip",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	is_ground_content = false,
	groups = {cracky = 1},
})

-- Worlds made without the main menu (e.g. a dedicated server) do not get the game's default_mapgen
core.set_mapgen_setting("mg_name", "singlenode", true)

-- Singlenode never places these, but the engine checks them at startup
core.register_alias("mapgen_stone", "aaf_world:wall")
core.register_alias("mapgen_water_source", "air")
core.register_alias("mapgen_river_water_source", "air")

core.register_mapgen_script(aaf_world.modpath .. "/mapgen.lua")
