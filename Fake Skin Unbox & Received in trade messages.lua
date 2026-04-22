local auto_disconnect = false
local auto_disconnect_on_damage = false
local auto_revert_name = false
local hide_name_change = false
local stattrak_weapon = false
local use_unbox_message = false
local use_skins_list = false
local use_custom_gap_value = false
local script_was_enabled = false
local can_clean_initial_change = true

local ui_get = ui.get
local ui_set = ui.set
local ui_reference = ui.reference
local ui_new_checkbox = ui.new_checkbox
local ui_new_combobox = ui.new_combobox
local ui_new_listbox = ui.new_listbox
local ui_set_visible = ui.set_visible
local ui_set_callback = ui.set_callback

local client_set_event_callback = client.set_event_callback
local client_unset_event_callback = client.unset_event_callback
local client_userid_to_entindex = client.userid_to_entindex
local client_delay_call = client.delay_call
local client_exec = client.exec
local client_set_clan_tag = client.set_clan_tag

local entity_get_local_player = entity.get_local_player
local entity_get_prop = entity.get_prop
local globals_mapname = globals.mapname

local string_rep = string.rep
local string_len = string.len
local string_sub = string.sub

local steal_player_name_ref = ui_reference("MISC", "Miscellaneous", "Steal player name")
local clan_tag_spammer_ref = ui_reference("MISC", "Miscellaneous", "Clan tag spammer")
local original_name = cvar.name:get_string()

local team_name_colors = {
    " \001",
    " \t",
    " \v"
}

local rarity_colors = {
    ["Restricted (Pruple)"] = "\003",
    ["Covert (Red)"] = "\007",
    ["Mil spec (DarkBlue)"] = "\012",
    ["Contraband (Orangeish)"] = "\016",
    ["Industrial (LightBlue)"] = "\011",
    ["Classified (PinkishPurple)"] = "\014"
}

local message_templates = {
    "received in a trade: ",
    "has opened a container and found: "
}

local knife_names = {
    "Bayonet",
    "Butterfly Knife",
    "Falchion Knife",
    "Flip Knife",
    "Gut Knife",
    "Huntsman Knife",
    "Karambit",
    "M9 Bayonet",
    "Shadow Daggers",
    "Bowie Knife",
    "Ursus Knife",
    "Navaja Knife",
    "Stiletto Knife",
    "Talon Knife",
    "Classic Knife",
    "Skeleton Knife",
    "Paracord Knife",
    "Survival Knife",
    "Nomad Knife"
}

local favorite_weapon_options = {
    "Show More (List)",
    "Bayonet",
    "Karambit",
    "M9 Bayonet",
    "AK-47",
    "AWP",
    "Desert Eagle",
    "Glock-18",
    "M4A4"
}

local extended_weapon_options = {
    "AK-47",
    "AUG",
    "AWP",
    "CZ75-Auto",
    "Desert Eagle",
    "Dual Berettas",
    "FAMAS",
    "Five-SeveN",
    "G3SG1",
    "Galil AR",
    "Glock-18",
    "M4A1-S",
    "M4A4",
    "M249",
    "MAC-10",
    "MAG-7",
    "MP5-SD",
    "MP7",
    "MP9",
    "Negev",
    "Nova",
    "P90",
    "P250",
    "P2000",
    "PP-Bizon",
    "R8 Revolver",
    "Sawed-Off",
    "SCAR-20",
    "SG 553",
    "SSG 08",
    "Tec-9",
    "UMP-45",
    "USP-S",
    "XM1014",
    "Bayonet",
    "Bowie Knife",
    "Butterfly Knife",
    "Classic Knife",
    "Falchion Knife",
    "Flip Knife",
    "Gut Knife",
    "Huntsman Knife",
    "Karambit",
    "M9 Bayonet",
    "Navaja Knife",
    "Nomad Knife",
    "Paracord Knife",
    "Shadow Daggers",
    "Skeleton Knife",
    "Stiletto Knife",
    "Survival Knife",
    "Talon Knife",
    "Ursus Knife"
}

