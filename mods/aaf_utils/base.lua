function aaf_utils.fill(color, size)
	size = size or 16
	return "[fill:" .. size .. "x" .. size .. ":" .. color
end

function aaf_utils.get_json(meta, key)
	local raw = meta:get_string(key)
	return raw ~= "" and core.parse_json(raw) or nil
end

function aaf_utils.set_json(meta, key, value)
	meta:set_string(key, value == nil and "" or core.write_json(value))
end

-- Tags: 4dir nodes keep the rotation in param2's low 2 bits, the rest (1-63, 0 = untagged) tells copies apart
aaf_utils.MAX_TAG = 63

local function is_4dir(name)
	local def = core.registered_nodes[name]
	return def ~= nil and def.paramtype2 == "4dir"
end

function aaf_utils.can_tag(node)
	return is_4dir(node.name)
end

function aaf_utils.get_tag(node)
	return is_4dir(node.name) and math.floor((node.param2 or 0) / 4) or 0
end

function aaf_utils.set_tag(param2, tag)
	return (param2 or 0) % 4 + 4 * tag
end

-- e.g. "aaf_props:safe#1"; nil when untagged
function aaf_utils.thing_id(node)
	local tag = aaf_utils.get_tag(node)
	return tag > 0 and node.name .. "#" .. tag or nil
end
