local parts = dofile(aaf_props.modpath .. "/parts.lua")

local FULL_BOX = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}
-- only the chair back blocks, so the detective can walk through the seat
local CHAIR_BACK = {type = "fixed", fixed = {-9/32, -0.5, 8/32, 9/32, 14/32, 11/32}}
local COAT_RACK_POLE = {type = "fixed", fixed = {-3/32, -0.5, -3/32, 3/32, 0.5, 3/32}}
-- bounding box of the bookshelf body, from the .nbx tool's selection box
local BOOKSHELF_BOX = {type = "fixed", fixed = {-0.5, -0.5, -8/32, 0.5, 0.5, 0.5}}
-- the closed safe's bounding box; the open one uses it too, so its door does not block
local SAFE_BOX = {type = "fixed", fixed = {-10/32, -0.5, -1/32, 10/32, 8/32, 0.5}}
local WASTEBASKET_BOX = {type = "fixed", fixed = {-8/32, -0.5, -8/32, 8/32, 0, 8/32}}
-- plants block only at their pots
local SMALL_POT_BOX = {type = "fixed", fixed = {-7/32, -0.5, -7/32, 7/32, -4/32, 7/32}}
local BIG_POT_BOX = {type = "fixed", fixed = {-9/32, -0.5, -9/32, 9/32, 2/32, 9/32}}
local BASKET_BOX = {type = "fixed", fixed = {-8/32, -0.5, -8/32, 8/32, 0, 8/32}}
local BLANK = "blank.png"

-- node -> {description, part (generated shape, default the node name), walkable (default true),
-- collision (default the full cell; "boxes" = the node boxes), light, drop, flat = texture alpha mode of a one-way,
-- front-only part}
local PART_DEFS = {
	desk_l = {"Desk, left half"},
	desk_l_papers = {"Desk with papers, left half"},
	desk_r = {"Desk, right half"},
	desk_r_papers = {"Desk with papers, right half"},
	desk_r_keys = {"Desk with keys underneath, right half"},
	chair = {"Office chair", collision = CHAIR_BACK},
	phone = {"Telephone", walkable = false},
	phone_mug = {"Telephone and coffee mug", walkable = false},
	typewriter = {"Typewriter", walkable = false},
	lamp = {"Desk lamp", walkable = false, light = 10},
	cabinet_bottom = {"Filing cabinet (small, or the bottom of a tall one)"},
	cabinet_top = {"Filing cabinet, top"},
	cabinet_top_open = {"Filing cabinet, top, drawer out"},
	cabinet_drawer = {"Filing cabinet drawer, pulled out", walkable = false},
	coat_rack_bottom = {"Coat rack, bottom", collision = COAT_RACK_POLE},
	coat_rack_top = {"Coat rack, top", collision = COAT_RACK_POLE},
	wastebasket = {"Wastebasket", collision = WASTEBASKET_BOX},
	keys = {"Keys", walkable = false},
	board_l = {"Clipping board, left half", walkable = false},
	board_r = {"Clipping board, right half", walkable = false},
	board_l_plain = {"Notice board, left half", walkable = false},
	board_r_plain = {"Notice board, right half", walkable = false},
	bookshelf_bottom = {"Bookshelf, empty, bottom", collision = BOOKSHELF_BOX},
	bookshelf_top = {"Bookshelf, empty, top", collision = BOOKSHELF_BOX},
	bookshelf_full_bottom = {"Bookshelf, bottom", collision = BOOKSHELF_BOX},
	bookshelf_full_top = {"Bookshelf, top", collision = BOOKSHELF_BOX},
	certificate = {"Framed certificate, red seal", walkable = false},
	certificate_blue = {"Framed certificate, blue ribbon", walkable = false},
	plaque_silver = {"Wall plaque, silver", walkable = false},
	plaque_gold = {"Wall plaque, gold", walkable = false},
	painting_umbrella = {"Painting: red umbrella", walkable = false},
	painting_flower = {"Painting: yellow flower", walkable = false},
	painting_city_l = {"Painting: night city, left half", walkable = false},
	painting_city_r = {"Painting: night city, right half", walkable = false},
	painting_harbor_l = {"Painting: harbour, left half", walkable = false},
	painting_harbor_r = {"Painting: harbour, right half", walkable = false},
	safe = {"Safe", collision = SAFE_BOX},
	safe_open = {"Safe, open", collision = SAFE_BOX},
	clock = {"Wall clock", walkable = false},
	plant_fern = {"Potted plant, bushy", collision = SMALL_POT_BOX},
	plant_snake = {"Potted snake plant", collision = SMALL_POT_BOX},
	plant_rubber_bottom = {"Rubber plant, bottom", collision = BIG_POT_BOX},
	plant_rubber_top = {"Rubber plant, top", walkable = false},
	plant_palm_bottom = {"Palm in a basket, bottom", collision = BASKET_BOX},
	plant_palm_top = {"Palm in a basket, top", walkable = false},
	door_bottom = {"Door, bottom", flat = "clip"},
	door_top = {"Door, top", flat = "clip"},
	door_open_bottom = {"Open doorway, bottom", flat = "clip", walkable = false},
	door_open_top = {"Open doorway, top", flat = "clip", walkable = false},
	window_bottom = {"Window, bottom", flat = "blend"},
	window_top = {"Window, top", flat = "blend"},
	window_blinds_bottom = {"Window with blinds, bottom", flat = "blend"},
	window_blinds_top = {"Window with blinds, top", flat = "blend"},
	wall_lamp = {"Wall lamp", walkable = false, light = 5},
	wall_lamp_flicker = {"Wall lamp, flickering", part = "wall_lamp", walkable = false, light = 5},
	wall_lamp_flicker_dim = {"Wall lamp, flickering (dimmed)", part = "wall_lamp", walkable = false, light = 2,
		drop = "aaf_props:wall_lamp_flicker"},
	sofa_l = {"Sofa, brown leather, left half"},
	sofa_r = {"Sofa, brown leather, right half"},
	sofa_l_teal = {"Sofa, teal, left half"},
	sofa_r_teal = {"Sofa, teal, right half"},
	sofa_l_plum = {"Sofa, plum, left half"},
	sofa_r_plum = {"Sofa, plum, right half"},
}