local skin_options = {
    "Abyss",
    "Acheron",
    "Acid Etched",
    "Acid Fade",
    "Acid Wash",
    "Aerial",
    "Afterimage",
    "Agent",
    "Airlock",
    "Akihabara Accept",
    "Akoben",
    "Aloha",
    "Amber Fade",
    "Amber Slipstream",
    "Angry Mob",
    "Anodized Gunmetal",
    "Arctic Camo",
    "Arctic Wolf",
    "Aristocrat",
    "Armor Core",
    "Army Mesh",
    "Arym Recon",
    "Army Sheen",
    "Ash Wood",
    "Asiimov",
    "Assault",
    "Asterion",
    "Astral Jörmungandr",
    "Atheris",
    "Atlas",
    "Atomic Alloy",
    "Autotronic",
    "Avalanche",
    "Aztec",
    "Azure Zebra",
    "BOOM",
    "Balance",
    "Bamboo Forest",
    "Bamboo Garden",
    "Bamboo Print",
    "Bamboo Shadow",
    "Bamboozle",
    "Banana Leaf",
    "Baroque Orange",
    "Baroque Purple",
    "Baroque Red",
    "Barricade",
    "Basilisk",
    "Bengal Tiger",
    "Big Iron",
    "Bioleak",
    "Black Laminate",
    "Black Limba",
    "Black Sand",
    "Black Tie",
    "Blaze",
    "Blaze Orange",
    "Blind Spot",
    "Blizzard Marbleized",
    "Blood Tiger",
    "Blood in the Water",
    "Bloodshot",
    "Bloodsport",
    "Bloomstick",
    "Blue Fissure",
    "Blue Laminate",
    "Blue Spruce",
    "Blue Steel",
    "Blue Streak",
    "Blue Titanium",
    "Blueprint",
    "Bone Machine",
    "Bone Mask",
    "Bone Pile",
    "Boreal Forest",
    "Boroque Sand",
    "Brake Light",
    "Brass",
    "Bratatat",
    "Briar",
    "Briefing",
    "Bright Water",
    "Bronze Deco",
    "Buddy",
    "Bulkhead",
    "Bulldozer",
    "Bullet Rain",
    "Bunsen Burner",
    "Business Class",
    "Buzz Kill",
    "Caged Steel",
    "Caiman",
    "Calf Skin",
    "CaliCamo",
    "Canal Spray",
    "Candy Apple",
    "Capillary",
    "Caramel",
    "Carbon Fiber",
    "Cardiac",
    "Carnivore",
    "Cartel",
    "Case Hardened",
    "Catacombs",
    "Cerberus",
    "Chainmail",
    "Chalice",
    "Chameleon",
    "Chantico's Fire",
    "Chatterbox",
    "Check Engine",
    "Chemical Green",
    "Chopper",
    "Chronos",
    "Cinquedea",
    "Cirrus",
    "Classic Crate",
    "Co-Processor",
    "Coach Class",
    "Colbalt Core",
    "Colbalt Disruption",
    "Colbalt Halftone",
    "Colbalt Quartz",
    "Cobra Strike",
    "Code Red",
    "Cold Blooded",
    "Cold Fusion",
    "Colony",
    "Colony IV",
    "Commemoration",
    "Commuter",
    "Condemned",
    "Conspiracy",
    "Containment Breach",
    "Contamination",
    "Contractor",
    "Contrast Spray",
    "Control Panel",
    "Converter",
    "Coolant",
    "Copper",
    "Copper Borre",
    "Copper Galaxy",
    "Copperhead",
    "Core Breach",
    "Corinthian",
    "Corporal",
    "Cortex",
    "Corticera",
    "Counter Terrace",
    "Cracked Opal",
    "Crimson Blossom",
    "Crimson Kimono",
    "Crimson Tsunami",
    "Crimson Web",
    "Crypsis",
    "Curse",
    "Cut Out",
    "Cyanospatter",
    "Cyrex",
    "Daedalus",
    "Damascus Steel",
    "Danger Close",
    "Dark Age",
    "Dark Blossom",
    "Dark Filigree",
    "Dark Water",
    "Dart",
    "Day Lily",
    "Daybreak",
    "Dazzle",
    "Deadly Poison",
    "Death Grip",
    "Death Rattle",
    "Death by Kitty",
    "Death by Puppy",
    "Death's Head",
    "Decimator",
    "Decommissioned",
    "Delusion",
    "Demeter",
    "Demolition",
    "Desert Storm",
    "Desert Warfare",
    "Desert-Strike",
    "Desolate Space",
    "Detour",
    "Devourer",
    "Directive",
    "Dirt Drop",
    "Djinn",
    "Doomkitty",
    "Doppler",
    "Dragon Lore",
    "Dragon Tattoo",
    "Dragonfire",
    "Dry Season",
    "Dualing Dragons",
    "Duelist",
    "Eco",
    "Electric Hive",
    "Elite 1.6",
    "Elite Build",
    "Embargo",
    "Emerald",
    "Emerald Dragon",
    "Emerald Jörmungandr",
    "Emerald Pinstripe",
    "Emerald Posion Dart",
    "Emerald Quartz",
    "Evil Daimyo",
    "Exchanger",
    "Exo",
    "Exposure",
    "Eye of Athena",
    "Facets",
    "Facility Dark",
    "Facility Draft",
    "Facility Negative",
    "Facility Sketch",
    "Fade",
    "Faded Zebra",
    "Fallout Warning",
    "Fever Dream",
    "Fire Elemental",
    "Fire Serpent",
    "Firefight",
    "Firestarter",
    "First Class",
    "Flame Jörmungandr",
    "Flame Test",
    "Flash Out",
    "Flashback",
    "Fleet Flock",
    "Flux",
    "Forest DDPAT",
    "Forest Leaves",
    "Forest Night",
    "Fowl Play",
    "Franklin",
    "Freehand",
    "Frontside Misty",
    "Frost Borre",
    "Fubar",
    "Fuel Injector",
    "Fuel Rod",
    "Full Stop",
    "Gamma Doppler",
    "Gator Mesh",
    "Golden Koi",
    "Goo",
    "Grand Prix",
    "Granite Marbleized",
    "Graphite",
    "Grassland",
    "Grassland Leaves",
    "Graven",
    "Green Apple",
    "Green Marine",
    "Green Plaid",
    "Griffin",
    "Grim",
    "Grinder",
    "Grip",
    "Grotto",
    "Groundwater",
    "Guardian",
    "Gungnir",
    "Gunsmoke",
    "Hades",
    "Hand Brake",
    "Hand Cannon",
    "Handgun",
    "Hard Water",
    "Harvester",
    "Hazard",
    "Heat",
    "Heaven Guard",
    "Heriloom",
    "Hellfire",
    "Hemoglobin",
    "Hexane",
    "High Beam",
    "High Roller",
    "High Seas",
    "Highwayman",
    "Hive",
    "Hot Rod",
    "Howl",
    "Hunter",
    "Hunting Blind",
    "Hydra",
    "Hydroponic",
    "Hyper Beast",
    "Hypnotic",
    "Icarus Fell",
    "Ice Cap",
    "Impact Drill",
    "Imperial",
    "Imperial Dragon",
    "Impire",
    "Imprint",
    "Incinegator",
    "Indigo",
    "Inferno",
    "Integrale",
    "Iron Clad",
    "Ironwork",
    "Irradiated Alert",
    "Isaac",
    "Ivory",
    "Jaguar",
    "Jambiya",
    "Jet Set",
    "Judgement of Anubis",
    "Jungle",
    "Jungle DDPAT",
    "Jungle Dashed",
    "Jungle Slipstream",
    "Jungle Spray",
    "Jungle Thicket",
    "Jungle Tiger",
    "Kami",
    "Kill Confirmed",
    "Knight",
    "Koi",
    "Kumicho Dragon",
    "Lab Rats",
    "Labyrinth",
    "Lapis Gator",
    "Last Dive",
    "Lead Conduit",
    "Leaded Glass",
    "Leather",
    "Lichen Dashed",
    "Light Rail",
    "Lightning Strike",
    "Limelight",
    "Lionfish",
    "Llama Cannon",
    "Lore",
    "Loudmouth",
    "Macabre",
    "Magma",
    "Magnesium",
    "Mainframe",
    "Malachite",
    "Man-o'-war",
    "Mandrel",
    "Marble Fade",
    "Marina",
    "Master Piece",
    "Mayan Dreams",
    "Mecha Industries",
    "Medusa",
    "Mehndi",
    "Memento",
    "Metal Flowers",
    "Metallic DDPAT",
    "Meteorite",
    "Midnight Lilly",
    "Midnight Storm",
    "Minotaur's Labyrinth",
    "Mint Kimono",
    "Mischief",
    "Mjölnir",
    "Modern Hunter",
    "Modest Threat",
    "Module",
    "Momentum",
    "Monkey Business",
    "Moon in Libra",
    "Moonrise",
    "Morris",
    "Mortis",
    "Mosaico",
    "Moss Quartz",
    "Motherboard",
    "Mudder",
    "Muertos",
    "Murky",
    "Naga",
    "Navy Murano",
    "Nebula Crusader",
    "Necropos",
    "Nemesis",
    "Neo-Noir",
    "Neon Kimono",
    "Neon Ply",
    "Neon Revolution",
    "Neon Rider",
    "Neural Net",
    "Nevermore",
    "Night",
    "Night Borre",
    "Night Ops",
    "Night Riot",
    "Night Stripe",
    "Nightmare",
    "Nightshade",
    "Nitro",
    "Nostalgia",
    "Nuclear Garden",
    "Nuclear Threat",
    "Nuclear Waste",
    "Obsidian",
    "Ocean Foam",
    "Oceanic",
    "Off World",
    "Olive Plaid",
    "Oni Taiji",
    "Orange Crash",
    "Orange DDPAT",
    "Orange Filigree",
    "Orange Kimono",
    "Orange Murano",
    "Orange Peel",
    "Orbit Mk01",
    "Origami",
    "Orion",
    "Osiris",
    "Outbreak",
    "Overgrowth",
    "Oxide Blaze",
    "Paw",
    "Palm",
    "Pandora's Box",
    "Panther",
    "Para Green",
    "Pathfinder",
    "Petroglyph",
    "Phantom",
    "Phobos",
    "Phosphor",
    "Photic Zone",
    "Pilot",
    "Pink DDPAT",
    "Pipe Down",
    "Pit Viper",
    "Plastique",
    "Plume",
    "Point Disarray",
    "Posion Dart",
    "Polar Camo",
    "Polar Mesh",
    "Polymer",
    "Popdog",
    "Poseidon",
    "Power Loader",
    "Powercore",
    "Praetorian",
    "Predator",
    "Primal Saber",
    "Pulse",
    "Pyre",
    "Quicksilver",
    "Radiation Hazar",
    "Random Access",
    "Rangeen",
    "Ranger",
    "Rat Rod",
    "Re-Entry",
    "Reactor",
    "Reboot",
    "Red Astor",
    "Red Filigree",
    "Red FragCam",
    "Red Laminate",
    "Red Leather",
    "Red Python",
    "Red Quartz",
    "Red Rock",
    "Red Stone",
    "Redline",
    "Remote Contol",
    "Retribution",
    "Ricochet",
    "Riot",
    "Ripple",
    "Rising Skull",
    "Road Rash",
    "Rocket Pop",
    "Roll Cage",
    "Rose Iron",
    "Royal Blue",
    "Royal Consorts",
    "Royal Legion",
    "Royal Paladin",
    "Ruby Posion Dart",
    "Rust Coat",
    "Rust Leaf",
    "SWAG-7",
    "Sacrifice",
    "Safari Mesh",
    "Safety Net",
    "Sage Spray",
    "Sand Dashed",
    "Sand Dune",
    "Sand Mesh",
    "Sand Scale",
    "Sand Spray",
    "Sandstorm",
    "Scaffold",
    "Scavenger",
    "Scorched",
    "Scorpion",
    "Scumbria",
    "Sea Calico",
    "Seabird",
    "Seasons",
    "See Ya Later",
    "Serenity",
    "Sergeant",
    "Serum",
    "Setting Sun",
    "Shallow Grave",
    "Shapewood",
    "Shattered",
    "Shipping Forecast",
    "Shred",
    "Signal",
    "Silver",
    "Silver Quartz",
    "Skull Crusher",
    "Skulls",
    "Slashed",
    "Slaughter",
    "Slide",
    "Slipstream",
    "Snake Camo",
    "Snek-9",
    "Sonar",
    "Special Delivery",
    "Spectre",
    "Spitfire",
    "Splash",
    "Splash Jam",
    "Stained",
    "Stained Glass",
    "Stainless",
    "Stalker",
    "Steel Disruption",
    "Stinger",
    "Stone Cold",
    "Stone Mosaico",
    "Storm",
    "Stymphalian",
    "Styx",
    "Sugar Rush",
    "Sun in Leo",
    "Sundown",
    "Sunset Lily",
    "Sunset Storm",
    "Supernova",
    "Surfwood",
    "Survivalist",
    "Survivor Z",
    "Sweeper",
    "Syd Mead",
    "Synth Leaf",
    "System Lock",
    "Tacticat",
    "Tatter",
    "Teal Blossom",
    "Teardown",
    "Teclu Burner",
    "Tempest",
    "Terrace",
    "Terrain",
    "The Battlestar",
    "The Emperor",
    "The Empress",
    "The Executioner",
    "The Fuschia Is Now",
    "The Kraken",
    "The Prince",
    "Tiger Moth",
    "Tiger Tooth",
    "Tigris",
    "Titanium Bit",
    "Torn",
    "Tornado",
    "Torque",
    "Toxic",
    "Toy Soldier",
    "Traction",
    "Tranquility",
    "Traveler",
    "Tread Plate",
    "Triarch",
    "Trigon",
    "Triqua",
    "Triumvierate",
    "Tropical Storm",
    "Turf",
    "Tuxedo",
    "Twilight Galaxy",
    "Twin Turbo",
    "Twist",
    "Ultraviolet",
    "Uncharted",
    "Undertow",
    "Urban DDPAT",
    "Urban Dashed",
    "Urban Hazard",
    "Urban Masked",
    "Urban Perforated",
    "Urban Rubble",
    "Urban Shock",
    "Valence",
    "VariCamo",
    "VariCamo Blue",
    "Ventilator",
    "Ventilators",
    "Verdigris",
    "Victoria",
    "Vino Primo",
    "Violent Daimyo",
    "Violet Murano",
    "Virus",
    "Vulcan",
    "Walnut",
    "Warbird",
    "Warhawk",
    "Wasteland Princess",
    "Wasteland Rebel",
    "Water Elemental",
    "Water Sigil",
    "Wave Spray",
    "Waves Perforated",
    "Weasel",
    "Whitefish",
    "Whiteout",
    "Wild Lily",
    "Wild Lotus",
    "Wild Six",
    "Wildfire",
    "Wings",
    "Wingshot",
    "Winter Forest",
    "Wood Fired",
    "Woodsman",
    "Worm God",
    "Wraiths",
    "X-Ray",
    "Xiangliu",
    "Yellow Jacket",
    "Yorick",
    "Zander",
    "Ziggy",
    "Zirka",
    "龍王 (Dragon King)"
}

