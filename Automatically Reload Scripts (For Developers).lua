local is_in_game = vtable_bind("engine.dll", "VEngineClient014", 196, "bool(__thiscall*)(void*)")
local crc32_lookup = {}
local loaded_script_hashes = {}

local function crc32(text, lookup_table)
	local table_cache = lookup_table or crc32_lookup

	if not table_cache[1] then
		for index = 1, 256 do
			local value = index - 1

			for _ = 1, 8 do
				value = bit.bxor(bit.rshift(value, 1), bit.band(3988292384.0, -bit.band(value, 1)))
			end

			table_cache[index] = value
		end
	end

	local hash = 4294967295.0

	for index = 1, #text do
		hash = bit.bxor(bit.rshift(hash, 8), table_cache[bit.band(bit.bxor(hash, string.byte(text, index)), 255) + 1])
	end

	return bit.band(bit.bnot(hash), 4294967295.0)
end

local function refresh_active_scripts()
	for script_name in pairs(package.loaded) do
		local script_source = readfile(script_name .. ".lua")

		if script_source ~= nil then
			local script_hash = crc32(script_source)

			if loaded_script_hashes[script_name] ~= nil then
				if loaded_script_hashes[script_name] ~= script_hash then
					print(string.format("%s was changed, reloading active scripts!", script_name))
					client.reload_active_scripts()

					return
				end
			else
				loaded_script_hashes[script_name] = script_hash
			end
		end
	end
end

local was_in_game = false

client.set_event_callback("paint_ui", function ()
	local in_game = is_in_game()

	if was_in_game == false and in_game then
		refresh_active_scripts()
		client.delay_call(0.5, refresh_active_scripts)
	end

	was_in_game = in_game
end)
