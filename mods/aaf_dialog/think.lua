local constants = aaf_utils.constants

-- Jack's thoughts: a HUD line on a black band 3/4 down the screen that goes away by itself
local POSITION = {x = 0.5, y = 0.75}
local COLOR = 0xE8D9B5
local BACKGROUND = "[fill:1x1:#000000D0"
-- HUD text does not wrap, so lines are wrapped at this many characters
local WRAP = 60
-- Text size, matching the interaction prompt (aaf_interact)
local TEXT_SIZE = 1.4 * constants.hud_text_scale
-- Band size in HUD pixels; the width fits WRAP characters of the game font
local WIDTH = 600 * TEXT_SIZE
local LINE_HEIGHT = 24 * TEXT_SIZE
local PAD = 12 * TEXT_SIZE
local SECONDS_MIN = 3
local SECONDS_PER_CHAR = 0.06

-- player name -> {bg, text, token}
local huds = {}

local function wrap(text)
	local lines, line = {}, ""
	for word in text:gmatch("%S+") do
		if line ~= "" and #line + 1 + #word > WRAP then
			lines[#lines + 1] = line
			line = word
		else
			line = line == "" and word or line .. " " .. word
		end
	end
	lines[#lines + 1] = line
	return lines
end

local function clear(player)
	local hud = huds[player:get_player_name()]
	if hud then
		player:hud_remove(hud.bg)
		player:hud_remove(hud.text)
		huds[player:get_player_name()] = nil
	end
end

-- Shows one of the detective's own lines; a new one replaces the one on screen
function aaf_dialog.think(player, text)
	clear(player)
	local name = player:get_player_name()
	local lines = wrap(text)
	local hud = {token = {}}
	hud.bg = player:hud_add({
		type = "image",
		position = POSITION,
		alignment = {x = 0, y = 0},
		scale = {x = WIDTH, y = #lines * LINE_HEIGHT + PAD * 2},
		text = BACKGROUND,
		z_index = 10,
	})
	hud.text = player:hud_add({
		type = "text",
		position = POSITION,
		alignment = {x = 0, y = 0},
		number = COLOR,
		size = {x = TEXT_SIZE, y = 0},
		text = table.concat(lines, "\n"),
		z_index = 11,
	})
	huds[name] = hud
	local token = hud.token
	core.after(math.max(SECONDS_MIN, #text * SECONDS_PER_CHAR), function()
		local p = core.get_player_by_name(name)
		if p and huds[name] and huds[name].token == token then
			clear(p)
		end
	end)
end

core.register_on_leaveplayer(function(player)
	huds[player:get_player_name()] = nil
end)
