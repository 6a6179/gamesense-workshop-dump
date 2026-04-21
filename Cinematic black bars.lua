local lua_container = "A"
local screen_width, screen_height = client.screen_size()
local black_bars_hotkey = ui.new_hotkey("LUA", lua_container, "Cinematic black bars hotkey", true)
local black_bars_color = ui.new_color_picker("LUA", lua_container, "Cinematic black bars color", 0, 0, 0, 255)
local black_bars_height = ui.new_slider(
    "LUA",
    lua_container,
    "\n Cinematic black bars height",
    1,
    screen_height / 2,
    math.floor(0.23809523809523808 * screen_height / 2 + 0.5),
    true,
    "px"
)
local black_bars_checkbox = ui.new_checkbox("LUA", lua_container, "Cinematic black bars")

ui.set(black_bars_hotkey, "Always on")

local default_safe_zone = 0
local animation_progress = 0

local function update_menu_state()
    default_safe_zone = tonumber(cvar.safezoney:get_string())

    cvar.safezoney:set_raw_float(default_safe_zone)

    local enabled = ui.get(black_bars_checkbox)

    ui.set_visible(black_bars_hotkey, enabled)
    ui.set_visible(black_bars_height, enabled)
end

update_menu_state()
ui.set_callback(black_bars_checkbox, update_menu_state)
client.set_event_callback("shutdown", update_menu_state)
client.set_event_callback("paint_ui", function()
    animation_progress = math.max(
        0,
        math.min(1, animation_progress + 0.02 * (ui.get(black_bars_checkbox) and ui.get(black_bars_hotkey) and 1 or -1))
    )

    local eased_progress = (math.sin(animation_progress * math.pi - math.pi / 2) + 1) / 2
    local bar_height = ui.get(black_bars_height)
    local r, g, b, a = ui.get(black_bars_color)

    renderer.rectangle(0, 0, screen_width, bar_height * eased_progress, r, g, b, a)
    renderer.rectangle(0, screen_height, screen_width, bar_height * eased_progress * -1, r, g, b, a)
    cvar.safezoney:set_raw_float((screen_height - bar_height * eased_progress * 2) / screen_height * default_safe_zone)
end)
