aaf_utils = {}
aaf_utils.modpath = core.get_modpath(core.get_current_modname())

-- Also loaded by the mapgen script, so it returns its table instead of assigning it
aaf_utils.constants = dofile(aaf_utils.modpath .. "/constants.lua")
dofile(aaf_utils.modpath .. "/base.lua")
