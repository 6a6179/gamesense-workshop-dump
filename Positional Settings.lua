local currentPlayerEntity = nil
local currentPlayerX, currentPlayerY, currentPlayerZ = nil, nil, nil
local currentPlayerCeilingZ = nil
local currentPlayerScreenX, currentPlayerScreenY = nil, nil
local currentWeaponClass = nil
local currentMapName = nil
local currentMapPathParts = nil

local drawDistance = 250
local positionState = { false, 0, 0, 0 }
local locationMarker = { false, 0, 0, 0 }
local positionFileContents = nil
local positionEntries = {}
local positionNames = {}
local savedMapSettings = {}

local weaponDefinitions = {
	{
		"CDEagle",
		"R8 or Deagle"
	},
	{
		"CWeaponSSG08",
		"SSG 08"
	},
	{
		"CWeaponAWP",
		"AWP"
	},
	{
		"CWeaponG3SG1",
		"G3SG1"
	},
	{
		"CWeaponSCAR20",
		"SCAR-20"
	}
}

local weaponUiRows = {}
local rageReferences = {}
local customColorControls = {
	ui.new_checkbox("LUA", "B", "Draw Color"),
	ui.new_color_picker("LUA", "B", "Draw Color", 3, 136, 252, 100),
	ui.new_checkbox("LUA", "B", "Hover Color"),
	ui.new_color_picker("LUA", "B", "Hover Color", 252, 198, 3, 100)
}

local mainEnabledCheckbox = ui.new_checkbox("LUA", "B", "Enabled")
local disableRechargeInRegionCheckbox = ui.new_checkbox("LUA", "B", "Disable Recharge in Region")
local debugLinesCheckbox = ui.new_checkbox("LUA", "B", "Debug Lines")
local drawDistanceSlider = ui.new_slider("LUA", "B", "Draw Distance", 5, 5000, 250)
local customColorsCheckbox = ui.new_checkbox("LUA", "B", "Custom Colors")
local positionNameTextbox = ui.new_textbox("LUA", "B", "Position Name")
local locationCombobox = nil
local weaponHeaderLabel = ui.new_label("LUA", "B", "-+-+-+-+ [ Aim -  ] +-+-+-+-")

local positionCreationActive = false
local regionIsActive = false
local activeRegionName = nil
local activeRegionIndex = nil
local regionActivationLatch = false
local weaponFiredSinceEntry = false
local dtRestorePending = false

rageReferences.dt = ui.reference("RAGE", "Other", "Double Tap")
rageReferences.hitchance = ui.reference("RAGE", "Aimbot", "Minimum Hit Chance")
rageReferences.mindamage = ui.reference("RAGE", "Aimbot", "Minimum Damage")
rageReferences.limbsafe = ui.reference("RAGE", "Aimbot", "Force Safe Point on Limbs")
rageReferences.prefersafe = ui.reference("RAGE", "Aimbot", "Prefer Safe Point")

if ui.get(rageReferences.dt) then
	dtRestorePending = true
end

ui.new_label("LUA", "B", "-+-+-+-+ [ Onion's Position LUA ] +-+-+-+-")

local function splitString(text, separator)
	if separator == nil then
		separator = "%s"
	end

	local parts = {}

	if text ~= nil then
		local pattern = separator

		for token in string.gmatch(text, "([^" .. pattern .. "]+)") do
			table.insert(parts, token)
		end
	end

	return parts
end

