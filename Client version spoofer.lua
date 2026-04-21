local ffi = require("ffi")
local http = require("gamesense/http")
local panorama_api = panorama.open()
local news_api = panorama_api.NewsAPI
local game_state_api = panorama_api.GameStateAPI
local current_client_version = ffi.cast("uint32_t**", ffi.cast("char*", client.find_signature("engine.dll", "\\xff5\\xcc\\xcc\\xccÌL$")) + 2)[0][0]
local version_sync_in_progress = false
local paint_ui_guard = 0

local function request_version_check()
	if version_sync_in_progress then
		return
	end

	http.get("https://api.steampowered.com/ISteamApps/UpToDateCheck/v1/?appid=730&version=" .. current_client_version, function(success, response)
		if not success or response.status ~= 200 then
			return
		end

		local parsed_response = json.parse(response.body)
		if parsed_response.response.required_version ~= nil then
			current_client_version = parsed_response.response.required_version
			ffi.cast("uint32_t**", ffi.cast("char*", client.find_signature("engine.dll", "\\xff5\\xcc\\xcc\\xccÌL$")) + 2)[0][0] = current_client_version
		end
	end)
end

local function read_engine_version()
	local buffer_size = 1048576
	local buffer = ffi.typeof("char[$]", buffer_size)()

	vtable_bind("vstdlib.dll", "VEngineCvar007", 35, "void(__thiscall*)(void*, int, char*, unsigned int)")(0, buffer, buffer_size)

	return ffi.string(buffer)
end

local function sync_client_version()
	client.exec("clear")

	version_sync_in_progress = true

	client.delay_call(0.5, function()
		local version_output = read_engine_version()
		if not version_output:match("server version (.+)") then
			return
		end

		current_client_version = version_output:gsub("\n(.+)", "") + 0
		ffi.cast("uint32_t**", ffi.cast("char*", client.find_signature("engine.dll", "\\xff5\\xcc\\xcc\\xccÌL$")) + 2)[0][0] = current_client_version

		client.exec("retry")
	end)

	client.delay_call(2, function()
		if read_engine_version():match("Connected to (.+)") and current_client_version ~= 0 then
			version_sync_in_progress = false

			request_version_check()
		end
	end)
end

client.set_event_callback("paint_ui", function()
	if (globals.mapname() ~= nil or game_state_api.IsConnectedOrConnectingToServer()) and not entity.get_local_player() then
		if paint_ui_guard == 0 then
			sync_client_version()

			paint_ui_guard = 1
		else
			paint_ui_guard = 0
		end
	else
		paint_ui_guard = 0
	end
end)

client.set_event_callback("cs_win_panel_match", request_version_check)
require("gamesense/panorama_events").register_event("CSGOShowMainMenu", request_version_check)
request_version_check()
