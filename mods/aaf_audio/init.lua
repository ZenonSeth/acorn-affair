aaf_audio = {
	music = {},
	sfx = {},
}
aaf_audio.modpath = core.get_modpath(core.get_current_modname())

dofile(aaf_audio.modpath .. "/base.lua")
