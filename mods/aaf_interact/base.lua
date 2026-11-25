-- Seconds between scans for the nearest interactable
local SCAN_INTERVAL = 0.1
-- Horizontal reach in nodes for "radius" things that set none
local DEFAULT_RADIUS = 1.5
-- How far above or below the detective's feet a "radius" thing may be
local VERTICAL_REACH = 1.5
local KEY_PREFIX = "[E] "
-- Shown while a low thing is in reach but the detective is standing
local LOW_HINT = "[Sneak] Look closer"
local GROUP = "aaf_interact"
local TEXT_SCALE = aaf_utils.constants.hud_text_scale

-- Better reach modes win ties of priority: standing on a thing beats standing next to it
local REACH_RANK = {inside = 3, adjacent = 2, radius = 1}
local DEFAULT_REACH = {node = "adjacent", object = "radius"}

-- id -> handler {label, on_interact, can_interact, reach, radius, priority, low}
local handlers = {}
local max_radius = DEFAULT_RADIUS

local function check_handler(def, what)
	assert(type(def) == "table", "aaf_interact: " .. what .. " has no handler table")
	assert(type(def.label) == "string" or type(def.label) == "function",
		"aaf_interact: " .. what .. " needs a label (string or function)")
	assert(type(def.on_interact) == "function", "aaf_interact: " .. what .. " needs on_interact")
	assert(def.can_interact == nil or type(def.can_interact) == "function",
		"aaf_interact: " .. what .. " can_interact must be a function")
	assert(def.reach == nil or REACH_RANK[def.reach], "aaf_interact: " .. what .. " has an unknown reach")
	assert(def.low == nil or type(def.low) == "boolean", "aaf_interact: " .. what .. " low must be a boolean")
end

function aaf_interact.register(id, def)
	assert(type(id) == "string" and not handlers[id], "aaf_interact: bad or duplicate id " .. tostring(id))
	check_handler(def, id)
	handlers[id] = def
end

-- A definition's `_aaf_interact` is a registered handler id or an inline handler table
local function resolve(field)
	if type(field) == "string" then
		return handlers[field]
	end
	return type(field) == "table" and field or nil
end

local function check_thing(def, name)
	local field = def._aaf_interact
	if type(field) == "string" then
		assert(handlers[field], "aaf_interact: " .. name .. " uses unknown handler " .. field)
	else
		check_handler(field, name)
	end
	local handler = resolve(field)
	assert(def._aaf_interact_reach == nil or REACH_RANK[def._aaf_interact_reach],
		"aaf_interact: " .. name .. " has an unknown _aaf_interact_reach")
	assert(def._aaf_interact_low == nil or type(def._aaf_interact_low) == "boolean",
		"aaf_interact: " .. name .. " _aaf_interact_low must be a boolean")
	max_radius = math.max(max_radius, def._aaf_interact_radius or handler.radius or 0)
end

core.register_on_mods_loaded(function()
	for name, def in pairs(core.registered_nodes) do
		if def._aaf_interact ~= nil then
			check_thing(def, name)
			local groups = table.copy(def.groups or {})
			groups[GROUP] = 1
			core.override_item(name, {groups = groups})
		end
	end
	for name, def in pairs(core.registered_entities) do
		if def._aaf_interact ~= nil then
			check_thing(def, name)
		end
	end
end)

local function horizontal_distance(a, b)
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

local function in_reach(reach, radius, cell, feet, pos)
	if reach == "radius" then
		return horizontal_distance(feet, pos) <= radius and math.abs(pos.y - feet.y) <= VERTICAL_REACH
	end
	local thing = vector.round(pos)
	if reach == "inside" then
		return vector.equals(thing, cell)
	end
	-- one cell up counts too, so things on a desk are in reach; the own cell for thin nodeboxes like doors
	if vector.equals(thing, cell) then
		return true
	end
	return (thing.y == cell.y or thing.y == cell.y + 1) and math.abs(thing.x - cell.x) + math.abs(thing.z - cell.z) == 1
end

-- Best candidate first: low things (only candidates while crouched), higher priority, better reach mode,
-- raised (on top of the thing next to it), nearer
local function better(a, b)
	if a.low ~= b.low then
		return a.low
	elseif a.priority ~= b.priority then
		return a.priority > b.priority
	elseif a.rank ~= b.rank then
		return a.rank > b.rank
	elseif a.raised ~= b.raised then
		return a.raised
	end
	return a.distance < b.distance
end

