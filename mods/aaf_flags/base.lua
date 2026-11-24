local get_json, set_json = aaf_utils.get_json, aaf_utils.set_json

local STORE_KEY = "aaf_flags:flags"

-- player name -> {flag name -> value}, loaded on first use
local caches = {}

local function flags_of(player)
	local name = player:get_player_name()
	local flags = caches[name]
	if not flags then
		flags = get_json(player:get_meta(), STORE_KEY) or {}
		caches[name] = flags
	end
	return flags
end

core.register_on_leaveplayer(function(player)
	caches[player:get_player_name()] = nil
end)

-- Unset flags are nil
function aaf_flags.get(player, flag)
	return flags_of(player)[flag]
end

-- Value is a boolean, number or string; nil or false unsets the flag
function aaf_flags.set(player, flag, value)
	assert(type(flag) == "string" and flag ~= "", "aaf_flags: bad flag name " .. tostring(flag))
	local flags = flags_of(player)
	flags[flag] = value or nil
	set_json(player:get_meta(), STORE_KEY, next(flags) and flags or nil)
end

-- A copy of all set flags
function aaf_flags.get_all(player)
	return table.copy(flags_of(player))
end

function aaf_flags.clear(player)
	caches[player:get_player_name()] = {}
	set_json(player:get_meta(), STORE_KEY, nil)
end
