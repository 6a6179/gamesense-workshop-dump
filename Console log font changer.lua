local ffi = require("ffi")

local surface_interface = client.create_interface("vguimatsurface.dll", "VGUI_Surface031")
local create_font = vtable_thunk(71, "unsigned int(__thiscall*)(void*)")
local set_font_glyph_set = vtable_thunk(72, "void(__thiscall*)(void*, unsigned long, const char*, int, int, int, int, unsigned long, int, int)")

local function create_console_font(font_name, font_size)
	local font_handle = create_font(surface_interface)
	set_font_glyph_set(surface_interface, font_handle, font_name, font_size, 400, 0, 0, 16, 0, 65535)
	return font_handle
end

local saved_font_names = database.read("Console_UserDefinedFonts") or {}
local font_handle_cache = {}
local selected_console_font = nil
local font_listbox
local font_size_slider
local new_font_name_textbox
local add_font_button
local delete_font_button
local font_menu_entries = {}

local console_font_handles = {
	client = ffi.cast("uint32_t*****", ffi.cast("uint32_t", client.find_signature("client.dll", "\\x8b\r\\xcc\\xcc\\xccÌ‹\\x89")) + 2)[0][0][136],
	engine = ffi.cast("uint32_t***", ffi.cast("uint32_t", client.find_signature("engine.dll", "\\x8b\\xcc\\xcc\\xccÌ‰]\\xf0")) + 2)[0][0][86]
}

local original_console_fonts = {
	history = console_font_handles.client[100][114],
	entry = console_font_handles.client[101][117],
	panel = console_font_handles.engine[86]
}

local function apply_console_font(font_name, font_size)
	font_handle_cache[font_name] = font_handle_cache[font_name] or {}

	if font_handle_cache[font_name][font_size] == nil then
		font_handle_cache[font_name][font_size] = create_console_font(font_name, font_size)
	end

	local font_handle = font_handle_cache[font_name][font_size]
	console_font_handles.client[100][114] = font_handle
	console_font_handles.client[101][117] = font_handle
	console_font_handles.engine[86] = font_handle
	selected_console_font = {
		family = font_name,
		size = font_size
	}
end

local function restore_console_fonts()
	console_font_handles.client[100][114] = original_console_fonts.history
	console_font_handles.client[101][117] = original_console_fonts.entry
	console_font_handles.engine[86] = original_console_fonts.panel
end

local function refresh_font_list()
	font_menu_entries = {}

	for _, font_name in ipairs(saved_font_names) do
		table.insert(font_menu_entries, font_name)
	end

	table.insert(font_menu_entries, "[+] Add New")
	ui.update(font_listbox, font_menu_entries)
end

ui.new_label("LUA", "B", "\t~ Console font ~\t")
ui.new_label("LUA", "B", "~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~")

font_listbox = ui.new_listbox("LUA", "B", "Cosole Font", {})
font_size_slider = ui.new_slider("LUA", "B", "Cosole Font Size", 12, 40, 18, true, "pt", 1)
new_font_name_textbox = ui.new_textbox("LUA", "B", "Font Name")
add_font_button = ui.new_button("LUA", "B", "Add font", function()
	local font_name = ui.get(new_font_name_textbox)

	if font_name ~= "" then
		table.insert(saved_font_names, font_name)
		ui.set(new_font_name_textbox, "")
		refresh_font_list()
		ui.set(font_listbox, #saved_font_names - 1)
		database.write("Console_UserDefinedFonts", saved_font_names)
	end
end)
delete_font_button = ui.new_button("LUA", "B", "Delete font", function()
	local selected_index = ui.get(font_listbox) or 0

	if selected_index >= #saved_font_names then
		return
	end

	table.remove(saved_font_names, selected_index + 1)
	refresh_font_list()
	ui.set(font_listbox, math.max(0, math.min(selected_index, #saved_font_names - 1)))
	database.write("Console_UserDefinedFonts", saved_font_names)
end)

ui.set_visible(add_font_button, false)
ui.set_visible(delete_font_button, false)
ui.set_visible(new_font_name_textbox, false)

local function update_font_controls()
	local selected_index = ui.get(font_listbox) or 0
	local selected_family = font_menu_entries[selected_index + 1]
	local selected_size = ui.get(font_size_slider)

	if selected_family == nil then
		return
	end

	local is_add_new_entry = selected_family == "[+] Add New"
	ui.set_visible(new_font_name_textbox, is_add_new_entry)
	ui.set_visible(add_font_button, is_add_new_entry)
	ui.set_visible(delete_font_button, not is_add_new_entry and #saved_font_names > 0)

	if is_add_new_entry then
		return
	end

	apply_console_font(selected_family, selected_size)
	database.write("Console_Font", {
		family = selected_family,
		size = selected_size
	})
end

ui.set_callback(font_listbox, update_font_controls)
ui.set_callback(font_size_slider, update_font_controls)

client.set_event_callback("shutdown", restore_console_fonts)

refresh_font_list()

local saved_console_font = database.read("Console_Font")
if type(saved_console_font) == "table" and saved_console_font.family ~= nil and saved_console_font.size ~= nil then
	for index, font_name in ipairs(font_menu_entries) do
		if font_name == saved_console_font.family then
			ui.set(font_listbox, index - 1)
			ui.set(font_size_slider, saved_console_font.size)
			break
		end
	end
end

update_font_controls()
