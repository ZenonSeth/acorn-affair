-- The one formspec theme (noir: near-black panels, worn cream rules, red accent). Textures from tools/gen_gui.py
local TEXT = "#E8D9B5"
local INK = "#0D0D0F"
-- Multiplies the player's font size in every themed formspec
local FONT_SCALE = 1.25

local theme = {
	text = TEXT,
	ink = INK,
	-- Greyed-out text and secondary lines
	muted = "#7A6A58",
	-- The one accent: underlines, the selected thing
	accent = "#A6453D",
	slate = "#405261",
	-- 9-slice middles are in texture pixels, which draw 1:1 on screen
	window = "aaf_gui_window.png",
	window_slice = 32,
	paper = "aaf_gui_paper.png",
	paper_slice = 40,
	input = "aaf_gui_field.png",
	input_slice = 6,
	frame = "aaf_gui_frame.png",
	frame_slice = 12,
	underline = "aaf_gui_underline.png",
}

-- Sent as the player's formspec prepend, so every formspec including the pause menu gets it
theme.prepend = table.concat({
	"style_type[button,button_exit,image_button;border=false;bgimg=aaf_gui_button.png;bgimg_middle=14;padding=-12;textcolor=" .. TEXT .. "]",
	"style_type[button:hovered,button_exit:hovered,image_button:hovered;bgimg=aaf_gui_button_hover.png;textcolor=" .. INK .. "]",
	"style_type[button:pressed,button_exit:pressed,image_button:pressed;bgimg=aaf_gui_button_pressed.png;textcolor=" .. INK .. "]",
	"style_type[*;font_size=*" .. FONT_SCALE .. "]",
	"style_type[label,field,pwdfield,textarea,checkbox,tabheader;textcolor=" .. TEXT .. "]",
	-- No engine background on text inputs: draw aaf_gui.input_bg() behind them instead
	"style_type[field,pwdfield,textarea;border=false]",
	"tableoptions[background=#141315;highlight=#5A2A25;highlight_text=" .. TEXT .. ";color=" .. TEXT .. "]",
})

aaf_gui.theme = theme
