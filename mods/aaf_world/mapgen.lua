local constants = dofile(core.get_modpath("aaf_utils") .. "/constants.lua")

local OFFICE_PATH = core.get_modpath("aaf_world") .. "/schems/office.mts"
local origin = constants.office.origin

local file = io.open(OFFICE_PATH, "rb")
local office = file and core.read_schematic(OFFICE_PATH, {})
if file then
	file:close()
else
	core.log("warning", "aaf_world: no office schematic at " .. OFFICE_PATH)
end

core.register_on_generated(function(vm, minp, maxp)
	if not office then
		return
	end
	local emin, emax = vm:get_emerged_area()
	local last = vector.add(origin, vector.subtract(office.size, 1))
	if emax.x < origin.x or emin.x > last.x or emax.y < origin.y or emin.y > last.y
			or emax.z < origin.z or emin.z > last.z then
		return
	end
	core.place_schematic_on_vmanip(vm, origin, OFFICE_PATH, "0", nil, true)
	vm:calc_lighting()
end)
