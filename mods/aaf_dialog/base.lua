local FORM = "aaf_dialog:panel"
local FREEZE = "aaf_dialog"
local theme = aaf_gui.theme
local escape = aaf_gui.escape
local TALK_WIDTH = 16
local PAD = 0.5
local PORTRAIT = 3.2
local TEXT_HEIGHT = 1.9
local OPTION_HEIGHT = 0.75
local OPTION_GAP = 0.12

-- player name -> {kind = "narrate", lines, index, on_done} or {kind = "talk", def}
local open = {}

local function narrate_form(text)
	return table.concat({
		"formspec_version[6]",
		"size[16,9]",
		"bgcolor[#000000;true;#000000]",
		"hypertext[1.5,2;13,4.5;text;<global halign=center valign=middle size=22 color=", theme.text, ">",
		"<i>", escape(text), "</i>]",
		"button[6,7.2;4,0.8;next;Continue]",
	})
end

-- The dialogue box along the bottom of the screen: portrait, speaker, line, then the replies
local function talk_form(def)
	local x = def.portrait and PAD + PORTRAIT + 0.4 or PAD
	local w = TALK_WIDTH - x - PAD
	local y = 1.3 + TEXT_HEIGHT + 0.15
	local options = {}
	for i, option in ipairs(def.options) do
		options[#options + 1] = ("button[%g,%g;%g,%g;option%d;%s]"):format(x, y, w, OPTION_HEIGHT, i,
			core.formspec_escape(option.text))
		y = y + OPTION_HEIGHT + OPTION_GAP
	end
	local height = math.max(PAD * 2 + PORTRAIT, y - OPTION_GAP + PAD)
	return table.concat({
		"formspec_version[6]",
		("size[%g,%g]"):format(TALK_WIDTH, height),
		"position[0.5,0.97]",
		"anchor[0.5,1]",
		"bgcolor[#00000000;true;#00000050]",
		-- Escape and clicks outside the box (the engine treats both alike) cannot close it: pick an option
		"allow_close[false]",
		("background9[0,0;%g,%g;%s;false;%d]"):format(TALK_WIDTH, height, theme.window, theme.window_slice),
		def.portrait and aaf_gui.portrait(PAD, PAD, PORTRAIT, def.portrait) or "",
		("hypertext[%g,0.4;%g,0.6;speaker;<global size=20 color=%s>%s]"):format(x, w, theme.text,
			escape(def.speaker or "")),
		def.speaker and aaf_gui.underline(x, 0.98, 3) or "",
		("hypertext[%g,1.3;%g,%g;text;<global size=18 color=%s>%s]"):format(x, w, TEXT_HEIGHT, theme.text,
			escape(def.text)),
		table.concat(options),
	})
end

local function show(player, state)
	local name = player:get_player_name()
	open[name] = state
	aaf_avatar.set_frozen(player, FREEZE, true)
	if state.kind == "narrate" then
		core.show_formspec(name, FORM, narrate_form(state.lines[state.index]))
	else
		core.show_formspec(name, FORM, talk_form(state.def))
	end
end

-- Clears the panel without running any callback
function aaf_dialog.close(player)
	local name = player:get_player_name()
	if open[name] then
		open[name] = nil
		aaf_avatar.set_frozen(player, FREEZE, false)
		core.close_formspec(name, FORM)
	end
end

-- Ends the panel, runs fn, and only closes the window when fn did not open the next one
local function finish(player, fn)
	local name = player:get_player_name()
	open[name] = nil
	aaf_avatar.set_frozen(player, FREEZE, false)
	if fn then
		fn(player)
	end
	if not open[name] then
		core.close_formspec(name, FORM)
	end
end

function aaf_dialog.is_open(player)
	return open[player:get_player_name()] ~= nil
end

-- Full-screen black cards, one line each; on_done(player) runs after the last, or when Escape skips the rest
function aaf_dialog.narrate(player, lines, on_done)
	assert(type(lines) == "table" and #lines > 0, "aaf_dialog: narrate needs lines")
	show(player, {kind = "narrate", lines = lines, index = 1, on_done = on_done})
end

-- def = {speaker, portrait (aaf_gui portrait id), text, options = {{text, on_choose = function(player)}}};
-- on_choose may open the next panel; the box only closes through an option
function aaf_dialog.talk(player, def)
	assert(type(def.text) == "string" and type(def.options) == "table" and #def.options > 0,
		"aaf_dialog: talk needs text and options")
	show(player, {kind = "talk", def = def})
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORM then
		return
	end
	local state = open[player:get_player_name()]
	if not state then
		return true
	end
	if state.kind == "narrate" then
		if fields.next and state.index < #state.lines then
			state.index = state.index + 1
			show(player, state)
		elseif fields.next or fields.quit then
			finish(player, state.on_done)
		end
		return true
	end
	for i, option in ipairs(state.def.options) do
		if fields["option" .. i] then
			finish(player, option.on_choose)
			return true
		end
	end
	return true
end)

core.register_on_leaveplayer(function(player)
	open[player:get_player_name()] = nil
end)
