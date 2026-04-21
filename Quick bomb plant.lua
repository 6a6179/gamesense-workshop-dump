local auto_plant_checkbox = ui.new_checkbox("MISC", "Miscellaneous", "Auto plant")
local auto_plant_hotkey = ui.new_hotkey("MISC", "Miscellaneous", "Auto plant hotkey", true)

local previous_can_plant = nil

client.set_event_callback("setup_command", function(command)
    if not ui.get(auto_plant_checkbox) then
        return
    end

    local local_player = entity.get_local_player()

    if
        (command.in_use == 1 or command.in_attack == 1 or ui.get(auto_plant_hotkey))
        and entity.get_classname(entity.get_player_weapon(local_player)) == "CC4"
    then
        local can_plant = entity.get_prop(local_player, "m_bInBombZone") == 1
            and bit.band(entity.get_prop(local_player, "m_fFlags"), 1) == 1

        if not can_plant or previous_can_plant == false then
            command.in_attack = 0
            command.in_use = 0
        elseif can_plant then
            command.in_attack = 1
        end

        previous_can_plant = can_plant
    else
        previous_can_plant = nil
    end
end)
