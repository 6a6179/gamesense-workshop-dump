local layout_lines = {}
local include_paths = {
	SessionUtil = "file://{resources}/scripts/common/sessionutil.js",
	CharacterAnims = "file://{resources}/scripts/common/characteranims.js",
	FlipPanelAnimation = "file://{resources}/scripts/common/flip_panel_anim.js",
	Scheduler = "file://{resources}/scripts/common/scheduler.js",
	TeamColor = "file://{resources}/scripts/common/teamcolor.js",
	LicenseUtil = "file://{resources}/scripts/common/licenseutil.js",
	OperationUtil = "file://{resources}/scripts/operation/operation_util.js",
	ItemContextEntires = "file://{resources}/scripts/common/item_context_entries.js",
	OperationMissionCard = "file://{resources}/scripts/operation/operation_mission_card.js",
	IconUtil = "file://{resources}/scripts/common/icon.js",
	MockAdapter = "file://{resources}/scripts/mock_adapter.js",
	FormatText = "file://{resources}/scripts/common/formattext.js",
	Avatar = "file://{resources}/scripts/avatar.js",
	EventUtil = "file://{resources}/scripts/common/eventutil.js",
	ItemInfo = "file://{resources}/scripts/common/iteminfo.js"
}
local utility_names = {
	SessionUtil = true,
	CharacterAnims = true,
	FlipPanelAnimation = true,
	Scheduler = true,
	TeamColor = true,
	LicenseUtil = true,
	OperationUtil = true,
	ItemContextEntires = true,
	OperationMissionCard = true,
	IconUtil = true,
	MockAdapter = true,
	FormatText = true,
	Avatar = true,
	EventUtil = true,
	ItemInfo = true
}

table.insert(layout_lines, "<root>")
table.insert(layout_lines, "\t<scripts>")

for _, include_path in pairs(include_paths) do
	table.insert(layout_lines, "\t\t<include src=\"" .. include_path .. "\"/>")
end

table.insert(layout_lines, "\t</scripts>")
table.insert(layout_lines, "")
table.insert(layout_lines, "\t<script>")

for utility_name, _ in pairs(utility_names) do
	table.insert(layout_lines, string.format("\t\t$.GetContextPanel().%s = %s;", utility_name, utility_name))
end

table.insert(layout_lines, "\t</script>")
table.insert(layout_lines, "")
table.insert(layout_lines, "\t<Panel>")
table.insert(layout_lines, "\t</Panel>")
table.insert(layout_lines, "</root>")

local layout_xml = table.concat(layout_lines, "\n")
local context_template = [[
	let global_this = this
	let modified_props = {}

	let _Create = function(layout, utilities) {
		let parent = $.GetContextPanel()
		if(!parent)
			return false

		let panel = $.CreatePanel("Panel", parent, "")
		if(!panel)
			return false

		if(!panel.BLoadLayoutFromString(layout, false, false))
			return false

		for(name in utilities) {
			if(panel[name]) {
				// global_this[name] = panel[name]

				Object.defineProperty(global_this, name, {
					enumerable: false,
					writable: false,
					configurable: true,
					value: panel[name]
				})

				modified_props[name] = true
			}
		}

		panel.RemoveAndDeleteChildren()
		panel.DeleteAsync(0.0)
	}

	let _Destroy = function() {
		for(key in modified_props) {
			delete global_this[key];
		}
		modified_props = {}
	}

	return {
		create: _Create,
		destroy: _Destroy
	}
]]
local registered_contexts = {}

local function register_for_context(context_name, utilities)
	context_name = context_name or ""

	if registered_contexts[context_name] ~= nil then
		return false
	elseif type(context_name) ~= "string" then
		return error("invalid context, expected a non-empty string")
	elseif context_name ~= "" and context_name:gsub(" ", "") == "" then
		return error("invalid context, expected a non-empty string")
	end

	local context = context_name == "" and panorama.loadstring(context_template)() or panorama.loadstring(context_template, context_name)()

	context.create(layout_xml, utilities or utility_names)

	registered_contexts[context_name] = context
end

client.set_event_callback("shutdown", function ()
	for _, context in pairs(registered_contexts) do
		context.destroy()
	end
end)

local default_contexts = {
	"CSGOJsRegistration",
	"CSGOHud",
	"CSGOMainMenu"
}

for context_index = 1, #default_contexts do
	register_for_context(default_contexts[context_index])
end

return {
	register_for_context = register_for_context
}
