local PLACE = "office"
local INTRO_SEEN = "office:intro_seen"
local PHONE_RANG = "office:phone_rang"
local CALL_DONE = "office:call_done"
local CAN_LEAVE = "office:can_leave"
local SEARCHED_PREFIX = "office:searched_"
local KEYS_HINTED = "office:keys_hinted"

local TASK_ANSWER = "office:answer"
local TASK_KEYS = "office:keys"
local TASK_LEAVE = "office:leave"
local TASK_LOCKPICKS = "station:lockpicks"
local HAS_LOCKPICKS = "station:has_lockpicks"
local STATION_ARRIVED = "station:arrived"
local KEYS_HINT = "hold Sneak to crouch and look low"
-- The key hunt's hint shows after this many wrong spots, or this many seconds
local HINT_SPOTS = 2
local HINT_SECONDS = 30
-- Lets the client finish joining before the first card shows
local INTRO_DELAY = 1
-- The detective walks around the office this long after the intro before the phone rings
local RING_DELAY = 20
-- The ring sound's loop length; sparkle bursts at these offsets match its bell
local RING_CYCLE = 3
local RING_BURSTS = {0, 0.5, 1}
local RING_SLOT = "phone"
local RING_TEXTURE = "aaf_office_story_ring.png"
local RING_LIFE = 0.4
local PHONE_SEARCH = 16

local INTRO_LINES = {
	"Another quiet night in this miserable city. The rain came down like it had a grudge.",
	"Another night waiting for the phone to ring. It always does, eventually.",
}
local LOCKED_LINE = "Locked. I locked it myself. Of course I did."
local LEAVE_LINES = {
	"The cab smelled of wet dog and broken dreams. "
		.. "Twenty minutes later I was standing in the police station. Nobody was home.",
}
local RETURN_LINES = {"Back to the station. Same cab. Same wet dog."}
local LOCKPICKS_LINE = "Three dollars, a photograph of a better man, and my lockpicking kit. "
	.. "Never leave home without it. Except tonight."
local KEYS_NOTE = "Maybe I should check low and look under things?"
local KEYS_LINE = "Under the desk. Things always end up under the desk. So do I, some nights."
local CHIEF = "Chief Harrington"

-- The detective's own lines
local function say(player, text)
	aaf_dialog.think(player, text)
end

-- The Sneak hint on the task, and its line on the notebook's note
local function show_keys_hint(player)
	aaf_tasks.set_hint(player, TASK_KEYS, KEYS_HINT)
	if not aaf_flags.get(player, KEYS_HINTED) then
		aaf_flags.set(player, KEYS_HINTED, true)
		aaf_notebook.refresh(player)
	end
end

local function start_hint_timer(player)
	local name = player:get_player_name()
	core.after(HINT_SECONDS, function()
		local p = core.get_player_by_name(name)
		if p and aaf_tasks.has(p, TASK_KEYS) then
			show_keys_hint(p)
		end
	end)
end

-- The intro's notebook page, until the keys are found; the key hunt's note is written from the call
local function in_intro(player)
	return not aaf_flags.get(player, CAN_LEAVE)
end

aaf_notebook.register_tab({id = "office", title = "Notes", default = true, visible = in_intro, build = function(player)
	local page = aaf_notebook.PAGE
	local text = "<mono>Nothing written down yet.</mono>"
	if aaf_flags.get(player, CALL_DONE) then
		text = "<style size=22>Find my keys</style>"
		if aaf_flags.get(player, KEYS_HINTED) then
			text = text .. "\n<mono>" .. aaf_gui.escape(KEYS_NOTE) .. "</mono>"
		end
	end
	return ("hypertext[%g,%g;%g,%g;office_note;<global size=18 color=%s>%s]"):format(
		page.x + 0.4, page.y + 0.4, page.w - 0.8, page.h - 0.8, aaf_gui.theme.ink, text)
end})

-- player name -> the token of the running ring loop
local ringing = {}

local function find_phone(player)
	local centre = vector.round(aaf_avatar.get_pos(player) or player:get_pos())
	local reach = vector.new(PHONE_SEARCH, PHONE_SEARCH, PHONE_SEARCH)
	for _, pos in ipairs(core.find_nodes_in_area(centre - reach, centre + reach, "aaf_props:phone_mug")) do
		if aaf_places.thing_id(player, core.get_node(pos)) == PLACE .. "/aaf_props:phone_mug#1" then
			return pos
		end
	end
end

-- A burst of particles over the phone, outward in every upward direction
local function ring_pulse(name, pos)
	for _ = 1, 14 do
		local yaw = math.random() * 2 * math.pi
		local up = math.asin(math.random())
		local dir = vector.new(math.cos(yaw) * math.cos(up), math.sin(up), math.sin(yaw) * math.cos(up))
		core.add_particle({
			playername = name,
			pos = pos + dir * 0.15,
			velocity = dir * 1.8,
			acceleration = dir * -2,
			expirationtime = RING_LIFE,
			size = 1,
			texture = RING_TEXTURE,
			-- length = -1 hangs the client for single particles (only spawners resolve it)
			animation = {type = "vertical_frames", aspect_w = 9, aspect_h = 9, length = RING_LIFE + 0.05},
			glow = 14,
		})
	end
