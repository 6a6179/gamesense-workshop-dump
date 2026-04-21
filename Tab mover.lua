local load_config = config.load
local get_ui_value = ui.get
local new_button = ui.new_button
local new_multiselect = ui.new_multiselect
local new_label = ui.new_label
local new_textbox = ui.new_textbox

local tab_mover_label = new_label("CONFIG", "Presets", "Tab mover")
local config_name_textbox = new_textbox("CONFIG", "Presets", "Config name")
local selected_tabs_multiselect = new_multiselect("CONFIG", "Presets", "\nTab", "Rage", "AA", "Legit", "Visuals", "Misc", "Skins")

local function load_selected_tabs()
    local config_name = get_ui_value(config_name_textbox)

    for _, tab_name in ipairs(get_ui_value(selected_tabs_multiselect)) do
        load_config(config_name, tab_name)
    end
end

local load_tab_button = new_button("CONFIG", "Presets", "Load tab", load_selected_tabs)
