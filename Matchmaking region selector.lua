local ffi = require("ffi")
local steamworks = require("gamesense/steamworks")
local http = require("gamesense/http")

local saved_settings = database.read("server_picker")
if type(saved_settings) ~= "table" then
	saved_settings = {}
end

if saved_settings.active_datacenter ~= nil then
	saved_settings.active_datacenters = saved_settings.active_datacenters or {
		saved_settings.active_datacenter
	}
	saved_settings.active_datacenter = nil
end

if type(saved_settings.active_datacenters) ~= "table" then
	saved_settings.active_datacenters = {}
end

local steam_networking_utils = steamworks.ISteamNetworkingUtils()
local datacenters_by_id = {}
local datacenter_order = {}
local panorama_bridge
local panorama_layout
local hide_from_obs_control = ui.reference("MISC", "Settings", "Hide from OBS")
local last_datacenter_refresh = 0
local runtime_started = false
local sdr_module = package.loaded["gamesense/sdr"]

if sdr_module == nil then
	sdr_module = {}
end

local function clear_table(values)
	for key in pairs(values) do
		values[key] = nil
	end
end

local function pop_id_to_string(pop_id)
	local bytes = ffi.cast("const char*", ffi.new("unsigned int[1]", pop_id))

	return string.char(bytes[2]) .. string.char(bytes[1]) .. string.char(bytes[0]) .. (bytes[3] == 0 and "" or string.char(bytes[3]))
end

local function string_to_pop_id(pop_code)
	local bytes = ffi.cast("char*", ffi.cast("unsigned int*", ffi.new("unsigned int[1]", 0)))
	bytes[2] = string.byte(pop_code, 1)
	bytes[1] = string.byte(pop_code, 2)
	bytes[0] = string.byte(pop_code, 3)
	bytes[3] = string.byte(pop_code, 4) or 0

	return bytes[0]
end

local function get_pop_list()
	local pop_count = steam_networking_utils.GetPOPCount()
	local pop_list = ffi.new("unsigned int[?]", pop_count)

	steam_networking_utils.GetPOPList(pop_list, pop_count)

	return pop_count, pop_list
end

local function geodesic_distance_km(first_datacenter_id, second_datacenter_id)
	local first_datacenter = datacenters_by_id[first_datacenter_id]
	local second_datacenter = datacenters_by_id[second_datacenter_id]

	if first_datacenter == nil or second_datacenter == nil or first_datacenter.geo == nil or second_datacenter.geo == nil then
		return 999
	end

	local first_latitude, first_longitude = unpack(first_datacenter.geo)
	local second_latitude, second_longitude = unpack(second_datacenter.geo)
	local half_latitude = math.sin(math.rad(second_latitude - first_latitude) / 2)
	local half_longitude = math.sin(math.rad(second_longitude - first_longitude) / 2)
	local haversine = half_latitude * half_latitude + math.cos(math.rad(first_latitude)) * math.cos(math.rad(second_latitude)) * half_longitude * half_longitude

	return 125 * 2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine))
end

local function refresh_datacenter_ping_data()
	local pop_count, pop_list = get_pop_list()

	for index = 1, pop_count do
		local pop_id = pop_list[index - 1]
		local datacenter_id = pop_id_to_string(pop_id)
		local datacenter = datacenters_by_id[datacenter_id]

		if datacenter ~= nil then
			local direct_ping = steam_networking_utils.GetDirectPingToPOP(pop_id)
			if direct_ping > 0 and direct_ping < 800 then
				datacenter.direct = direct_ping
			end

			local indirect_ping, relay_pop_id = steam_networking_utils.GetPingToDataCenter(pop_id)
			if indirect_ping > 0 and relay_pop_id ~= nil and indirect_ping < 800 then
				datacenter.relay = pop_id_to_string(relay_pop_id)
				datacenter.indirect = indirect_ping
			end
		end
	end
end

