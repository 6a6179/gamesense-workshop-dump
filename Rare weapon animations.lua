local bit_band = bit.band
local get_local_player = entity.get_local_player
local get_prop = entity.get_prop
local is_alive = entity.is_alive
local set_prop = entity.set_prop
local weapons = require("gamesense/csgo_weapons")

local rare_animation_sets = {
	{
		weapon = weapons.weapon_knife_butterfly,
		overrides = {
			[0] = 0,
			[13.0] = 15,
			[14.0] = 15
		}
	},
	{
		weapon = weapons.weapon_knife_falchion,
		overrides = {
			[12.0] = 13
		}
	},
	{
		weapon = weapons.weapon_knife_ursus,
		overrides = {
			[0] = 1,
			[14.0] = 13
		}
	},
	{
		weapon = weapons.weapon_knife_stiletto,
		overrides = {
			[13.0] = 12
		}
	},
	{
		weapon = weapons.weapon_knife_widowmaker,
		overrides = {
			[14.0] = 15
		}
	},
	{
		weapon = weapons.weapon_knife_skeleton,
		overrides = {
			[0] = 1,
			[13.0] = 14
		}
	},
	{
		weapon = weapons.weapon_knife_canis,
		overrides = {
			[0] = 1,
			[14.0] = 13
		}
	},
	{
		weapon = weapons.weapon_knife_cord,
		overrides = {
			[0] = 1,
			[14.0] = 13
		}
	},
	{
		weapon = weapons.weapon_knife_outdoor,
		overrides = {
			[14.0] = 13
		},
		overrides_durations = {
			[1.0] = 4
		}
	},
	{
		weapon = weapons.weapon_deagle,
		overrides = {
			[7.0] = 8
		}
	},
	{
		weapon = weapons.weapon_revolver,
		overrides = {
			[3.0] = 4
		}
	}
}

local function build_name_lookup(values)
	local lookup = {}
	for index = 1, #values do
		lookup[values[index]] = true
	end
	return lookup
end

local function build_option_names()
	local names = {}
	for index = 1, #rare_animation_sets do
		names[index] = rare_animation_sets[index].weapon.name
	end
	return names
end

local function clear_table_values(target)
	for key in pairs(target) do
		target[key] = nil
	end
end

local enabled_checkbox = ui.new_checkbox("SKINS", "Model options", "Rare weapon animations")
local weapon_selector = ui.new_multiselect("SKINS", "Model options", "\nActive rare animations", table.unpack(build_option_names()))
local active_overrides = {}

local function apply_selected_overrides()
	clear_table_values(active_overrides)

	local selected_names = build_name_lookup(ui.get(weapon_selector))
	for index = 1, #rare_animation_sets do
		local weapon_set = rare_animation_sets[index]
		if selected_names[weapon_set.weapon.name] then
			active_overrides[weapon_set.weapon.idx] = active_overrides[weapon_set.weapon.idx] or {}
			for sequence, replacement in pairs(weapon_set.overrides) do
				active_overrides[weapon_set.weapon.idx][sequence] = replacement
			end
		end
	end
end

ui.set_visible(weapon_selector, false)

ui.set_callback(enabled_checkbox, function()
	local enabled = ui.get(enabled_checkbox)
	ui.set_visible(weapon_selector, enabled)
	if not enabled then
		clear_table_values(active_overrides)
	else
		apply_selected_overrides()
	end
end)

ui.set_callback(weapon_selector, apply_selected_overrides)

client.set_event_callback("net_update_start", function()
	if not ui.get(enabled_checkbox) then
		return
	end

	local local_player = get_local_player()
	if local_player == nil or not is_alive(local_player) then
		return
	end

	local view_model = get_prop(local_player, "m_hViewModel[0]")
	if view_model == nil then
		return
	end

	local weapon_handle = get_prop(view_model, "m_hWeapon")
	if weapon_handle == nil then
		return
	end

	local item_definition_index = bit_band(get_prop(weapon_handle, "m_iItemDefinitionIndex") or 0, 65535)
	local sequence_overrides = active_overrides[item_definition_index]
	if sequence_overrides == nil then
		return
	end

	local current_sequence = get_prop(view_model, "m_nSequence")
	local replacement_sequence = sequence_overrides[current_sequence]
	if replacement_sequence ~= nil then
		set_prop(view_model, "m_nSequence", replacement_sequence)
	end
end)