local modifier_options = {
    "Auto-Disconnect",
    "Auto-Disconnect-Dmg",
    "Auto-Revert Name",
    "Hide Name Change",
    "StatTrak Weapon",
    "Unbox Message",
    "Use Skins List",
    "Custom Gap Value"
}

local enable_checkbox
local clean_chat_checkbox
local modifiers_multiselect
local weapon_type_combobox
local weapons_extended_listbox
local drop_rarity_combobox
local skin_name_label
local skin_textbox
local skins_extended_listbox
local gap_slider
local set_name_button

local function set_player_name(name)
    cvar.name:set_string(name)
end

local function contains(list, value)
    for index = 1, #list do
        if list[index] == value then
            return true
        end
    end

    return false
end

local function reset_modifier_flags()
    auto_disconnect = false
    auto_disconnect_on_damage = false
    auto_revert_name = false
    hide_name_change = false
    stattrak_weapon = false
    use_unbox_message = false
    use_skins_list = false
    use_custom_gap_value = false
end

local function update_modifier_flags()
    reset_modifier_flags()

    local selected_modifiers = ui_get(modifiers_multiselect)

    if next(selected_modifiers) == nil then
        return
    end

    for index = 1, #selected_modifiers do
        local modifier = selected_modifiers[index]

        if modifier == "Auto-Disconnect" then
            auto_disconnect = true
        elseif modifier == "Auto-Disconnect-Dmg" then
            auto_disconnect_on_damage = true
        elseif modifier == "Auto-Revert Name" then
            auto_revert_name = true
        elseif modifier == "Hide Name Change" then
            hide_name_change = true
        elseif modifier == "StatTrak Weapon" then
            stattrak_weapon = true
        elseif modifier == "Unbox Message" then
            use_unbox_message = true
        elseif modifier == "Use Skins List" then
            use_skins_list = true
        elseif modifier == "Custom Gap Value" then
            use_custom_gap_value = true
        end
    end
