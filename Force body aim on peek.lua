local vector = require("vector")
local entity_api = require("gamesense/entity")
local antiaim_funcs = require("gamesense/antiaim_funcs")

local trace_distance_slider = ui.new_slider("RAGE", "Other", "Trace add distance", 5, 50, 20, true, "u")
local double_tap_checkbox, double_tap_hotkey = ui.reference("Rage", "Other", "Double tap")
local force_baim_checkbox = ui.new_checkbox("RAGE", "Other", "Force baim on lethal")
local advanced_settings = ui.new_multiselect("RAGE", "Other", "\n", "Extrapolate local player", "Double tap", "I'm an advanced user")
local visualize_checkbox = ui.new_checkbox("RAGE", "Other", "Visualise calculations")
local ignore_force_baim_checkbox = ui.new_checkbox("PLAYERS", "Adjustments", "Ignore force baim calculations")

local body_hitboxes = { 2, 3, 4, 5, 7, 8 }
local ignored_players = {}
local last_forced_target = nil
local esp_flag_registered = false

local function contains_value(list, value)
	if list == nil then
		return false, -1
	end

	for index = 1, #list do
		if list[index] == value then
			return true, index
		end
	end

	return false, -1
end

local function clear_player_overrides(players)
	for index = 1, #players do
		plist.set(players[index]:get_entindex(), "Override prefer body aim", "-")
	end
end

local function get_eye_position(player)
	local origin = vector(player:get_prop("m_vecOrigin"))
	origin.z = origin.z + player:get_prop("m_vecViewOffset[2]")
	return origin
end

local function build_trace_points(start_position, target_position, extrapolate_local_player)
	local direction = target_position - start_position
	local distance_to_target = direction:length()

	if distance_to_target == 0 then
		return { start_position }
	end

	local unit_direction = direction / distance_to_target
	local add_distance = ui.get(trace_distance_slider)

	if extrapolate_local_player then
		return {
			start_position,
			start_position + unit_direction * add_distance,
			start_position - unit_direction * add_distance
		}
	end

	return {
		start_position,
		start_position + unit_direction * add_distance
	}
end

local function weapon_can_be_dual_tapped(weapon)
	return weapon ~= nil and weapon.cycletime ~= nil and weapon.cycletime >= 0.2 and weapon.cycletime <= 0.3
end

local function trace_damage(weapon, local_player, target_player, extrapolate_local_player, visualize)
	local best_damage = 0
	local start_position = get_eye_position(local_player)
	local target_position = get_eye_position(target_player)
	local trace_points = build_trace_points(start_position, target_position, extrapolate_local_player)

	for point_index = 1, #trace_points do
		local trace_start = trace_points[point_index]
		local best_hitbox_damage = 0

		for hitbox_index = 1, #body_hitboxes do
			local hitbox_position = target_player:hitbox_position(body_hitboxes[hitbox_index])
			local _, damage = weapon:trace_bullet(trace_start.x, trace_start.y, trace_start.z, hitbox_position.x, hitbox_position.y, hitbox_position.z, false)
			damage = damage or 0

			if damage > best_damage then
				best_damage = damage
			end

			if damage > best_hitbox_damage then
				best_hitbox_damage = damage
			end

			if visualize then
				local start_screen_x, start_screen_y = renderer.world_to_screen(trace_start:unpack())
				local hitbox_screen_x, hitbox_screen_y = renderer.world_to_screen(hitbox_position:unpack())

				if start_screen_x ~= nil and start_screen_y ~= nil and hitbox_screen_x ~= nil and hitbox_screen_y ~= nil then
					renderer.text(start_screen_x, start_screen_y, 255, 0, 0, 255, "d+", 0, string.format("%d", best_hitbox_damage))
					renderer.line(start_screen_x, start_screen_y, hitbox_screen_x, hitbox_screen_y, 255, 255, 255, 255)
				end
			end
		end
	end

	return best_damage
end

