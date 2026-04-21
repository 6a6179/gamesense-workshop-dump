local chat = require("gamesense/chat")
local localize = require("gamesense/localize")
local game_state_api = panorama.open().GameStateAPI
local last_enemy_chat_times = {}

local function reveal_enemy_chat(event)
	local player_entity = client.userid_to_entindex(event.userid)

	if not entity.is_enemy(player_entity) then
		return
	end

	if game_state_api.IsSelectedPlayerMuted(game_state_api.GetPlayerXuidStringFromEntIndex(player_entity)) then
		return
	end

	if cvar.cl_mute_enemy_team:get_int() == 1 then
		return
	end

	if cvar.cl_mute_all_but_friends_and_party:get_int() == 1 then
		return
	end

	client.delay_call(0.2, function ()
		if last_enemy_chat_times[player_entity] ~= nil and math.abs(globals.realtime() - last_enemy_chat_times[player_entity]) < 0.4 then
			return
		end

		local last_place_name = entity.get_prop(player_entity, "m_szLastPlaceName")

		chat.print_player(player_entity, localize(("Cstrike_Chat_%s_%s"):format(entity.get_prop(entity.get_player_resource(), "m_iTeam", player_entity) == 2 and "T" or "CT", entity.is_alive(player_entity) and "Loc" or "Dead"), {
			s1 = entity.get_player_name(player_entity),
			s2 = chat.text,
			s3 = localize(last_place_name ~= "" and last_place_name or "UI_Unknown")
		}))
	end)
end

local function remember_enemy_chat(event)
	if not entity.is_enemy(event.entity) then
		return
	end

	last_enemy_chat_times[event.entity] = globals.realtime()
end

local reveal_enemy_teamchat_checkbox = ui.new_checkbox("MISC", "Miscellaneous", "Reveal enemy teamchat")

ui.set_callback(reveal_enemy_teamchat_checkbox, function ()
	local register_event_callback = ui.get(reveal_enemy_teamchat_checkbox) and client.set_event_callback or client.unset_event_callback

	register_event_callback("player_say", reveal_enemy_chat)
	register_event_callback("player_chat", remember_enemy_chat)
end)
