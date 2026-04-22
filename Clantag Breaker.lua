local choke_count = globals.chokedcommands
local set_clan_tag = client.set_clan_tag

local function randomize_case(text)
	local characters = {}
	for index = 1, #text do
		local character = text:sub(index, index)
		characters[index] = client.random_int(0, 1) == 1 and character:upper() or character:lower()
	end
	return table.concat(characters)
end

local function lower_case(text)
	return text:lower()
end

local clan_tag_frames = {
	"\t\t\t  f",
	"\t\t\t fa",
	"\t\t\tfat",
	"\t\t   fata",
	"\t\t  fatal",
	"\t\t fatali",
	"\t\tfatalit",
	"\t   fatality",
	"\t  fatality ",
	"\t fatality  ",
	"\tfatality   ",
	"   fatality\t",
	"  fatality\t ",
	" fatality\t  ",
	"fatality\t   ",
	"atality\t\t",
	"tality\t\t ",
	"ality\t\t  ",
	"lity\t\t   ",
	"ity\t\t\t",
	"ty\t\t\t ",
	"y\t\t\t  ",
	"AIMWARE.NET ",
	"IMWARE.NET A",
	"MWARE.NET AI",
	"WARE.NET AIM",
	"ARE.NET AIMW",
	"RE.NET AIMWA",
	"E.NET AIMWAR",
	".NET AIMWARE",
	"NET AIMWARE.",
	"ET AIMWARE.N",
	"T AIMWARE.NE",
	" AIMWARE.NET",
	"AIMWARE.NET ",
	"AIMWARE.NET  ",
	"I\t\t ",
	"IN\t\t",
	"INI\t   ",
	"INIU\t  ",
	"INIUR\t ",
	"INIURI\t",
	"INIURIA   ",
	"INIURIA.  ",
	"INIURIA.U ",
	"INIURIA.US",
	"INIURIA.US",
	" NIURIA.US",
	"  IURIA.US",
	"   URIA.US",
	"\tRIA.US",
	"\t IA.US",
	"\t  A.US",
	"\t   .US",
	"\t\tUS",
	"\t\t S",
	"\t\t  ",
	"\t\t\t  g",
	"\t\t\t ga",
	"\t\t\tgam",
	"\t\t   game",
	"\t\t  games",
	"\t\t gamese",
	"\t\tgamesen",
	"\t   gamesens",
	"\t  gamesense",
	"\t gamesense ",
	"\tgamesense  ",
	"   gamesense   ",
	"  gamesense\t",
	" gamesense\t ",
	"gamesense\t  ",
	"amesense\t   ",
	"mesense\t\t",
	"esense\t\t ",
	"sense\t\t  ",
	"ense\t\t   ",
	"nse\t\t\t",
	"se\t\t\t ",
	"e\t\t\t  ",
	"\t\t\t  a",
	"\t\t\t aq",
	"\t\t\taqu",
	"\t\t   aqua",
	"\t\t  aquah",
	"\t\t aquaho",
	"\t\taquahol",
	"\t   aquaholi",
	"\t  aquaholic",
	"\t aquaholic ",
	"\taquaholic  ",
	"   aquaholic   ",
	"  aquaholic\t",
	" aquaholic\t ",
	"aquaholic\t  ",
	"quaholic\t   ",
	"uaholic\t\t",
	"aholic\t\t ",
	"holic\t\t  ",
	"olic\t\t   ",
	"lic\t\t\t",
	"ic\t\t\t ",
	"c\t\t\t  ",
	"\t\t\t  n",
	"\t\t\t ni",
	"\t\t\tnix",
	"\t\t   nixw",
	"\t\t  nixwa",
	"\t\t nixwar",
	"\t\tnixware",
	"\t   nixware.",
	"\t  nixware.c",
	"\t nixware.cc",
	"\tnixware.cc",
	"   nixware.c ",
	"  nixware.  ",
	" nixware   ",
	"nixwar\t",
	"nixwa\t ",
	"nixw\t  ",
	"nix\t   ",
	"ni\t\t",
	"n\t\t ",
	"N",
	"N3",
	"Ne",
	"Ne\\",
	"Ne\\/",
	"Nev",
	"Nev3",
	"Neve",
	"Neve|",
	"Neve|2",
	"Never",
	"Never|",
	"Never|_",
	"Neverl",
	"Neverl0",
	"Neverlo",
	"Neverlo5",
	"Neverlos",
	"Neverlos3",
	"Neverlose",
	"Neverlose.",
	"Neverlose.<",
	"Neverlose.c",
	"Neverlose.c<",
	"Neverlose.cc",
	"Neverlose.cc ",
	"Neverlose.cc ",
	"Neverlose.cc",
	"Neverlose.c<",
	"Neverlose.c",
	"Neverlose.<",
	"Neverlose.",
	"Neverlose",
	"Neverlos3",
	"Neverlos",
	"Neverlo5",
	"Neverlo",
	"Neverl0",
	"Neverl",
	"Never|_",
	"Never|",
	"Never",
	"Neve|2",
	"Neve|",
	"Neve",
	"Nev3",
	"Nev",
	"Ne\\/",
	"Ne\\",
	"Ne",
	"N3",
	"N",
	"onetap.su ",
	"netap.su o",
	"etap.su on",
	"tap.su one",
	"ap.su onet",
	"p.su oneta",
	".su onetap",
	"su onetap.",
	"u onetap.s",
	" onetap.su",
	"N ",
	"No ",
	"Nov",
	"Novo",
	"Novol",
	"Novoli",
	"Novolin",
	"Novoline",
	"Novolineh",
	"Novolineho",
	"Novolinehoo",
	"Novolinehook",
	"Novolinehook",
	"âŒ› ",
	"âŒ› p",
	"âŒ› pr",
	"âŒ› pri",
	"âŒ› prim",
	"âŒ› primo",
	"âŒ› primor",
	"âŒ› primord",
	"âŒ› primordi",
	"âŒ› primordia",
	"âŒ› primordial",
	"âŒ› primordial",
	"âŒ› primordia",
	"âŒ› primordi",
	"âŒ› primord",
	"âŒ› primor",
	"âŒ› primo",
	"âŒ› prim",
	"âŒ› pri",
	"âŒ› pr",
	"âŒ› p",
	"âŒ› ",
	"n3m3sis",
	"nemesis",
	"n3m3sis",
	"nemesis",
	"n3m3sis",
	"nemesis",
	"\t\tga",
	"\t   gam",
	"\t  game",
	"\t games",
	"\tgamese",
	"   gamesen",
	"  gamesens",
	" gamesense",
	" gamesense ",
	" amesense  ",
	" mesense   ",
	" esense\t",
	" sense\t ",
	" ense\t  ",
	" nse\t   ",
	" se\t\t",
	" e\t\t "
}

local animated_frames = {}
local normalized_frames = {}
for index = 1, #clan_tag_frames do
	animated_frames[index] = randomize_case(clan_tag_frames[index])
	normalized_frames[index] = lower_case(clan_tag_frames[index])
end

local current_frame = 1
local last_sent_tag = ""
local next_frame_time = 0

local function on_paint()
	if globals.chokedcommands ~= 0 then
		return
	end

	local now = globals.curtime()
	if now < next_frame_time then
		return
	end

	if current_frame > #animated_frames then
		current_frame = 1
	end

	local next_tag = animated_frames[current_frame]
	set_clan_tag(next_tag)
	last_sent_tag = next_tag
	current_frame = current_frame + 1
	next_frame_time = now + 0.4
end

ui.set_callback(ui.new_checkbox("LUA", "B", "Break Clantags"), function(enabled)
	if ui.get(enabled) then
		client.set_event_callback("paint", on_paint)
	else
		client.unset_event_callback("paint", on_paint)
	end
end)

client.set_event_callback("level_init", function()
	current_frame = 1
	last_sent_tag = ""
	next_frame_time = 0
end)
