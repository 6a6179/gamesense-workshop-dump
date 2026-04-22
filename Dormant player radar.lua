ffi_module = require("ffi")
ffi_cast = ffi_module.cast
panorama_radar_helpers = panorama.loadstring([[
	var _ClearStylesRecursive = function(panel) {
		if(panel == "Selected")
			return

		delete panel.style.backgroundPosition
		delete panel.style.backgroundSize
		delete panel.style.backgroundRepeat
		delete panel.style.paddingLeft
		delete panel.style.x

		try {
			for (var key in panel.style) {
				panel.style[key] = null
				delete panel.style[key]
			}
		} catch(e) {
			// $.Msg("[DormantRadar] Error clearing styles on " + panel.id + ": " + e)
		}

		for (var i = 0; i < panel.GetChildCount(); i++) {
			_ClearStylesRecursive(panel.GetChild(i))
		}
	}

	var _UpdatePlayers = function(players_associative, teammates_are_enemies, local_alive, bomb_player) {
		var radar = $.GetContextPanel().FindChildrenWithClassTraverse("hud-radar")[0].FindChild("Radar")

		if(radar == null)
			return

		// make sure RI_BombDefuserPackage is the last child
		var last_child = radar.GetChild(radar.GetChildCount() - 1)
		if(last_child && last_child.id != "RI_BombDefuserPackage") {
			if(radar.FindChild("RI_BombDefuserPackage"))
				radar.MoveChildAfter(radar.FindChild("RI_BombDefuserPackage"), last_child)
		}

		var last_child
		var bomb_child

		radar.Children().forEach(panel => {
			if(panel.entindex == null) {
				var match = panel.id.match(/^Player(\d+)$/)

				panel.entindex = match ? (match[1] || -1) : -1
			}

			// hide the default carried bomb for dormant players. we create our own icon
			if(panel.id == "RI_BombDefuserPackage") {
				var bomb = panel.FindChild("CreateBombPack")
				bomb.style.transition = bomb_player ? "opacity 0.2s ease-in-out 0.0s" : null
				bomb.style.opacity = bomb_player ? 0 : 1

				// $.Msg("default ", bomb)
			}

			if(panel.entindex == -1)
				return

			last_child = panel

			var images = panel.FindChildTraverse("PI_FirstRotated")
			var custom_bomb_icon = panel.FindChildTraverse("Custom_BombIcon")

			var player = players_associative[panel.id]

			if(!local_alive && (images.FindChild("ViewFrustrum").visible || images.FindChild("Selected").visible)){
				// $.Msg("ignoring player M1 ", panel.entindex)
				player = null
			}

			// images.FindChild("EnemyOnMap").visible = null
			if(teammates_are_enemies && player != null) {
				// I hate myself but I hate valve even more
				// var transform = images.style.transform
				// if(transform.includes("rotate3d"))
				//	 images.style.transform = transform.split("\n").filter(line => !line.startsWith("rotate3d")).map(line => line.replace(/(.*px) (.*px) (.*px)/, "$1, $2, $3")).join(" ")

				var ids = ["TOnMap", "CTOnMap"]
				ids.forEach((id) => {
					var image = images.FindChild(id)

					image.style.width = "14px"
					image.style.height = "14px"
					image.style.padding = "7px"
					image.style.saturation = "0"
					image.style.backgroundImage = "url(\"file://{images}/hud/radar/icon-enemy-on-map.png\")"
					image.style.backgroundPosition = "center center"
					image.style.backgroundRepeat = "no-repeat no-repeat"
					image.style.backgroundSize = "100%"
				})
			}

			if(player) {
				var offmap = images.FindChild("EnemyOffMap")
				var onmap = images.FindChild("EnemyOnMap")

				// images.visible = player.alive

				images.style.saturation = "0"
				images.style.washColor = player.dormant ? "#B2B2B2FF" : "#FF1919FF"
				images.style.transition = player.alpha > 0 ? "wash-color 0.2s ease-in-out 0.0s" : null
				images.style.opacity = player.alpha

				var enemy_ghost = images.FindChild("EnemyGhost")
				enemy_ghost.visible = false

				// onmap.style.maxHeight = (!offmap.visible && !enemy_ghost.visible && player.alive) ? null : 0
				// onmap.style.maxHeight = (!enemy_ghost.visible && player.alive) ? null : 0

				images.FindChild("AbovePlayer").style.maxHeight = 0
				images.FindChild("BelowPlayer").style.maxHeight = 0
				// images.FindChild("CTGhost").style.maxHeight = 0
				// images.FindChild("TGhost").style.maxHeight = 0
				// images.FindChild("EnemyDeath").visible = false

				if(player.entindex == bomb_player) {
					if(custom_bomb_icon == null) {
						// $.Msg("creating custom_bomb_icon ", panel.id)
						custom_bomb_icon = $.CreatePanel("Image", images, "Custom_BombIcon", {
							src: "file://{images}/hud/radar/C4_sml.png",
							style: "width: 15px; height: 11px; horizontal-align: center; vertical-align: center; wash-color: #C9C9C9FF; img-shadow: 0px 0px 1px 2 #11111111;"
						})
					}

					// $.Msg("custom ", custom_bomb_icon)
					custom_bomb_icon.visible = true
					custom_bomb_icon.style.opacity = Math.min(1, player.alpha * 1.2)
					bomb_child = panel
				} else if(custom_bomb_icon != null) {
					custom_bomb_icon.visible = false
				}
			} else {
				// clean up
				if(custom_bomb_icon != null) {
					custom_bomb_icon.DeleteAsync(0.0)
					custom_bomb_icon.visible = false
					custom_bomb_icon.SetParent($.GetContextPanel())
				}

				_ClearStylesRecursive(panel)
			}

			// fix csgo bug #81237123761236: the circle when spectating is off center
			images.FindChild("Selected").style.position = "0px -10px 0px"
		})

		// move the player with the bomb to the top
		if(last_child != null && bomb_child != null && last_child != bomb_child) {
			radar.MoveChildAfter(bomb_child, last_child)
		}
	}

	return {
		update_players: _UpdatePlayers
	}
]], "CSGOHud")()
client_entity_list_vtable = vtable_bind("client.dll", "VClient018", 8, "void*(__thiscall*)(void*)")
entity_class_t = ffi_module.typeof([[
	struct {
		int pad[2];
		char* name;
		void* recv_table;
		void* next;
		int class_id;
	} *
]])
player_cache = {}

