local setmetatable_fn = setmetatable
local raise_error = error
local set_event_callback = client.set_event_callback
local unset_event_callback = client.unset_event_callback
local get_value = ui.get
local new_checkbox = ui.new_checkbox
local set_value = ui.set
local set_callback = ui.set_callback
local set_visible = ui.set_visible
local pairs_fn = pairs

local control_state_by_object = {}
local control_state_by_reference = {}

local Control = {}
Control.__index = Control

local function get_state_by_object(control_object)
	return control_state_by_object[control_object] or raise_error("invalid object", 3)
end

local function get_state_by_reference(reference)
	return control_state_by_reference[reference] or raise_error("invalid reference", 2)
end

local function register_event_callback(state, event_name, callback)
	local event_state = state.event_bindings[event_name]

	if event_state == nil then
		event_state = {
			callbacks = {}
		}
		event_state.dispatcher = function (...)
			if get_value(state.reference) then
				for callback_index = 1, #event_state.callbacks do
					event_state.callbacks[callback_index](...)
				end
			end
		end
		state.event_bindings[event_name] = event_state
		set_event_callback(event_name, event_state.dispatcher)
	end

	event_state.callbacks[#event_state.callbacks + 1] = callback or raise_error("invalid callback", 3)
end

local function create_control(reference)
	local state = {
		reference = reference,
		event_bindings = {},
		change_callback = nil
	}
	local control = setmetatable_fn({}, Control)

	control_state_by_object[control] = state
	control_state_by_reference[reference] = state

	return control
end

function Control:on(event_name, callback)
	local state = get_state_by_object(self)

	if event_name == "change" then
		state.change_callback = callback or raise_error("invalid callback", 3)

		set_callback(state.reference, function (...)
			state.change_callback(...)
		end)
	else
		register_event_callback(state, event_name, callback)
	end

	return self
end

function Control:hide()
	set_visible(get_state_by_object(self).reference, false)
end

function Control:show()
	set_visible(get_state_by_object(self).reference, true)
end

function Control:get()
	return get_value(get_state_by_object(self).reference)
end

function Control:set(value)
	set_value(get_state_by_object(self).reference, value)
end

client.set_event_callback("shutdown", function ()
	for _, state in pairs_fn(control_state_by_object) do
		for event_name, event_state in pairs_fn(state.event_bindings) do
			unset_event_callback(event_name, event_state.dispatcher)
		end
	end
end)

return {
	new_checkbox = function (...)
		return create_control(new_checkbox(...))
	end
}
