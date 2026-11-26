-- Settings tab in the case notebook: per-player audio toggles and volume controls
local theme = aaf_gui.theme
local esc = aaf_gui.escape
local page = aaf_notebook.PAGE

local MARGIN = 0.5
local VOLUME_STEP = 10
local ROW_H = 1.25
local BTN_H = 0.85

local function build_settings(player)
	local x = page.x + MARGIN
	local y0 = page.y + MARGIN
	local fs = {
		("hypertext[%g,%g;4,0.6;audio_heading;<global size=22 color=%s>Audio]"):format(x, y0, theme.ink),
		aaf_gui.underline(x, y0 + 0.6, 2.4),
	}
	for i, category in ipairs(aaf_audio.categories) do
		local y = y0 + 1.0 + (i - 1) * ROW_H
		local on = aaf_audio.is_enabled(player, category.id)
		local pct = math.floor(aaf_audio.get_player_volume(player, category.id) * 100 + 0.5)
		local pct_color = on and theme.ink or theme.muted
		fs[#fs + 1] = ("hypertext[%g,%g;2.8,%g;audio_%s_label;<global valign=middle size=20 color=%s>%s]"):format(
			x, y, BTN_H, category.id, theme.ink, esc(category.title))
		fs[#fs + 1] = ("button[%g,%g;1.6,%g;audio_%s_toggle;%s]"):format(
			x + 3.0, y, BTN_H, category.id, on and "On" or "Off")
		fs[#fs + 1] = ("button[%g,%g;1.4,%g;audio_%s_down;-%d]"):format(
			x + 5.1, y, BTN_H, category.id, VOLUME_STEP)
		fs[#fs + 1] = ("hypertext[%g,%g;1.6,%g;audio_%s_pct;<global halign=center valign=middle size=20 color=%s>%d%%]"):format(
			x + 6.6, y, BTN_H, category.id, pct_color, pct)
		fs[#fs + 1] = ("button[%g,%g;1.4,%g;audio_%s_up;+%d]"):format(
			x + 8.3, y, BTN_H, category.id, VOLUME_STEP)
	end
	return table.concat(fs)
end

local function on_fields(player, fields)
	for _, category in ipairs(aaf_audio.categories) do
		local id = category.id
		local step = (fields["audio_" .. id .. "_up"] and VOLUME_STEP)
			or (fields["audio_" .. id .. "_down"] and -VOLUME_STEP)
		if step then
			local pct = math.floor(aaf_audio.get_player_volume(player, id) * 100 + 0.5) + step
			aaf_audio.set_volume(player, id, math.max(0, math.min(100, pct)) / 100)
			return true
		end
		if fields["audio_" .. id .. "_toggle"] then
			aaf_audio.set_enabled(player, id, not aaf_audio.is_enabled(player, id))
			return true
		end
	end
end

-- Registered after other mods so the settings icon always sits at the end of the tab row
core.register_on_mods_loaded(function()
	aaf_notebook.register_tab({
		id = "settings",
		title = "Settings",
		icon = "aaf_gui_settings.png",
		icon_dark = "aaf_gui_settings_dark.png",
		build = build_settings,
		on_fields = on_fields,
	})
end)
