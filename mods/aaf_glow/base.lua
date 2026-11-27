-- Light effects: each lamp near the player gets non-saved halo and beam entities.

local BEAM_TEXTURE = "aaf_glow_beam.png"
local HALO_TEXTURE = "aaf_glow_halo.png"
local WALL_BEAM_MESH = "aaf_glow_wall_beam.obj"
-- yaw change (radians) before a beam card is turned again
local YAW_STEP = 0.03

-- Offsets are in node coordinates at param2 0; beams start at `base` and reach `height` up (dir 1) or down (-1)
local LIGHTS = {
	wall = {
		halo = {offset = vector.new(0, 0.36, 0.3125), size = 1.2},
		beams = {
			-- The sconce faces -Z at param2 0; nudge the glow just in front of it.
			-- `origin` is where the mesh's origin goes (the OBJ is offset to match): straight behind the halo, so it always draws first
			{base = vector.new(0, 0.44, 0.49), origin = vector.new(0, 0.36, 0.49), dir = 1, width = 0.9, height = 1.1},
		},
	},
	floor = {
		halo = {offset = vector.new(0, 0.22, 0), size = 1.4},
		beams = {
			{base = vector.new(0, 0.41, 0), dir = 1, width = 0.8, height = 0.8, face_pos = true},
			{base = vector.new(0, 0.06, 0), dir = -1, width = 1.3, height = 1.56, face_pos = true},
		},
	},
	desk = {halo = {offset = vector.new(0, -0.1, 0.28), size = 0.9}},
	ceiling = {halo = {offset = vector.new(0, 0.4, 0), size = 1.4}},
	street = {halo = {offset = vector.new(0, 0.17, 0), size = 1.8}},
}

-- node name -> {light, brightness}; a lamp's effects follow its node through flicker swaps
local NODES = {
	["aaf_props:wall_lamp"] = {"wall", 1},
	["aaf_props:wall_lamp_flicker"] = {"wall", 1},
	["aaf_props:wall_lamp_flicker_dim"] = {"wall", 0.35},
	["aaf_props:floor_lamp_top"] = {"floor", 1},
	["aaf_props:lamp"] = {"desk", 1},
	["aaf_props:lamp_papers"] = {"desk", 1},
	["aaf_props:lamp_sandwich"] = {"desk", 1},
	["aaf_props:lamp_peanuts"] = {"desk", 1},
	["aaf_props:ceiling_lamp"] = {"ceiling", 1},
	["aaf_props:ceiling_lamp_dim"] = {"ceiling", 0.7},
	["aaf_props:ceiling_lamp_flicker"] = {"ceiling", 0.7},
	["aaf_props:ceiling_lamp_flicker_off"] = {"ceiling", 0},
	["aaf_props:lamp_post_top"] = {"street", 1},
}

-- lamp position hash -> its effect objects
local active = {}

local function rotate(v, param2, paramtype2)
	local x, z = v.x, v.z
	if paramtype2 == "4dir" then
		for _ = 1, param2 % 4 do
			x, z = z, -x
		end
	end
	return vector.new(x, v.y, z)
end

local function texture_for(self, brightness)
	local tex = self._flip and BEAM_TEXTURE .. "^[transformFY" or (self._beam and BEAM_TEXTURE or HALO_TEXTURE)
	if brightness < 1 then
		tex = tex .. "^[opacity:" .. math.floor(brightness * 255)
	end
	return tex
end

local function set_brightness(self, brightness)
	if brightness == self._brightness then
		return
	end
	self._brightness = brightness
	local tex = texture_for(self, math.max(brightness, 0.01))
	local textures = self._beam and {tex, tex} or {tex}
	self.object:set_properties({textures = textures, is_visible = brightness > 0})
end

local function check_lamp(self)
	local node = core.get_node(self._lamp)
	local entry = NODES[node.name]
	if not entry or entry[1] ~= self._light then
		self.object:remove()
		return false
	end
	set_brightness(self, entry[2])
	return true
end

-- the game has one player; beams face that player's view (or camera position when _face_pos is set)
local view_yaw, cam_pos

core.register_globalstep(function()
	local player = core.get_connected_players()[1]
	view_yaw = player and player:get_look_horizontal()
	cam_pos = player and player:get_pos()
end)

