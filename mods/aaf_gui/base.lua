local theme = aaf_gui.theme

local TITLE_SIZE = 24
local UNDERLINE_H = 0.2

-- Content of a themed window starts below its title at this y
aaf_gui.CONTENT_Y = 1.5

function aaf_gui.escape(text)
	return core.formspec_escape(core.hypertext_escape(text))
end

local function slice(x, y, w, h, texture, middle)
	return ("background9[%g,%g;%g,%g;%s;false;%d]"):format(x, y, w, h, texture, middle)
end

-- The red brush stroke under a heading
function aaf_gui.underline(x, y, w)
	return ("image[%g,%g;%g,%g;%s]"):format(x, y, w, UNDERLINE_H, theme.underline)
end

-- Opening of a themed window: version, size, the dark panel and a title with its underline
function aaf_gui.window(width, height, title)
	local fs = {
		"formspec_version[6]",
		("size[%g,%g]"):format(width, height),
		"bgcolor[#00000000;true;#00000080]",
		slice(0, 0, width, height, theme.window, theme.window_slice),
	}
	if title then
		fs[#fs + 1] = ("hypertext[0.5,0.35;%g,0.7;title;<global size=%d color=%s>%s]"):format(
			width - 1, TITLE_SIZE, theme.text, aaf_gui.escape(title))
		fs[#fs + 1] = aaf_gui.underline(0.5, 1.05, math.min(4, width - 1))
	end
	return table.concat(fs)
end

-- A sheet of paper (notebook pages, documents); put dark text on it
function aaf_gui.paper(x, y, w, h)
	return slice(x, y, w, h, theme.paper, theme.paper_slice)
end

-- Dark inset background for a field, pwdfield or textarea; put it just before the element (same rect)
function aaf_gui.input_bg(x, y, w, h)
	return slice(x, y, w, h, theme.input, theme.input_slice)
end

-- A framed square portrait of a character (aaf_gui_portrait_<id>.png)
function aaf_gui.portrait(x, y, size, id)
	return table.concat({
		("image[%g,%g;%g,%g;aaf_gui_portrait_%s.png]"):format(x, y, size, size, id),
		-- image[] rather than background9[], which always draws behind the other elements
		("image[%g,%g;%g,%g;%s;%d]"):format(x, y, size, size, theme.frame, theme.frame_slice),
	})
end

core.register_on_joinplayer(function(player)
	player:set_formspec_prepend(theme.prepend)
end)
