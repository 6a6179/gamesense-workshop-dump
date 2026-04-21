local bit_band = require("bit").band
local get_prop = entity.get_prop
local get_players = entity.get_players
local is_enemy = entity.is_enemy
local exec_command = client.exec

client.set_event_callback("round_freeze_end", function ()
	if entity.get_local_player() == nil then
		return
	end

	for _, player in ipairs(get_players()) do
		local flags = get_prop(player, "m_fFlags")

		if not is_enemy(player) and flags ~= nil and bit_band(flags, 512) == 512 then
			exec_command("holdpos")

			return
		end
	end
end)
