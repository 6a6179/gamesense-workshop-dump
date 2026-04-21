local syncCallbacksEnabled = false
local hotkeyModeLabels = {
	[0] = "Always on",
	"On hotkey",
	"Toggle",
	"Off hotkey"
}
local weaponTypeNames = {
	"Global",
	"G3SG1 / SCAR-20",
	"SSG 08",
	"AWP",
	"R8 Revolver",
	"Desert Eagle",
	"Pistol",
	"Zeus",
	"Rifle",
	"Shotgun",
	"SMG",
	"Machine gun"
}
local syncKeysCheckbox = ui.new_checkbox("RAGE", "Other", "Sync keys")
local weaponTypeReference = ui.reference("RAGE", "Weapon type", "Weapon type")

local function disableSyncCallbacks()
	syncCallbacksEnabled = false
end

local function enableSyncCallbacks()
	syncCallbacksEnabled = true
end

client.set_event_callback("pre_config_load", disableSyncCallbacks)
client.set_event_callback("pre_config_save", disableSyncCallbacks)
client.set_event_callback("post_config_load", enableSyncCallbacks)
client.set_event_callback("post_config_save", enableSyncCallbacks)

local rageSectionName = "RAGE"
local aimbotTabName = "Aimbot"

for _, hotkeyReference in ipairs({
	select(2, ui.reference("RAGE", "Aimbot", "Enabled")),
	select(2, ui.reference("RAGE", "Aimbot", "Multi-point")),
	select(2, ui.reference("RAGE", "Aimbot", "Minimum damage override")),
	select(1, ui.reference("RAGE", "Aimbot", "Force safe point")),
	select(1, ui.reference("RAGE", "Aimbot", "Force body aim")),
	select(2, ui.reference("RAGE", "Aimbot", "Quick stop")),
	select(2, ui.reference(rageSectionName, aimbotTabName, "Double tap"))
}) do
	if ui.type(hotkeyReference) == "hotkey" then
		ui.set_callback(hotkeyReference, function (changedHotkey)
			if syncCallbacksEnabled and ui.get(syncKeysCheckbox) then
				local _, hotkeyModeIndex, hotkeyKey = ui.get(changedHotkey)

				if hotkeyKey == nil then
					hotkeyKey = 0
				end

				local currentWeaponType = ui.get(weaponTypeReference)

				for _, weaponType in ipairs(weaponTypeNames) do
					ui.set(weaponTypeReference, weaponType)
					ui.set(changedHotkey, hotkeyModeLabels[hotkeyModeIndex])
					ui.set(changedHotkey, nil, hotkeyKey)
				end

				ui.set(weaponTypeReference, currentWeaponType)
			end
		end)
	else
		print("invalid hotkey: ", rageSectionName, " ", aimbotTabName)
	end
end

syncCallbacksEnabled = true
