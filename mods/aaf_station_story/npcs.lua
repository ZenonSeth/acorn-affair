-- Post-ending station NPCs seated on their tagged chairs, with two-step epilogue conversations
local PLACE = "station"
local CHAIR_NODE = "aaf_props:chair"
local CHAIR_OCCUPIED = "aaf_props:chair_occupied"
local CHAIR_NODES = {CHAIR_NODE, CHAIR_OCCUPIED}
local DETECTIVE = "Jack Graves"
local TALKED_PREFIX = "station:epilogue_talked_"
local EPILOGUE_STARTED = "station:epilogue_started"
local TASK_PREFIX = "station:epilogue_"
local SCAN_INTERVAL = 1
local SCAN_RADIUS = vector.new(24, 6, 24)
-- Seat cushion top is at y + 1/32; hips sit 0.625 above the model origin
local SEAT_Y_OFFSET = -0.52

-- chair param2 tag -> npc id
local CHAIR_NPCS = {
	[1] = "miller",
	[10] = "fred",
	[11] = "thompson",
	[12] = "jenkins",
	[30] = "chief",
}

local function return_key(player, flag, toast)
	if not aaf_flags.get(player, flag) then
		aaf_flags.set(player, flag, true)
		aaf_audio.sfx.play("keys_jingle", {player = player})
		aaf_notebook.refresh(player)
		aaf_notebook.notify(player, {toast})
	end
end

local function jack_says(player, text, on_done, label)
	aaf_dialog.talk(player, {
		speaker = DETECTIVE,
		portrait = "detective",
		text = text,
		options = {{text = label or "Continue", on_choose = on_done}},
	})
end

