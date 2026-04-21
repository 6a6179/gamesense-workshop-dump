local flashSpeedMultiplier = 15
local radioUrls = {
	"http://air.radiorecord.ru:805/dc_320",
	"http://uk7.internet-radio.com:8000/stream",
	"https://www.internet-radio.com/player/?mount=http://uk1.internet-radio.com:8200/live.m3u&title=Phever%20Media%20Live%20Audio%20Stream&website=www.phever.ie",
	"https://www.internet-radio.com/player/?mount=http://uk1.internet-radio.com:8294/live.m3u&title=Radio%20Bloodstream&website=http://www.RadioBloodstream.com",
	"https://www.internet-radio.com/player/?mount=http://us4.internet-radio.com:8107/listen.pls&title=kmjt98.6%20Radio&website=https://www.internet-radio.com",
	"https://www.internet-radio.com/player/?mount=http://uk7.internet-radio.com:8000/listen.pls&title=MoveDaHouse&website=http://www.movedahouse.com",
	"http://air.radiorecord.ru:805/dc_320",
	"https://icecast.z8r.de/radiosven-lofi-ogg",
	"http://playerservices.streamtheworld.com/api/livestream-redirect/TLPSTR19.mp3"
}
local indicatorModeCombo = ui.new_combobox("LUA", "a", "Choose active radio indicator", {
	"No indicator",
	"Static",
	"Breathing",
	"Flashing"
})
local radioCombo = ui.new_combobox("LUA", "a", "Choose radio", {
	"Hits",
	"House",
	"Techno",
	"Metal",
	"Rap",
	"Deep House",
	"Pop",
	"8bit",
	"Lo-Fi",
	"Ibiza"
})

local function openSelectedRadio()
	local selectedRadioIndex = nil

	for radioIndex, radioName in next, radioUrls, nil do
		if radioName == ui.get(radioCombo) then
			selectedRadioIndex = radioIndex
		end
	end

	panorama.loadstring([[
		return {
		  open_url: function(url){
			SteamOverlayAPI.OpenURL(url)
		  }
		}
		]])().open_url(radioUrls[selectedRadioIndex])
end

local function normalizeFlashValue(value, limit)
	value = value * flashSpeedMultiplier

	while limit < value do
		value = limit - value
	end

	return value
end

local function onDraw()
	local radioName = ui.get(radioCombo)
	local indicatorMode = ui.get(indicatorModeCombo)

	if indicatorMode == "No indicator" then
		return
	elseif indicatorMode == "Static" then
		renderer.indicator(0, 255, 255, 255, radioName)
	elseif indicatorMode == "Breathing" then
		local red = math.floor(math.sin((globals.curtime() + 0.7) * 4 + 4) * 127 + 128)
		local green = 255
		local blue = math.floor(math.sin((globals.curtime() + 0.7) * 4 + 4) * 127 + 128)

		renderer.indicator(0, red, green, blue, radioName)
	elseif indicatorMode == "Flashing" then
		local flashPeriod = 510 / flashSpeedMultiplier
		local red = normalizeFlashValue(globals.tickcount() % flashPeriod, 255)
		local green = 255
		local blue = normalizeFlashValue(globals.tickcount() % flashPeriod, 255)

		renderer.indicator(0, red, green, blue, radioName)
	end
end

client.set_event_callback("paint", onDraw)
ui.new_button("LUA", "a", "Start Radio", openSelectedRadio)
