local constants = {}

-- Top surface of the floor nodes is at floor_y + 0.5; rooms are on the second floor
constants.floor_y = 0

-- Top surface of the sidewalk and road is at street_y + 0.5, under a brick ground floor
constants.street_y = constants.floor_y - 4

-- Sites the mapgen places by minimum corner; the first schematic is forced, later ones only fill air
constants.sites = {
	office = {
		{schem = "office", origin = {x = -14, y = constants.street_y, z = -10}},
	},
	station = {
		{schem = "station", origin = {x = 590, y = constants.street_y, z = -10}},
	},
}

-- Open street where rain falls, as x/z rectangles (the building block stays dry)
constants.rain_areas = {
	{minp = {x = -14, z = -10}, maxp = {x = 18, z = -2}},
	{minp = {x = 10, z = -1}, maxp = {x = 18, z = 19}},
	{minp = {x = 590, z = 19}, maxp = {x = 637, z = 27}},
	{minp = {x = 590, z = -10}, maxp = {x = 598, z = 18}},
}

constants.spawn_pos = {x = 4, y = constants.floor_y + 1.5, z = 3}

-- Where the detective arrives in each place (its centre); the office one is the first spawn
constants.places = {
	office = constants.spawn_pos,
	station = {x = 604, y = constants.floor_y + 1.5, z = 2},
}

-- Multiplies every HUD text size; the game font (Federo) reads slightly small at the engine default
constants.hud_text_scale = 1.1

return constants