end

local function update_control_visibility()
    if ui_get(enable_checkbox) then
        update_modifier_flags()

        if use_skins_list then
            ui_set_visible(skins_extended_listbox, true)
            ui_set_visible(skin_textbox, false)
        else
            ui_set_visible(skins_extended_listbox, false)
            ui_set_visible(skin_textbox, true)
        end

        ui_set_visible(gap_slider, use_custom_gap_value)
        ui_set_visible(weapons_extended_listbox, ui_get(weapon_type_combobox) == "Show More (List)")

        if hide_name_change then
            ui_set(clan_tag_spammer_ref, false)
            ui_set_visible(clean_chat_checkbox, true)
        else
            ui_set_visible(clean_chat_checkbox, false)
        end
    else
        ui_set_visible(skins_extended_listbox, false)
        ui_set_visible(gap_slider, false)
        ui_set_visible(weapons_extended_listbox, false)
        ui_set_visible(clean_chat_checkbox, false)
    end
end

local function update_main_controls()
    local is_enabled = ui_get(enable_checkbox)

    ui_set_visible(modifiers_multiselect, is_enabled)
    ui_set_visible(weapon_type_combobox, is_enabled)
    ui_set_visible(drop_rarity_combobox, is_enabled)
    ui_set_visible(skin_name_label, is_enabled)
    ui_set_visible(skin_textbox, is_enabled)
    ui_set_visible(set_name_button, is_enabled)

    if is_enabled then
        original_name = cvar.name:get_string()
        script_was_enabled = true
    elseif script_was_enabled then
        reset_modifier_flags()
        set_player_name(original_name)
        client_set_clan_tag()
        script_was_enabled = false
    end

    update_control_visibility()
