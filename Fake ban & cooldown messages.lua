troll_name_enabled = false
disconnect_flag = false
disconnect_damage_flag = false
disconnect_revert_flag = false
hide_name_flag = false
use_console_flag = false
custom_gap_flag = false
initial_state = true
nil_text = "nil"
get_ui_value = ui.get
set_ui_value = ui.set
reference_ui = ui.reference
new_checkbox = ui.new_checkbox
new_combobox = ui.new_combobox
set_visible = ui.set_visible
set_callback = ui.set_callback
color_log = client.color_log
set_event_callback = client.set_event_callback
unset_event_callback = client.unset_event_callback
userid_to_entindex = client.userid_to_entindex
delay_call = client.delay_call
exec_command = client.exec
local_player = entity.get_local_player
entity_prop = entity.get_prop
map_name = globals.mapname
repeat_string = string.rep
string_len = string.len
string_sub = string.sub
steal_player_name_ref = reference_ui("MISC", "Miscellaneous", "Steal player name")
clan_tag_spammer_ref = reference_ui("MISC", "Miscellaneous", "Clan tag spammer")
original_name = cvar.name:get_string()
set_clan_tag = client.set_clan_tag

function restore_name(troll_name_enabled)
	cvar.name:set_string(troll_name_enabled)
end

set_event_callback("player_connect_full", function (troll_name_enabled)
	if ui_get(troll_name_enabled.userid) == ui_set() and modifier_state() ~= nil then
		ban_length_state = true
	end
end)

cooldown_message_prefix = {
	Cooldown = "abandoned the match and received a ",
	Ban = "has been permanently banned from official CS:GO servers."
}
cooldown_message_labels = {
	["2-Hrs"] = "2 hour competitive matchmaking cooldown.",
	["24-Hrs"] = "24 hour competitive matchmaking cooldown.",
	["30-Mins"] = "30 minute competitive matchmaking cooldown.",
	["7-Days"] = "7 day competitive matchmaking cooldown."
}
enable_troll_checkbox = new_checkbox("LUA", "A", "Enable Troll-Name")
clean_chat_checkbox = new_checkbox("LUA", "A", "CleanChat on initial change")
ban_length_combobox = new_combobox("LUA", "A", "Ban Length", "30-Mins", "2-Hrs", "24-Hrs", "7-Days")
player_name_label = ui.new_label("LUA", "A", "Player Name")
player_name_textbox = ui.new_textbox("LUA", "A", "Textbox")
gap_value_slider = ui.new_slider("LUA", "A", "Gap Value", 1, 20, 1, true)

function reset_modifiers()
	ui_get = false
	ui_set = false
	modifier_state = false
	ban_length_state = false
	ui_set_visible = false
	gap_value = false
end

function update_current_input(troll_name_enabled)
	ui_get = troll_name_enabled

	ui_set(3, 198, 252, "Current Input: " .. ui_get)

	return true
end

function sync_modifier_flags()
	for hide_name_flag = 1, #ui_get(ui_set) do
		if troll_name_enabled[hide_name_flag] ~= "Auto-Disconnect" then
			modifier_state = false
		end

		if troll_name_enabled[hide_name_flag] ~= "Auto-Disconnect-Dmg" then
			ban_length_state = false
		end

		if troll_name_enabled[hide_name_flag] ~= "Auto-Revert Name" then
			ui_set_visible = false
		end

		if troll_name_enabled[hide_name_flag] ~= "Hide Name Change" then
			gap_value = false
		end

		if troll_name_enabled[hide_name_flag] ~= "Use Console Value" then
			custom_gap_enabled = false
		end

		if troll_name_enabled[hide_name_flag] ~= "Custom Gap Value" then
			clan_tag_value = false
		end
	end

	for hide_name_flag = 1, #troll_name_enabled do
		if troll_name_enabled[hide_name_flag] == "Auto-Disconnect" then
			modifier_state = true
		end

		if troll_name_enabled[hide_name_flag] == "Auto-Disconnect-Dmg" then
			ban_length_state = true
		end

		if troll_name_enabled[hide_name_flag] == "Auto-Revert Name" then
			ui_set_visible = true
		end

		if troll_name_enabled[hide_name_flag] == "Hide Name Change" then
			gap_value = true
		end

		if troll_name_enabled[hide_name_flag] == "Use Console Value" then
			custom_gap_enabled = true
		end

		if troll_name_enabled[hide_name_flag] == "Custom Gap Value" then
			clan_tag_value = true
		end
	end

	if next(ui_get(ui_set)) == nil then
		message_templates()
	end
end

