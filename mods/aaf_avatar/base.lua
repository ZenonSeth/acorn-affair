local constants = aaf_utils.constants

-- Remove or comment out this block to allow multiplayer
core.register_on_prejoinplayer(function()
	if not core.is_singleplayer() then
		return "The Acorn Affair is singleplayer only.\n"
			.. "To try it anyway, comment out the singleplayer check in mods/aaf_avatar/base.lua."
	end
end)

-- Nodes per second
local SPEED = 4
local CROUCH_SPEED = 2
local GRAVITY = 20
-- The camera sits this far from the focus point, back along the look direction
local CAM_DISTANCE = 7
-- Focus point height above the avatar's feet
local FOCUS_HEIGHT = 1.45
-- How fast the rig closes the gap to its target (per second)
local FOLLOW_SPEED = 10
-- Pitch is positive looking down; the player can never look higher than MIN_PITCH
local MIN_PITCH = math.rad(30)
local PITCH_MARGIN = math.rad(0.5)
local START_PITCH = math.rad(60)
local START_YAW = 0
local SAVED_POS_KEY = "aaf_avatar:pos"

local HALF_WIDTH = 0.3
local HEIGHT = 1.9
local HALF_HEIGHT = HEIGHT / 2
local ANIM_BLEND = 0.15

-- Nodes walked per footstep; the first one plays this soon after starting off
local STRIDE = 1.7
local FIRST_STEP = 0.2
local CROUCH_STEP_GAIN = 0.5

core.override_item("", {range = 0})

-- Fills the hand slot in build mode; items without their own range use the hand's
core.register_craftitem("aaf_avatar:build_hand", {
	description = "Build mode hand",
	inventory_image = "blank.png",
	range = 10,
	groups = {not_in_creative_inventory = 1},
})
local BUILD_PRIVS = {"fly", "noclip", "fast", "give"}
local BUILD_FREEZE = "aaf_avatar:build"
local PLAY_HUD = {
	hotbar = false, healthbar = false, breathbar = false, crosshair = false,
	wielditem = false, minimap = false, minimap_radar = false,
}
local BUILD_HUD = {hotbar = true, crosshair = true, wielditem = true}

core.register_entity("aaf_avatar:detective", {
	initial_properties = {
		visual = "mesh",
		mesh = "aaf_avatar_detective.glb",
		-- glTF is exported in metres; Luanti's mesh scene node is in 1/10-node units
		visual_size = {x = 10, y = 10, z = 10},
		textures = {"aaf_avatar_detective.png"},
		physical = true,
		collide_with_objects = false,
		collisionbox = {-HALF_WIDTH, 0, -HALF_WIDTH, HALF_WIDTH, HEIGHT, HALF_WIDTH},
		pointable = false,
		static_save = false,
	},
	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
		self.object:set_acceleration(vector.new(0, -GRAVITY, 0))
	end,
})

core.register_entity("aaf_avatar:rig", {
	initial_properties = {
		visual = "cube",
		is_visible = false,
		physical = false,
		pointable = false,
		static_save = false,
	},
	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
	end,
})

-- player name -> {avatar = obj, rig = obj, eye_height = n, last_pos = pos, crouching = bool}
local sessions = {}
-- player name -> {pos = detective position to return to, privs = the privs it had before}
local building = {}
-- player name -> {reason -> true} while something (a dialog, a cutscene) holds the detective still
local frozen = {}

-- While any reason holds, the detective stands still and nothing can be used
function aaf_avatar.set_frozen(player, reason, on)
	local name = player:get_player_name()
	local reasons = frozen[name] or {}
	reasons[reason] = on or nil
	frozen[name] = next(reasons) and reasons or nil
end

function aaf_avatar.is_frozen(player)
	return frozen[player:get_player_name()] ~= nil
end

-- Feet position of the player's detective, or nil while it does not exist
function aaf_avatar.get_pos(player)
	local session = sessions[player:get_player_name()]
	return session and session.avatar:get_pos()
end

-- Horizontal unit vector the detective faces (the way it last walked), or nil while it does not exist
function aaf_avatar.get_facing(player)
	local session = sessions[player:get_player_name()]
	local yaw = session and session.avatar:get_yaw()
	return yaw and vector.new(-math.sin(yaw), 0, math.cos(yaw))
end

-- True while the player holds Sneak and the detective crouches
function aaf_avatar.is_crouching(player)
	local session = sessions[player:get_player_name()]
	return session ~= nil and session.crouching
end

