local weapons = require("gamesense/csgo_weapons")
local panorama_api = panorama.open()
local loadout_api = panorama_api.LoadoutAPI
local inventory_api = panorama_api.InventoryAPI
local heavy_pistol_definitions = {
	["Desert Eagle"] = weapons.weapon_deagle.idx,
	["R8 Revolver"] = weapons.weapon_revolver.idx
}
local teams = {
	"ct",
	"t"
}

local function get_equipped_definition_index(definition_index, team_id)
	local faux_item_id = loadout_api.GetFauxItemIDFromDefAndPaintIndex(definition_index)
	local slot_sub_position = loadout_api.GetSlotSubPosition(faux_item_id)

	return loadout_api.GetItemDefinitionIndex(inventory_api.GetItemID(team_id, slot_sub_position))
end

local function equip_definition_for_team(definition_index, team_id)
	local faux_item_id = loadout_api.GetFauxItemIDFromDefAndPaintIndex(definition_index)

	inventory_api.EquipItemInSlot(team_id, faux_item_id, loadout_api.GetSlotSubPosition(faux_item_id))
end

local heavy_pistol_menu = ui.new_combobox("MISC", "Miscellaneous", "Auto-equip Heavy Pistol", {
	"Off",
	"Desert Eagle",
	"R8 Revolver"
})

ui.set_callback(heavy_pistol_menu, function ()
	local selected_definition_index = heavy_pistol_definitions[ui.get(heavy_pistol_menu)]

	if selected_definition_index ~= nil then
		for _, team_id in ipairs(teams) do
			if get_equipped_definition_index(selected_definition_index, team_id) ~= selected_definition_index then
				equip_definition_for_team(selected_definition_index, team_id)
			end
		end
	end
end)
