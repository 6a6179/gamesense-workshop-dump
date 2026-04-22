local uix = require("gamesense/uix")
local userid_to_entindex = client.userid_to_entindex
local get_players = entity.get_players
local get_origin = entity.get_origin
local get_prop = entity.get_prop
local is_dormant = entity.is_dormant
local is_enemy = entity.is_enemy
local curtime = globals.curtime
local distance = math.sqrt
local draw_text = renderer.text
local world_to_screen = renderer.world_to_screen
local remove = table.remove

local enabled_checkbox = uix.new_checkbox("LUA", "A", "Footstep ESP")
local color_picker = uix.new_color_picker("LUA", "A", "Footstep color", 255, 255, 255, 255)
local distance_slider = uix.new_slider("LUA", "A", "\nFootstep distance", 0, 1250, 850, true, "u")
local active_footsteps = {}

local function distance3d(x1, y1, z1, x2, y2, z2)
	return distance((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2)
end

local function is_near_enemy(x, y, z)
	local players = get_players(true)
	for index = 1, #players do
		local player = players[index]
		if player ~= nil and not is_dormant(player) and is_enemy(player) then
			local enemy_x, enemy_y, enemy_z = get_prop(player, "m_vecOrigin")
			if enemy_x ~= nil and distance3d(enemy_x, enemy_y, enemy_z, x, y, z) <= ui.get(distance_slider) then
				return true
			end
		end
	end

	return false
end

local function clear_footsteps()
	active_footsteps = {}
end

local function update_visibility()
	local enabled = ui.get(enabled_checkbox)
	ui.set_visible(color_picker, enabled)
	ui.set_visible(distance_slider, enabled)
end

local function on_paint()
	local red, green, blue, alpha = ui.get(color_picker)
	local now = curtime()

	for index = #active_footsteps, 1, -1 do
		local footstep = active_footsteps[index]

		if footstep.expire_time <= now then
			footstep.alpha = footstep.alpha - 1
			if footstep.alpha <= 0 then
				remove(active_footsteps, index)
			end
		end

		local screen_x, screen_y = world_to_screen(footstep.x, footstep.y, footstep.z)
		if screen_x ~= nil and screen_y ~= nil then
			draw_text(screen_x, screen_y, red, green, blue, footstep.alpha, "cd", 0, "step")
		end
	end
end

local function on_player_footstep(event)
	local player = userid_to_entindex(event.userid)
	if player == 0 or not is_enemy(player) then
		return
	end

	local origin_x, origin_y, origin_z = get_origin(player)
	if origin_x ~= nil and is_near_enemy(origin_x, origin_y, origin_z) then
		active_footsteps[#active_footsteps + 1] = {
			alpha = 255,
			x = origin_x,
			y = origin_y,
			z = origin_z,
			expire_time = curtime() + 1
		}
	end
end

enabled_checkbox:on("change", update_visibility)
enabled_checkbox:on("paint", on_paint)
enabled_checkbox:on("player_footstep", on_player_footstep)
enabled_checkbox:on("round_start", clear_footsteps)
enabled_checkbox:on("level_init", clear_footsteps)
update_visibility()
