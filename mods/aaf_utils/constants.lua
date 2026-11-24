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
}

constants.spawn_pos = {x = 4, y = constants.floor_y + 1.5, z = 3}

-- Multiplies every HUD text size; the game font (Federo) reads slightly small at the engine default
constants.hud_text_scale = 1.1

return constants
