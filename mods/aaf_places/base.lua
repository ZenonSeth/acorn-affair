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

aaf_places.register(DEFAULT_PLACE, {spawn = constants.spawn_pos})

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

-- Puts the detective at the place's spawn and records it; false if the place or the detective is missing
function aaf_places.move(player, name)
	local place = places[name]
	if not place or not aaf_avatar.teleport(player, place.spawn) then
		return false
	end
	player:get_meta():set_string(STORE_KEY, name == DEFAULT_PLACE and "" or name)
	return true
end
