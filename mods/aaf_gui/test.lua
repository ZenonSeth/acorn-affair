-- Debug window for /guitest: the common elements in the theme, to see how they look on screen
local FORMNAME = "aaf_gui:test"
local W, H = 16, 10
local theme = aaf_gui.theme

local function elements()
	return table.concat({
		-- Column A: buttons, their state textures and inputs
		"label[0.5,1.8;Label (plain)]",
		"button[0.5,2.2;3.6,0.8;btn;Investigate]",
		"button_exit[0.5,3.2;3.6,0.8;btn_exit;Button exit]",
		"tooltip[btn;Tooltip text]",
		"image[0.5,4.2;1.1,0.6;aaf_gui_button.png;14]",
		"image[1.75,4.2;1.1,0.6;aaf_gui_button_hover.png;14]",
		"image[3.0,4.2;1.1,0.6;aaf_gui_button_pressed.png;14]",
		"checkbox[0.5,5.3;chk;Checkbox;true]",
		"dropdown[0.5,5.8;3.6,0.7;dd;Jenkins,Thompson,Miller,Fred;1]",
		aaf_gui.input_bg(0.5, 7.0, 3.6, 0.7),
		"field[0.5,7.0;3.6,0.7;fld;Field;text]",
		aaf_gui.input_bg(0.5, 8.1, 3.6, 1.3),
		"textarea[0.5,8.1;3.6,1.3;ta;;My notes\non two lines]",
		-- Column B: text, lists and the paper panel
		("hypertext[4.6,1.6;5,1.2;ht;<global color=%s><big>Hypertext</big> <b>bold</b> <i>italic</i> "
			.. "<style color=%s>accent</style> <style color=%s>muted</style>]"):format(theme.text, theme.accent,
			theme.muted),
		"tablecolumns[text]",
		"table[4.6,2.9;5,1.6;tb;Staff entry register,Miller's memo,Peanut shells,Fred's report;2]",
		aaf_gui.paper(4.6, 4.8, 5, 4.6),
		("hypertext[5.0,5.1;4.2,0.6;ph;<global size=20 color=%s>Case Notes]"):format(theme.ink),
		aaf_gui.underline(5.0, 5.7, 2.6),
		("hypertext[5.0,5.95;4.2,3.3;pt;<global color=%s><mono>Open drawers, missing pencils, a sandwich with "
			.. "a bite out of it. Miller is not amused.</mono>]"):format(theme.ink),
		-- Column C: portraits and tabs
		aaf_gui.portrait(10.4, 1.6, 2.4, "detective"),
		aaf_gui.portrait(13.1, 1.6, 2.4, "chief"),
		"label[10.4,4.3;Jack Graves]",
		"label[13.1,4.3;Arthur Harrington]",
		"scrollbar[10.4,5.0;5.1,0.4;horizontal;sb;300]",
		("box[10.4,5.8;1,0.5;%s]box[11.5,5.8;1,0.5;%s]box[12.6,5.8;1,0.5;%s]box[13.7,5.8;1,0.5;%s]"):format(
			theme.text, theme.muted, theme.accent, theme.slate),
		"button[10.4,8.6;5.1,0.8;wide;\\[Hang up\\]]",
	})
end

function aaf_gui.show_test(player_name)
	core.show_formspec(player_name, FORMNAME, aaf_gui.window(W, H, "GUI test") .. elements())
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then
		return
	end
	local parts = {}
	for key, value in pairs(fields) do
		parts[#parts + 1] = key .. "=" .. tostring(value)
	end
	table.sort(parts)
	core.chat_send_player(player:get_player_name(), "guitest: " .. table.concat(parts, ", "))
	return true
end)
