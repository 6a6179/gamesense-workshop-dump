local teleport_distance_mask = bit.lshift(1, 11)
local teleport_delay = 0.3
local weapons = require("gamesense/csgo_weapons")
local screen_width, screen_height = client.screen_size()
local screen_center = { screen_width / 2, screen_height / 2 }
local far_teleport_hotkey = ui.new_hotkey("AA", "Other", "Far Teleport")
local far_teleport_when_hittable_hotkey = ui.new_hotkey("AA", "Other", "Far Teleport When Hittable")
local double_tap_enabled, double_tap_hotkey, double_tap_mode = ui.reference("RAGE", "Aimbot", "Double tap")
local quick_peek_enabled, quick_peek_hotkey = ui.reference("RAGE", "Other", "Quick peek assist")
local pending_command_number
local last_tick_base
local tickbase_delta = 0
local teleport_active = false
local teleport_ready = false

local function reset_tickbase_tracking()
	pending_command_number = nil
	last_tick_base = nil
end

reset_tickbase_tracking()

client.set_event_callback("run_command", function(command)
	pending_command_number = command.command_number
end)

client.set_event_callback("predict_command", function(command)
	if command.command_number == pending_command_number then
		pending_command_number = nil

		local current_tick_base = entity.get_prop(entity.get_local_player(), "m_nTickBase")
		if last_tick_base ~= nil then
			tickbase_delta = current_tick_base - last_tick_base
		end

		last_tick_base = math.max(current_tick_base, last_tick_base or 0)
	end
end)

client.set_event_callback("level_init", reset_tickbase_tracking)

client.set_event_callback("setup_command", function(command)
	if not ui.get(double_tap_enabled) or not ui.get(double_tap_hotkey) or ui.get(double_tap_mode) ~= "Defensive" then
		teleport_ready = false
		teleport_active = false

		return
	end

	if not teleport_active and (command.in_forward == 1 or command.in_back == 1 or command.in_moveleft == 1 or command.in_moveright == 1 or command.in_jump == 1) then
		teleport_active = ui.get(far_teleport_hotkey)

		if not teleport_active and ui.get(far_teleport_when_hittable_hotkey) then
			for _, player in ipairs(entity.get_players(true)) do
				if bit.band(entity.get_esp_data(player).flags or 0, teleport_distance_mask) ~= 0 then
					teleport_active = true

					break
				end
			end
		end
	end

	if teleport_active then
		command.force_defensive = true

		if tickbase_delta >= 14 then
			teleport_ready = true
		end

		if (teleport_ready and tickbase_delta == 0) or weapons(entity.get_player_weapon(entity.get_local_player())).type == "grenade" then
			ui.set(double_tap_enabled, false)
			client.delay_call(teleport_delay, ui.set, double_tap_enabled, true)

			teleport_active = false
			teleport_ready = false
		end

		return
	end
end)

client.set_event_callback("paint", function()
	if teleport_active then
		renderer.indicator(143, 194, 21, 255, "+/- MAXIMIZING TELEPORT DISTANCE")
		renderer.text(screen_center[1] - 1206, 772, 143, 207, 219, 255, "-c", 0, "+/- MAXIMIZING TELEPORT DISTANCE")
	elseif ui.get(far_teleport_hotkey) or ui.get(far_teleport_when_hittable_hotkey) then
		if teleport_ready then
			renderer.indicator(255, 0, 50, 255, teleport_distance_mask)
		else
			renderer.indicator(255, 255, 255, 255, teleport_distance_mask)
		end
	end
end)

client.set_event_callback("setup_command", function(command)
	if command.weaponselect ~= 0 then
		command.force_defensive = 1
	end
end)
