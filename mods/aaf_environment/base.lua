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
		type = "regular",
		clouds = false,
		-- the raised night light blends in the day colours, so every phase is night
		sky_color = {
			day_sky = "#05070e", day_horizon = "#0a0d16",
			dawn_sky = "#05070e", dawn_horizon = "#0a0d16",
			night_sky = "#05070e", night_horizon = "#0a0d16",
		},
		fog = {fog_color = "#06080e"},
	})
	player:set_sun({visible = false, sunrise_visible = false})
	player:set_moon({visible = true})
	player:set_stars({visible = true, count = 600})
end

core.register_on_joinplayer(function(player)
	core.set_timeofday(0)
	aaf_environment.apply(player)
end)
