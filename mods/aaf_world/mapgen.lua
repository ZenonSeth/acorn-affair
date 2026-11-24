local constants = dofile(core.get_modpath("aaf_utils") .. "/constants.lua")

local SCHEM_DIR = core.get_modpath("aaf_world") .. "/schems/"

local placements = {}
for _, site in pairs(constants.sites) do
	for i, entry in ipairs(site) do
		local path = SCHEM_DIR .. entry.schem .. ".mts"
		local file = io.open(path, "rb")
		if file then
			file:close()
			local schem = core.read_schematic(path, {})
			placements[#placements + 1] = {path = path, origin = entry.origin,
				last = vector.add(entry.origin, vector.subtract(schem.size, 1)), force = i == 1}
		else
			core.log("warning", "aaf_world: no schematic at " .. path)
		end
	end
end

core.register_on_generated(function(vm)
	local emin, emax = vm:get_emerged_area()
	local placed = false
	for _, p in ipairs(placements) do
		local o, l = p.origin, p.last
		if emax.x >= o.x and emin.x <= l.x and emax.y >= o.y and emin.y <= l.y
				and emax.z >= o.z and emin.z <= l.z then
			core.place_schematic_on_vmanip(vm, o, p.path, "0", nil, p.force)
			placed = true
		end
	end
	if placed then
		vm:calc_lighting()
	end
end)
