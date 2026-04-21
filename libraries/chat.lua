local ffi = require("ffi")
local gsub = string.gsub
local pairs = pairs

local color_codes = {
	["{darkred}"] = "",
	["â€©"] = "",
	["{white}"] = "",
	["â€®"] = "",
	["{orange}"] = "",
	["%%"] = "%%%%",
	["{lightred}"] = "",
	["{violet}"] = "",
	["{purple}"] = "\r",
	["{darkblue}"] = "",
	["{blue}"] = "",
	["{bluegrey}"] = "\n",
	["{yellow}"] = "\t",
	["{grey}"] = "",
	["{red}"] = "",
	["{lime}"] = "",
	["{lightgreen}"] = "",
	["{green}"] = "",
	["{team}"] = "",
	["  +"] = function(space_count)
		return " " .. (" "):rep(space_count:len() - 1)
	end
}

local function resolve_signature(module_name, pattern, cast_type, offset, dereference_count)
	local address = client.find_signature(module_name, pattern) or error("signature not found", 2)

	if offset ~= nil and offset ~= 0 then
		address = ffi.cast("uintptr_t", address) + offset
	end

	if dereference_count ~= nil then
		for _ = 1, dereference_count do
			address = ffi.cast("uintptr_t*", address)[0]

			if address == nil then
				return error("signature not found", 2)
			end
		end
	end

	return ffi.cast(cast_type, address)
end

local function join_values(values, separator)
	local result = ""

	for index = 1, #values do
		result = result .. tostring(values[index]) .. (index == #values and "" or separator)
	end

	return result
end

local chat_printf = vtable_thunk(27, "void(__cdecl*)(void*, int, int, const char*, ...)")
local find_hud_element = resolve_signature("client.dll", "U\\x8b\\xecS\\x8b]\8VW\\x8b\\xf93\\xf69w(", "void***(__thiscall*)(void*, const char*)")
local hud_manager = resolve_signature("client.dll", "\\xb9\\xcc\\xcc\\xcc̈F\t", "void*", 1, 1)

if find_hud_element(hud_manager, "CHudChat") == nil then
	error("CHudChat not found")
end

local chat_hud = find_hud_element(hud_manager, "CCSGO_HudChat") or error("CCSGO_HudChat not found")

local chat_open_state = ffi.cast("bool*", chat_hud) + 88

return {
	print = function(...)
		return chat_printf(0, ...)
	end,
	print_player = function(player_index, ...)
		local message_parts = player_index == 0 and { " ", ... } or { ... }
		local message = join_values(message_parts, "")

		for pattern, replacement in pairs(color_codes) do
			message = gsub(message, pattern, replacement)
		end

		chat_printf(chat_hud, player_index, 0, message)
	end,
	is_open = function()
		return chat_open_state[0]
	end
}