local function rig_target(player, session, avatar_pos)
	local focus = vector.offset(avatar_pos, 0, FOCUS_HEIGHT, 0)
	local cam = vector.subtract(focus, vector.multiply(player:get_look_dir(), CAM_DISTANCE))
	return vector.offset(cam, 0, -session.eye_height, 0)
end

local function remove_session(name)
	local session = sessions[name]
	sessions[name] = nil
	if session then
		session.avatar:remove()
		session.rig:remove()
	end
end

local function set_anim(session, name, blend)
	if session.anim == name then
		return
	end
	if session.anim then
		session.avatar:stop_animation(session.anim)
	end
	session.avatar:play_animation(name, {speed = 1, blend = blend or ANIM_BLEND, loop = true})
	session.anim = name
end

local function start(player, pos)
	local name = player:get_player_name()
	local avatar = core.add_entity(pos, "aaf_avatar:detective")
	if not avatar then
		return
	end
	local session = {
		avatar = avatar, eye_height = player:get_properties().eye_height, last_pos = pos, crouching = false,
		step_left = FIRST_STEP,
	}
	local rig = core.add_entity(rig_target(player, session, pos), "aaf_avatar:rig")
	if not rig then
		avatar:remove()
		return
	end
	session.rig = rig
	sessions[name] = session
	set_anim(session, "idle", 0)
	player:set_attach(rig)
end

local function start_when_loaded(player, pos)
	local name = player:get_player_name()
	local radius = vector.new(16, 16, 16)
	core.emerge_area(vector.subtract(pos, radius), vector.add(pos, radius), function(_, _, remaining)
		if remaining > 0 then
			return
		end
		local p = core.get_player_by_name(name)
		if p and not sessions[name] and not building[name] then
			start(p, pos)
		end
	end)
end

core.register_on_joinplayer(function(player)
	local pos = core.string_to_pos(player:get_meta():get_string(SAVED_POS_KEY))
		or vector.offset(constants.spawn_pos, 0, -HALF_HEIGHT, 0)
	player:set_properties({is_visible = false, zoom_fov = 0})
	player:set_camera({mode = "first"})
	player:set_look_vertical(START_PITCH)
	player:set_look_horizontal(START_YAW)
	player:hud_set_flags(PLAY_HUD)
	player:set_pos(pos)
	start_when_loaded(player, pos)
end)

local function save_pos(player, pos)
	player:get_meta():set_string(SAVED_POS_KEY, core.pos_to_string(pos, 2))
end

-- Moves the detective (pos is its centre, like constants.spawn_pos); false if there is none
function aaf_avatar.teleport(player, pos)
	local session = sessions[player:get_player_name()]
	if not session then
		return false
	end
	local feet = vector.offset(pos, 0, -HALF_HEIGHT, 0)
	session.avatar:set_pos(feet)
	session.avatar:set_velocity(vector.zero())
	session.last_pos = vector.copy(feet)
	-- The rig would otherwise fly the camera across the map
	session.rig:set_pos(rig_target(player, session, feet))
	session.rig:set_velocity(vector.zero())
	return true
end

function aaf_avatar.is_building(player)
	return building[player:get_player_name()] ~= nil
end

local on_building = {}

-- fn(player, on) runs after the player enters or leaves build mode
function aaf_avatar.register_on_building(fn)
	on_building[#on_building + 1] = fn
end

-- Build mode: the detective stays put with controls disconnected; the player flies free with the hotbar and reach 10
function aaf_avatar.set_building(player, on)
	local name = player:get_player_name()
	if on == (building[name] ~= nil) then
		return
	end
	local inv = player:get_inventory()
	local session = sessions[name]
	if on then
		local pos = session and (session.avatar:get_pos() or session.last_pos) or player:get_pos()
		local cam = session and session.rig:get_pos()
		local privs = core.get_player_privs(name)
		building[name] = {pos = pos, privs = table.copy(privs)}
		save_pos(player, pos)
		aaf_avatar.set_frozen(player, BUILD_FREEZE, true)
		if session then
			local vel = session.avatar:get_velocity()
			if vel then
				session.avatar:set_velocity(vector.new(0, vel.y, 0))
			end
			set_anim(session, session.crouching and "crouch_idle" or "idle")
			session.rig:set_velocity(vector.zero())
		end
		player:set_detach()
		if cam then
			player:set_pos(cam)
		end
		for _, priv in ipairs(BUILD_PRIVS) do
			privs[priv] = true
		end
		core.set_player_privs(name, privs)
		inv:set_size("hand", 1)
		inv:set_stack("hand", 1, "aaf_avatar:build_hand")
		player:hud_set_flags(BUILD_HUD)
	else
		local state = building[name]
		building[name] = nil
		aaf_avatar.set_frozen(player, BUILD_FREEZE, false)
		core.set_player_privs(name, state.privs)
		inv:set_size("hand", 0)
		player:hud_set_flags(PLAY_HUD)
		player:set_look_vertical(START_PITCH)
		local pos = session and session.avatar:get_pos()
		if pos and session.rig:get_pos() then
			session.last_pos = pos
			session.rig:set_pos(rig_target(player, session, pos))
			session.rig:set_velocity(vector.zero())
			player:set_attach(session.rig)
		else
			remove_session(name)
			start_when_loaded(player, state.pos)
		end
	end
	for _, fn in ipairs(on_building) do
		fn(player, on)
	end
end

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local session = sessions[name]
	if session then
		save_pos(player, session.avatar:get_pos() or session.last_pos)
	end
	if building[name] then
		aaf_avatar.set_building(player, false)
	end
	frozen[name] = nil
	remove_session(name)
end)

