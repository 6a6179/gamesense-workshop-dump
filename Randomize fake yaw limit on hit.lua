local randomize_checkbox = ui.new_checkbox("AA", "Anti-aimbot angles", "Randomize fake yaw limit")
local fake_yaw_limit_reference = ui.reference("AA", "Anti-aimbot angles", "Fake yaw limit")

local function on_player_hurt(event)
    if not ui.get(randomize_checkbox) then
        return
    end

    local local_player = entity.get_local_player()
    local victim = client.userid_to_entindex(event.userid)
    local attacker = client.userid_to_entindex(event.attacker)

    if victim == local_player and entity.is_enemy(attacker) then
        ui.set(fake_yaw_limit_reference, client.random_int(0, 60))
    end
end

client.set_event_callback("player_hurt", on_player_hurt)
