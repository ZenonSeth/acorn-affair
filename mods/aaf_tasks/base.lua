local get_json, set_json = aaf_utils.get_json, aaf_utils.set_json

local STORE_KEY = "aaf_tasks:list"
-- Seconds a finished task stays on screen, greyed out
local DONE_SECONDS = 4
local COLOR_OPEN = "#E8E0D0"
local COLOR_HINT = "#B8A878"
local COLOR_DONE = "#6E8A62"

-- player name -> {entries = {{id, text, hint, done}}, hud = id}
local states = {}

local function save(player, state)
	local open = {}
	for _, entry in ipairs(state.entries) do
		if not entry.done then
			open[#open + 1] = {id = entry.id, text = entry.text, hint = entry.hint}
		end
	end
	set_json(player:get_meta(), STORE_KEY, open)
end

local function redraw(player, state)
	local lines = {}
	for _, entry in ipairs(state.entries) do
		if entry.done then
			lines[#lines + 1] = core.colorize(COLOR_DONE, "[x] " .. entry.text)
		else
			lines[#lines + 1] = core.colorize(COLOR_OPEN, "[ ] " .. entry.text)
			if entry.hint then
				lines[#lines + 1] = core.colorize(COLOR_HINT, "(" .. entry.hint .. ")")
			end
		end
	end
	player:hud_change(state.hud, "text", table.concat(lines, "\n"))
end

local function find(state, id)
	for _, entry in ipairs(state.entries) do
		if entry.id == id and not entry.done then
			return entry
		end
	end
end

-- Runs fn(state, entry) on the player's open task `id`, then saves and redraws; false if there is none
local function change(player, id, fn)
	local state = states[player:get_player_name()]
	local entry = state and find(state, id)
	if not entry then
		return false
	end
	fn(state, entry)
	save(player, state)
	redraw(player, state)
	return true
end

-- Adds an open task at the bottom of the list, or re-words it if it is already open
function aaf_tasks.add(player, id, text)
	local state = states[player:get_player_name()]
	if not state then
		return
	end
	local entry = find(state, id)
	if entry then
		entry.text = text
	else
		state.entries[#state.entries + 1] = {id = id, text = text}
	end
	save(player, state)
	redraw(player, state)
end

function aaf_tasks.has(player, id)
	local state = states[player:get_player_name()]
	return state ~= nil and find(state, id) ~= nil
end

function aaf_tasks.set_text(player, id, text)
	return change(player, id, function(_, entry)
		entry.text = text
	end)
end

-- A short hint shown in brackets under the task; nil removes it
function aaf_tasks.set_hint(player, id, hint)
	return change(player, id, function(_, entry)
		entry.hint = hint
	end)
end

-- Ticks the task off; it stays greyed out for a few seconds, then leaves the list
function aaf_tasks.complete(player, id)
	local name = player:get_player_name()
	return change(player, id, function(state, entry)
		entry.done = true
		core.after(DONE_SECONDS, function()
			local p = core.get_player_by_name(name)
			if p and states[name] == state then
				table.remove(state.entries, table.indexof(state.entries, entry))
				redraw(p, state)
			end
		end)
	end)
end

core.register_on_joinplayer(function(player)
	local entries = {}
	for _, saved in ipairs(get_json(player:get_meta(), STORE_KEY) or {}) do
		entries[#entries + 1] = {id = saved.id, text = saved.text, hint = saved.hint}
	end
	local state = {
		entries = entries,
		hud = player:hud_add({
			type = "text",
			position = {x = 1, y = 0.2},
			offset = {x = -24, y = 0},
			alignment = {x = -1, y = 1},
			number = 0xFFFFFF,
			size = {x = 1.2 * aaf_utils.constants.hud_text_scale, y = 0},
			text = "",
		}),
	}
	states[player:get_player_name()] = state
	redraw(player, state)
end)

core.register_on_leaveplayer(function(player)
	states[player:get_player_name()] = nil
end)
