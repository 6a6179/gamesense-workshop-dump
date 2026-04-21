local current_thirdperson_distance = 15
local animation_checkbox = ui.new_checkbox("CONFIG", "Presets", "Third person animation")
local thirdperson_reference = { ui.reference("Visuals", "Effects", "Force third person (alive)") }
local distance_slider = ui.new_slider("CONFIG", "Presets", "Third person distance", 0, 180, 100)
local speed_slider = ui.new_slider("CONFIG", "Presets", "Third person zoom speed", 1, 100, 25, true, "%", 1)

client.set_event_callback("paint_ui", function()
    if ui.get(animation_checkbox) then
        if
            not entity.is_alive(entity.get_local_player())
            or not ui.get(thirdperson_reference[1])
            or not ui.get(thirdperson_reference[2])
        then
            current_thirdperson_distance = 15
        else
            local target_distance = ui.get(distance_slider)
            local distance_delta = (target_distance - current_thirdperson_distance) / ui.get(speed_slider)

            current_thirdperson_distance = current_thirdperson_distance
                + (current_thirdperson_distance < target_distance and distance_delta or -distance_delta)
            current_thirdperson_distance = target_distance < current_thirdperson_distance and target_distance
                or current_thirdperson_distance

            cvar.cam_idealdist:set_float(current_thirdperson_distance)
        end
    end
end)
