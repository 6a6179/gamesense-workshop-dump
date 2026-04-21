local isEnemy = entity.is_enemy
local getPlistValue = plist.get

client.register_esp_flag("FAKE", 255, 255, 255, function (entityIndex)
	if isEnemy(entityIndex) then
		return getPlistValue(entityIndex, "Correction active")
	end
end)
