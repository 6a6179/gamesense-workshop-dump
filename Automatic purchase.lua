local ui_library = require("gamesense/uilib")
local weapons = require("gamesense/csgo_weapons")

local primary_options = {
	"-",
	"AWP",
	"SCAR20/G3SG1",
	"Scout",
	"M4/AK47",
	"Famas/Galil",
	"Aug/SG553",
	"M249",
	"Negev",
	"Mag7/SawedOff",
	"Nova",
	"XM1014",
	"MP9/Mac10",
	"UMP45",
	"PPBizon",
	"MP7"
}

local secondary_options = {
	"-",
	"CZ75/Tec9/FiveSeven",
	"P250",
	"Deagle/Revolver",
	"Dualies"
}

local grenade_options = {
	"HE Grenade",
	"Molotov",
	"Smoke",
	"Flash",
	"Flash",
	"Decoy"
}

local utility_options = {
	"Armor",
	"Helmet",
	"Zeus",
	"Defuser"
}

local item_prices = {
	["-"] = 0,
	AWP = weapons.weapon_awp.in_game_price,
	["SCAR20/G3SG1"] = weapons.weapon_scar20.in_game_price,
	Scout = weapons.weapon_ssg08.in_game_price,
	["M4/AK47"] = weapons.weapon_m4a1.in_game_price,
	["Famas/Galil"] = weapons.weapon_famas.in_game_price,
	["Aug/SG553"] = weapons.weapon_aug.in_game_price,
	M249 = weapons.weapon_m249.in_game_price,
	Negev = weapons.weapon_negev.in_game_price,
	["Mag7/SawedOff"] = weapons.weapon_mag7.in_game_price,
	Nova = weapons.weapon_nova.in_game_price,
	XM1014 = weapons.weapon_xm1014.in_game_price,
	["MP9/Mac10"] = weapons.weapon_mp9.in_game_price,
	UMP45 = weapons.weapon_ump45.in_game_price,
	PPBizon = weapons.weapon_bizon.in_game_price,
	MP7 = weapons.weapon_mp7.in_game_price,
	["CZ75/Tec9/FiveSeven"] = weapons.weapon_tec9.in_game_price,
	P250 = weapons.weapon_p250.in_game_price,
	["Deagle/Revolver"] = weapons.weapon_deagle.in_game_price,
	Dualies = weapons.weapon_elite.in_game_price,
	["HE Grenade"] = weapons.weapon_hegrenade.in_game_price,
	Molotov = weapons.weapon_molotov.in_game_price,
	Smoke = weapons.weapon_smokegrenade.in_game_price,
	Flash = weapons.weapon_flashbang.in_game_price,
	Decoy = weapons.weapon_decoy.in_game_price,
	Armor = weapons.item_kevlar.in_game_price,
	Helmet = weapons.item_assaultsuit.in_game_price,
	Zeus = weapons.weapon_taser.in_game_price,
	Defuser = weapons.item_cutters.in_game_price
}

local purchase_commands = {
	["MP9/Mac10"] = "buy mp9;",
	XM1014 = "buy xm1014;",
	Nova = "buy nova;",
	["Mag7/SawedOff"] = "buy mag7;",
	Negev = "buy negev;",
	M249 = "buy m249;",
	["Aug/SG553"] = "buy aug;",
	["Famas/Galil"] = "buy famas;",
	["M4/AK47"] = "buy m4a1;",
	Scout = "buy ssg08;",
	["SCAR20/G3SG1"] = "buy scar20;",
	AWP = "buy awp;",
	["-"] = "",
	Zeus = "buy taser;",
	Defuser = "buy defuser;",
	Helmet = "buy vesthelm;",
	Armor = "buy vest;",
	Decoy = "buy decoy;",
	Flash = "buy flashbang;",
	Smoke = "buy smokegrenade;",
	Molotov = "buy molotov;",
	["HE Grenade"] = "buy hegrenade;",
	Dualies = "buy elite;",
	["Deagle/Revolver"] = "buy deagle;",
	P250 = "buy p250;",
	["CZ75/Tec9/FiveSeven"] = "buy tec9;",
	MP7 = "buy mp7;",
	PPBizon = "buy bizon;",
	UMP45 = "buy ump45;"
}

local menu_tab = "MISC"
local menu_section = "Miscellaneous"

local automatic_purchase = ui_library.new_checkbox(menu_tab, menu_section, "Automatic purchase")
local fast_purchase = ui_library.new_checkbox(menu_tab, menu_section, "Fast purchase")
local hide_purchase = ui_library.new_checkbox(menu_tab, menu_section, "Hide purchase")
local cost_based = ui_library.new_checkbox(menu_tab, menu_section, "Cost based")

local purchase_controls = {
	primary = ui_library.new_combobox(menu_tab, menu_section, "Primary", primary_options),
	secondary = ui_library.new_combobox(menu_tab, menu_section, "Secondary", secondary_options),
	grenades = ui_library.new_multiselect(menu_tab, menu_section, "Grenades", grenade_options),
	utilities = ui_library.new_multiselect(menu_tab, menu_section, "Utilities", utility_options)
}