local function beam_yaw(pos, face_pos)
	if face_pos and cam_pos then
		local dx, dz = cam_pos.x - pos.x, cam_pos.z - pos.z
		if dx * dx + dz * dz > 1e-6 then
			return math.atan2(-dx, dz)
		end
	end
	return view_yaw
end

local function face_camera(self)
	local yaw = beam_yaw(self.object:get_pos(), self._face_pos)
	if not yaw then
		return
	end
	local diff = math.abs(yaw - (self._yaw or 1000)) % (2 * math.pi)
	if math.min(diff, 2 * math.pi - diff) > YAW_STEP then
		self._yaw = yaw
		self.object:set_yaw(yaw)
	end
end

local COMMON = {
	physical = false,
	collide_with_objects = false,
	pointable = false,
	static_save = false,
	use_texture_alpha = true,
	shaded = false,
	glow = 14,
	backface_culling = false,
}

local function entity(visual, on_step, mesh)
	local props = table.copy(COMMON)
	props.visual = visual
	props.textures = visual == "sprite" and {HALO_TEXTURE} or {BEAM_TEXTURE, BEAM_TEXTURE}
	props.mesh = mesh
	return {
		initial_properties = props,
		on_step = function(self)
			if not self._lamp then
				self.object:remove()
				return
			end
			if check_lamp(self) and on_step then
				on_step(self)
			end
		end,
	}
end

core.register_entity("aaf_glow:halo", entity("sprite"))
core.register_entity("aaf_glow:beam", entity("upright_sprite", face_camera))
core.register_entity("aaf_glow:wall_beam", entity("mesh", nil, WALL_BEAM_MESH))

local function add(name, pos, lamp_pos, light, init)
	local obj = core.add_entity(pos, name)
	if not obj then
		return nil
	end
	local self = obj:get_luaentity()
	self._lamp = lamp_pos
	self._light = light
	for k, v in pairs(init) do
		self[k] = v
	end
	if init._size then
		obj:set_properties({visual_size = init._size})
	end
	check_lamp(self)
	return obj
end

function aaf_glow.spawn(pos)
	local key = core.hash_node_position(pos)
	local objs = active[key]
	if objs then
		local alive = true
		for _, obj in ipairs(objs) do
			alive = alive and obj:is_valid()
		end
		if alive then
			return
		end
		for _, obj in ipairs(objs) do
			obj:remove()
		end
	end
	local node = core.get_node(pos)
	local entry = NODES[node.name]
	if not entry then
		return
	end
	local light = LIGHTS[entry[1]]
	local ptype = core.registered_nodes[node.name].paramtype2
	local lamp = vector.copy(pos)
	objs = {}
	if light.halo then
		local h = light.halo
		objs[#objs + 1] = add("aaf_glow:halo", vector.add(pos, rotate(h.offset, node.param2, ptype)), lamp, entry[1],
			{_size = {x = h.size, y = h.size}})
	end
	for _, b in ipairs(light.beams or {}) do
		local centre = b.origin and rotate(b.origin, node.param2, ptype)
			or vector.add(rotate(b.base, node.param2, ptype), vector.new(0, b.dir * b.height / 2, 0))
		local beam_pos = vector.add(pos, centre)
		local beam_name = entry[1] == "wall" and "aaf_glow:wall_beam" or "aaf_glow:beam"
		local beam = add(beam_name, beam_pos, lamp, entry[1],
			{_beam = true, _flip = b.dir < 0, _face_pos = b.face_pos, _size = {x = b.width, y = b.height}})
		if beam then
			if entry[1] == "wall" then
				beam:set_yaw((node.param2 % 4) * math.pi / 2)
			else
				beam:set_yaw(beam_yaw(beam_pos, b.face_pos) or 0)
			end
			objs[#objs + 1] = beam
		end
	end
	active[key] = objs
end

local names = {}
for name in pairs(NODES) do
	names[#names + 1] = name
end

-- LBMs do not run on freshly generated blocks, so lamps near the player are found by a scan instead
local SCAN_INTERVAL = 1
local SCAN_RADIUS = vector.new(24, 10, 24)
local timer = 0

core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < SCAN_INTERVAL then
		return
	end
	timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		local pos = vector.round(player:get_pos())
		for _, lamp in ipairs(core.find_nodes_in_area(pos - SCAN_RADIUS, pos + SCAN_RADIUS, names)) do
			aaf_glow.spawn(lamp)
		end
	end
end)
