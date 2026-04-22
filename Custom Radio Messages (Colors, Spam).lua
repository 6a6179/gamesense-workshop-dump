local color_names = {
	"default"
}

local color_codes = {
	white = string.char(1),
	red = string.char(2),
	purple = string.char(3),
	green = string.char(4),
	lightgreen = string.char(5),
	turquoise = string.char(6),
	lightred = string.char(7),
	gray = string.char(8),
	yellow = string.char(9),
	gray2 = string.char(10),
	lightblue = string.char(11),
	gray3 = string.char(12),
	blue = string.char(13),
	pink = string.char(14),
	darkorange = string.char(15),
	orange = string.char(16)
}

for name in pairs(color_codes) do
	table.insert(color_names, name)
end

table.insert(color_names, "rainbow")
table.insert(color_names, "christmas")

local radio_command_format = 'playerchatwheel . "%s"'
local menu_tab = "Lua"
local menu_group = "A"
local last_spam_tick = globals.tickcount()
local radio_controls

local function colorize_text(text, palette)
	local colored_text = string.char(32, 1, 11)
	local color_index = 1

	for character in text:gmatch(".") do
		if palette[color_index] == nil then
			color_index = 1
		end

		colored_text = colored_text .. palette[color_index] .. character

		if character ~= " " then
			color_index = color_index + 1
		end
	end

	return colored_text
end

local function build_radio_text(text, selected_color)
	if selected_color == "rainbow" then
		return colorize_text(text, {
			color_codes.red,
			color_codes.orange,
			color_codes.yellow,
			color_codes.green,
			color_codes.blue
		})
	elseif selected_color == "christmas" then
		return colorize_text(text, {
			color_codes.red,
			color_codes.green
		})
	elseif selected_color == "default" then
		return text
	end

	return string.char(32, 1, 11) .. color_codes[selected_color] .. text
end

radio_controls = {
	_ = ui.new_label(menu_tab, menu_group, "Radio Text"),
	color = ui.new_combobox(menu_tab, menu_group, "Text Color", color_names),
	text = ui.new_textbox(menu_tab, menu_group, "Text"),
	send_message = ui.new_button(menu_tab, menu_group, "Send", function(message)
		local radio_text = message and type(message) == "string" and message or ui.get(radio_controls.text)
		local selected_color = ui.get(radio_controls.color)

		client.exec(string.format(radio_command_format, build_radio_text(radio_text, selected_color)))
	end),
	spam = require("gamesense/uix").new_checkbox(menu_tab, menu_group, "Spam Radio")
}

radio_controls.spam:on("paint_ui", function()
	if globals.tickcount() - last_spam_tick > 32 then
		radio_controls.send_message()
		last_spam_tick = globals.tickcount()
	end
end)

client.set_event_callback("string_cmd", function(command)
	local chat_text = command.text:match('^say "(.*)"') or command.text:match('^say_team "(.*)"')

	if chat_text and chat_text:find("^!r ") then
		radio_controls.send_message(chat_text:sub(4))
		return true
	end
end)