-- Placer item -> {description, {part, right, up, forward}...}; forward -1 is the cell in front of the set
local SETS = {
	desk = {"Desk", {"desk_l", 0, 0, 0}, {"desk_r", 1, 0, 0}},
	desk_papers = {"Desk with papers", {"desk_l_papers", 0, 0, 0}, {"desk_r_papers", 1, 0, 0}},
	desk_keys = {"Desk with keys underneath", {"desk_l", 0, 0, 0}, {"desk_r_keys", 1, 0, 0}},
	cabinet = {"Filing cabinet", {"cabinet_bottom", 0, 0, 0}, {"cabinet_top", 0, 1, 0}},
	cabinet_open = {"Filing cabinet, drawer out",
		{"cabinet_bottom", 0, 0, 0}, {"cabinet_top_open", 0, 1, 0}, {"cabinet_drawer", 0, 1, -1}},
	coat_rack = {"Coat rack", {"coat_rack_bottom", 0, 0, 0}, {"coat_rack_top", 0, 1, 0}},
	board = {"Clipping board", {"board_l", 0, 0, 0}, {"board_r", 1, 0, 0}},
	board_plain = {"Notice board", {"board_l_plain", 0, 0, 0}, {"board_r_plain", 1, 0, 0}},
	bookshelf = {"Bookshelf, empty", {"bookshelf_bottom", 0, 0, 0}, {"bookshelf_top", 0, 1, 0}},
	bookshelf_full = {"Bookshelf", {"bookshelf_full_bottom", 0, 0, 0}, {"bookshelf_full_top", 0, 1, 0}},
	painting_city = {"Painting: night city", {"painting_city_l", 0, 0, 0}, {"painting_city_r", 1, 0, 0}},
	painting_harbor = {"Painting: harbour", {"painting_harbor_l", 0, 0, 0}, {"painting_harbor_r", 1, 0, 0}},
	plant_rubber = {"Rubber plant", {"plant_rubber_bottom", 0, 0, 0}, {"plant_rubber_top", 0, 1, 0}},
	plant_palm = {"Palm in a basket", {"plant_palm_bottom", 0, 0, 0}, {"plant_palm_top", 0, 1, 0}},
	door = {"Door", {"door_bottom", 0, 0, 0}, {"door_top", 0, 1, 0}},
	door_open = {"Open doorway", {"door_open_bottom", 0, 0, 0}, {"door_open_top", 0, 1, 0}},
	window = {"Window", {"window_bottom", 0, 0, 0}, {"window_top", 0, 1, 0}},
	window_blinds = {"Window with blinds", {"window_blinds_bottom", 0, 0, 0}, {"window_blinds_top", 0, 1, 0}},
	sofa = {"Sofa, brown leather", {"sofa_l", 0, 0, 0}, {"sofa_r", 1, 0, 0}},
	sofa_teal = {"Sofa, teal", {"sofa_l_teal", 0, 0, 0}, {"sofa_r_teal", 1, 0, 0}},
	sofa_plum = {"Sofa, plum", {"sofa_l_plum", 0, 0, 0}, {"sofa_r_plum", 1, 0, 0}},
}

