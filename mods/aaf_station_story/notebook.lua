-- The case notebook's Clues and Suspects tabs and its "what now" line, all drawn from the graph and the flags
local graph = aaf_station_story.graph
local facts = graph.facts
local holds = aaf_station_story.holds
local theme = aaf_gui.theme
local esc = aaf_gui.escape
local page = aaf_notebook.PAGE

local ARRIVED = "station:arrived"
local SUSPECT_PREFIX = "nb_suspect_"
local BUTTON_W, BUTTON_H, BUTTON_GAP = 5, 0.8, 0.15
local CLEARED_W = 1.4
local MARGIN = 0.4

-- clue id -> its notes, in graph order
local notes_of = {}
for _, note in ipairs(graph.notes) do
	notes_of[note.clue] = notes_of[note.clue] or {}
	table.insert(notes_of[note.clue], note)
end

-- player name -> selected suspect id
local selected = {}

local function arrived(player)
	return aaf_flags.get(player, ARRIVED) ~= nil
end

local function color(c, text)
	return "<style color=" .. c .. ">" .. text .. "</style>"
end

local function page_text(name, x, y, w, h, body)
	return ("hypertext[%g,%g;%g,%g;%s;<global size=18 color=%s>%s]"):format(x, y, w, h, name, theme.ink, body)
end

local function clues_tab(player)
	local parts = {}
	local found = aaf_station_story.found(player)
	for i = #found, 1, -1 do
		local id = found[i]
		local fact = facts[id]
		local head = "<style size=22>" .. esc(fact.title) .. "</style> " .. color(theme.muted, "(" .. esc(fact.where) .. ")")
		if fact.key then
			head = head .. " " .. color(theme.accent, "key")
		end
		parts[#parts + 1] = head .. "\n<mono>" .. esc(fact.line) .. "</mono>"
		for _, note in ipairs(notes_of[id] or {}) do
			if holds(player, note.when) then
				parts[#parts + 1] = color(theme.accent, "- ") .. esc(note.line)
			end
		end
		parts[#parts + 1] = ""
	end
	if #parts == 0 then
		parts[1] = "<mono>Nothing written down yet.</mono>"
	end
	return page_text("clues", page.x + MARGIN, page.y + MARGIN, page.w - 2 * MARGIN, page.h - 2 * MARGIN,
		table.concat(parts, "\n"))
end

local function listed_suspects(player)
	local list = {}
	for _, suspect in ipairs(graph.suspects) do
		if holds(player, suspect.listed) then
			list[#list + 1] = suspect
		end
	end
	return list
end

local function current_suspect(player, list)
	local id = selected[player:get_player_name()]
	for _, suspect in ipairs(list) do
		if suspect.id == id then
			return suspect
		end
	end
	return list[1]
end

local function suspect_details(player, suspect)
	local parts = {"<style size=22>" .. esc(suspect.name) .. "</style>", ""}
	for _, line in ipairs(suspect.lines) do
		if holds(player, line.when) then
			if line.struck and holds(player, line.struck) then
				parts[#parts + 1] = color(theme.muted, esc(line.line))
				parts[#parts + 1] = color(theme.accent, "- ") .. esc(line.struck_line)
			else
				parts[#parts + 1] = esc(line.line)
			end
		end
	end
	if aaf_station_story.is_cleared(player, suspect.id) then
		parts[#parts + 1] = ""
		parts[#parts + 1] = color(theme.accent, "Cleared. ") .. "<mono>" .. esc(suspect.cleared) .. "</mono>"
	end
	return table.concat(parts, "\n")
end

local function suspects_tab(player)
	local list = listed_suspects(player)
	local current = current_suspect(player, list)
	local fs = {}
	local x, y = page.x + MARGIN, page.y + MARGIN
	for _, suspect in ipairs(list) do
		local name = SUSPECT_PREFIX .. suspect.id
		local cleared = aaf_station_story.is_cleared(player, suspect.id)
		if suspect == current then
			fs[#fs + 1] = ("style[%s;bgimg=aaf_gui_button_pressed.png;textcolor=%s]"):format(name, theme.ink)
		elseif cleared then
			fs[#fs + 1] = ("style[%s;textcolor=%s]"):format(name, theme.muted)
		end
		fs[#fs + 1] = ("button[%g,%g;%g,%g;%s;%s]"):format(x, y, BUTTON_W, BUTTON_H, name,
			core.formspec_escape(suspect.name))
		if cleared then
			fs[#fs + 1] = page_text("cleared_" .. suspect.id, x + BUTTON_W + 0.1, y, CLEARED_W, BUTTON_H,
				"<global valign=middle>" .. color(theme.accent, "cleared"))
		end
		y = y + BUTTON_H + BUTTON_GAP
	end
	if current then
		local dx = x + BUTTON_W + CLEARED_W + 0.3
		fs[#fs + 1] = page_text("suspect", dx, page.y + MARGIN, page.x + page.w - MARGIN - dx, page.h - 2 * MARGIN,
			suspect_details(player, current))
	end
	return table.concat(fs)
end

aaf_notebook.register_tab({id = "clues", title = "Clues", default = true, visible = arrived, build = clues_tab})
aaf_notebook.register_tab({id = "suspects", title = "Suspects", visible = arrived, build = suspects_tab,
	on_fields = function(player, fields)
		for key in pairs(fields) do
			if key:sub(1, #SUSPECT_PREFIX) == SUSPECT_PREFIX then
				selected[player:get_player_name()] = key:sub(#SUSPECT_PREFIX + 1)
				return true
			end
		end
	end})

aaf_notebook.set_hint_source(function(player)
	if not arrived(player) then
		return nil
	end
	for _, hint in ipairs(graph.hints) do
		if holds(player, hint.when) then
			return hint.line
		end
	end
end)

core.register_on_leaveplayer(function(player)
	selected[player:get_player_name()] = nil
end)
