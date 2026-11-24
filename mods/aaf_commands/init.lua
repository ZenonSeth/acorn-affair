aaf_commands = {}
aaf_commands.modpath = core.get_modpath(core.get_current_modname())

pcall(dofile, aaf_commands.modpath .. "/base.lua")
