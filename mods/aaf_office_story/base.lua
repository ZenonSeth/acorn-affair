local PLACE = "office"
local INTRO_SEEN = "office:intro_seen"
local CALL_DONE = "office:call_done"
local CAN_LEAVE = "office:can_leave"
local SEARCHED_PREFIX = "office:searched_"

local TASK_ANSWER = "office:answer"
local TASK_KEYS = "office:keys"
local TASK_LEAVE = "office:leave"
local KEYS_HINT = "hold Sneak to crouch and look low"
-- The key hunt's hint shows after this many wrong spots, or this many seconds
local HINT_SPOTS = 2
local HINT_SECONDS = 30
-- Lets the client finish joining before the first card shows
local INTRO_DELAY = 1

local INTRO_LINES = {
	"Another quiet night in this miserable city. The rain came down like it had a grudge.",
	"Then the phone rang. It always does.",
}
local LOCKED_LINE = "Locked. I locked it myself. Of course I did."
local LEAVE_LINES = {
	"The cab smelled of wet dog and broken dreams. "
		.. "Twenty minutes later I was standing in the police station. Nobody was home.",
}
local KEYS_LINE = "Under the desk. Things always end up under the desk. So do I, some nights."
local DEAD_PHONE_LINE = "The line's dead. Like most of my leads."
local CHIEF = "Chief Harrington"

-- The detective's own lines
local function say(player, text)
	aaf_dialog.think(player, text)
end

local function start_hint_timer(player)
	local name = player:get_player_name()
	core.after(HINT_SECONDS, function()
		local p = core.get_player_by_name(name)
		if p and aaf_tasks.has(p, TASK_KEYS) then
			aaf_tasks.set_hint(p, TASK_KEYS, KEYS_HINT)
		end
	end)
end

local function hang_up(player)
	aaf_flags.set(player, CALL_DONE, true)
	aaf_tasks.complete(player, TASK_ANSWER)
	aaf_tasks.add(player, TASK_KEYS, "Find your keys")
	start_hint_timer(player)
end

-- The opening call (GDD 7.1): the chief's line and the detective's one reply, three times
local CALL = {
	{text = "Is this Jack Graves? The detective? This is Chief Arthur Harrington. Something has been taken "
		.. "from my office. Something irreplaceable.", reply = "Your wallet?"},
	{text = "My ACORN. The Award for Outstanding Constabulary Recognition and Notability. Solid gold-plated. "
		.. "It was on its stand at half past nine and gone by ten to midnight.", reply = "Anyone else in the building?"},
	{text = "My own officers. One of them did it, I'd stake my pension on it. The front door's unlocked. Call me "
		.. "from the front desk phone when you know who. I'll be by the phone. I won't be sleeping.",
		reply = "I'm on my way, Chief."},
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
	label = function(player)
		return aaf_flags.get(player, CALL_DONE) and "Look at the phone" or "Answer the phone"
	end,
	on_interact = function(player)
		if aaf_flags.get(player, CALL_DONE) then
			say(player, DEAD_PHONE_LINE)
		else
			call_step(player, 1)
		end
	end,
})

-- Dead ends of the key hunt: spot id -> {keys, label, line}
local SPOTS = {
	sofa = {keys = {"aaf_props:sofa_l#1", "aaf_props:sofa_r#1"}, label = "Search the sofa",
		line = "Between the cushions: a nickel, a button and the last of my dignity. No keys."},
	wastebasket = {keys = {"aaf_props:wastebasket#1"}, label = "Look in the wastebasket",
		line = "Old case files. Old regrets. No keys."},
	safe = {keys = {"aaf_props:safe#1"}, label = "Open the safe",
		line = "My safe. Three dollars and a photograph of a better man. No keys."},
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
			on_interact = function(player)
				say(player, spot.line)
				if aaf_tasks.has(player, TASK_KEYS) then
					aaf_flags.set(player, SEARCHED_PREFIX .. id, true)
					if searched_count(player) >= HINT_SPOTS then
						aaf_tasks.set_hint(player, TASK_KEYS, KEYS_HINT)
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
		core.swap_node(target.pos, {name = "aaf_props:desk_r", param2 = target.node.param2})
	end,
})

aaf_interact.register("aaf_office_story:door", {
	label = function(player)
		return aaf_flags.get(player, CAN_LEAVE) and "Leave" or "Try the door"
	end,
	on_interact = function(player)
		if not aaf_flags.get(player, CAN_LEAVE) then
			say(player, LOCKED_LINE)
			return
		end
		if aaf_places.travel(player, "station", LEAVE_LINES) then
			aaf_tasks.complete(player, TASK_LEAVE)
		end
	end,
})

local function start_intro(player)
	aaf_dialog.narrate(player, INTRO_LINES, function(p)
		aaf_flags.set(p, INTRO_SEEN, true)
		aaf_tasks.add(p, TASK_ANSWER, "Answer the phone")
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
	elseif aaf_tasks.has(player, TASK_KEYS) then
		-- The timer does not survive a rejoin
		start_hint_timer(player)
	end
end)
