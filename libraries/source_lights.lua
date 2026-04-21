local ffi = require("ffi")
local ffi_cast = ffi.cast
local ffi_new = ffi.new
local vector = require("vector")

local light_flags = {
	DLIGHT_NO_WORLD_ILLUMINATION = 1,
	DLIGHT_DISPLACEMENT_MASK = 12,
	DLIGHT_SUBTRACT_DISPLACEMENT_ALPHA = 8,
	DLIGHT_ADD_DISPLACEMENT_ALPHA = 4,
	DLIGHT_NO_MODEL_ILLUMINATION = 2
}

local create_dlight = vtable_bind("engine.dll", "VEngineEffects001", 4, "void*(__thiscall*)(void*,int)")
local create_elight = vtable_bind("engine.dll", "VEngineEffects001", 5, "void*(__thiscall*)(void*,int)")
local get_elight_by_key = vtable_bind("engine.dll", "VEngineEffects001", 8, "void*(__thiscall*)(void*,int)")
local light_methods = {}

local color_t = ffi.typeof([[
	struct {
		unsigned char r,g,b;
		signed char exponent;
	}
]])

local light_t = ffi.typeof("$ *", ffi.metatype(ffi.typeof([[
	struct {
		int	 flags;
		Vector  origin;
		float   radius;
		$   color;	  // Light color with exponent
		float   die;				// stop lighting after this time
		float   decay;			  // drop this each second
		float   minlight;		   // don't add when contributing less
		int	 key;
		int	 style;			  // lightstyle
		// For spotlights. Use m_OuterAngle == 0 for point lights
		Vector  m_Direction;		// center of the light cone
		float   m_InnerAngle;
		float   m_OuterAngle;
	}
]]), {
	__index = light_methods
}))

function light_methods.set_color(light, red, green, blue, exponent)
	light.color.r = red
	light.color.g = green
	light.color.b = blue
	light.color.exponent = exponent
end

function light_methods.set_flags(light, ...)
	local flags = 0

	for _, flag_name in pairs({ ... }) do
		flags = bit.bor(flags, light_flags[flag_name] or flag_name)
	end

	light.flags = flags
end

return {
	create_dlight = function(index)
		return ffi_cast(light_t, create_dlight(index))
	end,
	create_elight = function(index)
		return ffi_cast(light_t, create_elight(index))
	end,
	get_elight_by_key = function(key)
		return ffi_cast(light_t, get_elight_by_key(key))
	end
}
