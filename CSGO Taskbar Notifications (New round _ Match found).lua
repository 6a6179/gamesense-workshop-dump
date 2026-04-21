local schedule_delay = client.delay_call
local get_realtime = globals.realtime
local raise_error = error
local log_print = print
local ffi = require("ffi")
local uix = require("gamesense/uix")
local panorama_api = panorama.open()
local next_match_notification_at = 0
local find_signature = client.find_signature

local notification_window_handle_ptr = ffi.cast(
	"uintptr_t***",
	ffi.cast("uintptr_t", find_signature("engine.dll", "\\x8b\r\\xcc\\xcc\\xccÌ…\\xc9t\\x8b\\x8b") or raise_error("Invalid signature #1")) + 2
)[0][0] + 2
local flash_window_fn = ffi.cast(
	"int(__stdcall*)(uintptr_t, int)",
	find_signature("gameoverlayrenderer.dll", "U\\x8b\\xec\\x83\\xec\\x8bE\\xf7") or raise_error("Invalid signature #2")
)
local query_window_state_fn = ffi.cast(
	"int(__thiscall*)(uintptr_t)",
	find_signature("gameoverlayrenderer.dll", "\\xff\\xe1") or raise_error("Invalid signature #3")
)
local notification_state_ptr = ffi.cast(
	"uintptr_t**",
	ffi.cast("uintptr_t", find_signature("gameoverlayrenderer.dll", "\\xff\\xcc\\xcc\\xcc\\xcc;\\xc6t") or raise_error("Invalid signature #4")) + 2
)[0][0]

local function get_notification_window_handle()
	return notification_window_handle_ptr[0]
end

local function query_notification_state()
	return query_window_state_fn(notification_state_ptr)
end

local function flash_taskbar_notification()
	if query_notification_state() ~= get_notification_window_handle() then
		flash_window_fn(get_notification_window_handle(), 1)

		return true
	end

	return false
end

local match_found_checkbox = uix.new_checkbox("LUA", "A", "Notify on match found")

match_found_checkbox:on("paint_ui", function ()
	if next_match_notification_at <= get_realtime() then
		if panorama_api.PartyListAPI.GetPartySessionSetting("game/mmqueue") == "reserved" then
			flash_taskbar_notification()
		end

		next_match_notification_at = get_realtime() + 1
	end
end)
match_found_checkbox:set(true)

local round_start_checkbox = uix.new_checkbox("LUA", "A", "Notify on round start")

round_start_checkbox:on("round_start", function ()
	if flash_taskbar_notification() then
		schedule_delay(1, flash_taskbar_notification)
	end
end)
round_start_checkbox:set(true)
