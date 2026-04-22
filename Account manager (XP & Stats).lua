panorama_api = panorama.open()
party_list_api = panorama_api.PartyListAPI
friends_list_api = panorama_api.FriendsListAPI
local_xuid = panorama_api.MyPersonaAPI.GetXuid()
table_generator = require("gamesense/table_gen")
http_client = require("gamesense/http")
panorama_events = require("gamesense/panorama_events")
hide_from_obs = ui.reference("MISC", "Settings", "Hide from OBS")
account_store = {}
weekday_names = {
	"Monday",
	"Tuesday",
	"Wednesday",
	"Thursday",
	"Friday",
	"Saturday",
	"Sunday"
}
bonus_labels = {
	["3"] = "REDUCED",
	["1"] = "1x",
	[""] = "NO",
	["1,2"] = "2x"
}
column_headers = {
	"Name",
	"XP earned",
	"Bonus",
	"Level",
	"Rank",
	"Wins",
	"Prime",
	"Invite code",
	"Last seen",
	"Banned"
}
rank_labels = {
	[0] = "Unranked",
	"Silver 1",
	"Silver 2",
	"Silver 3",
	"Silver 4",
	"Silver Elite",
	"Silver Elite Master",
	"Gold Nova 1",
	"Gold Nova 2",
	"Gold Nova 3",
	"Gold Nova 4",
	"Master Guardian 1",
	"Master Guardian 2",
	"Master Guardian Elite",
	"Distinguished Master Guardian",
	"Legendary Eagle",
	"Legendary Eagle Master",
	"Supreme Master First Class",
	"The Global Elite"
}
timestamp_helpers = panorama.loadstring([[

	var _GetTimestamp = function() {
		return Date.now();
	}

	var _FormatTimestamp = function(timestamp) {
		var date = new Date(timestamp);
		return `${date.getMonth() + 1}/${date.getDate()}/${date.getFullYear()} ${date.getHours()}:${date.getMinutes()}`;
	}

	var _GetEvenLastWednesday = function() {
		var date = new Date();
		var new_date = new Date(date.setDate(date.getUTCDate()-date.getUTCDay()-4));
		var last_wednesday = new Date(new_date.getFullYear(), new_date.getMonth(), date.getDate(), -1, 0, 0);
		return last_wednesday.getTime();
	}
	
	var _GetLastWednesday = function() {
		var date = new Date();
		var new_date = new Date(date.setDate(date.getUTCDate()-date.getUTCDay() + 3));
		var last_wednesday = new Date(new_date.getFullYear(), new_date.getMonth(), date.getDate(), -1, 0, 0);
		return last_wednesday.getTime();
	}

	var _GetTodayUTC = function() {
		var date = new Date();
		return date.getUTCDay();
	}

	var _TimeAgo = function(timestamp) {
		var date = new Date(timestamp);
		var minute = 60;
		var hour = minute*60;
		var day = hour*24;
		var date_utc = new Date()
		var elapsed = Math.floor((date_utc - date) / 1000);
		var days_elapsed = 0;
		var hours_elapsed = 0;
		var minutes_elapsed = 0;
		if (elapsed > 7*day) return true;
		else return false;
	}
	
	return {
		get_timestamp: _GetTimestamp,
		format_timestamp: _FormatTimestamp,
		today_utc: _GetTodayUTC,
		get_last_wednesday: _GetLastWednesday,
		get_even_last_wednesday: _GetEvenLastWednesday,
		a_week_went_by: _TimeAgo
	}
]])()

function refresh_bonus_cache()
	for friends_list_api, local_xuid in pairs(account_store) do
		account_store[friends_list_api].bonus = "2x"
		account_store[friends_list_api].initial_xp = account_store[friends_list_api].actual_xp
		account_store[friends_list_api].initial_level = account_store[friends_list_api].actual_level
	end

	database.write("manager_reworked", account_store)
end