local function rebuild_search_ping_cap()
	local active_datacenters = saved_settings.active_datacenters or {}

	if #active_datacenters == 0 then
		return
	end

	local best_datacenter_id = nil
	local lowest_direct_ping = math.huge

	for _, datacenter_id in ipairs(active_datacenters) do
		local datacenter = datacenters_by_id[datacenter_id]

		if datacenter ~= nil and datacenter.direct ~= nil and datacenter.direct > 0 and datacenter.direct < lowest_direct_ping then
			lowest_direct_ping = datacenter.direct
			best_datacenter_id = datacenter_id
		end
	end

	if best_datacenter_id == nil then
		for datacenter_id, datacenter in pairs(datacenters_by_id) do
			if datacenter.direct ~= nil and datacenter.direct > 0 and datacenter.direct < lowest_direct_ping then
				lowest_direct_ping = datacenter.direct
				best_datacenter_id = datacenter_id
			end
		end
	end

	if lowest_direct_ping == math.huge then
		lowest_direct_ping = 50
	end

	if best_datacenter_id == nil then
		best_datacenter_id = active_datacenters[1]
	end

	local estimated_ping_cap = lowest_direct_ping

	if best_datacenter_id ~= nil then
		for _, datacenter_id in ipairs(active_datacenters) do
			if datacenter_id ~= best_datacenter_id and datacenters_by_id[datacenter_id] ~= nil then
				estimated_ping_cap = math.min(900, math.floor(estimated_ping_cap + client.random_int(25, 45) + geodesic_distance_km(datacenter_id, best_datacenter_id))) + client.random_int(30, 55)
				break
			end
		end
	end

	estimated_ping_cap = estimated_ping_cap + 20
	cvar.mm_dedicated_search_maxping:set_raw_float(estimated_ping_cap)
	cvar.mm_dedicated_search_maxping:set_raw_int(estimated_ping_cap)
end

local function sync_active_datacenters()
	if panorama_bridge ~= nil then
		panorama_bridge.set_active_datacenters(saved_settings.active_datacenters or {})
	end
end

local function validate_active_datacenters()
	for _, datacenter_id in pairs(saved_settings.active_datacenters) do
		if datacenters_by_id[datacenter_id] == nil then
			saved_settings.active_datacenters = {}
			break
		end
	end
end

local function build_datacenter_order()
	datacenter_order = {}

	for datacenter_id, datacenter in pairs(datacenters_by_id) do
		table.insert(datacenter_order, {
			datacenter.name,
			datacenter_id
		})
	end

	table.sort(datacenter_order, function(left, right)
		return left[1] < right[1]
	end)

	for index, entry in ipairs(datacenter_order) do
		datacenter_order[index] = entry[2]
	end
end

local function refresh_panorama_dropdown()
	validate_active_datacenters()
	build_datacenter_order()

	if panorama_bridge == nil then
		return
	end

	panorama_bridge.set_datacenters(datacenters_by_id, nil, datacenter_order)
	panorama_bridge.set_layouts(panorama_layout)
	panorama_bridge.set_active_datacenters(saved_settings.active_datacenters or {})

	local function try_create_panorama()
		if panorama_bridge.create() then
			if not runtime_started then
				runtime_started = true
				sync_active_datacenters()

				local function update_visibility()
					if panorama_bridge ~= nil then
						panorama_bridge.set_visible(not ui.get(hide_from_obs_control))
					end
				end

				ui.set_callback(hide_from_obs_control, update_visibility)
				update_visibility()

				client.set_event_callback("paint_ui", function()
					update_visibility()

					if globals.mapname() ~= nil then
						return
					end

					local now = globals.realtime()
					local _, relay_status = steam_networking_utils.GetRelayNetworkStatus()

					if now - last_datacenter_refresh > 0.2 then
						refresh_datacenter_ping_data()
						panorama_bridge.set_datacenters(datacenters_by_id, relay_status.m_bPingMeasurementInProgress == 1, datacenter_order)
						last_datacenter_refresh = now
					end

					if #saved_settings.active_datacenters > 0 then
						rebuild_search_ping_cap()
					end
				end)

				client.set_event_callback("shutdown", function()
					if panorama_bridge ~= nil then
						panorama_bridge.destroy()
					end

					database.write("server_picker", saved_settings)
				end)
			end
		else
			client.delay_call(0.2, try_create_panorama)
		end
	end

	try_create_panorama()
