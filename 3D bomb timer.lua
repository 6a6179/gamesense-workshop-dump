local c4_timer_color_picker = ui.new_color_picker("VISUALS", "Other ESP", "C4 Timer Color")
local radius_slider = ui.new_slider("VISUALS", "Other ESP", "Radius", 20, 100, 50, true, "%")
local oval_slider = ui.new_slider("VISUALS", "Other ESP", "Oval", 0, 50, 0, true, "%")
local enable_c4_timer_checkbox = ui.new_checkbox("VISUALS", "Other ESP", "Enable C4 Timer")

local function calculate_angles_between_points(x1, y1, z1, x2, y2, z2)
    local delta_x = x1 - x2
    local delta_y = y1 - y2

    return math.deg(math.atan((z1 - z2) / math.sqrt(delta_x * delta_x + delta_y * delta_y))),
        math.deg(math.atan(delta_y / delta_x))
end

local function project_to_screen_edge(world_x, world_y, world_z, local_x, local_y, local_z, oval_scale)
    local screen_width, screen_height = client.screen_size()
    local _, camera_yaw = client.camera_angles()
    local _, target_yaw = calculate_angles_between_points(world_x, world_y, world_z, local_x, local_y, local_z)
    local screen_angle = math.rad(camera_yaw - target_yaw - 90)

    if screen_angle < 0 and screen_angle > -math.pi then
        screen_angle = screen_angle + math.pi
    end

    return screen_width * 0.5 + screen_width * (0.5 + ui.get(radius_slider) / 100) * oval_scale * math.cos(screen_angle),
        screen_height * 0.5 + screen_width * 0.5 * oval_scale * math.sin(screen_angle)
end

local function draw_c4_timer()
    local planted_c4_entities = entity.get_all("CPlantedC4")

    for index = 1, #planted_c4_entities do
        local bomb_entity = planted_c4_entities[index]
        local bomb_blow_time = entity.get_prop(bomb_entity, "m_flC4Blow")

        if bomb_blow_time < globals.curtime() then
            return
        end

        local time_left = math.floor((bomb_blow_time - globals.curtime()) * 10) / 10
        local progress_ratio = time_left / cvar.mp_c4timer:get_int()

        if time_left <= 0 then
            return
        end

        local local_x, local_y, local_z = entity.get_origin(entity.get_local_player())
        local bomb_x, bomb_y, bomb_z = entity.get_origin(bomb_entity)
        local bomb_screen_x, bomb_screen_y = renderer.world_to_screen(bomb_x, bomb_y, bomb_z)
        local color_r, color_g, color_b, color_a = ui.get(c4_timer_color_picker)

        if bomb_screen_x ~= nil and bomb_screen_y ~= nil then
            renderer.circle_outline(bomb_screen_x, bomb_screen_y, 0, 0, 0, 200, 25, 270, 1, 8)
            renderer.circle_outline(
                bomb_screen_x,
                bomb_screen_y,
                color_r,
                color_g,
                color_b,
                color_a,
                25,
                270,
                progress_ratio,
                8
            )
            renderer.text(bomb_screen_x, bomb_screen_y, 255, 255, 255, 255, "c", 0, time_left)
        else
            local offscreen_x, offscreen_y =
                project_to_screen_edge(bomb_x, bomb_y, bomb_z, local_x, local_y, local_z, ui.get(oval_slider) / 200)

            renderer.circle_outline(offscreen_x, offscreen_y, 0, 0, 0, 200, 25, 270, 1, 8)
            renderer.circle_outline(
                offscreen_x,
                offscreen_y,
                color_r,
                color_g,
                color_b,
                color_a,
                25,
                270,
                progress_ratio,
                8
            )
            renderer.text(offscreen_x, offscreen_y, 255, 255, 255, 255, "c", 0, time_left)
        end
    end
end

ui.set_callback(enable_c4_timer_checkbox, function()
    if ui.get(enable_c4_timer_checkbox) then
        client.set_event_callback("paint", draw_c4_timer)
    else
        client.unset_event_callback("paint", draw_c4_timer)
    end
end)