end

local function start_ringing(player)
	local name = player:get_player_name()
	aaf_flags.set(player, PHONE_RANG, true)
	aaf_tasks.add(player, TASK_ANSWER, "Answer the phone")
	aaf_audio.sfx.start_loop(player, RING_SLOT, "phone_ring")
	local phone = find_phone(player)
	if not phone then
		return
	end
	local pos = phone + vector.new(0, 0.1, 0)
	local token = {}
	ringing[name] = token
	local function burst()
		if ringing[name] == token then
			ring_pulse(name, pos)
		end
	end
	local function cycle()
		if ringing[name] ~= token or not core.get_player_by_name(name) then
			return
		end
		for _, offset in ipairs(RING_BURSTS) do
			core.after(offset, burst)
		end
		core.after(RING_CYCLE, cycle)
	end
	cycle()
end

local function stop_ringing(player)
	ringing[player:get_player_name()] = nil
	aaf_audio.sfx.stop_loop(player, RING_SLOT)
end

local function start_ring_timer(player)
	local name = player:get_player_name()
	core.after(RING_DELAY, function()
		local p = core.get_player_by_name(name)
		if p and not aaf_flags.get(p, PHONE_RANG) then
			start_ringing(p)
		end
	end)
end

local function hang_up(player)
	aaf_flags.set(player, CALL_DONE, true)
	aaf_tasks.complete(player, TASK_ANSWER)
	aaf_tasks.add(player, TASK_KEYS, "Find your keys")
	start_hint_timer(player)
	aaf_places.play_music(player)
	aaf_notebook.refresh(player)
	aaf_notebook.notify(player, {"Note added: Find my keys"})
end

-- The opening call (GDD 7.1): the chief's line and the detective's one reply, three times
local CALL = {
	{text = "Is this Jack Graves? The detective? This is Chief Arthur Harrington. Something has been taken "
		.. "from my office. Something irreplaceable.", reply = "Your wallet?"},
	{text = "My ACORN. The Award for Outstanding Constabulary Recognition and Notability. Solid gold-plated. "
		.. "It was on its stand at half past nine and gone by ten to midnight.", reply = "Anyone else in the building?"},
	{text = "My own officers. One of them did it, I'd stake my pension on it. The front door's unlocked, and "
		.. "my keys to the rest of the building are under the register on the front desk. Call me from the front "
		.. "desk phone when you know who. I won't be sleeping.",
		reply = "I'll come take a look. Don't rush to accusations."},
}

local function call_step(player, i)
	local step = CALL[i]
	aaf_dialog.talk(player, {
		speaker = CHIEF,
		portrait = "chief",
		text = step.text,
		options = {{text = step.reply, on_choose = function(p)
			if i < #CALL then
				call_step(p, i + 1)
			else
				hang_up(p)
			end
		end}},
	})
end

aaf_places.register_thing(PLACE, "aaf_props:phone_mug#1", {
	label = "Answer the phone",
	can_interact = function(player)
		return aaf_flags.get(player, PHONE_RANG) ~= nil and not aaf_flags.get(player, CALL_DONE)
	end,
	on_interact = function(player)
		stop_ringing(player)
		aaf_audio.music.play(player, "call")
		call_step(player, 1)
	end,
})

-- Things to look at while waiting for the call (and after it)
local LOOKS = {
	["aaf_props:certificate#1"] = {label = "Look at the certificate",
		line = "Commendation from the city. For finding the mayor's cat. The cat never thanked me either."},
	["aaf_props:board_l#1"] = {label = "Look at the clippings",
		line = "Clippings from my old cases. Every headline spells my name wrong."},
	["aaf_props:board_r#1"] = {label = "Look at the clippings",
		line = "\"Local Detective Finds Dog.\" Front page. It was a slow week. They're all slow weeks."},
}
for key, look in pairs(LOOKS) do
	aaf_places.register_thing(PLACE, key, {label = look.label, on_interact = function(player)
		say(player, look.line)
	end})
end

-- Dead ends of the key hunt: spot id -> {keys, label, line, after (once the keys are found; none = inert)}
local SPOTS = {
	sofa = {keys = {"aaf_props:sofa_l#1", "aaf_props:sofa_r#1"},
		label = function(player)
			return aaf_office_story.can_sleep(player) and "Turn in for the night" or "Search the sofa"
		end,
		line = "Between the cushions: a nickel, a button and the last of my dignity. No keys."},
	wastebasket = {keys = {"aaf_props:wastebasket#1"}, label = "Look in the wastebasket",
		line = "Old case files. Old regrets. No keys.",
		after = "Old case files. Old regrets. They'll keep."},
	safe = {keys = {"aaf_props:safe#1"},
		label = function(player)
			return aaf_tasks.has(player, TASK_LOCKPICKS) and "Get lockpicking kit" or "Open the safe"
		end,
		line = "My safe. Three dollars and a photograph of a better man. No keys.",
		after = "Three dollars and a photograph of a better man. Neither one's coming with me."},
	cabinet_milk = {keys = {"aaf_props:cabinet_bottom#1"}, label = "Search the filing cabinet",
		line = "A bottle of milk. Gone sour, like everything else in this town."},
	cabinet_bills = {keys = {"aaf_props:cabinet_bottom#2"}, label = "Search the filing cabinet",
		line = "Unpaid bills. Mostly mine. No keys."},
	cabinet_cases = {keys = {"aaf_props:cabinet_bottom#3"}, label = "Search the filing cabinet",
		line = "Old cases. Lost dogs, mostly. I found every one of them. No keys."},
}

