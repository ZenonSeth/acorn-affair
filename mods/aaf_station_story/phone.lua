local graph = aaf_station_story.graph
local holds = aaf_station_story.holds

local PLACE = "station"
local CHIEF = "Chief Harrington"
local DETECTIVE = "Jack Graves"

local CALLS_FLAG = "station:phone_calls"
local NOTHING_FLAG = "station:nothing_calls"
local CONCEDED_PREFIX = "station:conceded_"
local REPORTED = "station:reported"
local CAN_LEAVE = "station:can_leave"
local HAS_LOCKPICKS = "station:has_lockpicks"
local HAS_MILLER_KEY = "station:has_miller_key"
local HAS_CHIEF_KEY = "station:has_chief_key"
local TASK_LOCKPICKS = "station:lockpicks"
local TASK_MILLER_KEY = "station:miller_key"
local TASK_CHIEF_KEY = "station:chief_key"
local TASK_ALIBI_PREFIX = "station:alibi_"

local OPENINGS = {
	"Well? Who was it?",
	"Have you made an arrest?",
	"I'm standing by the phone in my dressing gown, detective.",
}

local NOTHING_LINES = {
	"Then why are you calling me? Detect something!",
	"I didn't hire you to chat, Graves. Call me when you have a name.",
	"Still nothing? My feet are freezing on this linoleum. Go look around!",
}

local ACCUSATIONS = {
	miller = {
		jack_first = "What about Sgt. Miller? Ran the front desk all night, keeps tabs on everything.",
		jack_again = "Remind me where you said Miller keeps her spare key?",
		first = "Too organized. Nobody is that organized without hiding something. Check her drawer at the front desk. "
			.. "She keeps a spare key hidden in one of the crates in storage.",
		again = "I told you where to look, detective! Miller's drawer, and her spare key is in the storage crates.",
		concede = "On the phone all night? With Mrs. Dabney? Fine. Not Miller.",
		task = "Check Miller's drawer",
	},
	jenkins = {
		jack_first = "Det. Jenkins. Smudged sign-out, and half the precinct's got a complaint with his name on it.",
		jack_again = "Where did you say Jenkins hides his things again?",
		first = "Smudged sign-out! A man covering his tracks. Check his bottom drawer, he hides everything there. "
			.. "He's a slob, he's probably dropped his key somewhere around his desk.",
		again = "I told you where to look, detective! Jenkins' bottom drawer. Check around his desk for the key.",
		concede = "So it wasn't Jenkins. Fine. He's still suspicious, in general.",
		task = "Check Jenkins' bottom drawer",
	},
	thompson = {
		jack_first = "Det. Thompson. Last man out of the building last night.",
		jack_again = "What was that about Thompson's desk drawer again?",
		first = "He was here latest! Check his desk drawer, he keeps a little book in there. "
			.. "The lock is absurdly old, you have my permission to pick it open.",
		again = "I told you where to look, detective! Thompson's desk drawer. Pick the lock if you have to.",
		concede = "Watching peanuts for an hour and a half... Fine. Not Thompson. Who, then?",
		task = "Check Thompson's drawer",
	},
	fred = {
		jack_first = "Fred Pickett. Never signed in, still managed to be here all evening.",
		jack_again = "You said Pickett was skulking around the kitchen?",
		first = "Not even signed in! A phantom! The kitchen, that's where he skulks. The door gets locked "
			.. "sometimes. Don't break it down, Miller will bury us in paperwork, but if you can unlock it, go for it.",
		again = "I told you where to look, detective! The kitchen. Just don't break the door down.",
		concede = "Stuck in the kitchen for four hours... Only Pickett. Fine. Who else?",
		task = "Get into the kitchen",
	},
	chief = {
		jack_first = "Hate to say it, Chief, but you've got an open window, fresh insurance, and money trouble.",
		jack_again = "Remind me where that spare key of yours is taped, Chief?",
		first = "ME? I was giving the toast at the Benevolent Society dinner! Forty-seven minutes! "
			.. "The program is in my desk drawer. The spare key is taped behind my service certificate. "
			.. "Read it and apologize.",
		again = "I told you where to look, detective! The key's behind my service certificate. Read the program and apologize.",
		concede = "Finished accusing the man who hired you?",
		task = "Check the Chief's desk drawer",
	},
}

local REPORT_STEPS = {
	{speaker = CHIEF, portrait = "chief", text = "Then who? Out with it!", reply = "Tell him."},
	{speaker = DETECTIVE, portrait = "detective", text = "A squirrel.", reply = "Continue"},
	{speaker = CHIEF, portrait = "chief", text = "A WHAT?", reply = "Explain."},
	{speaker = DETECTIVE, portrait = "detective",
		text = "A squirrel. It lives in the elm outside. It's been coming in through your office window all week. "
			.. "The peanuts, the sandwiches, the drawers. Tonight it found something shiny shaped like an acorn.",
		reply = "Continue"},
	{speaker = CHIEF, portrait = "chief", text = "You're telling me a squirrel stole my ACORN.", reply = "Pretty much."},
	{speaker = DETECTIVE, portrait = "detective",
		text = "I'm telling you it thought your ACORN was an acorn. Can't say I blame it.", reply = "Continue"},
	{speaker = CHIEF, portrait = "chief", text = "...I want that animal arrested.", reply = "Hang up."},
}

local function hang_up(player)
	aaf_places.play_music(player)
end

local function jack_says(player, text, on_done, label)
	aaf_dialog.talk(player, {
		speaker = DETECTIVE,
		portrait = "detective",
		text = text,
		options = {{text = label or "Continue", on_choose = on_done}},
	})
end

