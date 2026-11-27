local graph = aaf_station_story.graph
local facts = graph.facts

local PLACE = "station"
local DETECTIVE = "Jack Graves"
local FACT_PREFIX = "station:fact_"
local KNOWS_PREFIX = "station:knows_"
local SEEN_PREFIX = "station:seen_"
local ACCUSED_PREFIX = "station:accused_"
local TASK_CASE = "station:case"
local TASK_ALIBI_PREFIX = "station:alibi_"
local TASK_MILLER_KEY = "station:miller_key"
local TASK_CHIEF_KEY = "station:chief_key"
local HAS_LOCKPICKS = "station:has_lockpicks"
local HAS_MILLER_KEY = "station:has_miller_key"
local HAS_JENKINS_KEY = "station:has_jenkins_key"
local HAS_CHIEF_KEY = "station:has_chief_key"
local SOLVED_TASK_TEXT = "Tell the Chief what really happened"
-- JSON list of fact ids in the order the player found them
local FOUND_KEY = "station:found"
-- Delay before scribble when an interaction sound plays first
local SOUND_DELAY = {drawer_open = 0.4, keys_jingle = 0.65}

local deduction_of, suspect_of = {}, {}
for _, deduction in ipairs(graph.deductions) do
	deduction_of[deduction.id] = deduction
end
for _, suspect in ipairs(graph.suspects) do
	suspect_of[suspect.id] = suspect
end
-- suspect id -> the fact that clears them
local alibi_of = {}
for id, fact in pairs(facts) do
	if fact.alibi then
		alibi_of[fact.alibi] = id
	end
end

-- The detective's own lines
local function say(player, text)
	aaf_dialog.think(player, text)
end

-- True once the player knows the fact or has made the deduction
function aaf_station_story.knows(player, id)
	if facts[id] then
		return aaf_flags.get(player, FACT_PREFIX .. id) ~= nil
	end
	assert(deduction_of[id], "aaf_station_story: unknown fact or deduction " .. tostring(id))
	return aaf_flags.get(player, KNOWS_PREFIX .. id) ~= nil
end

local holds

function aaf_station_story.is_listed(player, suspect)
	return holds(player, assert(suspect_of[suspect], "aaf_station_story: unknown suspect " .. tostring(suspect)).listed)
end

function aaf_station_story.is_accused(player, suspect)
	assert(suspect_of[suspect], "aaf_station_story: unknown suspect " .. tostring(suspect))
	return aaf_flags.get(player, ACCUSED_PREFIX .. suspect) ~= nil
end

local notebook_changed

-- The phone calls this; it unlocks the suspect's alibi
function aaf_station_story.accuse(player, suspect)
	assert(alibi_of[suspect], "aaf_station_story: " .. tostring(suspect) .. " cannot be accused")
	notebook_changed(player, function()
		aaf_flags.set(player, ACCUSED_PREFIX .. suspect, true)
	end)
end

function aaf_station_story.is_cleared(player, suspect)
	local alibi = alibi_of[suspect]
	return alibi ~= nil and aaf_station_story.knows(player, alibi)
end

local function holds_leaf(player, id)
	local kind, rest = id:match("^(%a+):(.+)$")
	if kind == "seen" then
		return aaf_flags.get(player, SEEN_PREFIX .. rest) ~= nil
	elseif kind == "accused" then
		return aaf_station_story.is_accused(player, rest)
	elseif kind == "suspect" then
		return aaf_station_story.is_listed(player, rest)
	end
	return aaf_station_story.knows(player, id)
end

-- Whether a requirement (see graph.lua) holds for the player
function holds(player, req)
	if type(req) == "string" then
		return holds_leaf(player, req)
	elseif req.all then
		for _, sub in ipairs(req.all) do
			if not holds(player, sub) then
				return false
			end
		end
		return true
	elseif req.any then
		for _, sub in ipairs(req.any) do
			if holds(player, sub) then
				return true
			end
		end
		return false
	elseif req.none then
		for _, sub in ipairs(req.none) do
			if holds(player, sub) then
				return false
			end
		end
		return true
	end
	local count = 0
	for _, sub in ipairs(req.of) do
		if holds(player, sub) then
			count = count + 1
		end
	end
	return count >= req.at_least
end
aaf_station_story.holds = holds

