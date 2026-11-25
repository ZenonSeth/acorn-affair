local theme = aaf_gui.theme

local WIDTH, HEIGHT = 15, 10.5
local TAB_W, TAB_H, TAB_GAP = 2.6, 0.8, 0.15
local TAB_PREFIX = "nb_tab_"
local HINT_H = 0.9
local EMPTY_LINE = "Nothing written down yet."

-- The paper page each tab draws on, in formspec units
local PAGE = {x = 0.5, y = aaf_gui.CONTENT_Y, w = WIDTH - 1}
PAGE.h = HEIGHT - PAGE.y - HINT_H - 0.6
aaf_notebook.PAGE = PAGE

-- In registration order: {id, title, visible(player), build(player) -> formspec, on_fields(player, fields)}
local tabs = {}
local hint_source
-- player name -> selected tab id
local selected = {}

-- def: id, title, build(player) -> formspec on the page, optional visible(player) and
-- on_fields(player, fields) -> true when handled (then the notebook is rebuilt)
function aaf_notebook.register_tab(def)
	assert(def.id and def.title and def.build, "aaf_notebook: a tab needs an id, a title and a build function")
	tabs[#tabs + 1] = def
end

-- fn(player) -> the "what now" line at the bottom of every tab, or nil
function aaf_notebook.set_hint_source(fn)
	hint_source = fn
end

local function visible_tabs(player)
	local list = {}
	for _, def in ipairs(tabs) do
		if not def.visible or def.visible(player) then
			list[#list + 1] = def
		end
	end
	return list
end

local function current_tab(player, list)
	local id = selected[player:get_player_name()]
	for _, def in ipairs(list) do
		if def.id == id then
			return def
		end
	end
	return list[1]
end

-- Build mode keeps the plain inventory, so items from /giveme can be moved
local function build_mode_form()
	return table.concat({
		"formspec_version[6]",
		"size[10.5,5.4]",
		"list[current_player;main;0.4,0.4;8,4]",
	})
end

local function build(player)
	if aaf_avatar.is_building(player) then
		return build_mode_form()
	end
	local list = visible_tabs(player)
	local tab = current_tab(player, list)
	local fs = {aaf_gui.window(WIDTH, HEIGHT, "Case Notebook")}
	local x = WIDTH - 0.5 - #list * TAB_W - (#list - 1) * TAB_GAP
	for _, def in ipairs(list) do
		local name = TAB_PREFIX .. def.id
		if def == tab then
			fs[#fs + 1] = ("style[%s;bgimg=aaf_gui_button_pressed.png;textcolor=%s]"):format(name, theme.ink)
		end
		fs[#fs + 1] = ("button[%g,0.35;%g,%g;%s;%s]"):format(x, TAB_W, TAB_H, name, core.formspec_escape(def.title))
		x = x + TAB_W + TAB_GAP
	end
	fs[#fs + 1] = aaf_gui.paper(PAGE.x, PAGE.y, PAGE.w, PAGE.h)
	if tab then
		fs[#fs + 1] = tab.build(player)
	else
		fs[#fs + 1] = ("hypertext[%g,%g;%g,1;empty;<global size=20 color=%s><mono>%s</mono>]"):format(
			PAGE.x + 0.6, PAGE.y + 0.6, PAGE.w - 1.2, theme.ink, aaf_gui.escape(EMPTY_LINE))
	end
	local hint = hint_source and hint_source(player)
	if hint then
		fs[#fs + 1] = ("hypertext[0.6,%g;%g,%g;hint;<global valign=middle size=18 color=%s>%s]"):format(
			PAGE.y + PAGE.h + 0.15, WIDTH - 1.2, HINT_H, theme.text, aaf_gui.escape(hint))
	end
	return table.concat(fs)
end

-- Rebuilds the player's notebook; call it whenever something it shows changes
function aaf_notebook.refresh(player)
	player:set_inventory_formspec(build(player))
end

core.register_on_joinplayer(aaf_notebook.refresh)
aaf_avatar.register_on_building(aaf_notebook.refresh)

core.register_on_leaveplayer(function(player)
	selected[player:get_player_name()] = nil
end)

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "" or aaf_avatar.is_building(player) then
		return
	end
	for key in pairs(fields) do
		if key:sub(1, #TAB_PREFIX) == TAB_PREFIX then
			selected[player:get_player_name()] = key:sub(#TAB_PREFIX + 1)
			aaf_notebook.refresh(player)
			return true
		end
	end
	local tab = current_tab(player, visible_tabs(player))
	if tab and tab.on_fields and tab.on_fields(player, fields) then
		aaf_notebook.refresh(player)
		return true
	end
end)