local function searched_count(player)
	local count = 0
	for id in pairs(SPOTS) do
		if aaf_flags.get(player, SEARCHED_PREFIX .. id) then
			count = count + 1
		end
	end
	return count
end

for id, spot in pairs(SPOTS) do
	for _, key in ipairs(spot.keys) do
		aaf_places.register_thing(PLACE, key, {
			label = spot.label,
			can_interact = function(player)
				if id == "sofa" and aaf_office_story.can_sleep(player) then
					return true
				end
				return aaf_flags.get(player, CALL_DONE) and (spot.after ~= nil or not aaf_flags.get(player, CAN_LEAVE))
			end,
			on_interact = function(player)
				if id == "sofa" and aaf_office_story.can_sleep(player) then
					aaf_office_story.start_ending(player)
					return
				end
				if id == "safe" and aaf_tasks.has(player, TASK_LOCKPICKS) then
					aaf_flags.set(player, HAS_LOCKPICKS, true)
					aaf_tasks.complete(player, TASK_LOCKPICKS)
					say(player, LOCKPICKS_LINE)
					return
				end
				if aaf_flags.get(player, CAN_LEAVE) then
					say(player, spot.after)
					return
				end
				say(player, spot.line)
				if aaf_tasks.has(player, TASK_KEYS) then
					aaf_flags.set(player, SEARCHED_PREFIX .. id, true)
					if searched_count(player) >= HINT_SPOTS then
						show_keys_hint(player)
					end
				end
			end,
		})
	end
end

-- Low, so only a crouched detective finds them; the keys vanish from under the desk once taken
aaf_places.register_thing(PLACE, "aaf_props:desk_r_keys#1", {
	label = "Look under the desk",
	can_interact = function(player)
		return aaf_flags.get(player, CALL_DONE) ~= nil and not aaf_flags.get(player, CAN_LEAVE)
	end,
	on_interact = function(player, target)
		say(player, KEYS_LINE)
		aaf_flags.set(player, CAN_LEAVE, true)
		aaf_tasks.complete(player, TASK_KEYS)
		aaf_tasks.add(player, TASK_LEAVE, "Leave the office")
		aaf_notebook.refresh(player)
		core.swap_node(target.pos, {name = "aaf_props:desk_r", param2 = target.node.param2})
	end,
})

aaf_interact.register("aaf_office_story:door", {
	can_interact = function(player)
		return aaf_flags.get(player, CALL_DONE)
	end,
	label = function(player)
		if not aaf_flags.get(player, CAN_LEAVE) then
			return "Try the door"
		end
		return aaf_flags.get(player, STATION_ARRIVED) and "Return to station" or "Leave"
	end,
	on_interact = function(player)
		if not aaf_flags.get(player, CAN_LEAVE) then
			say(player, LOCKED_LINE)
			return
		end
		local lines = aaf_flags.get(player, STATION_ARRIVED) and RETURN_LINES or LEAVE_LINES
		if aaf_places.travel(player, "station", lines) then
			aaf_tasks.complete(player, TASK_LEAVE)
		end
	end,
})

local function start_intro(player)
	aaf_dialog.narrate(player, INTRO_LINES, function(p)
		aaf_flags.set(p, INTRO_SEEN, true)
		start_ring_timer(p)
	end)
end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	if aaf_places.get(player) == PLACE and not aaf_flags.get(player, INTRO_SEEN) then
		core.after(INTRO_DELAY, function()
			local p = core.get_player_by_name(name)
			if p then
				start_intro(p)
			end
		end)
	elseif aaf_places.get(player) == PLACE and not aaf_flags.get(player, CALL_DONE) then
		-- Timers do not survive a rejoin
		if aaf_flags.get(player, PHONE_RANG) then
			core.after(INTRO_DELAY, function()
				local p = core.get_player_by_name(name)
				if p then
					start_ringing(p)
				end
			end)
		else
			start_ring_timer(player)
		end
	elseif aaf_tasks.has(player, TASK_KEYS) then
		start_hint_timer(player)
	elseif aaf_places.get(player) == PLACE then
		aaf_office_story.maybe_offer_sleep(player)
	end
end)

core.register_on_leaveplayer(function(player)
	ringing[player:get_player_name()] = nil
end)
