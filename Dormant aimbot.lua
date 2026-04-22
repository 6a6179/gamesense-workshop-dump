client_visible = client.visible
client_eye_position = client.eye_position
client_log = client.log
client_trace_bullet = client.trace_bullet
entity_get_bounding_box = entity.get_bounding_box
entity_get_local_player = entity.get_local_player
entity_get_origin = entity.get_origin
entity_get_player_name = entity.get_player_name
entity_get_player_resource = entity.get_player_resource
entity_get_player_weapon = entity.get_player_weapon
entity_get_prop = entity.get_prop
entity_is_dormant = entity.is_dormant
entity_is_enemy = entity.is_enemy
globals_curtime = globals.curtime
globals_maxplayers = globals.maxplayers
globals_tickcount = globals.tickcount
math_max = math.max
renderer_indicator = renderer.indicator
string_format = string.format
ui_get = ui.get
ui_new_hotkey = ui.new_hotkey
ui_reference = ui.reference
ui_set_callback = ui.set_callback
sqrt = sqrt
unpack = unpack
entity_is_alive = entity.is_alive
plist_get = plist.get
ffi_module = require("ffi")
vector_module = require("vector")
weapons_module = require("gamesense/csgo_weapons")
entity_list_vtable = vtable_bind("client_panorama.dll", "VClientEntityList003", 3, "void*(__thiscall*)(void*,int)")
is_entity_valid = vtable_thunk(166, "bool(__thiscall*)(void*)")
get_fov_delta = vtable_thunk(483, "float(__thiscall*)(void*)")
ui_references = {
	mindmg = ui_reference("RAGE", "Aimbot", "Minimum damage"),
	dormantEsp = ui_reference("VISUALS", "Player ESP", "Dormant")
}
dormant_aimbot_checkbox = ui.new_checkbox("RAGE", "Aimbot", "Dormant aimbot")

for build_target_points = 1, 26 do
end

dormant_settings = {
	dormantKey = ui_new_hotkey("RAGE", "Aimbot", "Dormant aimbot", true),
	dormantHitboxes = ui.new_multiselect("RAGE", "Aimbot", "Dormant target hitbox", "Head", "Chest", "Stomach", "Legs"),
	dormantAccuracy = ui.new_slider("RAGE", "Aimbot", "Dormant aimbot accuracy", 50, 100, 90, true, "%", 1),
	dormantMindmg = ui.new_slider("RAGE", "Aimbot", "Dormant minimum damage", 0, 126, 10, true, nil, 1, {
		[0] = "Inherited",
		[100 + build_target_points] = "HP + " .. build_target_points
	}),
	dormantLogs = ui.new_checkbox("RAGE", "Other", "Log dormant shots"),
	dormantIndicator = ui.new_checkbox("RAGE", "Other", "Dormant aimbot indicator")
}
hitgroup_names = {
	"generic",
	"head",
	"chest",
	"stomach",
	"left arm",
	"right arm",
	"left leg",
	"right leg",
	"neck",
	"?",
	"gear"
}
hitbox_labels = {
	"",
	"Head",
	"Chest",
	"Stomach",
	"Chest",
	"Chest",
	"Legs",
	"Legs",
	"Head",
	"",
	""
}

function build_target_points(client_visible, client_eye_position, client_log)
	client_trace_bullet, entity_get_bounding_box = client_visible:to(client_eye_position):angles()
	entity_get_bounding_box = math.rad(entity_get_bounding_box + 90)
	entity_get_local_player = vector_module(math.cos(entity_get_bounding_box), math.sin(entity_get_bounding_box), 0) * client_log
	entity_get_origin = vector_module(0, 0, client_log)

	return {
		{
			text = "Middle",
			vec = client_eye_position
		},
		{
			text = "Left",
			vec = client_eye_position + entity_get_local_player
		},
		{
			text = "Right",
			vec = client_eye_position - entity_get_local_player
		}
	}
end

