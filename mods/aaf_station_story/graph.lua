-- The case at the station as data (GDD 4.3-4.5); case.lua evaluates it, the notebook and phone read it.
-- A requirement is an id (a fact or deduction known), "seen:<fact>" (a gated thing used before its gate held),
-- "accused:<suspect>", "suspect:<suspect>" (listed in the notebook), {all = {...}}, {any = {...}},
-- {none = {...}} or {at_least = n, of = {...}}.

local graph = {}

-- fact id -> {title, where, line (the notebook's one line), key (a deduction needs it), gate (requirement
-- before the thing counts), alibi (the suspect it clears)}
graph.facts = {
	register = {title = "Staff entry register", where = "the front desk",
		line = "Miller, Jenkins, Thompson, the Chief. Times in, times out. Coffee on Jenkins' sign-out."},
	noise_complaint = {title = "Thompson's noise complaint", where = "the front desk",
		line = "Scratching and rummaging after hours. Thompson won't name names. It's Jenkins."},
	missing_notice = {title = "Missing property notice", where = "the reception noticeboard",
		line = "Food, stationery, open drawers, all week. The department accepts no responsibility for sandwiches."},
	window_notice = {title = "Window notice", where = "the reception noticeboard",
		line = "Close the windows before you leave. This means you too, Chief."},
	memo = {title = "Miller's memo", where = "the detectives' room wall",
		line = "Open drawers, missing pencils, a sandwich with a bite out of it. Miller is not amused."},
	peanut_complaint = {title = "Jenkins' peanut complaint", where = "Jenkins' desk",
		line = "His peanuts are gone again, third time this week. He has a pretty good idea who."},
	thompson_note = {title = "Thompson's note", where = "Thompson's desk",
		line = "He never ate Jenkins' peanuts. Somebody has been biting his lunch."},
	fred_report = {title = "Fred's unfinished report", where = "Fred's desk", key = true,
		line = "Something small in the Chief's office at 22:40. Nobody came out of that door all night. "
			.. "A draft moved the papers by it at 23:10."},
	fred_list = {title = "Fred's reminder list", where = "Fred's desk",
		line = "Milk. Miller's pen. SIGN THE REGISTER. Two for five."},
	sandwich = {title = "Bitten sandwich", where = "Thompson's desk", key = true, gate = "petty_thefts",
		line = "A bite the size of a postage stamp. Whoever did this had a mouth like a coin purse."},
	shells = {title = "Peanut shells", where = "under Jenkins' desk", key = true, gate = "petty_thefts",
		line = "Cracked open neat. Small teeth. Determined teeth."},
	display_case = {title = "Empty display case", where = "the Chief's office", key = true,
		line = "An empty stand. A gold-plated hole in the Chief's life."},
	certificate = {title = "ACORN certificate", where = "by the display case", key = true,
		line = "A solid gold-plated acorn. Unauthorized handling strictly prohibited."},
	letter = {title = "Letter to his mother", where = "the Chief's desk", key = true,
		line = "The ACORN catches the light from the window. He looks at it every morning. And every evening."},
	sill_prints = {title = "Paw prints on the sill", where = "the Chief's open window", key = true, gate = "small",
		line = "Prints. Tiny ones. Four toes up front. Our thief wasn't wearing regulation shoes."},
	scratches = {title = "Scratches under the door", where = "the Chief's door", key = true,
		gate = {any = {"fred_report", "thompson_log"}},
		line = "The gap under the door. The Chief's been complaining about the draft for years. "
			.. "Something else had been enjoying it."},
	insurance = {title = "Insurance policy", where = "the Chief's filing cabinet",
		line = "The ACORN, insured last Monday for five hundred dollars. Mother says one can't be too careful."},
	crumpled_note = {title = "Crumpled note", where = "the Chief's wastebasket",
		line = "He needs the money by Friday. \"If it comes to it, the ACORN...\" Torn off right where it got interesting."},
	safe = {title = "The Chief's safe", where = "the Chief's office",
		line = "Locked. Who knows what's in there?"},
	-- Alibis, behind an accusation each
	ticket_stub = {title = "Rialto ticket stub", where = "Jenkins' bottom drawer", alibi = "jenkins",
		line = "Love Among the Daisies, the 22:20 show. A pressed daisy tucked behind it."},
	thompson_log = {title = "Thompson's surveillance log", where = "Thompson's drawer", alibi = "thompson",
		line = "Eyes on Jenkins' desk from 22:06 to 23:40. The jar went from 31 to 27. Nobody came near it."},
	miller_log = {title = "Miller's telephone log", where = "Miller's drawer", alibi = "miller",
		line = "A call every fifteen minutes. Mrs. Dabney's cat, up and down the elm. Thompson, hearing things."},
	door_note = {title = "Miller's note to Fred", where = "the inside of the kitchen door", alibi = "fred",
		line = "She let Fred out at 23:30. He'd been stuck in there since about seven."},
	dinner_program = {title = "Dinner program", where = "the Chief's desk drawer", alibi = "chief",
		line = "Toast to the Department, 22:30, Chief A. Harrington. \"47 min. Ovation.\""},
}

