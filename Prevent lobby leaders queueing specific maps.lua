local panoramaAPI = panorama.open()
local mapGroupNamesBySelection = {
	["Mirage (Scrimmage)"] = "mg_de_mirage_scrimmagemap",
	Swamp = "mg_de_swamp",
	Mutiny = "mg_de_mutiny",
	Cache = "mg_de_cache",
	Anubis = "mg_de_anubis",
	["Dust 2"] = "mg_de_dust2",
	Train = "mg_de_train",
	Nuke = "mg_de_nuke",
	Vertigo = "mg_de_vertigo",
	Lake = "mg_de_lake",
	Overpass = "mg_de_overpass",
	Rialto = "mg_gd_rialto",
	Inferno = "mg_de_inferno",
	["Short Dust"] = "mg_de_shortdust",
	Mirage = "mg_de_mirage",
	["Short Nuke"] = "mg_de_shortnuke",
	Cbble = "mg_de_cbble",
	Office = "mg_cs_office",
	Agency = "mg_cs_agency"
}
local blacklistedMaps = ui.new_multiselect("Config", "Presets", "Blacklisted maps", {
	"Mirage",
	"Inferno",
	"Overpass",
	"Vertigo",
	"Nuke",
	"Train",
	"Dust 2",
	"Anubis",
	"Cache",
	"Mutiny",
	"Swamp",
	"Agency",
	"Office",
	"Cbble",
	"Short Nuke",
	"Short Dust",
	"Rialto",
	"Lake"
})
local autoMessageWhenQueueIsCancelled = ui.new_checkbox("Config", "Presets", "Auto-message when queue is cancelled")
local lastAutoMessageTime = 0

ui.new_button("Config", "Presets", "Stop matchmaking", function ()
	if panoramaAPI.LobbyAPI.IsSessionActive() then
		panoramaAPI.LobbyAPI.StopMatchmaking()
	end
end)

client.set_event_callback("paint_ui", function ()
	if panoramaAPI.LobbyAPI.BIsHost() then
		return
	end

	if panoramaAPI.LobbyAPI.IsSessionActive() == false then
		return
	end

	if panoramaAPI.LobbyAPI.GetMatchmakingStatusString() ~= "#SFUI_QMM_State_find_searching" then
		return
	end

	local sessionSettings = panoramaAPI.LobbyAPI.GetSessionSettings()

	if sessionSettings.game.mapgroupname == nil then
		return
	end

	local blockedMaps = {}

	for _, mapName in pairs(ui.get(blacklistedMaps)) do
		if string.find(sessionSettings.game.mapgroupname, mapGroupNamesBySelection[mapName]) then
			table.insert(blockedMaps, mapName)
		end
	end

	if #blockedMaps == 0 then
		return
	end

	panoramaAPI.LobbyAPI.StopMatchmaking()

	if ui.get(autoMessageWhenQueueIsCancelled) and client.unix_time() - lastAutoMessageTime > 2 then
		lastAutoMessageTime = client.unix_time()

		panoramaAPI.PartyListAPI.SessionCommand("Game::Chat", string.format("run all xuid %s chat %s", panoramaAPI.MyPersonaAPI.GetXuid(), string.format("[AUTO-MESSAGE] The queue was cancelled automatically due to a blacklisted map being selected."):gsub(" ", "\226\128\136")))
		panoramaAPI.PartyListAPI.SessionCommand("Game::Chat", string.format("run all xuid %s chat %s", panoramaAPI.MyPersonaAPI.GetXuid(), string.format("[AUTO-MESSAGE] Please remove: %s.", table.concat(blockedMaps, ", ")):gsub(" ", "\226\128\136")))
	end
end)