function update_account_entry(panorama_api)
	if not panorama_api then
		account_store[steam_id64] = {
			custom_name = false,
			xp = 0,
			actual_xp = persona_api.GetCurrentXp(),
			actual_level = persona_api.GetCurrentLevel(),
			initial_level = persona_api.GetCurrentLevel(),
			initial_xp = persona_api.GetCurrentXp(),
			rank = persona_api.GetCompetitiveRank(),
			wins = persona_api.GetCompetitiveWins(),
			invite_code = persona_api.GetFriendCode(),
			banned = friends_api.GetFriendIsVacBanned(steam_id64) and "YES" or "NO",
			last_seen = timestamp_helpers.format_timestamp(timestamp_helpers.get_timestamp()),
			prime = party_list_api.GetFriendPrimeEligible(steam_id64) and "YES" or "NO",
			bonus = bonus_labels[persona_api.GetActiveXpBonuses()] or "NO"
		}
	elseif account_store[steam_id64] then
		account_store[steam_id64].name = persona_api.GetName()
		account_store[steam_id64].actual_xp = persona_api.GetCurrentXp()
		account_store[steam_id64].actual_level = persona_api.GetCurrentLevel()
		account_store[steam_id64].rank = persona_api.GetCompetitiveRank()
		account_store[steam_id64].wins = persona_api.GetCompetitiveWins()
		account_store[steam_id64].bonus = bonus_labels[persona_api.GetActiveXpBonuses()] or "NO"
		account_store[steam_id64].last_seen = timestamp_helpers.format_timestamp(timestamp_helpers.get_timestamp())
		account_store[steam_id64].prime = party_list_api.GetFriendPrimeEligible(steam_id64) and "YES" or "NO"
		account_store[steam_id64].banned = friends_api.GetFriendIsVacBanned(steam_id64) and "YES" or "NO"
	end

	database.write("manager_reworked", account_store)
end

do
	if database.read("manager_reworked") == nil then
		account_store(false)
	else
		steam_id64 = database.read("manager_reworked")

		for friends_list_api, local_xuid in pairs(steam_id64) do
			if friends_list_api == persona_api then
				return
			end
		end

		account_store(false)
	end
end
do
	for friends_list_api, local_xuid in pairs(account_store) do
		steam_id64.get("https://api.steampowered.com/ISteamUser/GetPlayerBans/v1/?key=E9EA79BB465366C98E5BAF31EC8A6F31&steamids=" .. friends_list_api, function (panorama_api, account_database)
			if not panorama_api or account_database.status ~= 200 then
				return
			end

			if json.parse(account_database.body) and #party_list_api.players > 0 then
				account_store[steam_id64].banned = party_list_api.players[1].NumberOfVACBans > 0 and friends_list_api.NumberOfGameBans > 0 and "YES" or "NO"
			end
		end)
	end

	database.write("manager_reworked", account_store)
end

function calculate_xp(panorama_api, account_database, party_list_api, friends_list_api, local_xuid)
	if panorama_api == party_list_api then
		return friends_list_api - account_database
	elseif panorama_api < party_list_api then
		return 5000 * (party_list_api - panorama_api) - account_database + friends_list_api
	elseif party_list_api < panorama_api then
		account_store[local_xuid].initial_level = account_store[local_xuid].actual_level
		account_store[local_xuid].initial_xp = account_store[local_xuid].actual_xp

		database.write("manager_reworked", account_store)

		return 0
	end
end

account_manager_button = ui.new_button("MISC", "Settings", "Account manager", function ()
	account_store(false)
end)

do
	if type(database.read("reset_day")) ~= "number" then
		panorama_api = account_store.get_last_wednesday()

		if account_store.today_utc() < 3 then
			panorama_api = account_store.get_even_last_wednesday()
		end

		database.write("reset_day", panorama_api)
		steam_id64()
	elseif account_store.a_week_went_by(database.read("reset_day")) then
		account_database = account_store.get_last_wednesday()

		if account_store.today_utc() < 3 then
			account_database = account_store.get_even_last_wednesday()
		end

		database.write("reset_day", account_database)
		steam_id64()

		if ui.get(persona_api) then
			return
		end

		client.color_log(20, 255, 20, "[Account manager] XP bonus is back, enjoy!")
	end
end

