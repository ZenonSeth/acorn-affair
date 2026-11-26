-- Items tab in the case notebook: read-only 2x4 grid of keys and tools the detective carries
local theme = aaf_gui.theme
local esc = aaf_gui.escape
local page = aaf_notebook.PAGE

local MARGIN = 0.45
local COLS, ROWS = 2, 4
local COL_GAP, ROW_GAP = 0.4, 0.15
local ICON_SIZE, ICON_GAP = 1.05, 0.2
local TITLE_H = 0.48
local EMPTY_LINE = "Pockets are empty."

local items = {}

-- def: id, title, desc, icon, has(player) -> boolean
function aaf_notebook.register_item(def)
	assert(def.id and def.title and def.desc and def.icon and def.has,
		"aaf_notebook: an item needs id, title, desc, icon and has")
	items[#items + 1] = def
end

local function build_items(player)
	local owned = {}
	for _, def in ipairs(items) do
		if def.has(player) then
			owned[#owned + 1] = def
		end
	end
	if #owned == 0 then
		return ("hypertext[%g,%g;%g,1;items_empty;<global size=18 color=%s><mono>%s</mono>]"):format(
			page.x + MARGIN, page.y + MARGIN, page.w - 2 * MARGIN, theme.ink, esc(EMPTY_LINE))
	end
	local cell_w = (page.w - 2 * MARGIN - (COLS - 1) * COL_GAP) / COLS
	local cell_h = (page.h - 2 * MARGIN - (ROWS - 1) * ROW_GAP) / ROWS
	local text_w = cell_w - ICON_SIZE - ICON_GAP
	local fs = {}
	for i, def in ipairs(owned) do
		local col = (i - 1) % COLS
		local row = math.floor((i - 1) / COLS)
		local cx = page.x + MARGIN + col * (cell_w + COL_GAP)
		local cy = page.y + MARGIN + row * (cell_h + ROW_GAP)
		local iy = cy + (cell_h - ICON_SIZE) / 2
		local tx = cx + ICON_SIZE + ICON_GAP
		fs[#fs + 1] = ("image[%g,%g;%g,%g;%s]"):format(cx, iy, ICON_SIZE, ICON_SIZE, def.icon)
		fs[#fs + 1] = ("hypertext[%g,%g;%g,%g;item_t_%s;<global margin=0 size=19 color=%s>%s]"):format(
			tx, cy + 0.1, text_w, TITLE_H, def.id, theme.ink, esc(def.title))
		fs[#fs + 1] = ("hypertext[%g,%g;%g,%g;item_d_%s;<global margin=0 size=15 color=%s><mono>%s</mono>]"):format(
			tx, cy + 0.1 + TITLE_H, text_w, cell_h - 0.1 - TITLE_H, def.id, theme.ink, esc(def.desc))
	end
	return table.concat(fs)
end

-- Registered before settings so Items sits right next to the story tabs
core.register_on_mods_loaded(function()
	aaf_notebook.register_tab({
		id = "items",
		title = "Items",
		build = build_items,
	})
end)