(function ()
	table.clear(ffi_module)

	if entity.get_local_player() == nil then
		return
	end

	ffi_module = class_cache()

	while ffi_module ~= nil do
		if refresh_class_cache(ffi_cast, ffi_module).class_id > 0 and ffi_cast.recv_table ~= nil then
			ffi_module[string_module.string(ffi_cast.name)] = ffi_cast.class_id
		end

		ffi_module = ffi_cast.next
	end
end)()
assert(ffi_cast("int*", ffi_cast("char*", client.find_signature("client.dll", "h\\xcc\\xcc\\xcc\\xccAE\\xe4A \\xf3~E\\xccf\\xd6ẢA8\\xb9\\xcc\\xcc\\xcc\\xcc\\xe8\\xcc\\xcc\\xcc\\xccj\\xccj\\xccjj`")) + 1)[0] == 2432)

entity_list_vtable = vtable_bind("client_panorama.dll", "VClientEntityList003", 3, "void*(__thiscall*)(void*,int)")
hud_radar_ptr = ffi_cast("uintptr_t", ffi_cast("void***(__thiscall*)(void*, const char*)", client.find_signature("client.dll", "U\\x8b\\xecS\\x8b]VW\\x8b\\xf93\\xf69w("))(ffi_cast("void**", ffi_cast("char*", client.find_signature("client.dll", "\\xb9\\xcc\\xcc\\xcc̈F\t") or error("HUD signature outdated")) + 1)[0], "CCSGO_HudRadar"))
update_radar_entries = ffi_cast("bool(__thiscall*)(void*, int*)", client.find_signature("client.dll", "U\\x8b\\xec\\x83\\xecSV\\x8buW\\x8b\\xf9\\xc7E"))