if database.read("manager_output") then
	do local panorama_api = true
		account_store(true)

		for table_generator, http_client in pairs(steam_id64) do
			panorama_events = steam_id64[table_generator]
			panorama_events.xp = persona_api(panorama_events.initial_level, panorama_events.initial_xp, panorama_events.actual_level, panorama_events.actual_xp, table_generator)

			table.insert({}, {
				panorama_events.custom_name or panorama_events.name,
				tostring(panorama_events.xp) .. " XP",
				panorama_events.bonus,
				panorama_events.actual_level,
				friends_api[panorama_events.rank],
				panorama_events.wins,
				panorama_events.prime,
				panorama_events.invite_code,
				panorama_events.last_seen,
				panorama_events.banned
			})
		end

		if database.read("manager_output") then
			writefile("acc_manager.txt", timestamp_helpers(account_database, party_list_api, {
				style = "Unicode (Single Line)"
			}))
		end

		if ui.get(bonus_labels) or panorama_api then
			return
		end

		client.color_log(20, 255, 20, "[Account manager]")
		client.color_log(255, 255, 255, party_list_api)
	end
end

client.set_event_callback("console_input", function (panorama_api)
	if ui.get(account_store) then
		return false
	end

	if panorama_api:match("^manager_delete") then
		if steam_id64[panorama_api:match("^manager_delete (.*)$")] then
			steam_id64[account_database] = nil

			client.color_log(20, 255, 20, "[Account manager] Account deleted.")
		else
			client.color_log(240, 20, 20, "[Account manager] ID64 not found.")
		end

		return true
	elseif panorama_api:match("^manager_rename") then
		if panorama_api:sub(16, #panorama_api) ~= "" then
			if steam_id64[panorama_api:sub(16, 32)] then
				if panorama_api:sub(34, #panorama_api) ~= "" then
					steam_id64[panorama_api:sub(16, 32)].custom_name = panorama_api:sub(34, #panorama_api)

					client.color_log(20, 255, 20, "[Account manager] Custom name set for " .. panorama_api:sub(16, 32))
					persona_api(true)
				else
					client.color_log(240, 20, 20, "[Account manager] Please define a name for " .. panorama_api:sub(16, 32))
				end
			elseif steam_id64[friends_api] then
				steam_id64[friends_api].custom_name = panorama_api:sub(16, #panorama_api)

				persona_api(true)
				client.color_log(20, 255, 20, "[Account manager] Custom name set.")
			end
		elseif steam_id64[friends_api] then
			client.color_log(240, 20, 20, "[Account manager] Please define a name for this account.")
		else
			client.color_log(240, 20, 20, "[Account manager] Account doesn't exist in your database.")
		end

		return true
	elseif panorama_api:match("^manager_list") then
		account_database = {}

		for table_generator, http_client in pairs(steam_id64) do
			table.insert(account_database, {
				table_generator,
				steam_id64[table_generator].custom_name or panorama_events.name
			})
		end

		client.color_log(20, 255, 20, "[Account manager]")
		client.color_log(255, 255, 255, timestamp_helpers(account_database, {
			"ID64",
			"Name"
		}, {
			style = "Unicode (Single Line)"
		}))

		return true
	elseif panorama_api:match("^manager_output") then
		if not database.read("manager_output") then
			database.write("manager_output", true)
			client.color_log(20, 255, 20, "[Account manager] Output enabled.")
		else
			database.write("manager_output", false)
			client.color_log(20, 255, 20, "[Account manager] Output disabled.")
		end

		return true
	elseif panorama_api:match("^manager_print") then
		party_list_api(false)

		return true
	end
end)
panorama_events.register_event("CSGOShowMainMenu", function ()
	account_store()
	steam_id64(true)
end)
panorama_events.register_event("ShowContentPanel", function ()
	account_store()
	steam_id64(true)
end)
panorama_events.register_event("PanoramaComponent_Lobby_PlayerUpdated", function ()
	account_store()
	steam_id64(true)
end)
client.set_event_callback("cs_win_panel_match", function ()
	account_store()
	steam_id64(true)
end)
client.set_event_callback("shutdown", function ()
	account_store(true)
end)