end

local function stop_search_with_reason(reason)
	local is_searching = PartyListAPI.GetPartySessionSetting("game/mmqueue") == "searching"

	if is_searching then
		LobbyAPI.StopMatchmaking()
	end

	if reason ~= nil then
		local popup_message = "Failed to force region!\n\n" .. tostring(reason) .. "\n\n" .. (is_searching and "The search has been stopped.\n" or "") .. "If this error persists, please disable the lua script."

		UiToolkitAPI.ShowGenericPopupOk(
			"MM Region Selector Error",
			popup_message,
			"",
			function()
				UiToolkitAPI.CloseAllVisiblePopups()
			end
		)
	end
end

local function handle_config_response(request_succeeded, response)
	if not request_succeeded or response.status ~= 200 then
		return
	end

	local config = json.parse(response.body)
	if config.success ~= 1 then
		return
	end

	clear_table(datacenters_by_id)

	local pop_count, pop_list = get_pop_list()

	for index = 1, pop_count do
		local pop_code = pop_id_to_string(pop_list[index - 1])
		local config_pop = config.pops[pop_code]
		local datacenter = {
			i = index,
			id = pop_code,
			name = config_pop ~= nil and (config_pop.server_region or config_pop.desc or pop_code:upper()) or pop_code:upper()
		}

		if config_pop ~= nil then
			if datacenter.name:find("_") then
				datacenter.name = config_pop.desc or datacenter.name
			end

			if config_pop.country ~= nil then
				datacenter.country_code = config_pop.country.short_name
			end

			datacenter.server_region = config_pop.server_region
			datacenter.geo = config_pop.geo
			datacenter.time_offset = config_pop.time_offset
			datacenter.groups = config_pop.groups
		end

		datacenters_by_id[pop_code] = datacenter
	end

	refresh_datacenter_ping_data()
	rebuild_search_ping_cap()
	refresh_panorama_dropdown()
end

local function request_config_on_first_paint()
	if globals.mapname() == nil then
		xpcall(function()
			http.get("https://sapphyr.us/sdr-data/v1/config", handle_config_response)
		end, client.error_log)
		client.unset_event_callback("paint_ui", request_config_on_first_paint)
	end
end

local function get_all_datacenters()
	local datacenter_ids = {}

	for datacenter_id in pairs(datacenters_by_id) do
		table.insert(datacenter_ids, datacenter_id)
	end

	return datacenter_ids
end

local function get_datacenter_info(datacenter_id)
	if datacenters_by_id[datacenter_id] == nil then
		error("unknown datacenter: " .. tostring(datacenter_id), 2)
	end

	return {
		name = datacenters_by_id[datacenter_id].name,
		country_code = datacenters_by_id[datacenter_id].country_code,
		ping = {
			direct = datacenters_by_id[datacenter_id].direct,
			indirect = datacenters_by_id[datacenter_id].indirect,
			relay = datacenters_by_id[datacenter_id].relay
		}
	}
end

local function get_active_datacenters()
	return {
		unpack(saved_settings.active_datacenters or {})
	}
end

local function set_active_datacenters(active_datacenters)
	for _, datacenter_id in pairs(active_datacenters) do
		if datacenters_by_id[datacenter_id] == nil then
			error("unknown datacenter: " .. tostring(datacenter_id), 2)
			return
		end
	end

	saved_settings.active_datacenters = active_datacenters or {}
	sync_active_datacenters()
	rebuild_search_ping_cap()
