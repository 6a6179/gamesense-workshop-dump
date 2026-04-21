local weapons = require("gamesense/csgo_weapons")
local team_color_names = {
	[0] = "Yellow",
	"Purple",
	"Green",
	"Blue",
	"Orange",
	[-1.0] = "Grey"
}
local info_spam_delay = 0.8
local damage_taken_by_enemy = {}
local pending_chat_lines = {}
local informant_columns

local function cleanup_last_place_name(place_name)
	return (place_name .. " "):gsub("%u[%l ]", function(match)
		return " " .. match
	end):gsub("^%s+", ""):gsub("%s+$", "")
end

local function is_warmup()
	return entity.get_prop(entity.get_game_rules(), "m_bWarmupPeriod") == 1
end

local function get_color(player_index)
	return entity.get_prop(entity.get_player_resource(), "m_iCompTeammateColor", player_index)
end

local function get_enemies_from_resource()
	local player_resource = entity.get_player_resource()
	local enemies = {}

	for player_index = 0, globals.maxplayers() do
		if entity.get_prop(player_resource, "m_bAlive", player_index) == 1 and entity.get_prop(player_resource, "m_iTeam", player_index) ~= entity.get_prop(entity.get_local_player(), "m_iTeamNum") then
			table.insert(enemies, player_index)
		end
	end

	return enemies
end

local function get_health(player_index)
	return entity.get_prop(player_index, "m_iHealth")
end

local function get_weapon_definition_index(player_index)
	local player_weapon = entity.get_player_weapon(player_index)
	if player_weapon ~= nil then
		return entity.get_prop(player_weapon, "m_iItemDefinitionIndex")
	end

	return nil
end

local function get_last_location(player_index)
	return entity.get_prop(player_index, "m_szLastPlaceName") or "Unknown"
end

local function is_in_table(values, target)
	for index = 1, #values do
		if values[index] == target then
			return true
		end
	end

	return false
end

local function get_informant(player_index)
	return {
		Persona = entity.get_player_name(player_index),
		["Competitive color"] = team_color_names[get_color(player_index)],
		["Damage dealt"] = damage_taken_by_enemy[player_index] ~= nil and "-" .. damage_taken_by_enemy[player_index] .. " HP" or nil,
		Weapon = "Holding the " .. weapons[get_weapon_definition_index(player_index)].name,
		["Current health"] = "Currently has " .. get_health(player_index) .. " HP",
		["Last known location"] = "Last seen @ " .. cleanup_last_place_name(get_last_location(player_index))
	}
end

local function push_to_log(player_index)
	local columns = {}

	for column_name, column_value in pairs(get_informant(player_index)) do
		if column_value ~= nil and is_in_table(ui.get(informant_columns), column_name) then
			table.insert(columns, column_value)
		end
	end

	if #columns > 0 then
		table.insert(pending_chat_lines, table.concat(columns, " | "))
	end
end

local function on_player_death(event)
	if is_warmup() or client.userid_to_entindex(event.userid) ~= entity.get_local_player() or event.attacker == event.userid or event.attacker == 0 then
		return
	end

	local attacker_index = client.userid_to_entindex(event.attacker)
	if attacker_index ~= nil and damage_taken_by_enemy[attacker_index] == nil then
		push_to_log(attacker_index)
	end

	for enemy_index, _ in pairs(damage_taken_by_enemy) do
		if is_in_table(get_enemies_from_resource(), enemy_index) then
			push_to_log(enemy_index)
		end
	end

	for line_index = 1, #pending_chat_lines do
		client.delay_call(line_index * info_spam_delay, client.exec, "say_team ", pending_chat_lines[line_index])
	end
end

local function on_player_spawn(event)
	if client.userid_to_entindex(event.userid) ~= entity.get_local_player() then
		return
	end

	damage_taken_by_enemy = {}
	pending_chat_lines = {}
end

local function on_player_hurt(event)
	if client.userid_to_entindex(event.attacker) ~= entity.get_local_player() then
		return
	end

	local victim_index = client.userid_to_entindex(event.userid)
	if damage_taken_by_enemy[victim_index] == nil then
		damage_taken_by_enemy[victim_index] = 0
	end

	damage_taken_by_enemy[victim_index] = damage_taken_by_enemy[victim_index] + event.dmg_health
end

local function on_informant_ui_callback()
	local set_or_clear_event_callback = #ui.get(informant_columns) > 0 and client.set_event_callback or client.unset_event_callback

	set_or_clear_event_callback("player_death", on_player_death)
	set_or_clear_event_callback("player_spawn", on_player_spawn)
	set_or_clear_event_callback("player_hurt", on_player_hurt)
end

informant_columns = ui.new_multiselect("VISUALS", "Other ESP", "Informant", {
	"Persona",
	"Competitive color",
	"Damage dealt",
	"Weapon",
	"Current health",
	"Last known location"
})
ui.set_callback(informant_columns, on_informant_ui_callback)
on_informant_ui_callback()