local function has_pending_accusation(player)
	for _, suspect in ipairs(graph.suspects) do
		if suspect.accuse and aaf_station_story.is_accused(player, suspect.id)
				and not aaf_station_story.is_cleared(player, suspect.id) then
			return true
		end
	end
	return false
end

local function accusable_suspects(player)
	if has_pending_accusation(player) then
		return {}
	end
	local list = {}
	for _, suspect in ipairs(graph.suspects) do
		if suspect.accuse and aaf_station_story.is_listed(player, suspect.id)
				and holds(player, suspect.accuse) and not aaf_station_story.is_cleared(player, suspect.id) then
			list[#list + 1] = suspect
		end
	end
	return list
end

local function next_opening(player)
	for _, suspect in ipairs(graph.suspects) do
		local info = ACCUSATIONS[suspect.id]
		if info and aaf_station_story.is_cleared(player, suspect.id) and aaf_station_story.is_accused(player, suspect.id)
				and not aaf_flags.get(player, CONCEDED_PREFIX .. suspect.id) then
			aaf_flags.set(player, CONCEDED_PREFIX .. suspect.id, true)
			return info.concede
		end
	end
	local count = (aaf_flags.get(player, CALLS_FLAG) or 0) + 1
	aaf_flags.set(player, CALLS_FLAG, count)
	return OPENINGS[math.min(count, #OPENINGS)]
end

local function finish_report(player)
	aaf_flags.set(player, REPORTED, true)
	aaf_flags.set(player, CAN_LEAVE, true)
	aaf_tasks.complete(player, "station:case")
	aaf_tasks.complete(player, "station:report")
	aaf_tasks.clear(player)
	aaf_tasks.add(player, "station:leave", "Return to your office")
	hang_up(player)
end

local function report_step(player, i)
	local step = REPORT_STEPS[i]
	aaf_dialog.talk(player, {
		speaker = step.speaker,
		portrait = step.portrait,
		text = step.text,
		options = {{text = step.reply, on_choose = function(p)
			if i < #REPORT_STEPS then
				report_step(p, i + 1)
			else
				finish_report(p)
			end
		end}},
	})
end

local function accuse_suspect(player, suspect)
	local info = ACCUSATIONS[suspect.id]
	local already = aaf_station_story.is_accused(player, suspect.id)
	jack_says(player, already and info.jack_again or info.jack_first, function(p)
		if not already then
			aaf_station_story.accuse(p, suspect.id)
			if (suspect.id == "fred" or suspect.id == "thompson") and not aaf_flags.get(p, HAS_LOCKPICKS) then
				aaf_tasks.add(p, TASK_LOCKPICKS, "Get your lockpicking kit from the office safe")
			elseif suspect.id == "miller" and not aaf_flags.get(p, HAS_MILLER_KEY) then
				aaf_tasks.add(p, TASK_MILLER_KEY, "Find Miller's spare key in storage")
			elseif suspect.id == "chief" and not aaf_flags.get(p, HAS_CHIEF_KEY) then
				aaf_tasks.add(p, TASK_CHIEF_KEY, "Get the Chief's key behind his certificate")
			end
			aaf_tasks.add(p, TASK_ALIBI_PREFIX .. suspect.id, info.task)
		end
		aaf_dialog.talk(p, {
			speaker = CHIEF,
			portrait = "chief",
			text = already and info.again or info.first,
			options = {{text = "Hang up.", on_choose = hang_up}},
		})
	end)
end

local show_main

local function show_accuse_menu(player, opening)
	local options = {}
	for _, suspect in ipairs(accusable_suspects(player)) do
		options[#options + 1] = {
			text = suspect.name,
			on_choose = function(p)
				accuse_suspect(p, suspect)
			end,
		}
	end
	options[#options + 1] = {
		text = "Back",
		on_choose = function(p)
			show_main(p, opening)
		end,
	}
	aaf_dialog.talk(player, {
		speaker = "Accuse",
		portrait = "chief",
		text = "Well? Out with a name.",
		options = options,
	})
end

local function say_nothing(player)
	jack_says(player, "Nothing solid yet, Chief. Still piecing it together.", function(p)
		local count = (aaf_flags.get(p, NOTHING_FLAG) or 0) + 1
		aaf_flags.set(p, NOTHING_FLAG, count)
		aaf_dialog.talk(p, {
			speaker = CHIEF,
			portrait = "chief",
			text = NOTHING_LINES[math.min(count, #NOTHING_LINES)],
			options = {{text = "Hang up.", on_choose = hang_up}},
		})
	end)
end

function show_main(player, opening)
	local options = {}
	if #accusable_suspects(player) > 0 then
		options[#options + 1] = {
			text = "Accuse...",
			on_choose = function(p)
				show_accuse_menu(p, opening)
			end,
		}
	end
	if aaf_station_story.knows(player, "solved") then
		options[#options + 1] = {
			text = "Not an officer.",
			on_choose = function(p)
				jack_says(p, "Good news for your pension, Chief. It wasn't one of your officers.", function(p2)
					report_step(p2, 1)
				end)
			end,
		}
	end
	options[#options + 1] = {text = "Nothing yet.", on_choose = say_nothing}
	aaf_dialog.talk(player, {
		speaker = CHIEF,
		portrait = "chief",
		text = opening,
		options = options,
	})
end

aaf_places.register_thing(PLACE, "aaf_props:phone#1", {
	label = "Call the Chief",
	on_interact = function(player)
		aaf_audio.music.play(player, "call")
		if aaf_flags.get(player, REPORTED) then
			aaf_dialog.talk(player, {
				speaker = CHIEF,
				portrait = "chief",
				text = "I've got three nets and a lot of explaining to do, detective. Head back to your office.",
				options = {{text = "Hang up.", on_choose = hang_up}},
			})
			return
		end
		show_main(player, next_opening(player))
	end,
})
