local parts = aaf_props.parts

-- id -> name shown in the prompt; each id gets its own nodes, since schematics keep no node meta
local DOORS = {
	door = "Door",
	kitchen = "Kitchen door",
	reception = "Reception door",
	chief = "Chief's door",
	storage = "Storage door",
}

-- node name -> {id, half, open}
local node_info = {}
-- id -> function(player): true lets the door open, a string is the detective's line instead
local rules = {}

local function node_name(id, half, open)
	return "aaf_doors:" .. id .. "_" .. half .. (open and "_open" or "")
end

function aaf_doors.set_rule(id, rule)
	assert(DOORS[id], "aaf_doors: unknown door " .. tostring(id))
	assert(rule == nil or type(rule) == "function", "aaf_doors: a rule must be a function")
	rules[id] = rule
end

function aaf_doors.exists(id)
	return DOORS[id] ~= nil
end

-- The detective's own lines
local function say(player, text)
	aaf_dialog.think(player, text)
end

local function set_open(pos, id, open, param2)
	core.swap_node(pos, {name = node_name(id, "bottom", open), param2 = param2})
	local top_pos = vector.offset(pos, 0, 1, 0)
	local top = node_info[core.get_node(top_pos).name]
	if top and top.id == id and top.half == "top" then
		core.swap_node(top_pos, {name = node_name(id, "top", open), param2 = param2})
	end
end

aaf_interact.register("aaf_doors:door", {
	label = function(player, target)
		local info = node_info[target.node.name]
		return (info.open and "Close " or "Open ") .. DOORS[info.id]
	end,
	on_interact = function(player, target)
		local info = node_info[target.node.name]
		if not info.open and rules[info.id] then
			local result = rules[info.id](player)
			if result ~= true then
				if type(result) == "string" then
					say(player, result)
				end
				return
			end
		end
		set_open(target.pos, info.id, not info.open, target.node.param2)
		-- The listener is the camera, about 8 nodes away, and positional gain falls off as 3 / distance
		aaf_audio.sfx.play(info.open and "door_close" or "door_open", {pos = vector.offset(target.pos, 0, 1, 0), gain = 2.5})
	end,
})

local function register_half(id, half, open)
	local part = parts["leaf_" .. half .. (open and "_open" or "")]
	local box = {type = "fixed", fixed = part.boxes}
	local def = {
		description = DOORS[id] .. ", " .. half .. (open and ", open" or ""),
		drawtype = "nodebox",
		paramtype = "light",
		paramtype2 = "4dir",
		sunlight_propagates = true,
		node_box = box,
		collision_box = box,
		tiles = part.tiles,
		is_ground_content = false,
		groups = {cracky = 1},
	}
	if half == "bottom" then
		def._aaf_interact = "aaf_doors:door"
	end
	local name = node_name(id, half, open)
	node_info[name] = {id = id, half = half, open = open}
	core.register_node(name, def)
end

for id, description in pairs(DOORS) do
	for _, half in ipairs({"bottom", "top"}) do
		register_half(id, half, false)
		register_half(id, half, true)
	end
	-- Placer: a closed door, bottom on the pointed cell and top above, front toward the placer
	core.register_craftitem("aaf_doors:" .. id, {
		description = description .. " (opens)",
		inventory_image = parts.leaf_bottom.tiles[6],
		on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type ~= "node" or not placer then
				return itemstack
			end
			local pos = pointed_thing.above
			local top_pos = vector.offset(pos, 0, 1, 0)
			for _, p in ipairs({pos, top_pos}) do
				local def = core.registered_nodes[core.get_node(p).name]
				if not def or not def.buildable_to then
					return itemstack
				end
			end
			local param2 = core.dir_to_fourdir(placer:get_look_dir())
			core.set_node(pos, {name = node_name(id, "bottom", false), param2 = param2})
			core.set_node(top_pos, {name = node_name(id, "top", false), param2 = param2})
			return itemstack
		end,
	})
end
