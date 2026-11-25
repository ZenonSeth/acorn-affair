local constants = aaf_utils.constants

-- What just went into the notebook: a few HUD lines on a black band near the top of the screen
local POSITION = {x = 0.5, y = 0.12}
local COLOR = 0xE8D9B5
local BACKGROUND = "[fill:1x1:#000000D0"
local TEXT_SIZE = 1.2 * constants.hud_text_scale
-- Band size in HUD pixels; a character of the game font is about this wide at size 1
local CHAR_W = 10 * TEXT_SIZE
local LINE_HEIGHT = 24 * TEXT_SIZE
local PAD = 10 * TEXT_SIZE
local SECONDS = 3.5
local SECONDS_PER_LINE = 1
-- Added to the first toast a player ever sees
local TEACH_LINE = "(Open inventory to read the notebook)"
local TAUGHT_KEY = "aaf_notebook:taught"

-- player name -> {bg, text, lines, token}
local huds = {}

local function clear(player)
	local name = player:get_player_name()
	local hud = huds[name]
	if hud then
		player:hud_remove(hud.bg)
		player:hud_remove(hud.text)
		huds[name] = nil
	end
end

-- Shows lines (e.g. "Clue added: Staff entry register"); lines arriving while one is up join it
function aaf_notebook.notify(player, lines)
	if #lines == 0 then
		return
	end
	local name = player:get_player_name()
	local all = huds[name] and huds[name].lines or {}
	for _, line in ipairs(lines) do
		all[#all + 1] = line
	end
	local meta = player:get_meta()
	if meta:get_string(TAUGHT_KEY) == "" then
		meta:set_string(TAUGHT_KEY, "1")
		all[#all + 1] = TEACH_LINE
	end
	clear(player)
	local longest = 0
	for _, line in ipairs(all) do
		longest = math.max(longest, #line)
	end
	local hud = {lines = all, token = {}}
	hud.bg = player:hud_add({
		type = "image",
		position = POSITION,
		alignment = {x = 0, y = 0},
		scale = {x = longest * CHAR_W + PAD * 4, y = #all * LINE_HEIGHT + PAD * 2},
		text = BACKGROUND,
		z_index = 10,
	})
	hud.text = player:hud_add({
		type = "text",
		position = POSITION,
		alignment = {x = 0, y = 0},
		number = COLOR,
		size = {x = TEXT_SIZE, y = 0},
		text = table.concat(all, "\n"),
		z_index = 11,
	})
	huds[name] = hud
	local token = hud.token
	core.after(SECONDS + #all * SECONDS_PER_LINE, function()
		local p = core.get_player_by_name(name)
		if p and huds[name] and huds[name].token == token then
			clear(p)
		end
	end)
end

core.register_on_leaveplayer(function(player)
	huds[player:get_player_name()] = nil
end)
