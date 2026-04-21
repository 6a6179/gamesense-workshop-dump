local http = require("gamesense/http")

local embed_methods = {}
local webhook_methods = {}

function embed_methods.setTitle(self, title)
    self.Properties.title = title
end

function embed_methods.setDescription(self, description)
    self.Properties.description = description
end

function embed_methods.setURL(self, url)
    self.Properties.url = url
end

function embed_methods.setTimestamp(self, timestamp)
    self.Properties.timestamp = timestamp
end

function embed_methods.setColor(self, color)
    self.Properties.color = color
end

function embed_methods.setFooter(self, text, icon_url, proxy_icon_url)
    self.Properties.footer = {
        text = text,
        icon_url = icon_url or "",
        proxy_icon_url = proxy_icon_url or "",
    }
end

function embed_methods.setImage(self, url, proxy_url, height, width)
    self.Properties.image = {
        url = url or "",
        proxy_url = proxy_url or "",
        height = height or nil,
        width = width or nil,
    }
end

function embed_methods.setThumbnail(self, url, proxy_url, height, width)
    self.Properties.thumbnail = {
        url = url or "",
        proxy_url = proxy_url or "",
        height = height or nil,
        width = width or nil,
    }
end

function embed_methods.setVideo(self, url, height, width)
    self.Properties.video = {
        url = url or "",
        height = height or nil,
        width = width or nil,
    }
end

function embed_methods.setAuthor(self, name, url, icon_url, proxy_icon_url)
    self.Properties.author = {
        name = name or "",
        url = url or "",
        icon_url = icon_url or "",
        proxy_icon_url = proxy_icon_url or "",
    }
end

function embed_methods.addField(self, name, value, inline)
    if not self.Properties.fields then
        self.Properties.fields = {}
    end

    table.insert(self.Properties.fields, {
        name = name,
        value = value,
        inline = inline or false,
    })
end

function webhook_methods.send(self, ...)
    local payload = {
        username = self.username,
    }
    local arguments = table.pack(...)

    if self.avatar_url then
        payload.avatar_url = self.avatar_url
    end

    for index = 1, arguments.n do
        local value = arguments[index]

        if type(value) == "table" then
            if not payload.embeds then
                payload.embeds = {}
            end

            table.insert(payload.embeds, value.Properties)
        elseif type(value) == "string" then
            payload.content = value
        end
    end

    local body = json.stringify(payload)

    http.post(self.URL, {
        body = body,
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = #body,
        },
    }, function() end)
end

function webhook_methods.setUsername(self, username)
    self.username = username
end

function webhook_methods.setAvatarURL(self, avatar_url)
    self.avatar_url = avatar_url
end

return {
    newEmbed = function()
        return setmetatable({
            Properties = {},
        }, {
            __index = embed_methods,
        })
    end,
    new = function(url)
        return setmetatable({
            URL = url,
        }, {
            __index = webhook_methods,
        })
    end,
}
