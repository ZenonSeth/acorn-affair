local CAN_LEAVE = "office:can_leave"

local LOCKED_LINE = "Locked. I locked it myself. Of course I did."
local LEAVE_LINE = "The cab smelled of wet dog and broken dreams. "
	.. "Twenty minutes later I was standing in the police station. Nobody was home."

-- Until the dialog system exists, the detective's lines go to chat
local function say(player, text)
	core.chat_send_player(player:get_player_name(), text)
end

aaf_interact.register("aaf_office_story:door", {
	label = function(player)
		return aaf_flags.get(player, CAN_LEAVE) and "Leave" or "Try the door"
	end,
	on_interact = function(player)
		if not aaf_flags.get(player, CAN_LEAVE) then
			say(player, LOCKED_LINE)
			return
		end
		say(player, LEAVE_LINE)
		aaf_places.move(player, "station")
	end,
})

-- Temporary until the phone call and the key hunt set it
core.register_on_joinplayer(function(player)
	aaf_flags.set(player, CAN_LEAVE, true)
end)
