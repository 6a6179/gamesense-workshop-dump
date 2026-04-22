local ui_api = {
	checkbox = ui.new_checkbox,
	slider = ui.new_slider,
	multiselect = ui.new_multiselect,
	combobox = ui.new_combobox,
	label = ui.new_label,
	textbox = ui.new_textbox,
	color_picker = ui.new_color_picker,
	hotkey = ui.new_hotkey,
	set = ui.set,
	get = ui.get,
	ref = ui.reference,
	callback = ui.set_callback,
	visible = ui.set_visible
}

local preset_menu = {
	_debug = false,
	menu = {
		"config",
		"Presets"
	},
	groups = {
		awp = { 9 },
		auto = { 11, 38 },
		scout = { 40 },
		revolver = { 64 },
		deagle = { 1 },
		pistol = { 2, 3, 4, 30, 32, 36, 61, 63 },
		rifle = { 7, 8, 10, 13, 16, 39, 60 },
		smg = { 17, 19, 24, 26, 33, 34 },
		heavy = { 14, 28 },
		shotgun = { 25, 27, 29, 35 }
	}
}

function preset_menu:call(factory, reference_path, ...)
	if factory == nil then
		return nil
	end

	local settings = { ... }
	local label = reference_path[2] or reference_path[1] or ""

	return factory(self.menu[1], self.menu[2], label, table.unpack(settings))
end

local function contains_value(values, needle)
	for index = 1, #values do
		if values[index] == needle then
			return true
		end
	end

	return false
end

local function title_case(text)
	return text:gsub("^%l", string.upper)
end

local function group_name_from_weapon_id(weapon_id)
	for group_name, weapon_ids in pairs(preset_menu.groups) do
		if contains_value(weapon_ids, weapon_id) then
			return title_case(group_name)
		end
	end

	return false
end

local function get_active_weapon_id(player)
	return bit.band(65535, entity.get_prop(entity.get_player_weapon(player), "m_iItemDefinitionIndex"))
end

local separator_label = ui_api.label(preset_menu.menu[1], preset_menu.menu[2], "-------------------------------------------------")
local active_preset_label = preset_menu:call(ui_api.label, { "rcl_active_lbl", "Active preset:" })
local prefix_label = preset_menu:call(ui_api.label, { "rcl_prefix_lbl", "Preset name prefix" })
local prefix_textbox = preset_menu:call(ui_api.textbox, { "rcl_prefix", "preset_name_prefix" })

local weapon_group_labels = {}
for group_name in pairs(preset_menu.groups) do
	table.insert(weapon_group_labels, title_case(group_name))
end
table.sort(weapon_group_labels)

local selected_groups = preset_menu:call(ui_api.multiselect, { "rcl_selected", "Selected weapon groups" }, weapon_group_labels)
local indicator_color = preset_menu:call(ui_api.color_picker, { "rcl_indicator_color", "indicator_color" }, 123, 193, 21, 255)
local disable_weapon_loading = preset_menu:call(ui_api.checkbox, { "rcl_disabled", "Disable weapon based preset loading" })
local show_indicator = preset_menu:call(ui_api.checkbox, { "rcl_indicator", "Indicate current preset name" })

local current_preset_name = nil
local current_weapon_group = nil

local function load_preset(preset_suffix)
	local preset_name = string.format("%s%s", ui_api.get(prefix_textbox), preset_suffix)

	config.load(preset_name)

	current_preset_name = preset_name
	ui_api.set(active_preset_label, string.format("Active preset: %s", preset_name))
end

local function update_loaded_config_state()
	if ui_api.get(disable_weapon_loading) then
		return
	end

	local selected_groups_value = ui_api.get(selected_groups)
	if type(selected_groups_value) ~= "table" then
		selected_groups_value = {}
	end

	local active_group = group_name_from_weapon_id(get_active_weapon_id(entity.get_local_player()))
	if active_group == false then
		return
	end

	if not contains_value(selected_groups_value, active_group) then
		active_group = "global"
	end

	current_weapon_group = active_group
	load_preset(string.lower(current_weapon_group))
end

local function on_weapon_change()
	if not entity.is_alive(entity.get_local_player()) then
		return
	end

	local weapon_group = group_name_from_weapon_id(get_active_weapon_id(entity.get_local_player()))
	if weapon_group == false or weapon_group == current_weapon_group then
		return
	end

	current_weapon_group = weapon_group
	load_preset(string.lower(weapon_group))
end

local function paint_indicator()
	if not ui_api.get(show_indicator) then
		return
	end

	if current_preset_name == nil then
		return
	end

	local red, green, blue, alpha = ui_api.get(indicator_color)
	renderer.indicator(red, green, blue, alpha, string.upper(current_preset_name))
end

local function update_event_callbacks()
	local callback_setter = ui_api.get(disable_weapon_loading) and client.unset_event_callback or client.set_event_callback
	callback_setter("net_update_end", on_weapon_change)
	callback_setter("paint", paint_indicator)
end

update_event_callbacks()

ui_api.callback(disable_weapon_loading, update_event_callbacks)
ui_api.callback(show_indicator, function()
	local controls_visible = ui_api.get(show_indicator)

	ui_api.visible(prefix_label, controls_visible)
	ui_api.visible(prefix_textbox, controls_visible)
	ui_api.visible(selected_groups, controls_visible)
	ui_api.visible(indicator_color, controls_visible)
	ui_api.visible(separator_label, controls_visible)
end)

update_loaded_config_state()
