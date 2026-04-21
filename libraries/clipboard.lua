local ffi = require("ffi")
local strlen = string.len
local tostring = tostring
local ffi_string = ffi.string

local get_clipboard_text_length = vtable_bind("vgui2.dll", "VGUI_System010", 7, "int(__thiscall*)(void*)")
local set_clipboard_text = vtable_bind("vgui2.dll", "VGUI_System010", 9, "void(__thiscall*)(void*, const char*, int)")
local get_clipboard_text = vtable_bind("vgui2.dll", "VGUI_System010", 11, "int(__thiscall*)(void*, int, const char*, int)")
local char_buffer_t = ffi.typeof("char[?]")

local clipboard = {}

function clipboard.get()
	local clipboard_length = get_clipboard_text_length()

	if clipboard_length > 0 then
		local buffer = char_buffer_t(clipboard_length)

		get_clipboard_text(0, buffer, clipboard_length)

		return ffi_string(buffer, clipboard_length - 1)
	end
end

clipboard.paste = clipboard.get

function clipboard.set(text)
	text = tostring(text)

	set_clipboard_text(text, strlen(text))
end

clipboard.copy = clipboard.set

return clipboard
