local constants = {}

-- Top surface of the floor nodes is at floor_y + 0.5
constants.floor_y = 0

-- The detective's office schematic is placed with its minimum corner here (its floor layer at floor_y)
constants.office = {origin = {x = -1, y = constants.floor_y, z = -1}}

constants.spawn_pos = {x = 4, y = constants.floor_y + 1.5, z = 3}

-- Multiplies every HUD text size; the game font (Federo) reads slightly small at the engine default
constants.hud_text_scale = 1.1

return constants