for name, def in pairs(PART_DEFS) do
	local part = assert(parts[def.part or name], "aaf_props: no generated part " .. (def.part or name))
	local walkable = def.walkable ~= false
	local node = {
		description = def[1],
		drawtype = "nodebox",
		paramtype = "light",
		paramtype2 = "4dir",
		sunlight_propagates = true,
		is_ground_content = false,
		groups = {cracky = 1},
		walkable = walkable,
		light_source = def.light,
		drop = def.drop,
	}
	if def.flat then
		node.node_box = {type = "regular"}
		node.use_texture_alpha = def.flat
		node.tiles = {BLANK, BLANK, BLANK, BLANK, BLANK, {name = part.tiles[1], backface_culling = true}}
	else
		node.node_box = {type = "fixed", fixed = part.boxes}
		if walkable and def.collision ~= "boxes" then
			node.collision_box = def.collision or FULL_BOX
		end
		node.tiles = part.tiles
	end
	core.register_node("aaf_props:" .. name, node)
end

-- degrotate steps (1.5 degrees each) per rotation, and per placement snap
local ROTATE_STEP = 10
-- collision boxes do not turn with degrotate, so this one is centred
local ROTATABLE_CHAIR_BOX = {type = "fixed", fixed = {-9/32, -0.5, -9/32, 9/32, 14/32, 9/32}}

core.register_node("aaf_props:chair_rotatable", {
	description = "Office chair (free rotation)",
	drawtype = "mesh",
	mesh = "aaf_props_chair_rotatable.obj",
	tiles = {"aaf_props_chair_rotatable.png"},
	paramtype = "light",
	paramtype2 = "degrotate",
	sunlight_propagates = true,
	is_ground_content = false,
	groups = {cracky = 1},
	selection_box = ROTATABLE_CHAIR_BOX,
	collision_box = ROTATABLE_CHAIR_BOX,
	after_place_node = function(pos, placer)
		if not placer then
			return
		end
		-- front faces the placer; degrotate turns the -Z front to (sin a, -cos a)
		local look = placer:get_look_dir()
		local steps = math.deg(math.atan2(-look.x, look.z)) / 1.5
		local param2 = (math.floor(steps / ROTATE_STEP + 0.5) * ROTATE_STEP) % 240
		core.swap_node(pos, {name = "aaf_props:chair_rotatable", param2 = param2})
	end,
})