-- In evaluation order; titled ones are the notebook's deductions
graph.deductions = {
	{id = "petty_thefts",
		req = {at_least = 2, of = {"memo", "peanut_complaint", "thompson_note", "missing_notice"}}},
	{id = "small", title = "Small teeth",
		req = {any = {{all = {"sandwich", "shells"}}, {all = {{any = {"sandwich", "shells"}}, "thompson_log"}}}}},
	{id = "window", title = "In through the window", req = "sill_prints"},
	{id = "under_door", title = "Under the door", req = "scratches"},
	{id = "why_acorn", title = "Why the ACORN",
		req = {all = {"window", "display_case", {any = {"certificate", "letter"}}}}},
	{id = "solved", req = {all = {"small", "window", "under_door", "why_acorn"}}},
}

-- Notes added under a clue in the notebook
graph.notes = {
	{clue = "register", when = "suspect:fred", line = "No Fred. Fred was here."},
	{clue = "sandwich", when = "small", line = "Same teeth as the peanuts."},
	{clue = "shells", when = "small", line = "Same teeth as the sandwich."},
	{clue = "shells", when = "thompson_log", line = "Thompson counted 31 down to 27, and nobody came near the desk."},
	{clue = "sill_prints", when = "miller_log", line = "Cats have five toes up front."},
	{clue = "fred_report", when = "under_door", line = "Something went under that door. It wasn't a draft."},
	{clue = "display_case", when = "why_acorn",
		line = "Gold-plated, shaped like an acorn, by an open window, next to an elm."},
}

