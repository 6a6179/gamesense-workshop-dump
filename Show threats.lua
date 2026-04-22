local aim_dot_threshold = math.cos(math.rad(10))

local function normalize_vector(x, y, z)
    local length = math.sqrt(x * x + y * y + z * z)

    if length == 0 then
        return 0, 0, 0
    end

    local inverse_length = 1 / length

    return x * inverse_length, y * inverse_length, z * inverse_length
end

local function dot_product(x1, y1, z1, x2, y2, z2)
    return x1 * x2 + y1 * y2 + z1 * z2
end

local function angles_to_forward(pitch, yaw)
    local pitch_radians = math.rad(pitch)
    local yaw_radians = math.rad(yaw)
    local cos_pitch = math.cos(pitch_radians)

    return cos_pitch * math.cos(yaw_radians), cos_pitch * math.sin(yaw_radians), -math.sin(pitch_radians)
end

local function is_player_aiming_at_position(player, x, y, z)
    local pitch, yaw = entity.get_prop(player, "m_angEyeAngles")

    if pitch == nil then
        return false
    end

    local forward_x, forward_y, forward_z = angles_to_forward(pitch, yaw)
    local origin_x, origin_y, origin_z = entity.get_prop(player, "m_vecOrigin")

    if origin_x == nil then
        return false
    end

    local direction_x, direction_y, direction_z = normalize_vector(x - origin_x, y - origin_y, z - origin_z)

    return aim_dot_threshold < dot_product(direction_x, direction_y, direction_z, forward_x, forward_y, forward_z)
end

local function get_current_threat()
    local local_player = entity.get_local_player()

    if local_player == nil then
        return false, nil
    end

    local local_x, local_y, local_z = entity.get_prop(local_player, "m_vecOrigin")

    if local_x == nil then
        return false, nil
    end

    local enemies = entity.get_players(true)

    for index = 1, #enemies do
        local enemy = enemies[index]

        if is_player_aiming_at_position(enemy, local_x, local_y, local_z) then
            return true, entity.get_player_name(enemy) or "An enemy"
        end
    end

    return false, nil
end

local function on_paint()
    local is_threatening, enemy_name = get_current_threat()

    if is_threatening then
        local screen_width, screen_height = client.screen_size()

        renderer.text(
            screen_width / 2,
            screen_height - 100,
            255,
            255,
            50,
            255,
            "c+",
            0,
            enemy_name,
            " is aiming in your direction"
        )
    end
end

local show_threats_checkbox = ui.new_checkbox("VISUALS", "Other ESP", "Show threats")

ui.set_callback(show_threats_checkbox, function(checkbox)
    if ui.get(checkbox) then
        client.set_event_callback("paint", on_paint)
    else
        client.unset_event_callback("paint", on_paint)
    end
end)