local function rotate_pointed(pointed_thing, steps)
	if pointed_thing.type ~= "node" then
		return
	end
	local pos = pointed_thing.under
	local node = core.get_node(pos)
	local def = core.registered_nodes[node.name]
	if def and def.paramtype2 == "degrotate" then
		node.param2 = (node.param2 + steps) % 240
		core.swap_node(pos, node)
	end
end

core.register_tool("aaf_props:rotator", {
	description = "Rotator: punch turns a freely rotating prop 15 degrees one way, place turns it back",
	inventory_image = "aaf_props_rotator.png",
	range = 10,
	on_use = function(itemstack, user, pointed_thing)
		rotate_pointed(pointed_thing, ROTATE_STEP)
		return itemstack
	end,
	on_place = function(itemstack, placer, pointed_thing)
		rotate_pointed(pointed_thing, -ROTATE_STEP)
		return itemstack
	end,
	on_secondary_use = function(itemstack)
		return itemstack
	end,
})

local FLICKER_LIT = "aaf_props:wall_lamp_flicker"
local FLICKER_DIM = "aaf_props:wall_lamp_flicker_dim"

local function flicker_restore(pos)
	local node = core.get_node(pos)
	if node.name == FLICKER_DIM then
		core.swap_node(pos, {name = FLICKER_LIT, param2 = node.param2})
	end
end

local function flicker(pos, blinks)
	local node = core.get_node(pos)
	if node.name ~= FLICKER_LIT then
		return
	end
	core.swap_node(pos, {name = FLICKER_DIM, param2 = node.param2})
	local dim_time = 0.05 + math.random() * 0.15
	core.after(dim_time, flicker_restore, pos)
	if blinks > 1 then
		core.after(dim_time + 0.05 + math.random() * 0.1, flicker, pos, blinks - 1)
	end
end

core.register_abm({
	label = "Flicker wall lamps",
	nodenames = {FLICKER_LIT},
	interval = 1,
	chance = 6,
	catch_up = false,
	action = function(pos)
		flicker(pos, math.random(1, 3))
	end,
})

-- a shutdown mid-flicker would otherwise leave the lamp dim
core.register_lbm({
	label = "Relight dimmed wall lamps",
	name = "aaf_props:relight_wall_lamps",
	nodenames = {FLICKER_DIM},
	run_at_every_load = true,
	action = flicker_restore,
})

local function set_cells(set, pos, param2)
	local forward = core.fourdir_to_dir(param2)
	local right = vector.new(forward.z, 0, -forward.x)
	local cells = {}
	for i = 2, #set do
		local p = set[i]
		local across = vector.add(vector.multiply(right, p[2]), vector.multiply(forward, p[4]))
		cells[#cells + 1] = {pos = vector.add(vector.offset(pos, 0, p[3], 0), across), name = "aaf_props:" .. p[1]}
	end
	return cells
end

-- Places a whole set with its front facing param2's opposite (param2 0: front faces -Z); false if a cell is taken
function aaf_props.place(set_name, pos, param2)
	local set = assert(SETS[set_name], "aaf_props: unknown set " .. tostring(set_name))
	local cells = set_cells(set, pos, param2)
	for _, cell in ipairs(cells) do
		local def = core.registered_nodes[core.get_node(cell.pos).name]
		if not def or not def.buildable_to then
			return false
		end
	end
	for _, cell in ipairs(cells) do
		core.set_node(cell.pos, {name = cell.name, param2 = param2})
	end
	return true
end

for set_name, set in pairs(SETS) do
	local tiles = parts[set[2][1]].tiles
	core.register_craftitem("aaf_props:" .. set_name, {
		description = set[1],
		inventory_image = tiles[6] or tiles[1],
		on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type == "node" and placer then
				aaf_props.place(set_name, pointed_thing.above, core.dir_to_fourdir(placer:get_look_dir()))
			end
			return itemstack
		end,
	})
end
