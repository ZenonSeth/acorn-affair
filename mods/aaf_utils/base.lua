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
