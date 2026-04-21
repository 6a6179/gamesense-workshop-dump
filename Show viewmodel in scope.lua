local csgo_weapons = require("gamesense/csgo_weapons")
local clear_table = require("table.clear")
local ui_get = ui.get
local hidden_viewmodel_weapon_ids = {}

local function disable_viewmodel_hiding()
	for weapon_id, weapon in pairs(csgo_weapons) do
		if weapon.raw.hide_view_model_zoomed then
			table.insert(hidden_viewmodel_weapon_ids, weapon_id)

			weapon.raw.hide_view_model_zoomed = false
		end
	end
end

local function restore_viewmodel_hiding()
	for index = 1, #hidden_viewmodel_weapon_ids do
		csgo_weapons[hidden_viewmodel_weapon_ids[index]].raw.hide_view_model_zoomed = true
	end

	clear_table(hidden_viewmodel_weapon_ids)
end

local show_viewmodel_in_scope_checkbox = ui.new_checkbox("VISUALS", "Effects", "Show viewmodel in scope")

ui.set_callback(show_viewmodel_in_scope_checkbox, function ()
	if ui_get(show_viewmodel_in_scope_checkbox) then
		disable_viewmodel_hiding()
	else
		restore_viewmodel_hiding()
	end
end)
client.set_event_callback("shutdown", function ()
	restore_viewmodel_hiding()
end)