currentMapPathParts = splitString(globals.mapname(), "/")
currentMapName = currentMapPathParts[#currentMapPathParts]

local function isPointInsideBounds(minX, maxX, minY, maxY, pointX, pointY)
	local normalizedBounds = {
		tonumber(minX) or 0,
		tonumber(maxX) or 0,
		tonumber(pointX) or 0,
		tonumber(minY) or 0,
		tonumber(maxY) or 0,
		tonumber(pointY) or 0
	}

	for index = 1, #normalizedBounds do
		if normalizedBounds[index] > 0 then
			normalizedBounds[index] = normalizedBounds[index] + 100000
		end

		normalizedBounds[index] = math.abs(normalizedBounds[index])
	end

	if normalizedBounds[2] < normalizedBounds[1] then
		if normalizedBounds[1] < normalizedBounds[3] or normalizedBounds[3] < normalizedBounds[2] then
			return false
		end
	elseif normalizedBounds[3] < normalizedBounds[1] or normalizedBounds[2] < normalizedBounds[3] then
		return false
	end

	if normalizedBounds[5] < normalizedBounds[4] then
		if normalizedBounds[4] < normalizedBounds[6] or normalizedBounds[6] < normalizedBounds[5] then
			return false
		end
	elseif normalizedBounds[6] < normalizedBounds[4] or normalizedBounds[5] < normalizedBounds[6] then
		return false
	end

	return true
end

local function applyWeaponSettings(serializedSettings)
	if weaponUiRows == nil or serializedSettings == nil then
		return
	end

	local rows = splitString(serializedSettings, "\n")

	for rowIndex = 1, #rows do
		if weaponUiRows[rowIndex] ~= nil and weaponUiRows[rowIndex][1] ~= nil then
			local fields = splitString(rows[rowIndex], "|")

			if #fields >= 6 then
				ui.set(weaponUiRows[rowIndex][1], fields[1] == "true")
				ui.set(weaponUiRows[rowIndex][2], tonumber(fields[2]) or 0)
				ui.set(weaponUiRows[rowIndex][3], tonumber(fields[3]) or 0)
				ui.set(weaponUiRows[rowIndex][4], fields[4] == "true")
				ui.set(weaponUiRows[rowIndex][5], fields[5] == "true")
				ui.set(weaponUiRows[rowIndex][6], fields[6] == "true")
			end
		end
	end
end

local function refreshPositionData()
	positionEntries = {}
	positionNames = {}
	savedMapSettings = {}
	positionFileContents = readfile("onionPositions_" .. currentMapName .. ".db")

	local settingsFileContents = readfile("onionSettings.db")

	if settingsFileContents ~= nil and settingsFileContents ~= "" then
		local settingsLines = splitString(settingsFileContents, "\n")

		for lineIndex = 1, #settingsLines do
			if string.find(settingsLines[lineIndex], "map: ") and settingsLines[lineIndex + 5] ~= nil then
				table.insert(savedMapSettings, {
					settingsLines[lineIndex + 1] .. "\n" .. settingsLines[lineIndex + 2] .. "\n" .. settingsLines[lineIndex + 3] .. "\n" .. settingsLines[lineIndex + 4] .. "\n" .. settingsLines[lineIndex + 5],
					string.gsub(settingsLines[lineIndex], "map: ", "")
				})
			end
		end

		if #savedMapSettings ~= 0 then
			for recordIndex = 1, #savedMapSettings do
				if string.find(savedMapSettings[recordIndex][2], currentMapName) then
					applyWeaponSettings(savedMapSettings[recordIndex][1])
				end
			end
		end
	end

	if positionFileContents ~= nil and positionFileContents ~= "" then
		local positionLines = splitString(positionFileContents, "\n")

		for lineIndex = 1, #positionLines do
			local fields = splitString(positionLines[lineIndex], "|")

			if #fields == 6 then
				table.insert(positionEntries, {
					fields[1],
					fields[2],
					{
						fields[3],
						fields[4]
					},
					{
						fields[5],
						fields[6]
					}
				})
				table.insert(positionNames, fields[1])
			elseif fields[1] ~= nil then
				table.insert(positionEntries, {
					"Name",
					fields[1],
					{
						fields[2],
						fields[3]
					},
					{
						fields[4],
						fields[5]
					}
				})
				table.insert(positionNames, "Name")
			end
		end
	end

	if locationCombobox == nil and #positionNames ~= 0 then
		locationCombobox = ui.new_combobox("LUA", "B", "Location", positionNames)
	end
end

local function updateSettingsButtonCallback()
	refreshPositionData()
end

local function deletePosition()
	if locationCombobox == nil then
		return
	end

	local selectedPositionName = ui.get(locationCombobox)
	local updatedPositionFileContents = nil
	local filePath = "onionPositions_" .. currentMapName .. ".db"

	if positionFileContents ~= nil and positionFileContents ~= "" then
		local positionLines = splitString(positionFileContents, "\n")

		for lineIndex = 1, #positionLines do
			if not string.find(positionLines[lineIndex], selectedPositionName) then
				updatedPositionFileContents = updatedPositionFileContents ~= nil and updatedPositionFileContents .. "\n" .. positionLines[lineIndex] or positionLines[lineIndex]
			end
		end

		writefile(filePath, updatedPositionFileContents)
		refreshPositionData()
	end
end

local function createPosition()
	if ui.get(mainEnabledCheckbox) and currentPlayerEntity ~= nil then
		local filePath = "onionPositions_" .. currentMapName .. ".db"

		if positionCreationActive then
			positionCreationActive = false

			local positionName = "Name"

			if ui.get(positionNameTextbox) ~= nil and ui.get(positionNameTextbox) ~= "" then
				positionName = ui.get(positionNameTextbox)
			end

			local serializedPosition = positionName .. "|" .. positionState[4] .. "|" .. positionState[2] .. "|" .. positionState[3] .. "|" .. currentPlayerX .. "|" .. currentPlayerY

			if positionFileContents ~= nil and positionFileContents ~= "" then
				writefile(filePath, positionFileContents .. "\n" .. serializedPosition)
			else
				writefile(filePath, serializedPosition)
			end

			refreshPositionData()
			positionState[4] = 0
			positionState[3] = 0
			positionState[2] = 0
		else
			positionCreationActive = true
			positionState[4] = currentPlayerCeilingZ
			positionState[3] = currentPlayerY
			positionState[2] = currentPlayerX
		end
	end
end

local function logCurrentLocation()
	if ui.get(mainEnabledCheckbox) and currentPlayerEntity ~= nil then
		local logColor = 245
		local localPlayerX, localPlayerY, localPlayerZ = entity.get_origin(currentPlayerEntity)
		local localPlayerScreenX, localPlayerScreenY = renderer.world_to_screen(localPlayerX, localPlayerY, localPlayerZ)
		local localPlayerCeilingZ = localPlayerZ + 100000 * client.trace_line(currentPlayerEntity, localPlayerX, localPlayerY, localPlayerZ, localPlayerX, localPlayerY, localPlayerZ + 100000)

		client.color_log(66, 164, logColor, "playerX: " .. localPlayerX .. " playerY: " .. localPlayerY .. " playerZ: " .. localPlayerZ .. " Player Ceiling: " .. localPlayerCeilingZ .. "\n")

		for side = 0, 1 do
			local yAxisHit = client.trace_line(currentPlayerEntity, localPlayerX, localPlayerY, localPlayerZ, localPlayerX, localPlayerY - 100 + 200 * side, localPlayerZ)
			local xAxisHit = client.trace_line(currentPlayerEntity, localPlayerX, localPlayerY, localPlayerZ, localPlayerX - 100 + 200 * side, localPlayerY, localPlayerZ)
			local xAxisScreenX, xAxisScreenY = renderer.world_to_screen(localPlayerX + (-100 + 200 * side) * xAxisHit, localPlayerY, localPlayerZ)
			local yAxisScreenX, yAxisScreenY = renderer.world_to_screen(localPlayerX, localPlayerY + (-100 + 200 * side) * yAxisHit, localPlayerZ)

			if yAxisHit ~= 1 then
				client.color_log(0, 255, 0, "Hit on the Y Axis, yAxis: " .. yAxisHit .. ", Original playerY: " .. localPlayerY - 100 + 200 * side .. ", playerY Hit: " .. localPlayerY + (-100 + 200 * side) * yAxisHit .. ", i: " .. side .. "\n")
			else
				client.color_log(255, 0, 0, "No hit on the Y Axis, i: " .. side .. "\n")
			end

			if xAxisHit ~= 1 then
				client.color_log(0, 255, 0, "Hit on the X Axis, xAxis: " .. xAxisHit .. ", Original playerX: " .. localPlayerX - 100 + 200 * side .. ", playerX Hit: " .. localPlayerX + (-100 + 200 * side) * xAxisHit .. ", i: " .. side .. "\n")
			else
				client.color_log(255, 0, 0, "No hit on the X Axis, i: " .. side .. "\n")
			end

			renderer.line(localPlayerScreenX, localPlayerScreenY, yAxisScreenX, yAxisScreenY, 255, 255, 255, 255)
			renderer.line(localPlayerScreenX, localPlayerScreenY, xAxisScreenX, xAxisScreenY, 255, 255, 255, 255)
		end
	end
end

local function onActiveRegionChanged()
	weaponFiredSinceEntry = false
	dtRestorePending = false
end

local function saveCurrentSettings()
	if ui.get(mainEnabledCheckbox) and currentPlayerEntity ~= nil then
		local weaponSettingsLines = {}
		local serializedWeaponSettings = nil

		for weaponIndex = 1, #weaponDefinitions do
			local weaponRow = weaponUiRows[weaponIndex]
			local dtEnabled = ui.get(weaponRow[1]) and "true" or "false"
			local hitChance = ui.get(weaponRow[2])
			local minimumDamage = ui.get(weaponRow[3])
			local forceSafePointOnLimbs = ui.get(weaponRow[4]) and "true" or "false"
			local preferSafePoint = ui.get(weaponRow[5]) and "true" or "false"
			local overrideAimbot = ui.get(weaponRow[6]) and "true" or "false"

			table.insert(weaponSettingsLines, dtEnabled .. "|" .. hitChance .. "|" .. minimumDamage .. "|" .. forceSafePointOnLimbs .. "|" .. preferSafePoint .. "|" .. overrideAimbot)
		end

		for lineIndex = 1, #weaponSettingsLines do
			serializedWeaponSettings = serializedWeaponSettings ~= nil and serializedWeaponSettings ~= "" and serializedWeaponSettings .. "\n" .. weaponSettingsLines[lineIndex] or weaponSettingsLines[lineIndex]
		end

		local settingsFilePath = "onionSettings.db"
		local currentSettingsFileContents = readfile(settingsFilePath)
		local remainingSettingsLines = {}

		if currentSettingsFileContents ~= nil and currentSettingsFileContents ~= "" then
			local existingLines = splitString(currentSettingsFileContents, "\n")
			local lineIndex = 1

			while lineIndex <= #existingLines do
				if string.find(existingLines[lineIndex], "map: ") and lineIndex + 5 <= #existingLines then
					local mapName = string.gsub(existingLines[lineIndex], "map: ", "")

					if not string.find(mapName, currentMapName) then
						table.insert(remainingSettingsLines, existingLines[lineIndex])
						table.insert(remainingSettingsLines, existingLines[lineIndex + 1])
						table.insert(remainingSettingsLines, existingLines[lineIndex + 2])
						table.insert(remainingSettingsLines, existingLines[lineIndex + 3])
						table.insert(remainingSettingsLines, existingLines[lineIndex + 4])
						table.insert(remainingSettingsLines, existingLines[lineIndex + 5])
					end

					lineIndex = lineIndex + 6
				else
					table.insert(remainingSettingsLines, existingLines[lineIndex])
					lineIndex = lineIndex + 1
				end
			end
		end

		local remainingSettingsText = nil

		for lineIndex = 1, #remainingSettingsLines do
			remainingSettingsText = remainingSettingsText ~= nil and remainingSettingsText ~= "" and remainingSettingsText .. "\n" .. remainingSettingsLines[lineIndex] or remainingSettingsLines[lineIndex]
		end

		client.color_log(255, 255, 255, currentMapName)

		if remainingSettingsText ~= nil and remainingSettingsText ~= "" then
			client.color_log(255, 255, 255, "Mainframe 1/2")
			writefile(settingsFilePath, remainingSettingsText .. "\nmap: " .. currentMapName .. "\n" .. serializedWeaponSettings)
		else
			client.color_log(255, 255, 255, "Mainframe 2")
			writefile(settingsFilePath, "map: " .. currentMapName .. "\n" .. serializedWeaponSettings)
		end
	else
		client.color_log(255, 255, 255, "Please step inside a location to save settings.")
	end
end

refreshPositionData()

if currentMapName ~= nil and #positionNames ~= 0 then
	locationCombobox = ui.new_combobox("LUA", "B", "Location", positionNames)
end

local logLocationButton = ui.new_button("LUA", "B", "Log Location", logCurrentLocation)
local createPositionButton = ui.new_button("LUA", "B", "Create Position", createPosition)

if currentMapName ~= nil and #positionNames ~= 0 then
	local deletePositionButton = ui.new_button("LUA", "B", "Delete Position", deletePosition)
end

local updateSettingsButton = ui.new_button("LUA", "B", "Update Settings", updateSettingsButtonCallback)
local saveSettingsButton = ui.new_button("LUA", "B", "Save Settings", saveCurrentSettings)

for weaponIndex = 1, #weaponDefinitions do
	table.insert(weaponUiRows, {
		ui.new_checkbox("LUA", "B", "Double Tap"),
		ui.new_slider("LUA", "B", "Minimum hit chance", 0, 100, 10),
		ui.new_slider("LUA", "B", "Minimum Damage", 0, 126, 10),
		ui.new_checkbox("LUA", "B", "Force Safe-Point on Limbs"),
		ui.new_checkbox("LUA", "B", "Prefer Safe-Point"),
		ui.new_checkbox("LUA", "B", "Override Aimbot")
	})
end

refreshPositionData()

client.set_event_callback("paint", function ()
	currentPlayerEntity = entity.get_local_player()
	currentMapPathParts = splitString(globals.mapname(), "/")
	currentMapName = currentMapPathParts[#currentMapPathParts]

	for controlIndex = 1, #customColorControls do
		ui.set_visible(customColorControls[controlIndex], ui.get(customColorsCheckbox))
	end

	if ui.get(mainEnabledCheckbox) and currentPlayerEntity ~= nil and entity.is_alive(currentPlayerEntity) then
		currentWeaponClass = entity.get_classname(entity.get_player_weapon(currentPlayerEntity))
		currentPlayerX, currentPlayerY, currentPlayerZ = entity.get_origin(currentPlayerEntity)
		currentPlayerScreenX, currentPlayerScreenY = renderer.world_to_screen(currentPlayerX, currentPlayerY, currentPlayerZ)
		currentPlayerCeilingZ = currentPlayerZ + 100000 * client.trace_line(currentPlayerEntity, currentPlayerX, currentPlayerY, currentPlayerZ, currentPlayerX, currentPlayerY, currentPlayerZ + 100000)

		ui.set(weaponHeaderLabel, "-+-+-+-+ [ Aim - " .. currentWeaponClass .. " ] +-+-+-+-")

		for weaponIndex = 1, #weaponDefinitions do
			if currentWeaponClass ~= weaponDefinitions[weaponIndex][1] then
				for widgetIndex = 1, #weaponUiRows[weaponIndex] do
					ui.set_visible(weaponUiRows[weaponIndex][widgetIndex], false)
				end
			else
				for widgetIndex = 1, #weaponUiRows[weaponIndex] do
					ui.set_visible(weaponUiRows[weaponIndex][widgetIndex], true)
				end
			end
		end

		if locationMarker[1] then
			local markerScreenX, markerScreenY = renderer.world_to_screen(locationMarker[2], locationMarker[3], locationMarker[4])
			local xAxisScreenX, xAxisScreenY = renderer.world_to_screen(currentPlayerX, locationMarker[3], locationMarker[4])
			local yAxisScreenX, yAxisScreenY = renderer.world_to_screen(locationMarker[2], currentPlayerY, locationMarker[4])
			local playerScreenAtMarkerZ, playerScreenAtMarkerZY = renderer.world_to_screen(currentPlayerX, currentPlayerY, locationMarker[4])

			renderer.line(markerScreenX, markerScreenY, xAxisScreenX, xAxisScreenY, 255, 255, 255, 255)
			renderer.line(markerScreenX, markerScreenY, yAxisScreenX, yAxisScreenY, 255, 255, 255, 255)
			renderer.line(playerScreenAtMarkerZ, playerScreenAtMarkerZY, xAxisScreenX, xAxisScreenY, 255, 255, 255, 255)
			renderer.line(playerScreenAtMarkerZ, playerScreenAtMarkerZY, yAxisScreenX, yAxisScreenY, 255, 255, 255, 255)
		end

		if ui.get(debugLinesCheckbox) then
			for side = 0, 1 do
				local yAxisHit = client.trace_line(currentPlayerEntity, currentPlayerX, currentPlayerY, currentPlayerZ, currentPlayerX, currentPlayerY - 100 + 200 * side, currentPlayerZ)
				local xAxisScreenX, xAxisScreenY = renderer.world_to_screen(currentPlayerX + (-100 + 200 * side) * client.trace_line(currentPlayerEntity, currentPlayerX, currentPlayerY, currentPlayerZ, currentPlayerX - 100 + 200 * side, currentPlayerY, currentPlayerZ), currentPlayerY, currentPlayerZ)
				local yAxisScreenX, yAxisScreenY = renderer.world_to_screen(currentPlayerX, currentPlayerY + (-100 + 200 * side) * yAxisHit, currentPlayerZ)

				renderer.line(currentPlayerScreenX, currentPlayerScreenY, yAxisScreenX, yAxisScreenY, 255, 255, 255, 255)
				renderer.line(currentPlayerScreenX, currentPlayerScreenY, xAxisScreenX, xAxisScreenY, 255, 255, 255, 255)
			end

			local ceilingScreenX, ceilingScreenY = renderer.world_to_screen(currentPlayerX, currentPlayerY, currentPlayerCeilingZ)
			renderer.line(currentPlayerScreenX, currentPlayerScreenY, ceilingScreenX, ceilingScreenY, 255, 255, 255, 255)
		end

		regionIsActive = false

		for regionIndex = 1, #positionEntries do
			if isPointInsideBounds(positionEntries[regionIndex][3][1], positionEntries[regionIndex][4][1], positionEntries[regionIndex][3][2], positionEntries[regionIndex][4][2], currentPlayerX, currentPlayerY) then
				regionIsActive = true

				if activeRegionName ~= positionEntries[regionIndex][1] then
					activeRegionName = positionEntries[regionIndex][1]
					onActiveRegionChanged()
				end

				for weaponIndex = 1, #weaponDefinitions do
					if currentWeaponClass == weaponDefinitions[weaponIndex][1] and ui.get(weaponUiRows[weaponIndex][6]) then
						if not ui.get(disableRechargeInRegionCheckbox) then
							ui.set(rageReferences.dt, ui.get(weaponUiRows[weaponIndex][1]))
						end

						ui.set(rageReferences.hitchance, ui.get(weaponUiRows[weaponIndex][2]))
						ui.set(rageReferences.mindamage, ui.get(weaponUiRows[weaponIndex][3]))
						ui.set(rageReferences.limbsafe, ui.get(weaponUiRows[weaponIndex][4]))
						ui.set(rageReferences.prefersafe, ui.get(weaponUiRows[weaponIndex][5]))
					end
				end

				if not regionActivationLatch then
					regionActivationLatch = true
					activeRegionIndex = regionIndex
				end

				if weaponFiredSinceEntry and currentWeaponClass ~= "CWeaponAWP" and currentWeaponClass ~= "CWeaponSSG08" and ui.get(disableRechargeInRegionCheckbox) then
					if dtRestorePending then
						ui.set(rageReferences.dt, false)
					else
						ui.set(rageReferences.dt, true)
					end
				end

				local topRightScreenX, topRightScreenY = renderer.world_to_screen(positionEntries[regionIndex][3][1], positionEntries[regionIndex][3][2], positionEntries[regionIndex][2])
				local topLeftScreenX, topLeftScreenY = renderer.world_to_screen(positionEntries[regionIndex][3][1], positionEntries[regionIndex][4][2], positionEntries[regionIndex][2])
				local bottomLeftScreenX, bottomLeftScreenY = renderer.world_to_screen(positionEntries[regionIndex][4][1], positionEntries[regionIndex][3][2], positionEntries[regionIndex][2])
				local bottomRightScreenX, bottomRightScreenY = renderer.world_to_screen(positionEntries[regionIndex][4][1], positionEntries[regionIndex][4][2], positionEntries[regionIndex][2])

				if ui.get(customColorControls[3]) and ui.get(customColorsCheckbox) then
					renderer.triangle(topLeftScreenX, topLeftScreenY, bottomRightScreenX, bottomRightScreenY, bottomLeftScreenX, bottomLeftScreenY, ui.get(customColorControls[4]))
					renderer.triangle(topLeftScreenX, topLeftScreenY, topRightScreenX, topRightScreenY, bottomLeftScreenX, bottomLeftScreenY, ui.get(customColorControls[4]))
				else
					renderer.triangle(topLeftScreenX, topLeftScreenY, bottomRightScreenX, bottomRightScreenY, bottomLeftScreenX, bottomLeftScreenY, 255, 255, 255, 150)
					renderer.triangle(topLeftScreenX, topLeftScreenY, topRightScreenX, topRightScreenY, bottomLeftScreenX, bottomLeftScreenY, 255, 255, 255, 150)
				end
			else
				if (not regionActivationLatch or regionIndex == activeRegionIndex) and weaponFiredSinceEntry and currentWeaponClass ~= "CWeaponAWP" and currentWeaponClass ~= "CWeaponSSG08" and ui.get(disableRechargeInRegionCheckbox) then
					ui.set(rageReferences.dt, true)
					dtRestorePending = false
					regionActivationLatch = false
					activeRegionIndex = nil
				end

				if math.sqrt((currentPlayerX - positionEntries[regionIndex][4][1])^2 + (currentPlayerY - positionEntries[regionIndex][4][2])^2) <= ui.get(drawDistanceSlider) or math.sqrt((currentPlayerX - positionEntries[regionIndex][3][1])^2 + (currentPlayerY - positionEntries[regionIndex][3][2])^2) <= ui.get(drawDistanceSlider) then
					local topRightScreenX, topRightScreenY = renderer.world_to_screen(positionEntries[regionIndex][3][1], positionEntries[regionIndex][3][2], positionEntries[regionIndex][2])
					local topLeftScreenX, topLeftScreenY = renderer.world_to_screen(positionEntries[regionIndex][3][1], positionEntries[regionIndex][4][2], positionEntries[regionIndex][2])
					local bottomLeftScreenX, bottomLeftScreenY = renderer.world_to_screen(positionEntries[regionIndex][4][1], positionEntries[regionIndex][3][2], positionEntries[regionIndex][2])
					local bottomRightScreenX, bottomRightScreenY = renderer.world_to_screen(positionEntries[regionIndex][4][1], positionEntries[regionIndex][4][2], positionEntries[regionIndex][2])

					if ui.get(customColorControls[1]) and ui.get(customColorsCheckbox) then
						renderer.triangle(topLeftScreenX, topLeftScreenY, bottomRightScreenX, bottomRightScreenY, bottomLeftScreenX, bottomLeftScreenY, ui.get(customColorControls[2]))
						renderer.triangle(topLeftScreenX, topLeftScreenY, topRightScreenX, topRightScreenY, bottomLeftScreenX, bottomLeftScreenY, ui.get(customColorControls[2]))
					else
						renderer.triangle(topLeftScreenX, topLeftScreenY, bottomRightScreenX, bottomRightScreenY, bottomLeftScreenX, bottomLeftScreenY, 255, 255, 255, 150)
						renderer.triangle(topLeftScreenX, topLeftScreenY, topRightScreenX, topRightScreenY, bottomLeftScreenX, bottomLeftScreenY, 255, 255, 255, 150)
					end
				end
			end
		end
	else
		for weaponIndex = 1, #weaponUiRows do
			for widgetIndex = 1, #weaponUiRows[weaponIndex] do
				ui.set_visible(weaponUiRows[weaponIndex][widgetIndex], false)
			end
		end
	end
end)

client.set_event_callback("weapon_fire", function (event)
	if currentPlayerEntity ~= nil and client.userid_to_entindex(event.userid) == currentPlayerEntity then
		weaponFiredSinceEntry = true
	end
end)