-- In notebook order. listed: when the suspect shows up; accuse: when the phone offers them (and listed);
-- lines: {when, line, struck (requirement that crosses the line out), struck_line}; cleared: the alibi line
graph.suspects = {
	{id = "miller", name = "Sgt. Edna Miller", listed = "register", accuse = {any = {"memo", "missing_notice"}},
		lines = {
			{when = "register", line = "In 17:58, out 23:30. Ran the front desk all night."},
			{when = {any = {"memo", "missing_notice"}}, line = "Writes memos nobody reads. Notices everything."},
		},
		cleared = "On the phone from 21:35 to 23:25, every call logged."},
	{id = "jenkins", name = "Det. Walter Jenkins", listed = "register",
		accuse = {any = {"noise_complaint", "peanut_complaint"}},
		lines = {
			{when = "register", line = "In 18:10, out 2?:05. A coffee smudge obscures the hour."},
			{when = "peanut_complaint", line = "Missing peanuts, third time this week. Blames Thompson."},
			{when = "noise_complaint", line = "Thompson says he comes back after signing out."},
		},
		cleared = "At the Rialto at 22:20. Love Among the Daisies."},
	{id = "thompson", name = "Det. Ray Thompson", listed = "register", accuse = "thompson_note",
		lines = {
			{when = "register", line = "In 18:30, out 23:45. Last officer out."},
			{when = "noise_complaint", line = "Hears noises. Blames Jenkins."},
			{when = "thompson_note", line = "Somebody's been biting his sandwiches."},
		},
		cleared = "At his desk from 22:06 to 23:40, watching Jenkins' peanuts."},
	{id = "fred", name = "Fred Pickett",
		listed = {any = {"door_note", {all = {"register", {any = {"fred_list", "fred_report"}}}}}},
		accuse = "register",
		lines = {
			{when = "register", line = "Patrolman. Never signed in. Was here anyway."},
			{when = "fred_list", line = "Forgets things. Mostly the register."},
			{when = "fred_report", line = "Says he was stuck in the kitchen, watching the Chief's door."},
		},
		cleared = "Stuck in the kitchen from 19:00 to 23:30."},
	{id = "chief", name = "Chief Arthur Harrington", listed = {all = {}},
		accuse = {at_least = 2, of = {"insurance", "crumpled_note", "safe"}},
		lines = {
			{when = {all = {}},
				line = "My client. Left at 21:30 for a dinner, came back at 23:50 for his umbrella, found the stand empty."},
			{when = "window_notice", line = "Leaves his own window open."},
			{when = "insurance", line = "Insured the ACORN last Monday. Five hundred dollars."},
			{when = "crumpled_note", line = "Needs money by Friday."},
			{when = "safe", line = "His safe is locked. Who knows what's in there?"},
		},
		cleared = "Giving a 47-minute toast at the Benevolent Society at 22:30. Long-winded, but clean."},
	-- Never cleared and never accused: the phone's report option is its accusation
	{id = "outside", name = "Someone from outside?", listed = {any = {"small", "miller_log"}},
		lines = {
			{when = "miller_log", line = "Mrs. Dabney's cat? Up and down the elm behind the station all night.",
				struck = "window", struck_line = "Four toes up front on that sill. Cats have five. Not the cat."},
			{when = "small", line = "Small. Sharp little teeth. Fond of peanuts and sandwiches."},
			{when = "window", line = "Comes in through the Chief's window, from the elm."},
			{when = "under_door", line = "Goes under doors. Nobody sees it at eye level."},
			{when = "why_acorn", line = "Likes acorns. Shiny ones."},
			{when = "solved", line = "I knew what it was. I needed a phone."},
		}},
}

-- The notebook's "what now" line: the first whose requirement holds
graph.hints = {
	{when = "solved", line = "Four answers. One culprit. Nobody was going to believe me. I needed a phone."},
	{when = {all = {"miller_log", {none = {"window"}}}},
		line = "Something kept that cat busy up the elm all night. The elm by the Chief's window."},
	{when = {all = {"small", {none = {"window"}}}},
		line = "Something small got into a locked building. Small things don't use doors."},
	{when = {all = {"window", {none = {"under_door"}}}},
		line = "In by the window. But the peanuts are on the other side of the Chief's door."},
	{when = {all = {"window", "under_door", {none = {"why_acorn"}}}},
		line = "A thief that eats peanuts took a gold award. Why that, of all things?"},
	{when = {all = {"petty_thefts", {any = {"seen:sandwich", "seen:shells"}}, {none = {"small"}}}},
		line = "Those peanut shells. That sandwich. Worth a second look."},
	{when = {all = {"petty_thefts", {none = {"small"}}}},
		line = "Peanuts, sandwiches, pencils, all week. Whoever's been at this station isn't picky."},
	{when = {all = {}},
		line = "Somebody in this building took a gold acorn. Everybody in this building writes things down."},
}

aaf_station_story.graph = graph
