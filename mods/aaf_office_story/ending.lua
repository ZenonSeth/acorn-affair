local STATION_REPORTED = "station:reported"
local ENDING_SEEN = "office:ending_seen"
local TASK_SLEEP = "office:sleep"
local FREEZE = "aaf_office_ending"
local NEWS_FORM = "aaf_office_story:newspaper"

local FADE_SECONDS = 0.8
local HOLD_SECONDS = 1.0

local REFLECTION = {
	{
		text = "Five suspects, four alibis, one locked kitchen, and a whole precinct outsmarted "
			.. "by an eight-inch felon with a bushy tail.",
		reply = "Some nights in this city...",
	},
	{
		text = "Chief Harrington said he wanted that animal arrested. I told him to bring a net "
			.. "and a bag of Jenkins' peanuts. Me? I've got a date with this sofa.",
		reply = "Close your eyes",
	},
}

-- player name -> {phase = "fade" | "hold" | "card" | "paper", t, hud, alpha}
local active = {}

local function black_tex(alpha)
	return "[fill:8x8:#000000^[opacity:" .. alpha
end

local function cleanup(player, mark_seen)
	local name = player:get_player_name()
	local state = active[name]
	if state and state.hud then
		player:hud_remove(state.hud)
	end
	active[name] = nil
	if mark_seen then
		aaf_flags.set(player, ENDING_SEEN, true)
	end
	aaf_places.play_music(player)
	aaf_avatar.set_frozen(player, FREEZE, false)
	core.close_formspec(name, NEWS_FORM)
end

local function newspaper_form()
	local theme = aaf_gui.theme
	return table.concat({
		"formspec_version[6]",
		"size[13,11.6]",
		"bgcolor[#00000000;true;#000000F2]",
		"allow_close[false]",
		aaf_gui.paper(0.5, 0.3, 12, 10.1),
		-- Masthead rules and greeked header bar
		"box[1.0,0.85;11.0,0.06;#2A241E]",
		"box[1.0,1.0;11.0,0.03;#5A4C3E]",
		"hypertext[1.0,1.15;11.0,1.2;headline;<global halign=center valign=middle size=28 color=",
		theme.ink, "><b>MASTERMIND SQUIRREL ARRESTED</b>]",
		"box[1.0,2.35;11.0,0.05;#2A241E]",
		-- Framed pixel-art squirrel mugshot
		"image[3.3,2.65;6.4,4.8;aaf_office_story_squirrel_mugshot.png]",
		("image[3.3,2.65;6.4,4.8;%s;%d]"):format(theme.frame, theme.frame_slice),
		-- Illegible newspaper body columns below the photo
		"image[1.1,7.7;10.8,2.45;aaf_office_story_news_col.png]",
		"button[4.5,10.65;4,0.8;done;Continue]",
	})
end

local function show_newspaper(player)
	local name = player:get_player_name()
	local state = active[name]
	if not state then
		return
	end
	state.phase = "paper"
	core.show_formspec(name, NEWS_FORM, newspaper_form())
end

local function start_fade(player)
	local name = player:get_player_name()
	active[name] = {
		phase = "fade",
		t = 0,
		alpha = 0,
		hud = player:hud_add({
			type = "image",
			position = {x = 0.5, y = 0.5},
			alignment = {x = 0, y = 0},
			scale = {x = -100, y = -100},
			text = black_tex(0),
			z_index = 1000,
		}),
	}
end

local function reflection_step(player, i)
	local step = REFLECTION[i]
	aaf_dialog.talk(player, {
		speaker = "Jack Graves",
		portrait = "detective",
		text = step.text,
		options = {{text = step.reply, on_choose = function(p)
			if i < #REFLECTION then
				reflection_step(p, i + 1)
			else
				start_fade(p)
			end
		end}},
	})
end

function aaf_office_story.maybe_offer_sleep(player)
	if aaf_flags.get(player, STATION_REPORTED) and not aaf_flags.get(player, ENDING_SEEN)
			and not aaf_tasks.has(player, TASK_SLEEP) then
		aaf_tasks.add(player, TASK_SLEEP, "Turn in for the night")
		aaf_tasks.set_hint(player, TASK_SLEEP, "Sleep on your office sofa")
	end
end

function aaf_office_story.can_sleep(player)
	return aaf_tasks.has(player, TASK_SLEEP)
end

function aaf_office_story.start_ending(player)
	if active[player:get_player_name()] then
		return
	end
	aaf_tasks.complete(player, TASK_SLEEP)
	aaf_avatar.set_frozen(player, FREEZE, true)
	reflection_step(player, 1)
end

aaf_places.register_on_arrive("office", function(player)
	aaf_office_story.maybe_offer_sleep(player)
end)

core.register_globalstep(function(dtime)
	for pname, state in pairs(active) do
		local player = core.get_player_by_name(pname)
		if not player then
			active[pname] = nil
		elseif state.phase == "fade" then
			state.t = state.t + dtime
			local alpha = math.floor(math.min(1, state.t / FADE_SECONDS) * 255 + 0.5)
			if alpha ~= state.alpha then
				state.alpha = alpha
				player:hud_change(state.hud, "text", black_tex(alpha))
			end
			if state.t >= FADE_SECONDS then
				state.phase, state.t = "hold", 0
			end
		elseif state.phase == "hold" then
			state.t = state.t + dtime
			if state.t >= HOLD_SECONDS then
				state.phase = "card"
				aaf_audio.music.play(player, "ending")
				aaf_dialog.narrate(player, {"The next evening..."}, function(p)
					show_newspaper(p)
				end)
			end
		end
	end
end)

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= NEWS_FORM then
		return
	end
	if fields.done or fields.quit then
		cleanup(player, true)
	end
	return true
end)

core.register_on_leaveplayer(function(player)
	active[player:get_player_name()] = nil
end)