local function should_force_body_aim(local_player, target_player, force_double_tap)
	local weapon = local_player:get_player_weapon()
	if weapon == nil then
		return false
	end

	local target_health = target_player:get_prop("m_iHealth") or 0
	local extrapolate_local_player = contains_value(ui.get(advanced_settings), "Extrapolate local player")
	local damage = trace_damage(weapon, local_player, target_player, extrapolate_local_player, ui.get(visualize_checkbox))

	if damage >= target_health then
		return true
	end

	if force_double_tap and ui.get(double_tap_checkbox) and ui.get(double_tap_hotkey) and antiaim_funcs.get_tickbase_shifting() > 2 and weapon_can_be_dual_tapped(weapon) then
		return damage * 2 >= target_health
	end

	return false
end

local function update_visual_visibility()
	local show_advanced_settings = ui.get(force_baim_checkbox) and contains_value(ui.get(advanced_settings), "I'm an advanced user")
	ui.set_visible(trace_distance_slider, show_advanced_settings)
	ui.set_visible(visualize_checkbox, show_advanced_settings)
end

local function on_paint()
	if not ui.get(force_baim_checkbox) or not ui.get(visualize_checkbox) then
		return
	end
end

local function on_setup_command()
	if not ui.get(force_baim_checkbox) then
		return
	end

	local current_threat = client.current_threat()
	if current_threat == nil or current_threat == 0 then
		return
	end

	local target_player = entity_api.new(current_threat)
	local local_player = entity_api.get_local_player()

	if target_player == nil or local_player == nil then
		return
	end

	local target_index = target_player:get_entindex()
	if contains_value(ignored_players, target_index) then
		return
	end

	if last_forced_target ~= nil and last_forced_target:get_entindex() ~= target_index then
		plist.set(last_forced_target:get_entindex(), "Override prefer body aim", "-")
	end

	last_forced_target = target_player

	local should_force_double_tap = contains_value(ui.get(advanced_settings), "Double tap")
	plist.set(target_index, "Override prefer body aim", should_force_body_aim(local_player, target_player, should_force_double_tap) and "Force" or "-")
end

local function on_round_prestart()
	clear_player_overrides(entity_api.get_players(true))
	last_forced_target = nil
end

local function update_callbacks()
	local enabled = ui.get(force_baim_checkbox)
	local callback = enabled and client.set_event_callback or client.unset_event_callback

	callback("setup_command", on_setup_command)
	callback("round_prestart", on_round_prestart)

	if not esp_flag_registered then
		client.register_esp_flag("FORCE", 255, 255, 255, function(entity_index)
			return ui.get(force_baim_checkbox) and plist.get(entity_index, "Override prefer body aim") == "Force" and not contains_value(ignored_players, entity_index)
		end)

		esp_flag_registered = true
	end

	update_visual_visibility()
end

ui.set_callback(force_baim_checkbox, update_callbacks)
ui.set_callback(advanced_settings, update_callbacks)
ui.set_callback(visualize_checkbox, update_callbacks)

ui.set_callback(ignore_force_baim_checkbox, function()
	local selected_player = ui.get(ui.reference("PLAYERS", "Players", "Player list"))
	if selected_player == nil then
		return
	end

	local is_ignored, ignore_index = contains_value(ignored_players, selected_player)

	if ui.get(ignore_force_baim_checkbox) and not is_ignored then
		ignored_players[#ignored_players + 1] = selected_player
		plist.set(selected_player, "Override prefer body aim", "-")
		client.update_player_list()
	elseif not ui.get(ignore_force_baim_checkbox) and is_ignored then
		table.remove(ignored_players, ignore_index)
	end
end)

ui.set_callback(ui.reference("PLAYERS", "Players", "Player list"), function(control)
	ui.set(ignore_force_baim_checkbox, contains_value(ignored_players, ui.get(control)))
end)

ui.set_callback(ui.reference("PLAYERS", "Players", "Reset all"), function()
	ignored_players = {}
	ui.set(ignore_force_baim_checkbox, false)
end)

update_callbacks()
client.set_event_callback("paint", on_paint)