end

sdr_module.get_active_datacenters = get_active_datacenters
sdr_module.set_active_datacenters = set_active_datacenters
sdr_module.get_all_datacenters = get_all_datacenters
sdr_module.get_datacenter_info = get_datacenter_info
sdr_module.stop_search = stop_search_with_reason

if package.loaded["gamesense/sdr"] == nil then
	package.loaded["gamesense/sdr"] = sdr_module
end

panorama_bridge = panorama.loadstring([[
	var panel, panel_dropdown, panel_top_bar
	var update_visibility_callback
	var datacenters = {}
	var datacenters_arr = []
	var datacenters_active = []
	var ping_measurement = false
	var popup_open = false

	var dropdown_layout

	var _SetDatacenters = function(_datacenters, _ping_measurement, _datacenters_arr) {
		if(_datacenters != null) {
			datacenters = _datacenters

			if(panel_dropdown != null)
				_UpdateDropdownItems()
		}

		if(_datacenters_arr != null)
			datacenters_arr = _datacenters_arr

		if(_ping_measurement != null) {
			var update = ping_measurement != _ping_measurement
			ping_measurement = _ping_measurement

			if(update && panel_dropdown != null)
				_UpdateDropdownHeader()
		}

		if(popup_open)
			_UpdatePopup()
	}

	var _SetLayouts = function(_dropdown_layout) {
		dropdown_layout = _dropdown_layout
	}

	var _HandleScrollBar = function() {
		if(panel_top_bar == null || panel == null || !panel.IsValid())
			return

		if(panel.desiredlayoutwidth > panel.actuallayoutwidth)
			panel_top_bar.style.overflow = "scroll squish"
	}

	var _HandleDatacenterClick = function(id) {
		if(datacenters_active.includes(id)) {
			_SetActiveDatacenters(datacenters_active.filter((el) => el != id))
		} else {
			_SetActiveDatacenters(datacenters_active.concat([id]))
		}
	}

	var _GetRegionImage = function(country_code) {
		if(country_code == "HK" || country_code == "CN" || country_code == "BR" || country_code == "ZA" || country_code == "US" || country_code == "AU" || country_code == "SG")
			return `https://raw.githubusercontent.com/hampusborgos/country-flags/master/png100px/${country_code.toLowerCase()}.png`

		return `file://{images}/regions/${country_code}.png`
	}

	var _Create = function(){
		if(panel != null){
			return false
		}

		var panel_bot_difficulty = $.GetContextPanel().FindChildTraverse("BotDifficultyDropdown")
		if(panel_bot_difficulty != null){
			var panel_parent = panel_bot_difficulty.GetParent()

			if(panel_parent != null){
				panel_top_bar = panel_parent.GetParent()
				panel = $.CreatePanel("Panel", panel_parent, "")

				// debug
				// $.Msg(panel_top_bar.style.width = true ? "100%" : "600px")

				_HandleScrollBar()

				$.Schedule(0.05, _HandleScrollBar)
				$.Schedule(0.1, _HandleScrollBar)
				$.Schedule(0.2, _HandleScrollBar)

				panel_top_bar.SetPanelEvent("onmouseover", _HandleScrollBar)
				panel_top_bar.SetPanelEvent("onmouseout", _HandleScrollBar)

				if (panel != null) {
					panel.SetParent(panel_parent)

					if (panel.BLoadLayoutFromString(dropdown_layout, false, false)) {
						panel_dropdown = panel.FindChildTraverse("ServerPickerDropdown")

						if(panel_dropdown != null){
							update_visibility_callback = $.RegisterForUnhandledEvent("PanoramaComponent_Lobby_MatchmakingSessionUpdate", _UpdateVisibility)
							_UpdateVisibility()
							_UpdateDropdownHeader()

							datacenters_arr.forEach((id) => {
								var datacenter = datacenters[id]

								var panel_datacenter = $.CreatePanel("Label", panel_dropdown, datacenter.id, {
									text: "",
									style: "padding: 0px 0px 0px 0px; margin: 0px 0px 0px 0px; flow-children: right;"
								})
								panel_datacenter.SetPanelEvent("onactivate", _HandleDatacenterClick.bind(null, datacenter.id))

								let panel_checkbox = $.CreatePanel("Panel", panel_datacenter, "checkbox", {
									class: "fix-scale",
									style: "vertical-align: center; width: 20px; height: 20px; background-size: 20px 20px; border-radius: 2px; border: 1.8px solid white; opacity: 0.8; margin-right: 2px; background-image: url('file://{images}/icons/ui/checkbox.svg'); transition: background-img-opacity 0.1s ease-in-out 0.0s;",
								})

								var panel_img
								if(datacenter.country_code) {
									panel_img = $.CreatePanel("Image", panel_datacenter, "", {
										class: "fix-scale",
										style: "background-color: rgba(0, 0, 0, 0.0); margin: 0px 10px 0px 10px; width: 32px; height: 21px; background-color: black; wash-color: #49494925; saturation: 1.1; border-radius: 3px; border: 1px solid #151515; opacity: 0.8; opacity-mask: url('file://{images}/masks/fade-both-top-bottom.png'); box-shadow: fill #00000080 1px 1px 8px 0px; "
									})

									panel_img.SetImage(_GetRegionImage(datacenter.country_code))
								}

								var panel_name = $.CreatePanel("Label", panel_datacenter, "name", {
									text: datacenter.name,
									style: "letter-spacing: 1px; background-color: rgba(0, 0, 0, 0.0); padding: 10px 5px 10px 0px; margin: 0;"
								})

								panel_datacenter.GetChild(0).style.marginLeft = "25px;"

								var panel_pings = $.CreatePanel("Panel", panel_datacenter, "pings", {
									class: "fix-scale",
									style: "flow-children: down; vertical-align: center; horizontal-align: right; padding: 0; margin: 0;"
								})

								// lines for extra info
								$.CreatePanel("Label", panel_pings, "line-1", {
									text: "500ms",
									style: "text-align: right; horizontal-align: right; margin: 0; padding: 0; font-size: 11; font-family: Stratum2 Regular; letter-spacing: 1px; background-color: rgba(0, 0, 0, 0.0); color: rgba(200, 200, 200, 0.5); margin-right: 18px;"
								})

								$.CreatePanel("Label", panel_pings, "line-2", {
									text: "500ms",
									style: "text-align: right; horizontal-align: right; margin: 0; padding: 0; font-size: 11; font-family: Stratum2 Regular; letter-spacing: 1px; background-color: rgba(0, 0, 0, 0.0); color: rgba(200, 200, 200, 0.6) padding-top: 1px; margin-right: 18px;"
								})

								panel_dropdown.AddOption(panel_datacenter)
							})

							_UpdateDropdownItems()

							panel_dropdown.SetPanelEvent("onmouseover", function(){
								popup_open = true
								_UpdatePopup()

								_UpdateDropdownItems()
							})

							panel_dropdown.SetPanelEvent("onmouseout", function(){
								popup_open = false
								UiToolkitAPI.HideTextTooltip()

								_UpdateDropdownItems()
							})
						}
					}
				}
			}
		} else {
			return false
		}

		return true
	}

	var _UpdateDropdownHeader = function(){
		var el = panel_dropdown.GetChild(0)
		if(el) {
			el.text = ""

			el.Children().forEach((child) => {
				child.visible = false
				child.DeleteAsync(0.0)
			})

			var container = $.CreatePanel("Panel", el, "", {
				class: "left-right-flow",
				style: "height: 100%;"
			})

			if(ping_measurement) {
				var spinner = $.CreatePanel("Panel", container, "", {
					class: "Spinner",
					style: "margin-right: 5px; max-height: 25px; opacity: 0.8;"
				})
			}

			var header = $.CreatePanel("Panel", container, "", {
				class: "left-right-flow",
				style: "padding-top: 3px; padding: 0 0 0 0; margin: 0 0 0 0;"
			})

			var panel_images = $.CreatePanel("Panel", header, "", {
				style: "margin: 0 0 0 0; flow-children: none; vertical-align: top; horizontal-align: center; overflow: noclip;"
			})

			var panel_label = $.CreatePanel("Label", header, "", {
				style: "margin: 0 0 0 0; padding: 0 0 0 0; text-transform: none; font-family: stratum2Font; letter-spacing: 0px; max-width: 280px; text-overflow: ellipsis;",
			})

			if(datacenters_active.length == 0) {
				panel_label.text = "Select matchmaking region"
				panel_dropdown.style.opacity = 0.44
			} else {
				panel_label.text = datacenters_arr.filter(id => datacenters_active.includes(id)).map(id => datacenters[id].name).join(", ")
				panel_dropdown.style.opacity = 1.0

				var seen = {}
				var count = 0
				datacenters_arr.filter(id => datacenters_active.includes(id)).forEach(id => {
					var datacenter = datacenters[id]
					if(datacenter.country_code in seen)
						return

					if(count >= 3)
						return

					seen[datacenter.country_code] = true
					var panel_img = $.CreatePanel("Image", panel_images, "", {
						class: "left-right-flow",
						style: "margin-right: 8px; width: 40px; height: 25px; box-shadow: fill #00000080 1px 1px 8px 0px; border-radius: 2px; brightness: 0.9;"
					})
					panel_img.style.marginLeft = count*6 + "px"
					panel_img.style.marginTop = count*6 + "px"

					panel_img.SetImage(_GetRegionImage(datacenter.country_code))
					count++
				})
				panel_images.style.marginTop = -count*3 + "px"
			}
		}
	}

	var _UpdateVisibility = function(){
		if(panel_dropdown != null){
			var settings = LobbyAPI.GetSessionSettings()
			panel_dropdown.visible = (settings && settings.options && settings.options.server == "official") == true
		}
	}

	var _UpdateDropdownItems = function(){
		var dropdown_menu = panel_dropdown.AccessDropDownMenu()

		if(!dropdown_menu)
			return

		var uiscale_def = `${(dropdown_menu.actualuiscale_x*100).toFixed(3)}%`
		var uiscale_inv = `${((1/dropdown_menu.actualuiscale_x)*100).toFixed(3)}%`

		dropdown_menu.Children().forEach((child) => {
			child.style.uiScaleX = uiscale_inv

			child.FindChildrenWithClassTraverse("fix-scale").forEach((child2) => {
				child2.style.uiScaleX = uiscale_def
			})

			if(datacenters[child.id]) {
				var dc = datacenters[child.id]

				var line1 = child.FindChildTraverse("line-1")
				var line2 = child.FindChildTraverse("line-2")

				/*
				if(dc.direct != null) {
					line1.visible = true
					line1.text = `${dc.direct}ms`
				} else {
					line1.visible = false
				}

				if(dc.relay != null && dc.relay != dc.id) {
					line2.text = `${dc.relay}: ${dc.indirect}ms`
					line2.visible = true
					line1.style.verticalAlign = "top"
				} else {
					line2.visible = false
					line1.style.verticalAlign = "center"
				}
				*/

				line1.text = `${Math.min(dc.direct || dc.indirect, dc.indirect || 99999)}ms`
				line1.style.verticalAlign = "center"
				line1.visible = true

				if(dc.time_offset != null) {
					var now = new Date()
					var offset_to_local = dc.time_offset + now.getTimezoneOffset() * 60
					var time = new Date(now.getTime() + offset_to_local * 1000)
					line2.text = `${time.getHours().toString().padStart(2, "0")}:${time.getMinutes().toString().padStart(2, "0")}`
				} else {
					line2.text = ""
				}
				line2.visible = true

				var panel_checkbox = child.FindChildTraverse("checkbox")
				if(panel_checkbox) {
					panel_checkbox.style.backgroundImgOpacity = datacenters_active.includes(child.id) ? "1" : "0"
					// panel_checkbox.style.backgroundImage = datacenters_active.includes(child.id) ? `url("file://{images}/icons/ui/checkbox.svg");` : null
				}
			}
		})
	}

	var _UpdatePopup = function() {
		var text = []
		var active = _GetActiveDatacenters()

		if(active.length > 0) {
			text.push(active.length > 1 ? `Current matchmaking regions:` : `Current matchmaking region:`)
			active.forEach((id) => {
				var datacenter = datacenters[id]
				text.push(`${datacenter.name} (${datacenter.id}, ${datacenter.direct || datacenter.indirect}ms)`)
			})
		} else {
			text.push("Select matchmaking region")
		}

		if(ping_measurement)
			text.push("\nPing measurement in progress...")

		UiToolkitAPI.ShowTextTooltip("ServerPickerDropdown", text.join("\n"))
	}

	var _GetActiveDatacenters = function(){
		return datacenters_active
	}

	var _SetActiveDatacenters = function(datacenters_active_){
		datacenters_active = datacenters_active_
		if(panel_dropdown != null){
			panel_dropdown.SetSelected(datacenters_active[0] || datacenters_arr[0])

			_UpdateDropdownItems()
			_UpdateDropdownHeader()
		}
	}

	var _Destroy = function(){
		if(panel_top_bar != null) {
			panel_top_bar.ClearPanelEvent("onmouseover")
			panel_top_bar.ClearPanelEvent("onmouseout")

			panel_top_bar.style.overflow = "squish squish"
		}
		if(panel != null) {
			// panel.GetParent().GetParent().style.overflow = "squish squish"

			panel.RemoveAndDeleteChildren()
			panel.DeleteAsync(0.0)
			panel = null
		}
		if(update_visibility_callback != null) {
			$.UnregisterForUnhandledEvent("PanoramaComponent_Lobby_MatchmakingSessionUpdate", update_visibility_callback)
			update_visibility_callback = null
		}
	}

	var _GetLauncherType = function(){
		return MyPersonaAPI.GetLauncherType()
	}

	var _SetVisible = function(visible){
		if(panel != null) {
			panel.visible = visible
		}
	}

	var _StopSearch = function(reason) {
		var is_searching = PartyListAPI.GetPartySessionSetting("game/mmqueue") == "searching"

		if(is_searching)
			LobbyAPI.StopMatchmaking()

		if(reason != null) {
			UiToolkitAPI.ShowGenericPopupOk(
				"MM Region Selector Error",
				`Failed to force region!\n\n${reason}\n\n${is_searching ? "The search has been stopped.\n" : ""}If this error persists, please disable the lua script.`,
				"",
				() => {
					UiToolkitAPI.CloseAllVisiblePopups()
				}
			)
		}
	}

	return {
		create: _Create,
		destroy: _Destroy,
		get_active_datacenters: _GetActiveDatacenters,
		set_active_datacenters: _SetActiveDatacenters,
		get_launcher_type: _GetLauncherType,
		set_datacenters: _SetDatacenters,
		set_layouts: _SetLayouts,
		set_visible: _SetVisible,
		stop_search: _StopSearch,
	}
]], "CSGOMainMenu")()
local panorama_layout = [[
	<root>
		<styles>
			<include src="file://{resources}/styles/csgostyles.css" />
		</styles>
		<Panel>
			<DropDown class="PopupButton White hidden" id="ServerPickerDropdown" menuclass="DropDownMenu" style="margin-right: -2px; text-align: right;">
				<Label text="No forced region" id="" style="visibility: collapse;"/>
			</DropDown>
		</Panel>
	</root>
]]

client.set_event_callback("paint_ui", request_config_on_first_paint)
