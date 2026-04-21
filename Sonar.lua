local vector = require("vector")
local sonar_controls = {
	enabled = ui.new_checkbox("LUA", "A", "Enable Sonar"),
	volume = ui.new_slider("LUA", "A", "Sonar Volume", 0, 10, 10, true, "", 0.1),
	minDistance = ui.new_slider("LUA", "A", "Sonar Min Distance", 0, 1000, 0, true, "f"),
	maxDistance = ui.new_slider("LUA", "A", "Sonar Max Distance", 0, 1000, 250, true, "f"),
	teams = ui.new_checkbox("LUA", "A", "Sonar On Teammates")
}
local last_beep_time = 0

local function get_closest_player_distance()
	local closest_distance = nil
	local use_team_filter = sonar_controls.teams

	for _, player_entity in ipairs(entity.get_players(not ui.get(use_team_filter))) do
		local local_origin = vector(entity.get_prop(entity.get_local_player(), "m_vecOrigin"))
		local player_origin = vector(entity.get_prop(player_entity, "m_vecOrigin"))
		local distance = local_origin:dist(player_origin)

		if closest_distance == nil or distance < closest_distance then
			closest_distance = distance
		end
	end

	if closest_distance ~= nil then
		return closest_distance * 0.0254 * 3.281
	end
end

local function play_sonar(distance_seconds)
	if globals.realtime() > last_beep_time + distance_seconds then
		client.exec("playvol  ", "/buttons/blip1.wav ", ui.get(sonar_controls.volume) * 0.1)

		last_beep_time = globals.realtime()
	end
end

client.set_event_callback("run_command", function ()
	if entity.is_alive(entity.get_local_player()) and ui.get(sonar_controls.enabled) then
		local max_distance = ui.get(sonar_controls.maxDistance)
		local closest_distance = get_closest_player_distance()

		if closest_distance ~= nil and (closest_distance <= max_distance or max_distance == 0) and ui.get(sonar_controls.minDistance) <= closest_distance then
			play_sonar(closest_distance / max_distance * 5)
		end
	end
end)
