ui.new_label("LUA", "B", "Music Kits")

local music_kit_listbox

local function update_music_kit()
    local local_player = entity.get_local_player()

    if local_player == nil then
        return
    end

    local selected_music_kit_index = ui.get(music_kit_listbox)
    local desired_music_kit_id = selected_music_kit_index == 0 and 1 or selected_music_kit_index + 2
    local player_resource = entity.get_player_resource()

    if entity.get_prop(player_resource, "m_nMusicID", local_player) ~= desired_music_kit_id then
        entity.set_prop(player_resource, "m_nMusicID", desired_music_kit_id, local_player)
    end
end

music_kit_listbox = ui.new_listbox("LUA", "B", "Music Kits", {
    "Default",
    nil,
    "Crimson Assault",
    "Sharpened",
    "Insurgency",
    "A*D*8",
    "High Noon",
    "Death's Head Demolition",
    "Desert Fire",
    "LNOE",
    "Metal",
    "All I Want for Christmas",
    "IsoRhythm",
    "For No Mankind",
    "Hotline Miami",
    "Total Domination",
    "The Talos Principle",
    "Battlepack",
    "MOLOTOV",
    "Uber Blasto Phone",
    "Hazardous Environments",
    "Headshot",
    "The 8-Bit Kit",
    "I Am",
    "Diamonds",
    "Invasion!",
    "Lion's Mouth",
    "Sponge Fingerz",
    "Disgusting",
    "Java Havana Funkaloo",
    "Moments CSGO",
    "Aggressive",
    "The Good Youth",
    "FREE",
    "Life's Not Out To Get You",
    "Backbone",
    "GLA",
    "III-Arena",
    "EZ4ENCE",
    "The Master Chief Collection",
    "Scar",
    "Anti Citizen",
    "Bachram",
    "Gunman Taco Truck",
    "Eye of the Dragon",
    "M.U.D.D. FORCE",
    "Neo Noir",
    "Bodacious",
    "Drifter",
    "All for Dust",
    "Hades Music Kit",
    "The Lowlife Pack",
    "CHAIN$AW.LXADXUT.",
    "Mocha Petal",
    "~Yellow Magic~",
    "Vici",
    "Astro Bellum",
    "Work Hard, Play Hard",
    "KOLIBRI",
    "u mad!",
    "Flashbang Dance",
    "Heading for the Source",
    "Void",
    "Shooters",
    "dashstar*",
    "Gothic Luxury",
    "Lock Me Up",
    "花脸 Hua Lian (Painted Face)",
    "ULTIMATE",
})
ui.set_callback(music_kit_listbox, update_music_kit)
client.set_event_callback("round_start", update_music_kit)
