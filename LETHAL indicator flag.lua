client.register_esp_flag("LETHAL", 255, 0, 0, function(player)
    local local_player = entity.get_local_player()

    if not entity.is_alive(local_player) or not entity.is_enemy(player) then
        return
    end

    local pelvis_position = { entity.hitbox_position(player, "pelvis") }

    if #pelvis_position ~= 3 then
        return
    end

    local _, damage = client.trace_bullet(
        local_player,
        pelvis_position[1] - 1,
        pelvis_position[2] - 1,
        pelvis_position[3] - 1,
        pelvis_position[1],
        pelvis_position[2],
        pelvis_position[3],
        true
    )

    return entity.get_prop(player, "m_iHealth") <= damage
end)
