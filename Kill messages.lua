local kill_message_checkbox = ui.new_checkbox("LUA", "B", "Kill message")
local kill_message_textbox = ui.new_textbox("LUA", "B", "Message text")

local placeholder_resolvers = {}

local function replace_all(text, needle, replacement)
    local start_index = 1

    while true do
        local begin_index, end_index = text:find(needle, start_index, true)
        if not begin_index then
            break
        end

        text = text:sub(1, begin_index - 1) .. replacement .. text:sub(end_index + 1)
        start_index = begin_index + #replacement
    end

    return text
end

local function update_textbox_visibility()
    ui.set_visible(kill_message_textbox, ui.get(kill_message_checkbox))
end

local function on_player_death(event)
    if not ui.get(kill_message_checkbox) then
        return
    end

    local local_player = entity.get_local_player()
    if client.userid_to_entindex(event.attacker) ~= local_player then
        return
    end

    local message = ui.get(kill_message_textbox)

    for token, resolver in pairs(placeholder_resolvers) do
        if message:find(token, 1, true) then
            message = replace_all(message, token, resolver(event))
        end
    end

    client.exec("say " .. message)
end

placeholder_resolvers["$victim"] = function(event)
    local victim = client.userid_to_entindex(event.userid)
    return entity.get_player_name(victim) or ""
end

placeholder_resolvers["$attacker"] = function(event)
    local attacker = client.userid_to_entindex(event.attacker)
    return entity.get_player_name(attacker) or ""
end

placeholder_resolvers["$weapon"] = function(event)
    return event.weapon or ""
end

placeholder_resolvers["$location"] = function(event)
    local victim = client.userid_to_entindex(event.userid)
    return entity.get_prop(victim, "m_szLastPlaceName") or ""
end

placeholder_resolvers["$time"] = function()
    return string.format("%d:%02d:%02d", client.system_time())
end

ui.set_callback(kill_message_checkbox, update_textbox_visibility)
client.set_event_callback("player_death", on_player_death)
update_textbox_visibility()
