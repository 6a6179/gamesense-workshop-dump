local bit_ops = require("bit")

local renderer_api = renderer
local draw_gradient = renderer_api.gradient
local draw_rectangle = renderer_api.rectangle
local draw_text = renderer_api.text
local measure_text = renderer_api.measure_text

local screen_size = client.screen_size
local get_ping = client.latency
local get_frame_time = globals.absoluteframetime
local get_tick_interval = globals.tickinterval
local get_local_player = entity.get_local_player
local get_entity_prop = entity.get_prop

local clamp_min = math.min
local clamp_max = math.max
local absolute_value = math.abs
local square_root = math.sqrt
local round_down = math.floor

local band = bit_ops.band
local bnot = bit_ops.bnot
local bor = bit_ops.bor

local history_length = 64
local half = 0.5
local one = 1
local two = 2
local three = 3
local four = 4
local five = 5
local six = 6

local history_index = 0
local histories = {
	ping = {},
	fps = {},
	var = {},
	speed = {}
}

local last_fps = 0
local last_var = 0
local last_speed = 0

local function round_to_nearest(value)
	return round_down(value + half)
end

local function ceil_value(value)
	return round_down(value + one, clamp_min(1))
end

local function push_sample(history, value)
	history[history_index] = value
end

local function advance_history_cursor()
	history_index = history_index + 1

	if history_index >= history_length then
		history_index = 0
	end
end

local function get_average(history)
	local sample_total = 0
	local sample_count = 0

	for offset = 0, history_length - 1 do
		local sample_index = history_index - offset - 1
		if sample_index < 0 then
			sample_index = history_length - 1
		end

		local sample = history[sample_index]
		if sample == nil then
			break
		end

		sample_total = sample_total + sample
		sample_count = sample_count + 1
	end

	if sample_count == 0 then
		return 0
	end

	local average = sample_total / sample_count
	if absolute_value(round_to_nearest(1 / average) - last_fps) > 5 then
		last_fps = round_to_nearest(1 / average)
	else
		average = 1 / last_fps
	end

	return round_to_nearest(1 / average)
end

local function ping_color()
	return 255, 60, 80
end

local function fps_color()
	return 255, 222, 0
end

local function var_color()
	return 159, 202, 43
end

local function write_stat(stat_table, ping, fps, var, speed)
	stat_table.ping = ping
	stat_table.fps = fps
	stat_table.var = var
	stat_table.speed = speed
end

local function write_stat_value(stat_table, value)
	stat_table.value = value
end

local function sample_ping(stat)
	if round_to_nearest(clamp_min(1000, get_ping() * 1000)) < 40 then
		write_stat(stat, ping_color())
	elseif stat.value < 100 then
		write_stat(stat, fps_color())
	else
		write_stat(stat, var_color())
	end

	write_stat_value(stat, stat.value)
end

local function sample_fps(stat)
	if get_frame_time() < 1 / clamp_max(1, round_down(1 / get_frame_time())) then
		write_stat(stat, ping_color())
	else
		write_stat(stat, fps_color())
	end

	write_stat_value(stat, stat.value)
end

local function sample_var(stat)
	if get_tick_interval() < half then
		write_stat(stat, ping_color())
	elseif stat.value > 0.5 then
		write_stat(stat, fps_color())
	else
		write_stat(stat, var_color())
	end

	write_stat_value(stat, round_to_nearest(stat.value * 1000))
end

local function sample_speed(stat)
	local local_player = get_local_player()
	local velocity_x, velocity_y = get_entity_prop(local_player, "m_vecVelocity")
	local speed = 0

	if velocity_x ~= nil and velocity_y ~= nil then
		speed = round_to_nearest(square_root(velocity_x * velocity_x + velocity_y * velocity_y))
	end

	write_stat(stat, speed)
end

local stat_entries = {
	{
		name = "PING",
		color = ping_color,
		value = 0
	},
	{
		name = "FPS",
		color = fps_color,
		value = 0
	},
	{
		name = "VAR",
		color = var_color,
		value = 0
	},
	{
		name = "SPEED",
		color = function()
			return 255, 255, 255
		end,
		value = 0
	}
}

local function draw_stat_panel(stat_entry, x, y, width, height)
	local label_width = measure_text("d", "0")
	local label_padding = ceil_value(1)
	local title_height = measure_text("d-", "0")
	local panel_height = label_padding + height + label_padding
	local panel_width = width
	local panel_half_width = panel_width * half
	local screen_width, screen_height = screen_size()
	local center_x = round_down(screen_width * half)
	local top_y = screen_height - panel_height
	local red, green, blue = stat_entry.color()

	draw_gradient(center_x - panel_width, top_y, panel_width, panel_height, 0, 0, 0, 0, 0, 0, 0, 80, true)
	draw_rectangle(center_x - panel_half_width, top_y, panel_width, panel_height, 0, 0, 0, 80)
	draw_gradient(center_x + panel_half_width, top_y, panel_half_width, panel_height, 0, 0, 0, 80, 0, 0, 0, 0, true)

	local cursor_x = center_x - panel_half_width + title_height * half
	local cursor_y = top_y + label_padding

	for index = 1, history_length do
		local history_value = histories[stat_entry.name:lower()][index] or 0
		draw_text(cursor_x, cursor_y, red, green, blue, 255, "dr", 0, tostring(history_value))
		cursor_x = cursor_x + title_height
	end

	draw_text(center_x - panel_half_width, top_y, 255, 255, 255, 175, "d-", 0, stat_entry.name .. ": " .. tostring(stat_entry.value))
end

local function sample_stats()
	advance_history_cursor()

	local local_player = get_local_player()
	local speed_value = 0
	if local_player ~= nil then
		local velocity_x, velocity_y = get_entity_prop(local_player, "m_vecVelocity")
		if velocity_x ~= nil and velocity_y ~= nil then
			speed_value = round_to_nearest(square_root(velocity_x * velocity_x + velocity_y * velocity_y))
		end
	end

	local ping_value = round_to_nearest(get_ping() * 1000)
	local frame_time = get_frame_time()
	local fps_value = frame_time > 0 and round_to_nearest(1 / frame_time) or 0
	local var_value = round_to_nearest(absolute_value(fps_value - last_fps))

	last_fps = fps_value
	last_var = var_value
	last_speed = speed_value

	histories.ping[history_index] = ping_value
	histories.fps[history_index] = fps_value
	histories.var[history_index] = var_value
	histories.speed[history_index] = speed_value

	stat_entries[1].value = ping_value
	stat_entries[2].value = fps_value
	stat_entries[3].value = var_value
	stat_entries[4].value = speed_value
end

local function paint_callback()
	sample_stats()

	for _, stat_entry in ipairs(stat_entries) do
		draw_stat_panel(stat_entry, 0, 0, 0, 0)
	end
end

client.set_event_callback("paint", paint_callback)
