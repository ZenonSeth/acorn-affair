local CAN_LEAVE = "station:can_leave"

local LOCKED_LINE = "Not until this is solved."
local RESTROOM_LINE = "Some mysteries a man leaves alone."
local KITCHEN_STUCK_LINE = "Stuck. Somebody should fix this door. Somebody won't."
local LEAVE_LINES = {"Back to the office. The cab driver remembered me. Neither of us was happy about it."}
local ARRIVED = "station:arrived"

-- The detective's own lines
local function say(player, text)
	aaf_dialog.think(player, text)
end

aaf_interact.register("aaf_station_story:door", {
	label = function(player)
		return aaf_flags.get(player, CAN_LEAVE) and "Leave" or "Try the door"
	end,
	on_interact = function(player)
		if not aaf_flags.get(player, CAN_LEAVE) then
			say(player, LOCKED_LINE)
			return
		end
		aaf_places.travel(player, "office", LEAVE_LINES)
	end,
})

aaf_interact.register("aaf_station_story:restroom", {
	label = "Try the restroom door",
	on_interact = function(player)
		say(player, RESTROOM_LINE)
	end,
})

aaf_interact.register("aaf_station_story:fridge", {
	label = "Open the fridge",
	on_interact = function(player)
		say(player, "Half a sandwich. Evidence of something. Probably lunch.")
	end,
})

aaf_interact.register("aaf_station_story:sink", {
	label = "Look at the sink",
	on_interact = function(player)
		say(player, "A dripping tap. It had been talking all night. Nobody listened.")
	end,
})

-- Stuck until the chief's tip about Fred
aaf_doors.set_rule("kitchen", function(player)
	return aaf_station_story.is_accused(player, "fred") or KITCHEN_STUCK_LINE
end)

-- The case's tasks, on the first arrival
aaf_places.register_on_arrive("station", function(player)
	if not aaf_flags.get(player, ARRIVED) then
		aaf_flags.set(player, ARRIVED, true)
		aaf_tasks.add(player, "station:case", "Find out who took the ACORN")
		aaf_tasks.add(player, "station:report", "Report to the Chief (front desk phone)")
	end
end)

-- Temporary: the case being solved will set it
core.register_on_joinplayer(function(player)
	aaf_flags.set(player, CAN_LEAVE, true)
end)