-- Catches typos in graph.lua at load
local function check(req, where)
	if type(req) == "string" then
		local kind, rest = req:match("^(%a+):(.+)$")
		local ok
		if kind == "seen" then
			ok = facts[rest] and facts[rest].gate
		elseif kind == "accused" then
			ok = alibi_of[rest]
		elseif kind == "suspect" then
			ok = suspect_of[rest]
		else
			ok = facts[req] or deduction_of[req]
		end
		assert(ok, "aaf_station_story: " .. where .. " has an unknown requirement " .. req)
		return
	end
	assert(type(req) == "table", "aaf_station_story: " .. where .. " has a bad requirement")
	local list = req.all or req.any or req.none or req.of
	assert(type(list) == "table" and (req.of == nil or type(req.at_least) == "number"),
		"aaf_station_story: " .. where .. " has a bad requirement")
	for _, sub in ipairs(list) do
		check(sub, where)
	end
end
for id, fact in pairs(facts) do
	if fact.gate then
		check(fact.gate, "fact " .. id)
	end
	assert(not fact.alibi or suspect_of[fact.alibi], "aaf_station_story: fact " .. id .. " clears an unknown suspect")
end
for _, deduction in ipairs(graph.deductions) do
	check(deduction.req, "deduction " .. deduction.id)
end
for _, note in ipairs(graph.notes) do
	assert(facts[note.clue], "aaf_station_story: a note is under an unknown clue " .. tostring(note.clue))
	check(note.when, "a note under " .. note.clue)
end
for _, suspect in ipairs(graph.suspects) do
	check(suspect.listed, "suspect " .. suspect.id)
	if suspect.accuse then
		check(suspect.accuse, "suspect " .. suspect.id)
	end
	for _, line in ipairs(suspect.lines) do
		check(line.when, "suspect " .. suspect.id)
		if line.struck then
			check(line.struck, "suspect " .. suspect.id)
		end
	end
end
for i, hint in ipairs(graph.hints) do
	check(hint.when, "hint " .. i)
end

