local fill = aaf_utils.fill
local constants = aaf_utils.constants

-- Nodes per second
local SPEED = 4
local CROUCH_SPEED = 2
local GRAVITY = 20
-- The camera sits this far from the focus point, back along the look direction
local CAM_DISTANCE = 7
-- Focus point height above the avatar's origin
local FOCUS_HEIGHT = 0.5
-- How fast the rig closes the gap to its target (per second)
local FOLLOW_SPEED = 10
-- Pitch is positive looking down; the player can never look higher than MIN_PITCH
local MIN_PITCH = math.rad(30)
local PITCH_MARGIN = math.rad(0.5)
local START_PITCH = math.rad(60)
local START_YAW = 0
local SAVED_POS_KEY = "aaf_avatar:pos"

local HALF_WIDTH = 0.3
local HALF_HEIGHT = 0.95
-- Placeholder cube height while crouched, as a fraction of standing height
local CROUCH_SCALE = 0.7

core.override_item("", {range = 0})

-- Fills the hand slot in build mode; items without their own range use the hand's
core.register_craftitem("aaf_avatar:build_hand", {
	description = "Build mode hand",
	inventory_image = "blank.png",
	range = 10,
	groups = {not_in_creative_inventory = 1},
})
local BUILD_PRIVS = {"fly", "noclip", "fast", "give"}
local PLAY_HUD = {
	hotbar = false, healthbar = false, breathbar = false, crosshair = false,
	wielditem = false, minimap = false, minimap_radar = false,
}
local BUILD_HUD = {hotbar = true, crosshair = true, wielditem = true}

core.register_entity("aaf_avatar:detective", {
	initial_properties = {
		visual = "cube",
		visual_size = {x = HALF_WIDTH * 2, y = HALF_HEIGHT * 2, z = HALF_WIDTH * 2},
		-- +Y, -Y, +X, -X, +Z (front at yaw 0), -Z
		textures = {
			fill("#6b5a3e"), fill("#2a2a2a"), fill("#8a7350"),
			fill("#8a7350"), fill("#d9c9a3"), fill("#8a7350"),
		},
		physical = true,
		collide_with_objects = false,
		collisionbox = {-HALF_WIDTH, -HALF_HEIGHT, -HALF_WIDTH, HALF_WIDTH, HALF_HEIGHT, HALF_WIDTH},
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

-- Feet position of the player's detective, or nil while it does not exist
function aaf_avatar.get_pos(player)
	local session = sessions[player:get_player_name()]
	local pos = session and session.avatar:get_pos()
	return pos and vector.offset(pos, 0, -HALF_HEIGHT, 0)
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

local function start(player, pos)
	local name = player:get_player_name()
	local avatar = core.add_entity(pos, "aaf_avatar:detective")
	if not avatar then
		return
	end
	local session = {avatar = avatar, eye_height = player:get_properties().eye_height, last_pos = pos, crouching = false}
	local rig = core.add_entity(rig_target(player, session, pos), "aaf_avatar:rig")
	if not rig then
		avatar:remove()
		return
	end
	session.rig = rig
	sessions[name] = session
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
		if p and not sessions[name] then
			start(p, pos)
		end
	end)
end

core.register_on_joinplayer(function(player)
	local pos = core.string_to_pos(player:get_meta():get_string(SAVED_POS_KEY)) or vector.copy(constants.spawn_pos)
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
	session.avatar:set_pos(pos)
	session.avatar:set_velocity(vector.zero())
	session.last_pos = vector.copy(pos)
	return true
end

function aaf_avatar.is_building(player)
	return building[player:get_player_name()] ~= nil
end

-- Build mode: no detective, the player flies free with the hotbar and a reach of 10
function aaf_avatar.set_building(player, on)
	local name = player:get_player_name()
	if on == (building[name] ~= nil) then
		return
	end
	local inv = player:get_inventory()
	if on then
		local session = sessions[name]
		local pos = session and (session.avatar:get_pos() or session.last_pos) or player:get_pos()
		local cam = session and session.rig:get_pos()
		local privs = core.get_player_privs(name)
		building[name] = {pos = pos, privs = table.copy(privs)}
		save_pos(player, pos)
		remove_session(name)
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
		core.set_player_privs(name, state.privs)
		inv:set_size("hand", 0)
		player:hud_set_flags(PLAY_HUD)
		player:set_look_vertical(START_PITCH)
		start_when_loaded(player, state.pos)
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
	remove_session(name)
end)

local function clamp_pitch(player)
	if player:get_look_vertical() < MIN_PITCH - PITCH_MARGIN then
		player:set_look_vertical(MIN_PITCH)
	end
end

local function set_crouching(session, crouching)
	if crouching == session.crouching then
		return
	end
	session.crouching = crouching
	local height = HALF_HEIGHT * 2 * (crouching and CROUCH_SCALE or 1)
	session.avatar:set_properties({visual_size = {x = HALF_WIDTH * 2, y = height, z = HALF_WIDTH * 2}})
end

local function move_avatar(player, session)
	local avatar = session.avatar
	local ctrl = player:get_player_control()
	set_crouching(session, ctrl.sneak)
	local speed = session.crouching and CROUCH_SPEED or SPEED
	local yaw = player:get_look_horizontal()
	local fwd = (ctrl.up and 1 or 0) - (ctrl.down and 1 or 0)
	local side = (ctrl.right and 1 or 0) - (ctrl.left and 1 or 0)
	-- Yaw is counter-clockwise from +Z, so forward is (-sin, cos) and right is (cos, sin)
	local dir = vector.normalize(vector.new(
		-math.sin(yaw) * fwd + math.cos(yaw) * side, 0,
		math.cos(yaw) * fwd + math.sin(yaw) * side))
	local vel = avatar:get_velocity()
	avatar:set_velocity(vector.new(dir.x * speed, vel.y, dir.z * speed))
	if dir.x ~= 0 or dir.z ~= 0 then
		avatar:set_yaw(math.atan2(-dir.x, dir.z))
	end
end

core.register_globalstep(function(dtime)
	for name, session in pairs(sessions) do
		local player = core.get_player_by_name(name)
		local pos = session.avatar:get_pos()
		local rig_pos = session.rig:get_pos()
		if not player then
			remove_session(name)
		elseif not pos or not rig_pos then
			-- An entity was lost (e.g. its block unloaded): rebuild both where the avatar was
			local last = session.last_pos
			remove_session(name)
			start_when_loaded(player, last)
		else
			session.last_pos = pos
			clamp_pitch(player)
			move_avatar(player, session)
			local offset = vector.subtract(rig_target(player, session, pos), rig_pos)
			session.rig:set_velocity(vector.multiply(offset, math.min(FOLLOW_SPEED, 1 / dtime)))
		end
	end
end)