local NPCS = {
	chief = {
		name = "Chief Arthur Harrington",
		speaker = "Chief Harrington",
		first = function(player)
			local has_drawer = aaf_flags.get(player, "station:has_chief_key") ~= nil
			return {
				open = "Graves! Good timing. Still trying to live down that front-page headline.",
				choice1 = "Your keys, Chief.",
				jack1 = has_drawer
					and "Brought back your station keys, and the spare from behind your service certificate."
					or "Brought back your station keys. Left the register just how I found it.",
				on_step1 = function(p)
					return_key(p, "station:returned_chief",
						has_drawer and "Returned: Chief's keys" or "Returned: Chief's station key")
				end,
				reply1 = "Appreciate it. Though I'm still deciding whether to put a padlock on the window or hire a hawk.",
				choice2 = "And the ACORN?",
				jack2 = "At least you got the ACORN back in one piece. Mostly.",
				reply2 = "Two tooth marks on the pedestal, Graves. Two. Still... good work. Don't let it go to your head.",
				bye = "Take care, Chief.",
			}
		end,
		again = "I told Miller to file the squirrel under 'repeat offender.' She gave me a look that could curdle milk.",
		again_bye = "Good luck with that.",
	},
	miller = {
		name = "Sgt. Edna Miller",
		speaker = "Sgt. Miller",
		first = function(player)
			local has_key = aaf_flags.get(player, "station:has_miller_key") ~= nil
			return {
				open = "Detective Graves. You're the talk of the precinct this morning.",
				choice1 = has_key and "Your spare key." or "Nice call logs.",
				jack1 = has_key
					and "Found your spare desk key in the storage crates. Returning it before you write me up."
					or "Have to say, Sergeant, your call logs saved me half the night.",
				on_step1 = has_key and function(p)
					return_key(p, "station:returned_miller", "Returned: Miller's spare key")
				end or nil,
				reply1 = has_key
					and "I wondered who'd been in those crates. At least you put it back in one piece."
					or "Somebody around here has to keep records, Detective.",
				choice2 = "How's the paperwork?",
				jack2 = "How's the arrest paperwork going for our bushy-tailed suspect?",
				reply2 = "There is no form for a rodent, Graves. I had to invent two. Tell the Chief next time to close his window.",
				bye = "Will do.",
			}
		end,
		again = "Three pages of incident report for a squirrel. My pen is never going to forgive me.",
		again_bye = "Hang in there.",
	},
	jenkins = {
		name = "Det. Walter Jenkins",
		speaker = "Det. Jenkins",
		first = function(player)
			local has_key = aaf_flags.get(player, "station:has_jenkins_key") ~= nil
			return {
				open = "Hey, Graves. Heard you cracked the big nut heist.",
				choice1 = has_key and "Found your key." or "About those peanuts.",
				jack1 = has_key
					and "Fished your desk key out of your wastebasket last night. Thought you might want it back."
					or "Good news, Jenkins. Your peanut thief is officially behind bars.",
				on_step1 = has_key and function(p)
					return_key(p, "station:returned_jenkins", "Returned: Jenkins' key")
				end or nil,
				reply1 = has_key
					and "Oh! That's where it went! I thought I lost it at the Rialto."
					or "A squirrel. I can't believe I filed three complaints against a squirrel.",
				choice2 = "Square with Thompson?",
				jack2 = "So you and Thompson are square now?",
				reply2 = "Mostly. Though I'm still keeping my peanuts in a tin can from now on. Just in case.",
				bye = "Smart move.",
			}
		end,
		again = "I'm buying a metal tin for the peanuts tomorrow. Let's see a squirrel chew through steel.",
		again_bye = "Good luck.",
	},
	thompson = {
		name = "Det. Ray Thompson",
		speaker = "Det. Thompson",
		first = function(player)
			local picked = aaf_station_story.knows(player, "thompson_log")
			return {
				open = "Detective. Didn't expect to see you back here again.",
				choice1 = picked and "About your lock..." or "About your sandwiches...",
				jack1 = picked
					and "Look, Thompson, I owe you an apology. I had to pick your desk lock last night. Chief's orders."
					or "Turns out the phantom sandwich-biter wasn't Jenkins after all.",
				reply1 = picked
					and "I noticed the scratch on the brass. That lock's older than the Chief, Graves. I'll send you the bill."
					or "A squirrel. I sat here ninety minutes staring at Jenkins' peanuts for a squirrel.",
				choice2 = "Lunches are safe.",
				jack2 = "Look on the bright side, your lunches are safe again.",
				reply2 = "Until the next one climbs the elm. Good work anyway, Detective. Just keep those picks in your pocket.",
				bye = "Fair enough.",
			}
		end,
		again = "New padlock on the drawer, lunchbox with a clasp. I'm ready for anything now.",
		again_bye = "Glad to hear it.",
	},
	fred = {
		name = "Fred Pickett",
		speaker = "Fred Pickett",
		first = function()
			return {
				open = "Oh, hey Detective! Thanks for getting that kitchen door unstuck last night.",
				choice1 = "Holding up alright?",
				jack1 = "Four hours in a locked kitchen's rough, Fred. You holding up alright?",
				reply1 = "Yeah, once I stopped smelling burnt coffee. Still can't believe the thief went right under the Chief's door.",
				choice2 = "Sign the register.",
				jack2 = "Just remember to sign the register next time, alright?",
				reply2 = "Already wrote myself a note! Now if I can just remember where I put the note...",
				bye = "Never change, Fred.",
			}
		end,
		again = "I signed in twice this morning just to be safe. Miller crossed one of them out.",
		again_bye = "Progress.",
	},
}

local function talk_to(player, id)
	local npc = NPCS[id]
	if aaf_flags.get(player, TALKED_PREFIX .. id) then
		aaf_dialog.talk(player, {
			speaker = npc.speaker,
			portrait = id,
			text = npc.again,
			options = {{text = npc.again_bye, on_choose = function() end}},
		})
		return
	end
	local c = npc.first(player)
	aaf_dialog.talk(player, {
		speaker = npc.speaker,
		portrait = id,
		text = c.open,
		options = {{text = c.choice1, on_choose = function(p)
			jack_says(p, c.jack1, function(p2)
				if c.on_step1 then
					c.on_step1(p2)
				end
				aaf_dialog.talk(p2, {
					speaker = npc.speaker,
					portrait = id,
					text = c.reply1,
					options = {{text = c.choice2, on_choose = function(p3)
						jack_says(p3, c.jack2, function(p4)
							aaf_flags.set(p4, TALKED_PREFIX .. id, true)
							aaf_tasks.complete(p4, TASK_PREFIX .. id)
							aaf_dialog.talk(p4, {
								speaker = npc.speaker,
								portrait = id,
								text = c.reply2,
								options = {{text = c.bye, on_choose = function() end}},
							})
						end)
					end}},
				})
			end)
		end}},
	})
end

