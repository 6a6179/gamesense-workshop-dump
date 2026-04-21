local panoramaAPI = panorama.open()
local gameStateAPI = panoramaAPI.GameStateAPI
local friendsListAPI = panoramaAPI.FriendsListAPI
local cyrillicCharacters = {
	"Ð",
	"Ð‘",
	"Ð’",
	"Ð“",
	"Ð”",
	"Ð•",
	"Ð",
	"Ð–",
	"Ð—",
	"Ð˜",
	"Ð™",
	"Ðš",
	"Ð›",
	"Ðœ",
	"Ð",
	"Ðž",
	"ÐŸ",
	"Ð ",
	"Ð¡",
	"Ð¢",
	"Ð£",
	"Ð¤",
	"Ð¥",
	"Ð¦",
	"Ð§",
	"Ð¨",
	"Ð©",
	"Ðª",
	"Ð«",
	"Ð¬",
	"Ð­",
	"Ð®",
	"Ð¯",
	"Ð°",
	"Ð±",
	"Ð²",
	"Ð³",
	"Ð´",
	"Ðµ",
	"Ñ‘",
	"Ð¶",
	"Ð·",
	"Ð¸",
	"Ð¹",
	"Ðº",
	"Ð»",
	"Ð¼",
	"Ð½",
	"Ð¾",
	"Ð¿",
	"Ñ€",
	"Ñ",
	"Ñ‚",
	"Ñ„",
	"Ñ…",
	"Ñ†",
	"Ñ‡",
	"Ñˆ",
	"Ñ‰",
	"ÑŠ",
	"Ñ‹",
	"ÑŒ",
	"Ñ",
	"ÑŽ",
	"Ñ"
}
local responseModes = ui.new_multiselect("lua", "a", "If cyrillic is found:", "Mute", "Report")

local function containsValue(values, needle)
	for index = 1, #values do
		if values[index] == needle then
			return true
		end
	end

	return false
end

local function handleChattyEnemy(xuid, playerName)
	if containsValue(ui.get(responseModes), "Report") then
		gameStateAPI.SubmitPlayerReport(xuid, "textabuse, voiceabuse")
		print("Enemy reported, " .. playerName .. " " .. xuid)
	elseif containsValue(ui.get(responseModes), "Mute") then
		friendsListAPI.ToggleMute(xuid)
		print("Enemy muted, " .. playerName .. " " .. xuid)
	end
end

client.set_event_callback("player_chat", function (chatEvent)
	if chatEvent.entity == entity.get_local_player() then
		return
	end

	for _, cyrillicCharacter in pairs(cyrillicCharacters) do
		if string.find(chatEvent.text, cyrillicCharacter) then
			handleChattyEnemy(gameStateAPI.GetPlayerXuidStringFromEntIndex(chatEvent.entity), chatEvent.name)
		end
	end
end)
