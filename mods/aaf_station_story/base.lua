local CAN_LEAVE = "station:can_leave"
local HAS_LOCKPICKS = "station:has_lockpicks"
local ENDING_SEEN = "office:ending_seen"

local RESTROOM_LINE = "Some mysteries are best left alone."
local RECEPTION_LOCKED_LINE = "Locked. The Chief said his keys were under the register."
local KITCHEN_STUCK_LINE = "Stuck. Somebody should fix this door. Somebody won't."
local KITCHEN_NEED_PICKS_LINE = "Still jammed. I'll need my lockpicking kit from the office safe."
local MIDCASE_LEAVE_LINES = {"Back to the office. The cab driver didn't ask questions. I liked him for that."}
local LEAVE_LINES = {"Back to the office. The cab driver remembered me. He didn't even ask for the address."}
local EPILOGUE_LEAVE_LINES = {"Back to the office. Quiet streets, warm cab, no missing acorns."}
local ARRIVED = "station:arrived"

function aaf_station_story.is_epilogue(player)
	return aaf_flags.get(player, ENDING_SEEN) ~= nil
end

local function not_epilogue(player)
	return not aaf_station_story.is_epilogue(player)
end

-- Disable case clues, desks and the front desk phone once the ending has played
aaf_places.set_things_enabled("station", not_epilogue)

-- The detective's own lines
local function say(player, text)
	aaf_dialog.think(player, text)
end

aaf_interact.register("aaf_station_story:door", {
	label = function(player)
		return aaf_flags.get(player, CAN_LEAVE) and "Leave" or "Return to office"
	end,
	on_interact = function(player)
		local solved = aaf_flags.get(player, CAN_LEAVE)
		local lines = aaf_station_story.is_epilogue(player) and EPILOGUE_LEAVE_LINES
			or (solved and LEAVE_LINES or MIDCASE_LEAVE_LINES)
		if aaf_places.travel(player, "office", lines) and solved then
			aaf_tasks.complete(player, "station:leave")
		end
	end,
})

aaf_interact.register("aaf_station_story:restroom", {
	label = "Try the restroom door",
	can_interact = not_epilogue,
	on_interact = function(player)
		say(player, RESTROOM_LINE)
	end,
})

aaf_interact.register("aaf_station_story:fridge", {
	label = "Open the fridge",
	can_interact = not_epilogue,
	on_interact = function(player)
		say(player, "Half a sandwich. Evidence of something. Probably lunch.")
	end,
})

aaf_interact.register("aaf_station_story:sink", {
	label = "Look at the sink",
	can_interact = not_epilogue,
	on_interact = function(player)
		say(player, "A dripping tap. Rehearsing a speech all night. Nobody stayed for the encore.")
	end,
})

-- Locked until the register is read (the keys are under it), so every suspect is listed before the clues
aaf_doors.set_rule("reception", function(player)
	return aaf_station_story.is_epilogue(player) or aaf_station_story.knows(player, "register") or RECEPTION_LOCKED_LINE
end)

-- Stuck until the detective brings the lockpicking kit from the office safe
aaf_doors.set_rule("kitchen", function(player)
	if aaf_station_story.is_epilogue(player) or aaf_flags.get(player, HAS_LOCKPICKS) then
		return true
	end
	return aaf_station_story.is_accused(player, "fred") and KITCHEN_NEED_PICKS_LINE or KITCHEN_STUCK_LINE
end)

-- The case's tasks, on the first arrival
aaf_places.register_on_arrive("station", function(player)
	if not aaf_flags.get(player, ARRIVED) then
		aaf_flags.set(player, ARRIVED, true)
		aaf_tasks.add(player, "station:keys", "Get the Chief's keys (under the register)")
		aaf_tasks.add(player, "station:case", "Find out who took the ACORN")
		aaf_tasks.add(player, "station:report", "Report to the Chief (front desk phone)")
		aaf_notebook.refresh(player)
	end
end)