for id, npc in pairs(NPCS) do
	core.register_entity("aaf_station_story:npc_" .. id, {
		initial_properties = {
			visual = "mesh",
			mesh = "aaf_station_story_" .. id .. ".glb",
			visual_size = {x = 10, y = 10, z = 10},
			textures = {"aaf_station_story_" .. id .. ".png"},
			-- Raised collisionbox keeps the entity's light sample in the room air instead of the floor node
			collisionbox = {-0.3, 0, -0.3, 0.3, 1.5, 0.3},
			physical = false,
			collide_with_objects = false,
			pointable = false,
			static_save = false,
		},
		_aaf_interact = {
			label = "Talk to " .. npc.name,
			reach = "radius",
			radius = 2.0,
			priority = 10,
			can_interact = function(player)
				return aaf_station_story.is_epilogue(player)
			end,
			on_interact = function(player)
				talk_to(player, id)
			end,
		},
		on_activate = function(self)
			self.object:set_armor_groups({immortal = 1})
			self.object:play_animation("sitting", {speed = 1, blend = 0, loop = true})
		end,
	})
end

-- chair position hash -> spawned npc object
local active = {}

local function spawn_at_chair(pos, id, rot)
	local key = core.hash_node_position(pos)
	local obj = active[key]
	if obj and obj:is_valid() then
		return
	end
	local npc = core.add_entity(vector.offset(pos, 0, SEAT_Y_OFFSET, 0), "aaf_station_story:npc_" .. id)
	if npc then
		npc:set_yaw(math.pi - rot * math.pi / 2)
		active[key] = npc
	end
end

local EPILOGUE_ORDER = {"miller", "fred", "thompson", "jenkins", "chief"}

local function epilogue_task_text(player, id)
	if id == "chief" then
		return "Return the Chief's keys"
	elseif id == "miller" then
		return aaf_flags.get(player, "station:has_miller_key") and "Return Miller's spare key" or "Talk to Sgt. Miller"
	elseif id == "jenkins" then
		return aaf_flags.get(player, "station:has_jenkins_key") and "Return Jenkins' key" or "Talk to Det. Jenkins"
	elseif id == "thompson" then
		return aaf_station_story.knows(player, "thompson_log") and "Apologize to Det. Thompson" or "Talk to Det. Thompson"
	end
	return "Check in on Fred Pickett"
end

local EPILOGUE_REMOVE = {"aaf_props:peanut_shells", "aaf_props:paper_scrap"}

local function update_epilogue_nodes(centre)
	local minp, maxp = centre - SCAN_RADIUS, centre + SCAN_RADIUS
	for _, pos in ipairs(core.find_nodes_in_area(minp, maxp, "aaf_props:clock")) do
		core.swap_node(pos, {name = "aaf_props:clock_915", param2 = core.get_node(pos).param2})
	end
	for _, pos in ipairs(core.find_nodes_in_area(minp, maxp, EPILOGUE_REMOVE)) do
		core.remove_node(pos)
	end
end

local function start_epilogue_tasks(player)
	if not aaf_station_story.is_epilogue(player) or aaf_flags.get(player, EPILOGUE_STARTED) then
		return
	end
	aaf_flags.set(player, EPILOGUE_STARTED, true)
	for _, id in ipairs(EPILOGUE_ORDER) do
		if not aaf_flags.get(player, TALKED_PREFIX .. id) then
			aaf_tasks.add(player, TASK_PREFIX .. id, epilogue_task_text(player, id))
		end
	end
end

aaf_places.register_on_arrive(PLACE, function(player)
	if not aaf_station_story.is_epilogue(player) then
		return
	end
	start_epilogue_tasks(player)
	update_epilogue_nodes(vector.round(player:get_pos()))
end)

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < SCAN_INTERVAL then
		return
	end
	timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		if aaf_places.get(player) == PLACE and aaf_station_story.is_epilogue(player) then
			start_epilogue_tasks(player)
			local centre = vector.round(player:get_pos())
			update_epilogue_nodes(centre)
			for _, pos in ipairs(core.find_nodes_in_area(centre - SCAN_RADIUS, centre + SCAN_RADIUS, CHAIR_NODES)) do
				local node = core.get_node(pos)
				local id = CHAIR_NPCS[math.floor(node.param2 / 4)]
				if id then
					if node.name ~= CHAIR_OCCUPIED then
						core.swap_node(pos, {name = CHAIR_OCCUPIED, param2 = node.param2})
					end
					spawn_at_chair(pos, id, node.param2 % 4)
				end
			end
		end
	end
end)
