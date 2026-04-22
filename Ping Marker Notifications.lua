local image_api = require("gamesense/images")

local controls = {
	menu = {
		enabled = image_api.ui.checkbox("VISUALS", "Other ESP", "Enemy Ping Marker"),
		heading = image_api.ui.label("LUA", "B", "Ping Marker Settings:"),
		show_name = image_api.ui.checkbox("LUA", "B", "Show Name"),
		play_sound = image_api.ui.checkbox("LUA", "B", "Ping Sound"),
		ping_delay = image_api.ui.slider("LUA", "B", "Ping Duration", 1, 30, 10, true, "s"),
		normal_label = image_api.ui.label("LUA", "B", "Normal Ping Color"),
		normal_color = image_api.ui.colorPicker("LUA", "B", "Normal Ping Color", 93, 167, 254, 200),
		urgent_label = image_api.ui.label("LUA", "B", "Urgent Ping Color"),
		urgent_color = image_api.ui.colorPicker("LUA", "B", "Urgent Ping Color", 255, 30, 30, 200),
		spacer = image_api.ui.label("LUA", "B", " ")
	},
	sounds = {
		[true] = "ui/panorama/ping_alert_01",
		[false] = "player/playerping"
	},
	images = {
		[false] = {
			image_api.get_panorama_image("icons/ui/info.svg"),
			image_api.load("<?xml version=\"1.0\" ?><svg width=\"32px\" height=\"32px\"><circle cx=\"16\" cy=\"16\" r=\"15\" fill=\"#fff\" /></svg>")
		},
		[true] = {
			image_api.get_panorama_image("icons/ui/alert.svg"),
			image_api.load("<?xml version=\"1.0\" ?><svg width=\"32px\" height=\"32px\"><polygon points=\"16,3 31,29 1,29\" style=\"fill:#fff\" /></svg>")
		}
	},
	pings = {}
}

local function set_menu_visibility(enabled)
	for name, control in pairs(controls.menu) do
		if name ~= "enabled" then
			image_api.ui.setVisible(control, enabled)
		end
	end
end

local function clear_pings()
	controls.pings = {}
end

local function on_player_ping(event)
	local player_index = image_api.client.useridToEnt(event.userid)
	if player_index == 0 then
		return
	end

	if not image_api.entity.isEnemy(player_index) then
		return
	end

	local player_name = image_api.entity.getName(player_index)
	local ping_time = image_api.curtime()

	for ping_index = #controls.pings, 1, -1 do
		local ping = controls.pings[ping_index]
		if ping_time - ping[6] <= 2 and ping[5] == player_name then
			table.remove(controls.pings, ping_index)
		end
	end

	controls.pings[#controls.pings + 1] = {
		event.x,
		event.y,
		event.z,
		event.urgent,
		player_name,
		ping_time
	}

	if image_api.ui.get(controls.menu.play_sound) then
		image_api.client.exec("play " .. controls.sounds[event.urgent])
	end
end

local function on_paint()
	for ping_index = #controls.pings, 1, -1 do
		local ping = controls.pings[ping_index]
		local age = image_api.curtime() - ping[6]

		if age > image_api.ui.get(controls.menu.ping_delay) then
			table.remove(controls.pings, ping_index)
		else
			local screen_x, screen_y = image_api.draw.w2s(ping[1], ping[2], ping[3])
			if screen_x ~= nil and screen_y ~= nil then
				local red, green, blue, alpha = image_api.ui.get(controls.menu.normal_color)

				if ping[4] and math.floor(age * 32) % 16 < 8 then
					red, green, blue, alpha = image_api.ui.get(controls.menu.urgent_color)
				end

				if ping[4] then
					local pulse = math.floor(age * 32) % 16
					image_api.draw.circleOutline(screen_x, screen_y, red, green, blue, 155 - 2 * pulse, 24 - pulse, 0, 1, 4)
				else
					image_api.draw.circleOutline(screen_x, screen_y, red, green, blue, alpha, 24, 0, 1, 4)
				end

				controls.images[ping[4]][2]:draw(screen_x - 16, screen_y - 16, 32, 32, 0, 0, 0, 225)
				controls.images[ping[4]][1]:draw(screen_x - 15, screen_y - 15, 30, 30, red, green, blue, math.min(alpha, 200))

				if image_api.ui.get(controls.menu.show_name) then
					local text_width = image_api.draw.textSize("cb", ping[5])
					if text_width > 360 then
						text_width = 360
					end

					image_api.draw.rectangle(math.ceil(screen_x - 4 - text_width / 2), screen_y + 22, text_width + 7, 18, 0, 0, 0, 100)
					image_api.draw.text(screen_x, screen_y + 30, 255, 255, 255, 255, "cb", 360, ping[5])
				end
			end
		end
	end
end

image_api.ui.cb(controls.menu.enabled, function(control)
	local enabled = image_api.ui.get(control)
	local callback_name = enabled and "cb" or "unsetCb"

	clear_pings()
	image_api.client[callback_name]("round_start", clear_pings)
	image_api.client[callback_name]("player_ping", on_player_ping)
	image_api.client[callback_name]("paint", on_paint)
	set_menu_visibility(enabled)
end)

set_menu_visibility(false)
