aaf_notebook = {}
aaf_notebook.modpath = core.get_modpath(core.get_current_modname())

dofile(aaf_notebook.modpath .. "/base.lua")
dofile(aaf_notebook.modpath .. "/settings.lua")
dofile(aaf_notebook.modpath .. "/toast.lua")