end

local function build_gap_string(gap_value)
    if not use_custom_gap_value then
        return " "
    end

    return string_rep("ᅠ", gap_value)
end

local function on_player_hurt(event)
    local local_player = entity_get_local_player()
    local attacker = client_userid_to_entindex(event.attacker)
    local victim = client_userid_to_entindex(event.userid)

    if attacker == local_player and entity_get_prop(victim, "m_iTeamNum") == entity_get_prop(local_player, "m_iTeamNum") then
        if auto_revert_name then
            ui_set(enable_checkbox, false)
            print("Reverted name back to normal and disabled the main checkbox for the script.")
        end

        if auto_disconnect_on_damage then
            ui_set(enable_checkbox, false)
            client_exec("Disconnect")
            print("Disconnected from the server after reverting name.")
        end
    end
end

local function update_player_hurt_callback(control)
    update_main_controls()

    if ui_get(control) then
        client_set_event_callback("player_hurt", on_player_hurt)
    else
        client_unset_event_callback("player_hurt", on_player_hurt)
    end
end

client_set_event_callback("player_connect_full", function(event)
    if client_userid_to_entindex(event.userid) == entity_get_local_player() and globals_mapname() ~= nil then
        can_clean_initial_change = true
    end
end)

enable_checkbox = ui_new_checkbox("LUA", "A", "Enable Skin-Name")
clean_chat_checkbox = ui_new_checkbox("LUA", "A", "CleanChat on initial change")
weapons_extended_listbox = ui_new_listbox("LUA", "A", "Weapons Extended", extended_weapon_options)
drop_rarity_combobox = ui_new_combobox("LUA", "A", "Drop Rarity/Color", "Industrial (LightBlue)", "Mil spec (DarkBlue)", "Restricted (Pruple)", "Classified (PinkishPurple)", "Covert (Red)", "Contraband (Orangeish)")
skin_name_label = ui.new_label("LUA", "A", "Skin Name")
skin_textbox = ui.new_textbox("LUA", "A", "Skin")
skins_extended_listbox = ui_new_listbox("LUA", "A", "Skins Extended", skin_options)
gap_slider = ui.new_slider("LUA", "A", "Gap Value", 1, 20, 1, true)
set_name_button = ui.new_button("LUA", "A", "Set Name", function()
    local local_player = entity_get_local_player()
    local weapon_name = ui_get(weapon_type_combobox)
    local skin_name = ui_get(skin_textbox)
    local message_text = message_templates[1]
    local team_color = team_name_colors[entity_get_prop(local_player, "m_iTeamNum")]
    local rarity_color = rarity_colors[ui_get(drop_rarity_combobox)]
    local gap_value = ui_get(gap_slider)

    if weapon_name == "Show More (List)" then
        weapon_name = extended_weapon_options[ui_get(weapons_extended_listbox) + 1]
    end

    if use_unbox_message then
        message_text = message_templates[2]
    end

    if use_skins_list then
        skin_name = skin_options[ui_get(skins_extended_listbox) + 1]
    end

    local weapon_prefix = contains(knife_names, weapon_name) and "★ " or ""
    local weapon_display = stattrak_weapon and weapon_prefix .. "StatTrak™ " .. weapon_name or weapon_prefix .. weapon_name
    local item_suffix = rarity_color .. build_gap_string(gap_value) .. " | " .. skin_name .. "\n" .. message_text

    ui_set(steal_player_name_ref, true)
    client_exec("\n\\xad\\xad\\xad\\xad")

    client_delay_call(0, function()
        if can_clean_initial_change and ui_get(clean_chat_checkbox) and ui_get(enable_checkbox) then
            client_delay_call(0.01, client_exec, "Say " .. string_rep(" ﷽﷽", 40))
            print("Spammed the chat in an attempt to hide the initial name change.")
        end
    end)

    client_delay_call(0.3, function()
        can_clean_initial_change = false

        if auto_disconnect then
            set_player_name(team_color .. weapon_display .. "\001 " .. item_suffix .. "? \001")
            client_delay_call(0.8, client_exec, "disconnect")
            client_delay_call(5.2, function()
                ui_set(enable_checkbox, false)
                print("Automatically disconnected from the server after setting Skin-Name.")
            end)
        elseif hide_name_change then
            local clan_tag_name = weapon_display

            if string_len(weapon_display) > 12 then
                clan_tag_name = string_sub(weapon_display, 1, 12)
                print("Clamped the clantag to prevent fuck up on scoreboard :).")
            end

            client_set_clan_tag(team_color .. clan_tag_name .. " \n")
            set_player_name("\n\001" .. item_suffix .. "\001You")
        else
            client_set_clan_tag()
            set_player_name(team_color .. weapon_display .. "\001 " .. item_suffix .. "\001You")
        end
    end)
end)

modifiers_multiselect = ui.new_multiselect("LUA", "A", "Modifiers", unpack(modifier_options))
weapon_type_combobox = ui_new_combobox("LUA", "A", "Weapon Type", unpack(favorite_weapon_options))

ui_set_callback(modifiers_multiselect, update_control_visibility)
ui_set_callback(weapon_type_combobox, update_control_visibility)
ui_set_callback(enable_checkbox, update_player_hurt_callback)

client_set_event_callback("shutdown", function()
    ui_set(enable_checkbox, false)
end)

update_player_hurt_callback(enable_checkbox)
