local set_cvar = client.set_cvar
local get_ui = ui.get
local new_slider = ui.new_slider
local set_callback = ui.set_callback
local set_visible = ui.set_visible

local aspect_slider
local screen_width, screen_height = client.screen_size()
local aspect_step = 0.01
local aspect_steps = 200

local function gcd(a, b)
	while b ~= 0 do
		a, b = b, math.fmod(a, b)
	end

	return a
end

local function apply_aspect_ratio()
	local ratio_value = 2 - get_ui(aspect_slider) * aspect_step
	set_cvar("r_aspectratio", tostring(ratio_value))
end

local function rebuild_slider(width, height)
	screen_width, screen_height = width, height

	local labels = {}
	for step = 1, aspect_steps do
		local ratio = (aspect_steps - step) * aspect_step
		local ratio_width = math.floor(width * ratio + 0.5)
		local ratio_height = height
		local divisor = gcd(ratio_width, ratio_height)

		if divisor == 0 then
			labels[step] = string.format("%.2f:1", ratio)
		else
			labels[step] = string.format("%d:%d", ratio_width / divisor, ratio_height / divisor)
		end
	end

	if aspect_slider ~= nil then
		set_visible(aspect_slider, false)
		set_callback(aspect_slider, function()
		end)
	end

	aspect_slider = new_slider("VISUALS", "Effects", "Force aspect ratio", 0, aspect_steps - 1, aspect_steps / 2, true, "%", 1, labels)
	set_callback(aspect_slider, apply_aspect_ratio)
	apply_aspect_ratio()
end

rebuild_slider(screen_width, screen_height)

client.set_event_callback("paint", function()
	local current_width, current_height = client.screen_size()
	if current_width ~= screen_width or current_height ~= screen_height then
		rebuild_slider(current_width, current_height)
	end
end)