function contains_value(client_visible, client_eye_position)
	for entity_get_local_player = 1, #client_visible do
		if client_visible[entity_get_local_player] == client_eye_position then
			return true
		end
	end

	return false
end

function scale_movement(client_visible, client_eye_position)
	if client_eye_position <= 0 or math.sqrt(client_visible.forwardmove * client_visible.forwardmove + client_visible.sidemove * client_visible.sidemove) <= 0 then
		return
	end

	if client_visible.in_duck == 1 then
		client_eye_position = client_eye_position * 2.94117647
	end

	if client_log <= client_eye_position then
		return
	end

	client_trace_bullet = client_eye_position / client_log
	client_visible.forwardmove = client_visible.forwardmove * client_trace_bullet
	client_visible.sidemove = client_visible.sidemove * client_trace_bullet
end

function collect_dormant_targets()
	client_visible = {}

	for entity_get_local_player = 1, globals.maxplayers() do
		if local_player_address(vector_module(), "m_bConnected", entity_get_local_player) == 1 then
			if dormant_settings(entity_get_local_player, "Add to whitelist") then
				-- Nothing
			elseif entity.is_dormant(entity_get_local_player) and entity.is_enemy(entity_get_local_player) then
				client_visible[#client_visible + 1] = entity_get_local_player
			end
		end
	end

	return client_visible
end

target_cursor = 0
dormant_state_cache = {}
hitbox_offsets = {
	{
		scale = 5,
		hitbox = "Stomach",
		vec = vector_module(0, 0, 40)
	},
	{
		scale = 6,
		hitbox = "Chest",
		vec = vector_module(0, 0, 50)
	},
	{
		scale = 3,
		hitbox = "Head",
		vec = vector_module(0, 0, 58)
	},
	{
		scale = 4,
		hitbox = "Legs",
		vec = vector_module(0, 0, 20)
	}
}
hitbox_cycle = 1
current_target, current_hitbox, current_aim_point, current_aim_text, current_accuracy = nil
shot_pending = false

function setup_command_handler(client_visible)
	if not vector_module(local_player_address) then
		return
	end

	if not vector_module(dormant_settings.dormantKey) then
		return
	end

	if not entity_is_alive(entity_get_local_player()) then
		return
	end

	if not entity_is_alive(client_log) or not entity_is_enemy(client_trace_bullet) then
		return
	end

	if not entity_is_dormant(client_trace_bullet) then
		return
	end

	entity_get_local_player = entity_get_origin(entity_get_player_weapon())
	entity_get_origin = entity_get_prop(client_eye_position, "m_flSimulationTime")
	entity_get_player_resource = entity_get_player_resource(client_log)
	entity_get_player_weapon = entity_get_prop(client_eye_position, "m_bIsScoped") == 1
	entity_get_prop = bit.band(entity_get_prop(client_eye_position, "m_fFlags"), bit.lshift(1, 0))

	if globals.tickcount() % #collect_dormant_targets() ~= 0 then
		target_cycle = target_cycle + 1
	else
		target_cycle = 1
	end

	if not entity_is_dormant[target_cycle] then
		dormant_state_cache = {}

		return
	end

	if entity_get_player_name < dormant_accuracy then
		dormant_state_cache = {}

		return
	end

	if entity_get_player_resource.type == "grenade" or entity_get_player_resource.type == "knife" then
		dormant_state_cache = {}

		return
	end

	if client_visible.in_jump == 1 and entity_get_prop == 0 then
		dormant_state_cache = {}

		return
	end

	globals_maxplayers = {}
	globals_tickcount = vector_module(dormant_settings.dormantAccuracy)

	if (vector_module(dormant_settings.dormantMindmg) == 0 and vector_module(ui_references.mindmg) or vector_module(dormant_settings.dormantMindmg)) > 100 then
		renderer_indicator = renderer_indicator - 100 + entity.get_esp_data(globals_curtime).health
	end

	string_format = vector_module(dormant_settings.dormantHitboxes)

	for ui_reference, ui_set_callback in ipairs(target_points) do
		if #string_format ~= 0 then
			if contains_value(string_format, ui_set_callback.hitbox) then
				table.insert(globals_maxplayers, {
					vec = ui_set_callback.vec,
					scale = ui_set_callback.scale,
					hitbox = ui_set_callback.hitbox
				})
			end
		else
			table.insert(globals_maxplayers, 1, {
				vec = ui_set_callback.vec,
				scale = ui_set_callback.scale,
				hitbox = ui_set_callback.hitbox
			})
		end
	end

	ui_get = nil

	if not (entity_get_player_resource.is_revolver and entity_get_prop(client_log, "m_flNextPrimaryAttack") < entity_get_origin or get_shot_timeout(entity_get_prop(client_eye_position, "m_flNextAttack"), entity_get_prop(client_log, "m_flNextPrimaryAttack"), entity_get_prop(client_log, "m_flNextSecondaryAttack")) < entity_get_origin) then
		return
	end

	ui_new_hotkey, ui_reference, ui_set_callback, sqrt, unpack = entity.get_bounding_box(globals_curtime)
	dormant_state_cache[globals_curtime] = nil

	if entity_get_origin(entity.get_origin(globals_curtime)).x and unpack > 0 then
		if not (globals_tickcount < math.floor(unpack * 100) + 5) then
			return
		end

		plist_get, ffi_module, vector_module = nil

		for get_fov_delta, ui_references in ipairs(globals_maxplayers) do
			for build_target_points, contains_value in ipairs(build_target_points(entity_get_local_player, aim_offset + ui_references.vec, ui_references.scale)) do
				scale_movement = contains_value.vec
				collect_dormant_targets, target_cursor = client_trace_bullet(client_eye_position, entity_get_local_player.x, entity_get_local_player.y, entity_get_local_player.z, scale_movement.x, scale_movement.y, scale_movement.z, true)

				if target_cursor ~= 0 and renderer_indicator < target_cursor then
					plist_get = scale_movement
					ffi_module = target_cursor
					selected_hitbox = ui_references.hitbox
					selected_hitbox_name = contains_value.text
					selected_target = globals_curtime
					target_height = unpack

					break
				end
			end

			if plist_get and ffi_module then
				break
			end
		end

		if not ffi_module then
			return
		end

		if not plist_get then
			return
		end

		if is_visible(plist_get.x, plist_get.y, plist_get.z) then
			return
		end

		scale_movement(client_visible, (entity_get_player_weapon and entity_get_player_resource.max_player_speed_alt or entity_get_player_resource.max_player_speed) * 0.33)

		weapons_module, entity_list_vtable = entity_get_local_player:to(plist_get):angles()

		if not entity_get_player_weapon and entity_get_player_resource.type == "sniperrifle" and client_visible.in_jump == 0 and entity_get_prop == 1 then
			client_visible.in_attack2 = 1
		end

		dormant_state_cache[globals_curtime] = true

		if entity_get_bounding_box < 0.01 then
			client_visible.pitch = weapons_module
			client_visible.yaw = entity_list_vtable
			client_visible.in_attack = 1
			shot_fired = true
		end
	end
end

client.register_esp_flag("DA", 255, 255, 255, function (client_visible)
	if ui.get(vector_module) and entity.is_alive(local_player_address()) then
		return dormant_settings[client_visible]
	end
end)
client.set_event_callback("weapon_fire", function (client_visible)
	client.delay_call(0.03, function ()
		if client.userid_to_entindex(vector_module.userid) == entity.get_local_player() then
			if local_player_address and not dormant_settings then
				client.fire_event("dormant_miss", {
					userid = entity_get_local_player,
					aim_hitbox = entity_is_alive,
					aim_point = entity_is_alive,
					accuracy = entity_is_enemy
				})
			end

			dormant_settings = false
			local_player_address = false
			entity_is_alive = nil
			entity_is_alive = nil
			entity_get_local_player = nil
			entity_is_enemy = nil
		end
	end)
end)

function player_hurt_handler(client_visible)
	client_eye_position = client.userid_to_entindex(client_visible.userid)
	client_trace_bullet, entity_get_bounding_box, entity_get_local_player, entity_get_origin, entity_get_player_name = entity.get_bounding_box(client.userid_to_entindex(client_visible.userid))

	if client.userid_to_entindex(client_visible.attacker) == entity.get_local_player() and client_eye_position ~= nil and entity.is_dormant(client_eye_position) and vector_module == true then
		local_player_address = true

		client.fire_event("dormant_hit", {
			userid = client_eye_position,
			attacker = client_log,
			health = client_visible.health,
			armor = client_visible.armor,
			weapon = client_visible.weapon,
			dmg_health = client_visible.dmg_health,
			dmg_armor = client_visible.dmg_armor,
			hitgroup = client_visible.hitgroup,
			accuracy = entity_get_player_name,
			aim_hitbox = dormant_settings
		})
	end
end

function reset_freeze_timer()
	vector_module = local_player_address() + (cvar.mp_freezetime:get_float() + 1) / globals.tickinterval()
end

ui_set_callback(dormant_aimbot_checkbox, function ()
	client_eye_position = vector_module(local_player_address) and client.set_event_callback or client.unset_event_callback

	if client_visible then
		ui.set(dormant_settings.dormantEsp, client_visible)
	end

	client_eye_position("setup_command", entity_get_local_player)
	client_eye_position("round_prestart", entity_is_alive)
	client_eye_position("player_hurt", entity_is_alive)
	entity_is_enemy()
end)
do
	for entity_get_bounding_box, entity_get_local_player in pairs(local_player_address) do
		ui.set_visible(entity_get_local_player, ui.get(vector_module))
	end
end
client.set_event_callback("paint", function ()
	client_visible = ({
		vector_module(local_player_address.dormantKey)
	})[2]

	if not dormant_settings(entity_get_local_player()) then
		return
	end

	if vector_module(entity_is_alive) and vector_module(local_player_address.dormantKey) and vector_module(local_player_address.dormantIndicator) then
		client_eye_position = {
			255,
			255,
			255,
			200
		}

		for entity_get_local_player, entity_get_origin in pairs(entity_is_alive) do
			if entity_get_origin then
				client_eye_position = {
					143,
					194,
					21,
					255
				}

				break
			end
		end

		if #entity_is_enemy() == 0 then
			client_eye_position = {
				255,
				0,
				50,
				255
			}
		end

		entity_is_dormant(client_eye_position[1], client_eye_position[2], client_eye_position[3], client_eye_position[4], "DA")
	end
end)
client.set_event_callback("dormant_hit", function (client_visible)
	if vector_module(local_player_address.dormantLogs) then
		if dormant_settings[client_visible.hitgroup + 1] == client_visible.aim_hitbox or entity_get_local_player == "Head" then
			print(string.format("[DA] Hit %s in the %s for %i damage (%i health remaining) (%s accuracy)", entity.get_player_name(client_visible.userid), entity_is_alive[client_visible.hitgroup + 1], client_visible.dmg_health, client_visible.health, string.format("%.0f", client_visible.accuracy * 100) .. "%"))
		else
			print(string.format("[DA] Hit %s in the %s for %i damage (%i health remaining) aimed=%s (%s accuracy)", client_eye_position, entity_is_alive[client_visible.hitgroup + 1], client_visible.dmg_health, client_visible.health, client_visible.aim_hitbox, string.format("%.0f", client_visible.accuracy * 100) .. "%"))
		end
	end
end)
client.set_event_callback("dormant_miss", function (client_visible)
	if vector_module(local_player_address.dormantLogs) then
		print(string.format("[DA] Missed %s's %s (mp=%s) (%s accuracy)", entity.get_player_name(client_visible.userid), dormant_settings, entity_get_local_player, string.format("%.0f", client_visible.accuracy * 100) .. "%"))
	end
end)