local function clamp_pitch(player)
	if player:get_look_vertical() < MIN_PITCH - PITCH_MARGIN then
		player:set_look_vertical(MIN_PITCH)
	end
end

local function move_avatar(player, session)
	local avatar = session.avatar
	local vel = avatar:get_velocity()
	if frozen[player:get_player_name()] then
		avatar:set_velocity(vector.new(0, vel.y, 0))
		set_anim(session, session.crouching and "crouch_idle" or "idle")
		return
	end
	local ctrl = player:get_player_control()
	session.crouching = ctrl.sneak
	local speed = session.crouching and CROUCH_SPEED or SPEED
	local yaw = player:get_look_horizontal()
	local fwd = (ctrl.up and 1 or 0) - (ctrl.down and 1 or 0)
	local side = (ctrl.right and 1 or 0) - (ctrl.left and 1 or 0)
	-- Yaw is counter-clockwise from +Z, so forward is (-sin, cos) and right is (cos, sin)
	local dir = vector.normalize(vector.new(
		-math.sin(yaw) * fwd + math.cos(yaw) * side, 0,
		math.cos(yaw) * fwd + math.sin(yaw) * side))
	avatar:set_velocity(vector.new(dir.x * speed, vel.y, dir.z * speed))
	local moving = dir.x ~= 0 or dir.z ~= 0
	if moving then
		avatar:set_yaw(math.atan2(-dir.x, dir.z))
	end
	if session.crouching then
		set_anim(session, moving and "crouch_walk" or "crouch_idle")
	else
		set_anim(session, moving and "walk" or "idle")
	end
end

-- Steps by the distance actually walked, so pushing against a wall stays quiet
local function play_footsteps(player, session, from, to)
	local walked = math.sqrt((to.x - from.x) ^ 2 + (to.z - from.z) ^ 2)
	if walked < 0.001 or walked > 1 or math.abs(to.y - from.y) > 0.01 then
		session.step_left = FIRST_STEP
		return
	end
	session.step_left = session.step_left - walked
	if session.step_left > 0 then
		return
	end
	session.step_left = session.step_left + STRIDE
	local def = core.registered_nodes[core.get_node(vector.offset(to, 0, -0.2, 0)).name]
	if def and def.walkable then
		aaf_audio.sfx.play("footstep_" .. (def._aaf_footstep or "wood"),
			{player = player, gain = session.crouching and CROUCH_STEP_GAIN or 1})
	end
end

core.register_globalstep(function(dtime)
	for name, session in pairs(sessions) do
		local player = core.get_player_by_name(name)
		local pos = session.avatar:get_pos()
		local rig_pos = session.rig:get_pos()
		if not player then
			remove_session(name)
		elseif building[name] then
			if pos then
				session.last_pos = pos
			end
		elseif not pos or not rig_pos then
			-- An entity was lost (e.g. its block unloaded): rebuild both where the avatar was
			local last = session.last_pos
			remove_session(name)
			start_when_loaded(player, last)
		else
			play_footsteps(player, session, session.last_pos, pos)
			session.last_pos = pos
			clamp_pitch(player)
			move_avatar(player, session)
			local offset = vector.subtract(rig_target(player, session, pos), rig_pos)
			session.rig:set_velocity(vector.multiply(offset, math.min(FOLLOW_SPEED, 1 / dtime)))
		end
	end
end)
