local constants = aaf_utils.constants

local STORE_KEY = "aaf_places:place"
local DEFAULT_PLACE = "office"

-- place name -> {spawn = detective centre position on arrival}
local places = {}

function aaf_places.register(name, def)
	assert(type(name) == "string" and not places[name], "aaf_places: bad or duplicate place " .. tostring(name))
	assert(type(def) == "table" and def.spawn, "aaf_places: " .. name .. " needs a spawn position")
	places[name] = {spawn = vector.copy(def.spawn)}
end

for name, spawn in pairs(constants.places) do
	aaf_places.register(name, {spawn = spawn})
end
assert(places[DEFAULT_PLACE], "aaf_places: constants.places has no " .. DEFAULT_PLACE)

function aaf_places.exists(name)
	return places[name] ~= nil
end

-- The place's definition (a copy), or nil if there is none
function aaf_places.get_def(name)
	return places[name] and table.copy(places[name])
end

-- Where the detective is; places that are no longer registered read as the default
function aaf_places.get(player)
	local name = player:get_meta():get_string(STORE_KEY)
	return places[name] and name or DEFAULT_PLACE
end

-- place name -> {function(player)} run after the detective arrives there
local arrive_callbacks = {}

function aaf_places.register_on_arrive(name, fn)
	assert(places[name], "aaf_places: unknown place " .. tostring(name))
	arrive_callbacks[name] = arrive_callbacks[name] or {}
	table.insert(arrive_callbacks[name], fn)
end

-- Puts the detective at the place's spawn and records it; false if the place or the detective is missing
function aaf_places.move(player, name)
	local place = places[name]
	if not place or not aaf_avatar.teleport(player, place.spawn) then
		return false
	end
	player:get_meta():set_string(STORE_KEY, name == DEFAULT_PLACE and "" or name)
	for _, fn in ipairs(arrive_callbacks[name] or {}) do
		fn(player)
	end
	return true
end

-- Seconds of the fade to black, and of waiting for the map there before giving up on it
local FADE = 0.6
local MAP_TIMEOUT = 15
-- Extra black after the map is active, so the client has the blocks meshed
local SETTLE = 0.3
local EMERGE_RADIUS = vector.new(16, 16, 16)
local TRAVEL_FREEZE = "aaf_places"

-- player name -> {name = place, phase = "fade" | "black", t, ready, read, arrived, hud, alpha}
local trips = {}

local function black(alpha)
	return "[fill:8x8:#000000^[opacity:" .. alpha
end

function aaf_places.is_traveling(player)
	return trips[player:get_player_name()] ~= nil
end

-- Fades to black, shows the narration lines (if any) on it, moves the detective once the map there is
-- loaded, and drops the black when both are done; false if already traveling or the place is unknown
function aaf_places.travel(player, name, lines)
	local place = places[name]
	local pname = player:get_player_name()
	if not place or trips[pname] then
		return false
	end
	local trip = {
		name = name, phase = "fade", t = 0, ready = false, read = lines == nil, alpha = 0,
		hud = player:hud_add({
			type = "image", position = {x = 0.5, y = 0.5}, alignment = {x = 0, y = 0},
			scale = {x = -100, y = -100}, text = black(0), z_index = 1000,
		}),
	}
	trip.lines = lines
	core.emerge_area(vector.subtract(place.spawn, EMERGE_RADIUS), vector.add(place.spawn, EMERGE_RADIUS),
		function(_, _, remaining)
			if remaining == 0 then
				trip.ready = true
			end
		end)
	aaf_avatar.set_frozen(player, TRAVEL_FREEZE, true)
	trips[pname] = trip
	return true
end

local function finish(player, pname, trip)
	player:hud_remove(trip.hud)
	aaf_avatar.set_frozen(player, TRAVEL_FREEZE, false)
	trips[pname] = nil
end

core.register_globalstep(function(dtime)
	for pname, trip in pairs(trips) do
		local player = core.get_player_by_name(pname)
		if not player then
			trips[pname] = nil
		else
			trip.t = trip.t + dtime
			if trip.phase == "fade" then
				local alpha = math.floor(math.min(1, trip.t / FADE) * 255 + 0.5)
				if alpha ~= trip.alpha then
					trip.alpha = alpha
					player:hud_change(trip.hud, "text", black(alpha))
				end
				if trip.t >= FADE then
					trip.phase, trip.t = "black", 0
					if trip.lines then
						aaf_dialog.narrate(player, trip.lines, function()
							trip.read = true
						end)
					end
				end
			else
				if not trip.arrived and trip.ready and aaf_places.move(player, trip.name) then
					trip.arrived, trip.arrived_t = true, trip.t
				end
				local timed_out = trip.t >= MAP_TIMEOUT
				local loaded = trip.arrived and trip.t >= trip.arrived_t + SETTLE
					and core.compare_block_status(places[trip.name].spawn, "active")
				if trip.read and (loaded or timed_out) then
					finish(player, pname, trip)
				end
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	trips[player:get_player_name()] = nil
end)

-- A tagged thing's id in the detective's place, e.g. "office/aaf_props:safe#1", so each place numbers its own tags; nil when untagged
function aaf_places.thing_id(player, node)
	local id = aaf_utils.thing_id(node)
	return id and aaf_places.get(player) .. "/" .. id
end

-- place -> {thing key -> {label, on_interact, can_interact}}; the key is the node's thing id ("aaf_props:safe#30"),
-- or the bare node name for an untagged thing (matching every untagged copy in that place)
local things = {}

function aaf_places.register_thing(place, key, def)
	assert(places[place], "aaf_places: unknown place " .. tostring(place))
	assert(type(key) == "string", "aaf_places: bad thing key " .. tostring(key))
	things[place] = things[place] or {}
	assert(not things[place][key], "aaf_places: duplicate thing " .. place .. "/" .. key)
	assert(type(def) == "table" and (type(def.label) == "string" or type(def.label) == "function"),
		"aaf_places: " .. place .. "/" .. key .. " needs a label (string or function)")
	assert(type(def.on_interact) == "function", "aaf_places: " .. place .. "/" .. key .. " needs on_interact")
	assert(def.can_interact == nil or type(def.can_interact) == "function",
		"aaf_places: " .. place .. "/" .. key .. " can_interact must be a function")
	things[place][key] = def
end

local function thing_of(player, target)
	local list = target.type == "node" and things[aaf_places.get(player)]
	return list and list[aaf_utils.thing_id(target.node) or target.node.name]
end

-- The shared handler of nodes that are story things; it only matches things registered for the detective's place
aaf_interact.register("aaf_places:thing", {
	label = function(player, target)
		local label = thing_of(player, target).label
		return type(label) == "function" and label(player, target) or label
	end,
	can_interact = function(player, target)
		local thing = thing_of(player, target)
		return thing ~= nil and (not thing.can_interact or thing.can_interact(player, target))
	end,
	on_interact = function(player, target)
		thing_of(player, target).on_interact(player, target)
	end,
})