-- Makes every deduction that now follows; returns the new ones in order
local function update(player)
	local new = {}
	local changed = true
	while changed do
		changed = false
		for _, deduction in ipairs(graph.deductions) do
			if not aaf_station_story.knows(player, deduction.id) and holds(player, deduction.req) then
				aaf_flags.set(player, KNOWS_PREFIX .. deduction.id, true)
				new[#new + 1] = deduction
				changed = true
			end
		end
	end
	if aaf_station_story.knows(player, "solved") then
		aaf_tasks.set_text(player, TASK_CASE, SOLVED_TASK_TEXT)
	end
	return new
end

-- Records a fact and whatever follows from it
function aaf_station_story.learn(player, id, scribble_delay)
	assert(facts[id], "aaf_station_story: unknown fact " .. tostring(id))
	if aaf_station_story.knows(player, id) then
		return
	end
	notebook_changed(player, function()
		aaf_flags.set(player, FACT_PREFIX .. id, true)
		local meta = player:get_meta()
		local found = aaf_utils.get_json(meta, FOUND_KEY) or {}
		found[#found + 1] = id
		aaf_utils.set_json(meta, FOUND_KEY, found)
		update(player)
	end, scribble_delay)
	if facts[id].alibi then
		aaf_tasks.complete(player, TASK_ALIBI_PREFIX .. facts[id].alibi)
	end
end

-- The known facts in the order found; ones set by hand (e.g. /flag) follow, by title
function aaf_station_story.found(player)
	local list, listed = {}, {}
	for _, id in ipairs(aaf_utils.get_json(player:get_meta(), FOUND_KEY) or {}) do
		if facts[id] and not listed[id] and aaf_station_story.knows(player, id) then
			list[#list + 1] = id
			listed[id] = true
		end
	end
	local rest = {}
	for id in pairs(facts) do
		if not listed[id] and aaf_station_story.knows(player, id) then
			rest[#rest + 1] = id
		end
	end
	table.sort(rest, function(a, b)
		return facts[a].title < facts[b].title
	end)
	for _, id in ipairs(rest) do
		list[#list + 1] = id
	end
	return list
end

-- What the notebook shows, as {key, line, parent} entries: parent is an entry that, if new too, says it already
local function snapshot(player)
	local list = {}
	local function add(key, line, parent)
		list[#list + 1] = {key = key, line = line, parent = parent}
	end
	for _, id in ipairs(aaf_station_story.found(player)) do
		add("clue:" .. id, "Clue added: " .. facts[id].title)
	end
	if aaf_station_story.knows(player, "register") then
		add("item:station_keys", "Item added: Chief's station key")
	end
	for i, note in ipairs(graph.notes) do
		if aaf_station_story.knows(player, note.clue) and holds(player, note.when) then
			add("note:" .. i, "Note added: " .. facts[note.clue].title, "clue:" .. note.clue)
		end
	end
	for _, deduction in ipairs(graph.deductions) do
		if deduction.title and aaf_station_story.knows(player, deduction.id) then
			add("deduction:" .. deduction.id, "Worked out: " .. deduction.title)
		end
	end
	for _, suspect in ipairs(graph.suspects) do
		if holds(player, suspect.listed) then
			local key = "suspect:" .. suspect.id
			add(key, "Suspect added: " .. suspect.name)
			for j, line in ipairs(suspect.lines) do
				if holds(player, line.when) then
					add(key .. ":" .. j, "Note added: " .. suspect.name, key)
				end
				if line.struck and holds(player, line.struck) then
					add(key .. ":struck" .. j, "Note added: " .. suspect.name, key)
				end
			end
			if aaf_station_story.is_cleared(player, suspect.id) then
				add(key .. ":cleared", "Cleared: " .. suspect.name)
			end
		end
	end
	return list
end

-- Runs change(), then rebuilds the notebook and announces what it gained
function notebook_changed(player, change, scribble_delay)
	local before = {}
	for _, entry in ipairs(snapshot(player)) do
		before[entry.key] = true
	end
	change()
	local lines, shown = {}, {}
	for _, entry in ipairs(snapshot(player)) do
		local new = not before[entry.key]
		if new and not (entry.parent and not before[entry.parent]) and not shown[entry.line] then
			lines[#lines + 1] = entry.line
			shown[entry.line] = true
		end
	end
	aaf_notebook.refresh(player)
	if #lines > 0 then
		if scribble_delay then
			local pname = player:get_player_name()
			core.after(scribble_delay, function()
				local p = core.get_player_by_name(pname)
				if p then
					aaf_audio.sfx.play("scribble", {player = p})
				end
			end)
		else
			aaf_audio.sfx.play("scribble", {player = player})
		end
	end
	aaf_notebook.notify(player, lines)
end

-- Facts set by hand (e.g. /flag) are followed through on the next join
core.register_on_joinplayer(function(player)
	update(player)
	aaf_notebook.refresh(player)
end)

-- Interactive pickup dialog for physical keys
local function offer_key(player, def)
	aaf_dialog.talk(player, {
		speaker = DETECTIVE,
		portrait = "detective",
		text = def.text,
		options = {
			{text = def.take, on_choose = function(p)
				aaf_audio.sfx.play("keys_jingle", {player = p})
				aaf_flags.set(p, def.flag, true)
				if def.task then
					aaf_tasks.complete(p, def.task)
				end
				aaf_notebook.refresh(p)
				if def.item_name then
					aaf_notebook.notify(p, {"Item added: " .. def.item_name})
				end
				say(p, def.taken_line)
			end},
			{text = "Close", on_choose = function() end},
		},
	})
end

local function offer_jenkins_trash(player)
	aaf_dialog.talk(player, {
		speaker = DETECTIVE,
		portrait = "detective",
		text = "Wrappers and a racing form. Jenkins lost.",
		options = {
			{text = "Dig through trash", on_choose = function(p)
				offer_key(p, {
					text = "Under the racing form and a crumpled peanut wrapper: a small desk key.",
					take = "Take Jenkins' key",
					flag = HAS_JENKINS_KEY,
					item_name = "Jenkins' key",
					taken_line = "At the bottom of his own wastebasket. Figures.",
				})
			end},
			{text = "Close", on_choose = function() end},
		},
	})
end

-- Thing key -> {label, then one of: fact (+ doc: shown as a document; before: the line while the fact's gate
-- does not hold; later = {when, line} once it does; key_flag/locked/locked_accused: physical unlock flag;
-- cleared: narration when the alibi is read; first: narration joined on the first read; task: completed on the
-- first read), on_use(player), or line (flavor only)}
local THINGS = {
	-- Reception
	["aaf_props:register#1"] = {label = "Read the register", fact = "register", doc = true,
		first = "Under it, the Chief's keys.", sound = "keys_jingle", task = "station:keys"},
	["aaf_props:papers_mug#1"] = {label = "Read the papers", fact = "noise_complaint", doc = true},
	["aaf_props:board_l_plain#2"] = {label = "Read the missing property notice", fact = "missing_notice", doc = true},
	["aaf_props:board_r_plain#2"] = {label = "Read the window notice", fact = "window_notice", doc = true},
	["aaf_props:reception_desk#1"] = {label = "Search Miller's drawer", fact = "miller_log", doc = true, drawer = true,
		key_flag = HAS_MILLER_KEY,
		locked = "Locked.",
		locked_accused = "Locked. The Chief said she keeps a spare key in the storage crates.",
		cleared = "Miller never left that desk. Mrs. Dabney made sure of it. Miller was clean."},
	-- Detectives' room
	["aaf_props:board_l_plain#10"] = {label = "Read the memo", fact = "memo", doc = true},
	["aaf_props:board_r_plain#10"] = {label = "Read the memo", fact = "memo", doc = true},
	["aaf_props:lamp_papers#10"] = {label = "Read the report", fact = "fred_report", doc = true},
	["aaf_props:papers_mug#10"] = {label = "Read the list", fact = "fred_list", doc = true},
	["aaf_props:desk_l_papers#10"] = {label = "Search Fred's drawer", drawer = true, line = "Three pens. All of them Miller's."},
	["aaf_props:lamp_sandwich#11"] = {label = "Look at the sandwich", fact = "sandwich",
		before = "Somebody's lunch. Not mine. Not evidence."},
	["aaf_props:phone_papers#11"] = {label = "Read the note", fact = "thompson_note", doc = true},
	["aaf_props:desk_l#11"] = {label = "Search Thompson's drawer", fact = "thompson_log", doc = true, drawer = true,
		key_flag = HAS_LOCKPICKS,
		locked = "Locked. An old lock.",
		locked_accused = "Locked. An old lock. My lockpicking kit from the office safe would open it.",
		cleared = "Thompson watched that desk for an hour and a half and never saw a thing. He was watching at "
			.. "eye level. Most people do. Thompson was clean."},
	["aaf_props:lamp_peanuts#12"] = {label = "Look at the peanuts",
		line = "A jar of peanuts, guarded like the crown jewels."},
	["aaf_props:phone_papers#12"] = {label = "Read the complaint", fact = "peanut_complaint", doc = true},
	["aaf_props:desk_l_papers#12"] = {label = "Search the bottom drawer", fact = "ticket_stub", doc = true, drawer = true,
		key_flag = HAS_JENKINS_KEY,
		locked = "Locked.",
		locked_accused = "Locked. The Chief said Jenkins probably dropped his key somewhere near his desk.",
		cleared = "Jenkins. A man who'd rather be a suspect than be seen at a love picture. I respected that. "
			.. "Jenkins was clean."},
	["aaf_props:peanut_shells#12"] = {label = "Look at the shells", fact = "shells",
		before = "Peanut shells. Jenkins is a slob. Not a crime."},
	["aaf_props:wastebasket#12"] = {label = "Look in the wastebasket", on_use = function(player)
		if not aaf_flags.get(player, HAS_JENKINS_KEY) then
			offer_jenkins_trash(player)
		else
			say(player, "Wrappers and a racing form. Jenkins lost.")
		end
	end},
	["aaf_props:desk_l#13"] = {label = "Search the empty desk", drawer = true, line = "Nobody's desk. Suspiciously empty drawers."},
	["aaf_props:paper_scrap#17"] = {label = "Look at the paper", line = "Last week's duty roster, gone soft from the "
		.. "radiator. Fred's name is on every night shift. Nobody's crossed it out."},
	-- Chief's office
	["aaf_props:display_case_top#30"] = {label = "Look at the display case", fact = "display_case"},
	["aaf_props:certificate_blue#30"] = {label = "Read the certificate", fact = "certificate", doc = true},
	["aaf_props:certificate#30"] = {label = "Read the certificate", on_use = function(player)
		if aaf_station_story.is_accused(player, "chief") and not aaf_flags.get(player, HAS_CHIEF_KEY) then
			offer_key(player, {
				text = "Ten years of service. The Chief framed it himself. "
					.. "Sure enough, there's a small brass key taped to the back.",
				take = "Take the Chief's key",
				flag = HAS_CHIEF_KEY,
				task = TASK_CHIEF_KEY,
				item_name = "Chief's drawer key",
				taken_line = "Taped behind his own commendation. Subtle.",
			})
		else
			say(player, "Ten years of service. The Chief framed it himself.")
		end
	end},
	["aaf_props:photo_acorn#30"] = {label = "Look at the photo", fact = "photo_acorn"},
	["aaf_props:window_sill_prints#30"] = {label = "Look at the window", fact = "sill_prints",
		before = "Open a crack. Rain on the sill, the elm right outside. Nice view, if you like trees.",
		later = {when = "window", line = "The elm. Close enough to jump, for something small."}},
	["aaf_props:door_scratches#30"] = {label = "Look at the gap under the door", fact = "scratches",
		before = "A draft. The Chief's complained about it for years."},
	["aaf_props:lamp_papers#30"] = {label = "Read the letter", fact = "letter", doc = true},
	["aaf_props:phone#30"] = {label = "Look at the phone", line = "The Chief's phone. He's on the other end of a different one."},
	["aaf_props:cabinet_top_open#30"] = {label = "Look in the drawer", fact = "insurance", doc = true},
	["aaf_props:wastebasket#30"] = {label = "Look in the wastebasket", fact = "crumpled_note", doc = true},
	["aaf_props:safe#30"] = {label = "Try the safe", fact = "safe",
		picks_line = "This lock is beyond my lockpicking skills. And I wouldn't want to anyway.",
		later = {when = "dinner_program", line = "Still locked. Still none of my business."}},
	["aaf_props:desk_l_papers#30"] = {label = "Search the Chief's drawer", fact = "dinner_program", doc = true, drawer = true,
		key_flag = HAS_CHIEF_KEY,
		locked = "The Chief's private drawer. Locked.",
		locked_accused = "The Chief's private drawer. Locked. He said the key is behind his service certificate.",
		cleared = "Forty-seven minutes. The ovation was probably people standing up to leave. The Chief was clean. "
			.. "Long-winded, but clean."},
	["aaf_props:radio#30"] = {label = "Turn on the radio", line = "The late news. The late news didn't know about this yet."},
	-- Kitchen (its door only opens with the lockpicking kit)
	["aaf_props:notice#20"] = {label = "Read the note", fact = "door_note", doc = true,
		cleared = "Four and a half hours in a kitchen with a cold percolator and a view of a door. Fred had the best "
			.. "alibi in the building and the worst evening. Fred was clean."},
}
for i = 1, 9 do
	THINGS["aaf_props:crate_large#" .. i] = {label = "Look in the crate",
		line = "Storage of old case notes, nothing interesting here."}
end
THINGS["aaf_props:crate_large#5"] = {label = "Look in the crate", on_use = function(player)
	if aaf_station_story.is_accused(player, "miller") and not aaf_flags.get(player, HAS_MILLER_KEY) then
		offer_key(player, {
			text = "Old case notes. Tucked under the top folder, a small key with a neat label: MILLER - DESK.",
			take = "Take Miller's key",
			flag = HAS_MILLER_KEY,
			task = TASK_MILLER_KEY,
			item_name = "Miller's spare key",
			taken_line = "Labelled and filed. Classic Miller.",
		})
	else
		say(player, "Storage of old case notes, nothing interesting here.")
	end
end}

local function use(player, thing)
	if thing.on_use then
		thing.on_use(player)
		return
	end
	if thing.line then
		if thing.drawer then
			aaf_audio.sfx.play("drawer_open", {player = player})
		end
		say(player, thing.line)
		return
	end
	local id = thing.fact
	local fact = facts[id]
	local known = aaf_station_story.knows(player, id)
	if thing.key_flag and not known and not aaf_flags.get(player, thing.key_flag) then
		local accused = fact.alibi and aaf_station_story.is_accused(player, fact.alibi)
		say(player, accused and thing.locked_accused or thing.locked)
		return
	end
	if fact.gate and not known and not holds(player, fact.gate) then
		aaf_flags.set(player, SEEN_PREFIX .. id, true)
		say(player, thing.before)
		return
	end
	if known and thing.later and holds(player, thing.later.when) then
		say(player, thing.later.line)
		return
	end
	local extra = not known and (thing.cleared or thing.first)
	-- Documents read as "Title: line" until the document panel exists
	local line = thing.doc and fact.title .. ": " .. fact.line or fact.line
	if thing.picks_line and aaf_flags.get(player, HAS_LOCKPICKS) then
		line = thing.picks_line
	end
	-- One thought at a time, so the alibi's verdict joins the line
	say(player, extra and line .. " " .. extra or line)
	local sound = (not known and thing.sound) or (thing.drawer and "drawer_open") or nil
	if sound then
		aaf_audio.sfx.play(sound, {player = player})
	end
	aaf_station_story.learn(player, id, sound and SOUND_DELAY[sound])
	if thing.task then
		aaf_tasks.complete(player, thing.task)
	end
end

for key, thing in pairs(THINGS) do
	local fact = thing.fact and facts[thing.fact]
	assert(thing.line or thing.on_use or fact, "aaf_station_story: thing " .. key .. " has neither a line nor a known fact")
	assert(not fact or not fact.gate or thing.before, "aaf_station_story: gated thing " .. key .. " needs a before line")
	assert(not thing.key_flag or thing.locked, "aaf_station_story: keyed thing " .. key .. " needs a locked line")
	aaf_places.register_thing(PLACE, key, {
		label = thing.label,
		on_interact = function(player)
			use(player, thing)
		end,
	})
end
