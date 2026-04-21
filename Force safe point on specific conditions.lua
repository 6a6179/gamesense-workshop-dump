local bit = require("bit")

local force_safe_point_checkbox = ui.new_checkbox("RAGE", "Other", "Force safe point conditions")
local condition_multiselect = ui.new_multiselect("RAGE", "Other", "\nbox", "Duck", "X > HP", "In air")
local hp_slider = ui.new_slider("RAGE", "Other", "X > HP", 1, 100, 70, true, "HP", 1)

local function contains_value(values, needle)
    for index = 1, #values do
        if values[index] == needle then
            return true
        end
    end

    return false
end

local function update_hp_slider_visibility(reference)
    ui.set_visible(hp_slider, contains_value(ui.get(reference), "X > HP"))
end

local function update_menu_visibility(reference)
    local enabled = ui.get(reference)

    ui.set_visible(condition_multiselect, enabled)
    ui.set_visible(hp_slider, enabled)
    update_hp_slider_visibility(condition_multiselect)
end

client.set_event_callback("paint", function()
    if not ui.get(force_safe_point_checkbox) then
        return
    end

    local selected_conditions = ui.get(condition_multiselect)

    if #selected_conditions == 0 then
        return
    end

    local enemies = entity.get_players(true)

    for index = 1, #enemies do
        local enemy = enemies[index]
        local should_force_safe_point = false

        if contains_value(selected_conditions, "Duck") and entity.get_prop(enemy, "m_flDuckAmount") >= 0.7 then
            should_force_safe_point = true
        elseif
            contains_value(selected_conditions, "X > HP")
            and entity.get_prop(enemy, "m_iHealth") <= ui.get(hp_slider)
        then
            should_force_safe_point = true
        elseif
            contains_value(selected_conditions, "In air") and bit.band(entity.get_prop(enemy, "m_fFlags"), 1) == 0
        then
            should_force_safe_point = true
        end

        plist.set(enemy, "Override safe point", should_force_safe_point and "On" or "-")
    end
end)

client.register_esp_flag("SP", 204, 204, 0, function(player)
    return ui.get(force_safe_point_checkbox) and plist.get(player, "Override safe point") == "On"
end)

update_menu_visibility(force_safe_point_checkbox)
ui.set_callback(force_safe_point_checkbox, update_menu_visibility)
update_hp_slider_visibility(condition_multiselect)
ui.set_callback(condition_multiselect, update_hp_slider_visibility)
