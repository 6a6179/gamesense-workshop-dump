local vector = require("vector")
local weapons = require("gamesense/csgo_weapons")

local ignored_weapon_types = {
	"taser",
	"grenade",
	"c4"
}

local breakable_ragebot_enabled = false
local cached_breakables = {}
local max_target_distance = 64

local function contains_value(values, needle)
	for index = 1, #values do
		if values[index] == needle then
			return true
		end
	end

	return false
end

local function get_entity_position(entity_index)
	if entity.get_prop(entity_index, "m_nModelIndex") == 824 then
		local adjusted_position = vector(entity.get_origin(entity_index))
		adjusted_position.x = adjusted_position.x - 15
		return adjusted_position
	end

	return vector(entity.get_origin(entity_index)) + vector(entity.get_prop(entity_index, "m_vecMins")) / 2 + vector(entity.get_prop(entity_index, "m_vecMaxs")) / 2
end

local function get_breakable_entities()
	local breakables = {}

	for entity_index = 65, 1000 do
		local success, move_type = pcall(entity.get_prop, entity_index, "m_MoveType")

		if success and move_type == 7 and bit.band(entity.get_prop(entity_index, "m_usSolidFlags"), 65535) == 2048 then
			breakables[#breakables + 1] = entity_index
		end
	end

	return breakables
end

local function get_visible_breakables()
	cached_breakables = {}

	local local_player = entity.get_local_player()
	if local_player == nil then
		return cached_breakables
	end

	local eye_position = client.eye_position()
	local player_velocity = vector(entity.get_prop(local_player, "m_vecVelocity"))
	player_velocity.z = 0

	local predicted_eye_position = vector(eye_position) + player_velocity:scaled(globals.tickinterval() * 64)
	local breakables = get_breakable_entities()

	for _, entity_index in ipairs(breakables) do
		local trace_fraction, hit_entity = client.trace_line(local_player, eye_position.x, eye_position.y, eye_position.z, predicted_eye_position.x, predicted_eye_position.y, predicted_eye_position.z)

		if hit_entity == entity_index then
			cached_breakables[#cached_breakables + 1] = entity_index
			break
		end
	end

	if #cached_breakables == 0 then
		local camera_direction = vector():init_from_angles(client.camera_angles())
		camera_direction:scale(32)
		camera_direction = camera_direction + predicted_eye_position

		for _, entity_index in ipairs(breakables) do
			local trace_fraction, hit_entity = client.trace_line(local_player, eye_position.x, eye_position.y, eye_position.z, camera_direction.x, camera_direction.y, camera_direction.z)

			if hit_entity == entity_index then
				cached_breakables[#cached_breakables + 1] = entity_index
				break
			end
		end
	end

	return cached_breakables
end

local function draw_breakable_marker(entity_index)
	local origin = get_entity_position(entity_index)
	local screen_origin = vector(renderer.world_to_screen(origin:unpack()))
	local mins_screen = vector(renderer.world_to_screen((vector(entity.get_origin(entity_index)) + vector(entity.get_prop(entity_index, "m_vecMins"))):unpack()))
	local maxs_screen = vector(renderer.world_to_screen((vector(entity.get_origin(entity_index)) + vector(entity.get_prop(entity_index, "m_vecMaxs"))):unpack()))

	renderer.line(mins_screen.x, mins_screen.y, maxs_screen.x, maxs_screen.y, 0, 0, 0, 255)
	renderer.circle(screen_origin.x, screen_origin.y, 50, 50, 50, 255, 3, 0, 100)
end

local function paint_callback()
	local local_player = entity.get_local_player()
	if local_player == nil then
		return
	end

	for _, breakable_entity in ipairs(get_visible_breakables()) do
		draw_breakable_marker(breakable_entity)
	end

	local eye_position = client.eye_position()
	local velocity = vector(entity.get_prop(local_player, "m_vecVelocity"))
	velocity.z = 0

	local eye_screen = vector(renderer.world_to_screen(eye_position:unpack()))
	local predicted_eye_screen = vector(renderer.world_to_screen((eye_position + velocity:scaled(globals.tickinterval() * 64)):unpack()))
	renderer.line(eye_screen.x, eye_screen.y, predicted_eye_screen.x, predicted_eye_screen.y, 255, 255, 255, 255)
end

local function find_best_breakable_target()
	local local_player = entity.get_local_player()
	if local_player == nil then
		return nil
	end

	local player_weapon = entity.get_player_weapon(local_player)
	if player_weapon == nil then
		return nil
	end

	local weapon_definition = weapons(player_weapon)
	if weapon_definition == nil then
		return nil
	end

	if math.max(0, entity.get_prop(player_weapon, "m_flNextPrimaryAttack") or 0, entity.get_prop(local_player, "m_flNextAttack") or 0) - globals.curtime() >= 0 then
		return nil
	end

	if weapon_definition.type ~= "knife" and entity.get_prop(player_weapon, "m_iClip1") <= 0 then
		return nil
	end

	if contains_value(ignored_weapon_types, weapon_definition.type) then
		return nil
	end

	local eye_position = vector(client.eye_position())
	local best_target = nil
	local best_distance = math.huge

	for _, entity_index in ipairs(get_breakable_entities()) do
		local target_position = get_entity_position(entity_index)
		local distance = eye_position:dist(target_position)

		if distance < max_target_distance and distance < best_distance then
			local trace_fraction, hit_entity = client.trace_line(local_player, eye_position.x, eye_position.y, eye_position.z, target_position.x, target_position.y, target_position.z)

			if trace_fraction >= 0.95 or hit_entity == entity_index then
				best_distance = distance
				best_target = target_position
			end
		end
	end

	return best_target
end

local function setup_command_callback(command)
	local target_position = find_best_breakable_target()
	if target_position == nil then
		return
	end

	local eye_position = vector(client.eye_position())
	command.pitch, command.yaw = eye_position:to(target_position):angles()
	command.in_attack = 1
end

local function update_callbacks()
	if breakable_ragebot_enabled then
		client.set_event_callback("paint", paint_callback)
		client.set_event_callback("setup_command", setup_command_callback)
	else
		client.unset_event_callback("paint", paint_callback)
		client.unset_event_callback("setup_command", setup_command_callback)
	end
end

local breakables_ragebot_toggle = ui.new_checkbox("MISC", "Miscellaneous", "Breakables Ragebot")
ui.set_callback(breakables_ragebot_toggle, function()
	breakable_ragebot_enabled = ui.get(breakables_ragebot_toggle)
	update_callbacks()
end)

breakable_ragebot_enabled = ui.get(breakables_ragebot_toggle)
update_callbacks()