function clear_player_cache(ffi_module, ffi_cast)
	radar_panel = ffi_module.new("uint8_t[32]")

	if class_cache.CCSPlayer == nil then
		refresh_class_cache()

		return
	end

	ffi_cast("bool*", radar_panel + 24)[0] = ffi_module
	ffi_cast("int*", radar_panel + 12)[0] = #ffi_cast
	player_index = ffi_module.new("int[?]", #ffi_cast)
	ffi_cast("int*", radar_panel + 8)[0] = ffi_cast("int", player_index)

	for player_index, player_state in ipairs(ffi_cast) do
		entity_list_vtable = ffi_module.new("uint8_t[?]", #ffi_cast * 100) + (player_index - 1) * 100
		entity_class_lookup[player_index - 1] = ffi_cast("int", entity_list_vtable)
		ffi_cast("int*", entity_list_vtable + 8)[0] = player_state.entindex
		ffi_cast("int*", entity_list_vtable + 12)[0] = class_cache[entity.get_classname(player_state.entindex)]
		ffi_cast("int*", entity_list_vtable + 16)[0] = player_state.x / 4
		ffi_cast("int*", entity_list_vtable + 20)[0] = player_state.y / 4
		ffi_cast("int*", entity_list_vtable + 24)[0] = player_state.z / 4
		ffi_cast("int*", entity_list_vtable + 28)[0] = player_state.yaw
		ffi_cast("bool*", entity_list_vtable + 32)[0] = player_state.defuser
		ffi_cast("bool*", entity_list_vtable + 34)[0] = player_state.player_has_c4
	end

	string_module(ffi_cast("void*", panorama_radar_helpers - 20), ffi_cast("int*", radar_panel))
end

radar_target = nil

client.set_event_callback("level_init", function ()
	ffi_module = nil

	client.delay_call(1, class_cache)
end)
client.set_event_callback("round_end", player_index)
client.set_event_callback("player_connect_full", player_index)

function collect_radar_players()
	ffi_module = {}
	ffi_cast = {}

	if entity.get_local_player() == nil then
		return
	end

	entity_class_lookup, panorama_radar_helpers = nil
	client_entity_list_vtable = cvar.mp_teammates_are_enemies:get_int() ~= 0
	player_cache = nil

	if not (entity.get_prop(radar_panel, "deadflag") == 0) then
		player_cache = entity.get_prop(radar_panel, "m_hObserverTarget")
	end

	if client_entity_list_vtable then
		entity_class_lookup = select(3, entity.get_origin(radar_panel))
		panorama_radar_helpers = entity.get_prop(radar_panel, "m_iTeamNum")
	end

	player_state = entity.get_prop(entity.get_player_resource(), "m_iPlayerC4")
	entity_list_vtable = nil

	for update_radar_entries = 1, globals.maxplayers() do
		if update_radar_entries ~= radar_panel and entity.get_classname(update_radar_entries) == "CCSPlayer" and entity.is_enemy(update_radar_entries) then
			if client_entity_list_vtable then
				radar_target = class_cache("int64_t*", class_cache("char*", ffi_module(update_radar_entries)) + refresh_class_cache)
				radar_target[0] = bit.bor(radar_target[0], bit.lshift(1, radar_panel - 1))
			end

			entity.set_prop(update_radar_entries, "m_bSpotted", 1)

			radar_target = entity.is_alive(update_radar_entries)
			ffi_module[string.format("Player%d", update_radar_entries - 1)] = {
				name = entity.get_player_name(update_radar_entries),
				entindex = update_radar_entries,
				dormant = clear_player_cache,
				alive = radar_target,
				alpha = entity.is_dormant(update_radar_entries) and math.floor(entity.get_esp_data(update_radar_entries).alpha * 80 + 0.5) / 80 or 1,
				observed = update_radar_entries == player_cache
			}

			if radar_target and (not clear_player_cache or collect_radar_players.alpha > 0) then
				clear_observer_target, toggle_radar_hooks, player_z = entity.get_origin(update_radar_entries)

				if client_entity_list_vtable and update_radar_entries ~= player_cache and entity.get_prop(update_radar_entries, "m_iTeamNum") == panorama_radar_helpers then
					player_z = entity_class_lookup - 500
				end

				table.insert(ffi_cast, {
					player_has_c4 = false,
					player_has_defuser = false,
					defuser = false,
					yaw = 0,
					entindex = update_radar_entries,
					x = clear_observer_target,
					y = toggle_radar_hooks,
					z = player_z
				})

				if player_state == update_radar_entries and entity.is_dormant(update_radar_entries) then
					entity_list_vtable = update_radar_entries
				end
			end
		end
	end

	ffi_cast(false, ffi_cast)

	if json.stringify(ffi_module) ~= string_module then
		string_module = local_player_ref

		panorama_radar_helpers.update_players(ffi_module, client_entity_list_vtable, entity_class_t, entity_list_vtable)
	end
end

function reset_radar_cache()
	ffi_module = nil
end

function clear_observer_target()
	ffi_module = nil

	class_cache.update_players({}, false, false, nil)
end

function toggle_radar_hooks()
	if ui.get(ffi_module) and ui.get(class_cache) then
		client.set_event_callback("pre_render", refresh_class_cache)
		client.set_event_callback("shutdown", ffi_cast)
		client.set_event_callback("spec_target_updated", string_module)
	else
		client.unset_event_callback("pre_render", refresh_class_cache)
		client.unset_event_callback("shutdown", ffi_cast)
		client.unset_event_callback("spec_target_updated", string_module)
		ffi_cast()
	end
end

ui.set_callback(ui.reference("VISUALS", "Player ESP", "Dormant"), toggle_radar_hooks)
ui.set_callback(ui.reference("VISUALS", "Other ESP", "Radar"), toggle_radar_hooks)
toggle_radar_hooks()