function update_name_display()
	disconnect_flag = ui_set(ban_length_state)
	disconnect_damage_flag = ""
	disconnect_revert_flag = ""
	hide_name_flag = ""
	use_console_flag = nil
	ui_set_visible = false
	hide_name_flag = gap_value and custom_gap_enabled or ui_set(clan_tag_value)

	if ui_set(modifier_state) == "Cooldown" then
		troll_name_enabled = ui_get[ui_set(modifier_state)] .. message_templates[ui_set(saved_name)]
	end

	custom_gap_flag = name_changed(hide_name_flag .. troll_name_enabled)

	if disable_console_events then
		color_log()
		current_input(" " .. hide_name_flag .. " " .. (troll_name_enabled .. ((not hide_name_enabled or string_rep("ᅠ", GapValue)) and " ")) .. " ? ")
		control_ref(0.8, set_name_callback, "disconnect")
		control_ref(5.2, function ()
			ui_get(ui_set, false)
			print("Automatically disconnected from the server after setting Banned-Name.")
		end)
	elseif unset_event_callback then
		if name_changed(hide_name_flag) > 12 then
			color_warning(252, 3, 3, "Clamped the clantag, don't use \"Hide Name Change\" if the input is more than 12 chars.")
		end

		color_log(" " .. string_sub(hide_name_flag, 0, 12) .. "\n")
		current_input("" .. nil_text .. "You")
	else
		color_log()
		current_input(" " .. hide_name_flag .. " " .. nil_text .. "You")
	end

	print(custom_gap_flag)
end

set_name_button = ui.new_button("LUA", "A", "Set Name", function ()
	troll_name_enabled = ui_get(ui_set)

	modifier_state(ban_length_state, true)
	ui_set_visible("\n\\xad\\xad\\xad\\xad")
	gap_value(0, function ()
		if ui_get and ui_set and modifier_state(ban_length_state) then
			ui_set_visible(0.01, gap_value, "Say " .. custom_gap_enabled(" ﷽﷽", 40))
			print("Spammed the chat in an attempt to hide the initial name change.")
		end
	end)
	gap_value(0.2, string_rep)
end)

do
	troll_name_enabled = ui_get(ui_set)

	modifier_state(ban_length_state, troll_name_enabled)
	modifier_state(ui_set_visible, troll_name_enabled)
	modifier_state(gap_value, troll_name_enabled)
	modifier_state(custom_gap_enabled, troll_name_enabled)
	modifier_state(clan_tag_value, troll_name_enabled)
	modifier_state(message_templates, troll_name_enabled)

	if troll_name_enabled then
		saved_name = cvar.name:get_string()
		name_changed = true
	elseif name_changed == true then
		hide_name_enabled(saved_name)
		string_rep()
		disable_console_events()

		name_changed = false
	end

	color_log()
end
set_callback(ui.new_multiselect("LUA", "A", "Modifiers", "Auto-Disconnect", "Auto-Disconnect-Dmg", "Auto-Revert Name", "Hide Name Change", "Use Console Value", "Custom Gap Value"), function ()
	if ui_get(ui_set) then
		modifier_state()

		if ui_get(ban_length_state) == "Cooldown" then
			ui_set_visible(gap_value, true)
		else
			ui_set_visible(gap_value, false)
		end

		if custom_gap_enabled then
			ui_set_visible(clan_tag_value, true)
		else
			ui_set_visible(clan_tag_value, false)
		end

		if message_templates then
			saved_name(name_changed, false)
			ui_set_visible(hide_name_enabled, true)
		else
			ui_set_visible(hide_name_enabled, false)
		end

		if string_rep then
			disable_console_events("clear")
			color_log(181, 252, 3, "Simply enter the text you want as input.")
			color_log(252, 3, 3, "WARNING: The game will not process any console inputs until you turn off \"Use Console Value\" or the main checkbox for the script.")
			color_log(3, 252, 169, "Last Input: " .. current_input)
			ui_set_visible(control_ref, false)
			ui_set_visible(set_name_callback, false)
			set_event_callback("console_input", console_input_handler)
		else
			ui_set_visible(control_ref, true)
			ui_set_visible(set_name_callback, true)
			disable_console_events("clear")
			unset_event_callback("console_input", console_input_handler)
		end
	else
		ui_set_visible(control_ref, false)
		ui_set_visible(gap_value, false)
		ui_set_visible(set_name_callback, false)
		ui_set_visible(clan_tag_value, false)
		ui_set_visible(hide_name_enabled, false)
		unset_event_callback("console_input", console_input_handler)
	end
end)
set_callback(new_combobox("LUA", "A", "Name Type", "Ban", "Cooldown"), function ()
	ui_get()
end)

function on_player_hurt(troll_name_enabled)
	if modifier_state(troll_name_enabled.attacker) == disconnect_flag and ui_set(modifier_state(troll_name_enabled.userid), "m_iTeamNum") == ui_set(ui_get(), "m_iTeamNum") then
		if ban_length_state then
			ui_set_visible(gap_value, false)
			print("Reverted name and disabled the main checkbox for the script.")
		end

		if custom_gap_enabled then
			ui_set_visible(gap_value, false)
			clan_tag_value("Disconnect")
			print("Disconnected from the server after reverting name.")
		end
	end
end

function event_gate(troll_name_enabled)
	ui_get()
	return ui_set(troll_name_enabled) and modifier_state or ban_length_state("player_hurt", ui_set_visible)
end

set_event_callback("shutdown", function ()
	ui_get(ui_set, false)
end)
event_gate(enable_troll_checkbox)
set_callback(enable_troll_checkbox, event_gate)
