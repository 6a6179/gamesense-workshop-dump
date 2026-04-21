local ui_get = ui.get
local ui_set = ui.set
local disable_fakelag_on_round_end_checkbox = ui.new_checkbox("aa", "fake lag", "Disable fake lag on round end")
local fakelag_enabled_reference = ui.reference("aa", "fake lag", "enabled")

client.set_event_callback("round_start", function ()
	if ui_get(disable_fakelag_on_round_end_checkbox) then
		ui_set(fakelag_enabled_reference, true)
	end
end)
client.set_event_callback("round_end", function ()
	if ui_get(disable_fakelag_on_round_end_checkbox) then
		ui_set(fakelag_enabled_reference, false)
	end
end)
