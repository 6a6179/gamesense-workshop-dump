local matchmaking = require("gamesense/steamworks").ISteamMatchmaking
local panorama_view = panorama.open()
local my_persona_api = panorama_view.MyPersonaAPI
local party_list_api = panorama_view.PartyListAPI
local invite_bridge = panorama.loadstring([[
    let _ActionInviteFriend = FriendsListAPI.ActionInviteFriend;
    let Invites = [];
    
    FriendsListAPI.ActionInviteFriend = (xuid) => {
        if (!LobbyAPI.CreateSession()) {
            LobbyAPI.CreateSession();
            PartyListAPI.SessionCommand('MakeOnline', '');
        }

        Invites.push(xuid);
    };

    return {
        get: () => {
            let inviteCache = Invites;
            Invites = [];
            return inviteCache;
        },
        old: (xuid) => {
            _ActionInviteFriend(xuid);
        },
        shutdown: () => {
            FriendsListAPI.ActionInviteFriend = _ActionInviteFriend;
        }
    }
]])()

local silent_invites_checkbox = ui.new_checkbox("Misc", "Miscellaneous", "Silent Invites")

local function send_invite_to_lobby(xuid)
    local lobby_id = matchmaking:GetLobbyID()

    if lobby_id ~= nil then
        if not ui.get(silent_invites_checkbox) then
            party_list_api.SessionCommand(
                "Game::ChatInviteMessage",
                string.format("run all xuid %s %s %s", my_persona_api.GetXuid(), "friend", xuid)
            )
        end

        matchmaking:InviteUserToLobby(lobby_id, xuid)
    else
        client.delay_call(0.1, send_invite_to_lobby, xuid)
    end
end

local function flush_pending_invites()
    local pending_invites = invite_bridge.get()

    for index = 0, pending_invites.length - 1 do
        send_invite_to_lobby(pending_invites[index])
    end

    client.delay_call(0.05, flush_pending_invites)
end

flush_pending_invites()

client.set_event_callback("shutdown", function()
    invite_bridge.shutdown()
end)
