local CAN_LEAVE = "station:can_leave"

local LOCKED_LINE = "Not until this is solved."
local RESTROOM_LINE = "Some mysteries a man leaves alone."
local KITCHEN_UNSTUCK = "station:kitchen_unstuck"
local KITCHEN_STUCK_LINE = "Stuck. Somebody should fix this door. Somebody won't."
local LEAVE_LINE = "Back to the office. The cab driver remembered me. Neither of us was happy about it."

-- Until the dialog system exists, the detective's lines go to chat
local function say(player, text)
	core.chat_send_player(player:get_player_name(), text)
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
		say(player, LEAVE_LINE)
		aaf_places.move(player, "office")
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

-- Stuck until the chief's tip about Fred sets the flag
aaf_doors.set_rule("kitchen", function(player)
	return aaf_flags.get(player, KITCHEN_UNSTUCK) and true or KITCHEN_STUCK_LINE
end)

-- Temporary: the case being solved will set it
core.register_on_joinplayer(function(player)
	aaf_flags.set(player, CAN_LEAVE, true)
end)
