local hide_error_models_checkbox = ui.new_checkbox("MISC", "Miscellaneous", "Hide error models")

local function hide_error_model(entity_index)
	for _, material in ipairs(materialsystem.get_model_materials(entity_index)) do
		if material:get_name() == "models/error/error" then
			material:set_material_var_flag(2, true)
			entity.set_prop(entity_index, "m_fEffects", 32)
		end
	end
end

require("gamesense/netvar_hooks").hook_prop("DT_BaseEntity", "m_fEffects", function (_, entity_index)
	if ui.get(hide_error_models_checkbox) and entity.get_classname(entity_index) == "CDynamicProp" then
		hide_error_model(entity_index)
		client.delay_call(0, hide_error_model, entity_index)
	end
end)
ui.set_callback(hide_error_models_checkbox, function ()
	if ui.get(hide_error_models_checkbox) then
		for _, dynamic_prop in ipairs(entity.get_all("CDynamicProp")) do
			hide_error_model(dynamic_prop)
		end
	end
end)
