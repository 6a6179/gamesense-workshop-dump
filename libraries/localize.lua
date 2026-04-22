local ffi = require("ffi")

local cast = ffi.cast
local ffi_string = ffi.string
local stringify_json = json.stringify
local char_buffer_t = ffi.typeof("char[?]")
local uint16_ptr_t = ffi.typeof("uint16_t*")
local convert_unicode_to_ansi =
    vtable_bind("localize.dll", "Localize_001", 16, "int(__thiscall*)(void*, const unsigned char*, char*, int)")
local find_localized_token =
    vtable_bind("localize.dll", "Localize_001", 11, "unsigned char*(__thiscall*)(void*, const char*)")

local function get_wide_string_length(wide_string)
    local length = 0

    while cast("wchar_t*", wide_string)[length] ~= 0 do
        length = length + 1
    end

    return length + 1
end

local function localize_token_raw(token)
    local wide_string = find_localized_token(token)

    if wide_string == nil then
        return token
    end

    local buffer_length = get_wide_string_length(wide_string)
    local buffer = char_buffer_t(buffer_length)

    if convert_unicode_to_ansi(wide_string, buffer, buffer_length) < 2 then
        return ""
    end

    return ffi_string(buffer, buffer_length - 1)
end

local panorama_localize = panorama.loadstring([[
	return {
		localize: (str, params) => {
			if(params == null)
				return $.Localize(str)

			var panel = $.CreatePanel("Panel", $.GetContextPanel(), "")

			for(key in params) {
				panel.SetDialogVariable(key, params[key])
			}

			var result = $.Localize(str, panel)

			panel.DeleteAsync(0.0)

			return result
		},
		language: () => {
			return $.Language()
		}
	}
]])()

local current_language = panorama_localize.language()
local localize_cache = {}

local function localize_cached(token, params)
    if token == nil then
        return ""
    end

    if localize_cache[token] == nil then
        localize_cache[token] = {}
    end

    local cache_key = params ~= nil and stringify_json(params) or true

    if localize_cache[token][cache_key] == nil then
        localize_cache[token][cache_key] = params ~= nil and panorama_localize.localize(token, params)
            or localize_token_raw(token)
    end

    return localize_cache[token][cache_key]
end

local function localize_english(token, params)
    return localize_cached(token, params)
end

if current_language ~= "english" then
    function localize_english(token, ...)
        return localize_cached("#[english]" .. token:sub(2, -1))
    end
end

return setmetatable({
    localize = localize_cached,
    localize_english = localize_english,
    language = function()
        return current_language
    end,
}, {
    __call = function(_, ...)
        return localize_cached(...)
    end,
})