local backup_purchase_controls = {
	primary = ui_library.new_combobox(menu_tab, menu_section, "Backup Primary", primary_options),
	secondary = ui_library.new_combobox(menu_tab, menu_section, "Backup Secondary", secondary_options),
	grenades = ui_library.new_multiselect(menu_tab, menu_section, "Backup Grenades", grenade_options),
	utilities = ui_library.new_multiselect(menu_tab, menu_section, "Backup Utilities", utility_options)
}

local balance_override = ui_library.new_slider(menu_tab, menu_section, "Balance override", 0, 16000, 0, true, "$", 1, {
	[0] = "Auto"
})

local main_grenade_selection_cache = {}
local backup_grenade_selection_cache = {}
local primary_purchase_command = ""
local backup_purchase_command = ""
local primary_purchase_cost = 0
local backup_purchase_cost = 0
local round_reset_in_progress = false
local purchase_pending = false

local function build_purchase_payload(selection_controls)
	local command_parts = {}
	local total_cost = 0

	local function append_choice(choice_name)
		local command = purchase_commands[choice_name] or ""
		local price = item_prices[choice_name] or 0

		if command ~= "" then
			table.insert(command_parts, command)
		end

		total_cost = total_cost + price
	end

	append_choice(selection_controls.secondary.value)

	for _, utility_name in ipairs(selection_controls.utilities.value) do
		append_choice(utility_name)
	end

	append_choice(selection_controls.primary.value)

	for _, grenade_name in ipairs(selection_controls.grenades.value) do
		append_choice(grenade_name)
	end

	return table.concat(command_parts, " "), total_cost
end

local function clamp_multiselect_to_four(widget, previous_value_cache)
	if #widget.value > 4 then
		widget.value = previous_value_cache[widget] or {}
	else
		previous_value_cache[widget] = widget.value
	end
end

local function refresh_purchase_state()
	primary_purchase_command, primary_purchase_cost = build_purchase_payload(purchase_controls)
	backup_purchase_command, backup_purchase_cost = build_purchase_payload(backup_purchase_controls)
end

local function update_visibility()
	local automatic_enabled = automatic_purchase.state
	local fast_purchase_enabled = fast_purchase.state
	local cost_based_enabled = cost_based.state

	fast_purchase.vis = automatic_enabled
	hide_purchase.vis = automatic_enabled
	cost_based.vis = automatic_enabled
	balance_override.vis = automatic_enabled and cost_based_enabled

	for _, widget in pairs(purchase_controls) do
		widget.vis = automatic_enabled
	end

	for _, widget in pairs(backup_purchase_controls) do
		widget.vis = automatic_enabled and not fast_purchase_enabled
	end
end

local function issue_purchase()
	if not automatic_purchase.state then
		return
	end

	local local_player = entity.get_local_player()
	if local_player == nil then
		return
	end

	local account_balance = entity.get_prop(local_player, "m_iAccount") or 0
	local threshold = balance_override.value == 0 and primary_purchase_cost or balance_override.value
	local purchase_command = primary_purchase_command

	if account_balance < threshold and backup_purchase_command ~= "" then
		purchase_command = backup_purchase_command
	end

	if purchase_command == "" then
		return
	end

	purchase_pending = true

	if fast_purchase.state then
		client.exec(purchase_command)
	else
		client.delay_call(0.0001, client.exec, purchase_command)
	end
end

local function on_purchase_tick()
	if not purchase_pending then
		return
	end

	purchase_pending = false
end

automatic_purchase:add_callback(update_visibility)
fast_purchase:add_callback(update_visibility)
hide_purchase:add_callback(update_visibility)
cost_based:add_callback(update_visibility)

purchase_controls.grenades:add_callback(function(widget)
	clamp_multiselect_to_four(widget, main_grenade_selection_cache)
end)
backup_purchase_controls.grenades:add_callback(function(widget)
	clamp_multiselect_to_four(widget, backup_grenade_selection_cache)
end)

for _, widget in pairs(purchase_controls) do
	widget:add_callback(refresh_purchase_state)
end

for _, widget in pairs(backup_purchase_controls) do
	widget:add_callback(refresh_purchase_state)
end

refresh_purchase_state()
update_visibility()

automatic_purchase:add_event_callback("enter_buyzone", function(event)
	if not round_reset_in_progress and client.userid_to_entindex(event.userid) == entity.get_local_player() and event.canbuy then
		issue_purchase()
	end
end)

automatic_purchase:add_event_callback("cs_pre_restart", function()
	round_reset_in_progress = true
	purchase_pending = false

	if automatic_purchase.state then
		client.delay_call(0.3 - (client.latency() + totime(8)), client.exec, primary_purchase_command)
	end
end)

automatic_purchase:add_event_callback("round_poststart", function()
	round_reset_in_progress = false

	if not hide_purchase.state then
		client.delay_call(0, on_purchase_tick)
	end
end)

automatic_purchase:add_event_callback("player_spawn", function(event)
	if not round_reset_in_progress and client.userid_to_entindex(event.userid) == entity.get_local_player() then
		issue_purchase()
	end
end)

automatic_purchase:add_event_callback("net_update_end", on_purchase_tick)
automatic_purchase:invoke()
