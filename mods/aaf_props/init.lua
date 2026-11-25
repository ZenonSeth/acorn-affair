aaf_props = {}
aaf_props.modpath = core.get_modpath(core.get_current_modname())

dofile(aaf_props.modpath .. "/base.lua")
dofile(aaf_props.modpath .. "/ceiling_lamp.lua")
