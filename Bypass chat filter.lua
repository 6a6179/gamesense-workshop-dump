local ffi = require("ffi")
local steamworks = require("gamesense/steamworks")
local wide_char_buffer = ffi.typeof("char[?]")
local steam_utils_message_filter = vtable_thunk(32, "int(__thiscall*)(void*, char*, uint32_t, const char*, bool)")
local steam_utils = vtable_bind("steamclient.dll", "SteamClient017", 9, "uintptr_t*(__thiscall*)(void*, int, const char*)")(1, "SteamUtils009")

if steam_utils == nil then
	return error("failed to get ISteamUtils")
end

local function convert_message(text, preserve_control_characters)
	local length = #text + 1
	local buffer = wide_char_buffer(length)

	return ffi.string(buffer, length - 1), steam_utils_message_filter(steam_utils, buffer, length, text, preserve_control_characters)
end

local bypass_chat_filter = ui.new_checkbox("LUA", "B", "Bypass Chat Filter")
local replacement_map = {
	B = "á¸‚",
	h = "á¸¥",
	i = "Ä¯",
	P = "á¹–",
	b = "á¸ƒ",
	p = "á¹—",
	A = "È¦",
	O = "È®",
	q = "É‹",
	o = "È¯",
	Q = "ÉŠ",
	N = "á¹†",
	r = "á¹›",
	R = "á¹š",
	M = "á¹‚",
	s = "á¹£",
	m = "á¹ƒ",
	S = "á¹¢",
	L = "á¸¶",
	t = "á¹­",
	l = "á¸·",
	T = "á¹¬",
	z = "áº“",
	Z = "áº’",
	n = "á¹‡",
	Y = "á»´",
	y = "á»µ",
	X = "áºŠ",
	G = "Ä ",
	x = "áº‹",
	g = "Ä¡",
	W = "áºˆ",
	F = "á¸ž",
	w = "áº‰",
	f = "á¸Ÿ",
	V = "á¹¾",
	E = "áº¸",
	v = "á¹¿",
	e = "áº¹",
	U = "á»¤",
	D = "á¸Œ",
	u = "á»¥",
	d = "á¸",
	K = "á¸²",
	C = "ÄŠ",
	k = "á¸³",
	c = "Ä‹",
	J = "Ä´",
	j = "Äµ",
	I = "Ä®",
	a = "È§",
	H = "á¸¤"
}
local zero_width_joiner = "â€Œâ€‹"
local non_breaking_space = "Â "
local panorama_api = panorama.open()
local my_persona_api = panorama_api.MyPersonaAPI
local party_list_api = panorama_api.PartyListAPI

local function send_party_chat(message)
	local normalized_words = {}

	for word in message:gmatch("[^%s]+") do
		local _, converted_length = convert_message(word, false)

		if converted_length > 0 and #word > 1 then
			word = word:sub(1, 2) .. (replacement_map[word:sub(3, 3)] or zero_width_joiner) .. word:sub(4, -1)
		end

		table.insert(normalized_words, word)
	end

	party_list_api.SessionCommand("Game::Chat", string.format("run all xuid %s chat %s", my_persona_api.GetXuid(), table.concat(normalized_words, non_breaking_space)))
end

client.set_event_callback("console_input", function(input_text)
	if input_text:sub(1, #"party_say") == "party_say" then
		send_party_chat(input_text:sub(#"party_say" + 2, -1))

		return true
	end
end)

client.set_event_callback("string_cmd", function(command)
	if not ui.get(bypass_chat_filter) then
		return
	end

	local command_name, chat_message = command.text:match("^(.-) (.+)$")

	if (command_name == "say" or command_name == "say_team") and chat_message ~= nil then
		local should_rewrite = false
		local rewritten_words = {}

		if chat_message:find("\"", 1) and chat_message:find("\"", -1) then
			chat_message = chat_message:sub(2, -2)
		end

		for word in chat_message:gmatch("[^%s]+") do
			local _, converted_length = convert_message(word, false)

			if converted_length > 0 and #word > 1 then
				should_rewrite = true
				local replacement_index = #word > 2 and 3 or 2
				word = word:sub(1, replacement_index - 1) .. (replacement_map[word:sub(replacement_index, replacement_index)] or zero_width_joiner) .. word:sub(replacement_index + 1, -1)
			end

			table.insert(rewritten_words, word)
		end

		if should_rewrite then
			command.text = command_name .. " " .. table.concat(rewritten_words, " ")
		end
	end
end)
