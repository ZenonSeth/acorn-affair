-- Real midnight leaves only lamps lit; this keeps moonlit rooms dim but readable
local NIGHT_LIGHT = 0.3

local LIGHTING = {
	-- A set direction keeps shadows on at night; it points out towards the light (a low moon, about 28 degrees up, beyond -Z)
	shadows = {intensity = 0.9, tint = {r = 10, g = 14, b = 30}, direction = vector.normalize({x = 0.3, y = 0.47, z = -0.83})},
	bloom = {intensity = 0.1},
	volumetric_light = {strength = 0.2},
	exposure = {
		luminance_min = -3.5,
		luminance_max = -2.5,
		exposure_correction = 0,
		speed_dark_bright = 1500,
		speed_bright_dark = 700,
	},
	saturation = 0.9,
}

core.settings:set("time_speed", "0")

function aaf_environment.apply(player)
	player:override_day_night_ratio(NIGHT_LIGHT)
	player:set_lighting(LIGHTING)
	player:set_sky({
		type = "skybox",
		textures = {
			"aaf_sky_top.png",
			"aaf_sky_bottom.png",
			"aaf_sky_left.png",
			"aaf_sky_right.png",
			"aaf_sky_front.png",
			"aaf_sky_back.png",
		},
		clouds = false,
		base_color = "#06080e",
		fog = {fog_color = "#06080e"},
	})
	player:set_sun({visible = false, sunrise_visible = false})
	player:set_moon({visible = true})
	player:set_stars({visible = false})
end

local constants = aaf_utils.constants

-- A thin streak, brighter at the bottom, on a 32 px square so the particle stays narrow
local DROP_TEXTURE = "[fill:32x32:#00000000^[fill:1x14:15,0:#8c9cb060^[fill:1x18:15,14:#aabacec0"
local SPLASH_TEXTURE = "[fill:2x2:#aabace70"
local DROP_SIZE = 1.9
local DROP_SPEED = 12
-- Drops (and splashes) per second for each node of open street
local RAIN_DENSITY = 1
local RAIN_GLOW = 3
local RAIN_TOP = constants.floor_y + 7
local GROUND_Y = constants.street_y + 0.5

local function add_rain(player)
	local name = player:get_player_name()
	local fall_time = (RAIN_TOP + 1 - GROUND_Y) / DROP_SPEED + 0.2
	for _, area in ipairs(constants.rain_areas) do
		local cells = (area.maxp.x - area.minp.x + 1) * (area.maxp.z - area.minp.z + 1)
		local amount = math.ceil(cells * RAIN_DENSITY)
		local x0, x1 = area.minp.x - 0.5, area.maxp.x + 0.5
		local z0, z1 = area.minp.z - 0.5, area.maxp.z + 0.5
		core.add_particlespawner({
			playername = name,
			amount = amount,
			time = 0,
			pos = {min = vector.new(x0, RAIN_TOP, z0), max = vector.new(x1, RAIN_TOP + 1, z1)},
			vel = vector.new(0, -DROP_SPEED, 0),
			exptime = fall_time,
			size = DROP_SIZE,
			collisiondetection = true,
			collision_removal = true,
			vertical = true,
			texture = DROP_TEXTURE,
			glow = RAIN_GLOW,
		})
		core.add_particlespawner({
			playername = name,
			amount = amount,
			time = 0,
			pos = {min = vector.new(x0, GROUND_Y + 0.05, z0), max = vector.new(x1, GROUND_Y + 0.05, z1)},
			vel = {min = vector.new(-0.4, 0.8, -0.4), max = vector.new(0.4, 1.4, 0.4)},
			acc = vector.new(0, -12, 0),
			exptime = {min = 0.12, max = 0.2},
			size = {min = 0.06, max = 0.1},
			texture = SPLASH_TEXTURE,
			glow = RAIN_GLOW,
		})
	end
end

core.register_on_joinplayer(function(player)
	core.set_timeofday(0)
	aaf_environment.apply(player)
	add_rain(player)
	aaf_audio.sfx.start_loop(player, "ambience", "rain")
end)