-- The thing the detective would use now ({target, handler, def, ...} or nil), and whether a low thing
-- is in reach that only crouching would reveal
function aaf_interact.find_target(player)
	local feet = aaf_avatar.get_pos(player)
	if not feet then
		return nil, false
	end
	-- The cell the detective stands in; feet sit on the floor's top face, so nudge them up into it
	local cell = vector.round(vector.offset(feet, 0, 0.1, 0))
	local crouching = aaf_avatar.is_crouching(player)
	local best
	local low_hidden = false

	local function consider(target, def, pos)
		local handler = resolve(def._aaf_interact)
		if not handler then
			return
		end
		local reach = def._aaf_interact_reach or handler.reach or DEFAULT_REACH[target.type]
		local radius = def._aaf_interact_radius or handler.radius or DEFAULT_RADIUS
		if not in_reach(reach, radius, cell, feet, pos)
				or (handler.can_interact and not handler.can_interact(player, target)) then
			return
		end
		local low = def._aaf_interact_low
		if low == nil then
			low = handler.low or false
		end
		if low and not crouching then
			low_hidden = true
			return
		end
		local candidate = {
			target = target, handler = handler, def = def, low = low,
			priority = def._aaf_interact_priority or handler.priority or 0,
			rank = REACH_RANK[reach], distance = horizontal_distance(feet, pos),
			raised = reach == "adjacent" and math.floor(pos.y + 0.5) > cell.y,
		}
		if not best or better(candidate, best) then
			best = candidate
		end
	end

	local r = math.ceil(max_radius)
	local nodes = core.find_nodes_in_area(vector.offset(cell, -r, -1, -r), vector.offset(cell, r, 1, r), "group:" .. GROUP)
	for _, pos in ipairs(nodes) do
		local node = core.get_node(pos)
		local def = core.registered_nodes[node.name]
		consider({type = "node", pos = pos, node = node, def = def}, def, pos)
	end
	for obj in core.objects_inside_radius(feet, max_radius + VERTICAL_REACH) do
		local entity = obj:get_luaentity()
		if entity and entity._aaf_interact ~= nil then
			consider({type = "object", object = obj, entity = entity}, entity, obj:get_pos())
		end
	end
	return best, low_hidden
end

local function label_of(player, found)
	local label = found.handler.label
	if type(label) == "function" then
		return label(player, found.target)
	end
	local name = found.def._aaf_name
	return name and (label .. " " .. name) or label
end

-- player name -> {hud, hint_hud = ids, text = shown prompt, hint = hint shown, aux1 = key held last step}
local states = {}

core.register_on_joinplayer(function(player)
	states[player:get_player_name()] = {
		text = "",
		hint = false,
		hud = player:hud_add({
			type = "text",
			position = {x = 0.5, y = 0.85},
			alignment = {x = 0, y = 0},
			number = 0xFFFFFF,
			size = {x = 1.5 * TEXT_SCALE, y = 0},
			style = 1,
			text = "",
		}),
		hint_hud = player:hud_add({
			type = "text",
			position = {x = 0.5, y = 0.85},
			offset = {x = 0, y = 40},
			alignment = {x = 0, y = 0},
			number = 0x9A9A9A,
			size = {x = TEXT_SCALE, y = 0},
			text = "",
		}),
	}
end)

core.register_on_leaveplayer(function(player)
	states[player:get_player_name()] = nil
end)

local function show_prompt(player, state, found, low_hidden)
	local text = found and (KEY_PREFIX .. label_of(player, found)) or ""
	if text ~= state.text then
		state.text = text
		player:hud_change(state.hud, "text", text)
	end
	if low_hidden ~= state.hint then
		state.hint = low_hidden
		player:hud_change(state.hint_hud, "text", low_hidden and LOW_HINT or "")
	end
end

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	local scan = timer >= SCAN_INTERVAL
	if scan then
		timer = 0
	end
	for _, player in ipairs(core.get_connected_players()) do
		local state = states[player:get_player_name()]
		if state then
			local aux1 = player:get_player_control().aux1
			local pressed = aux1 and not state.aux1
			state.aux1 = aux1
			if scan or pressed then
				local found, low_hidden = aaf_interact.find_target(player)
				if pressed and found then
					found.handler.on_interact(player, found.target)
					-- Using a thing may change or remove it
					found, low_hidden = aaf_interact.find_target(player)
				end
				show_prompt(player, state, found, low_hidden)
			end
		end
	end
end)
