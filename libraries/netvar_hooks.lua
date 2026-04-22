local ffi = require("ffi")

ffi.cdef([[
	typedef struct _ntv_RecvProp ntv_RecvProp;
	typedef struct _ntv_RecvTable ntv_RecvTable;
	typedef struct _ntv_DVariant ntv_DVariant;
	typedef struct _ntv_CRecvProxyData ntv_CRecvProxyData;
	typedef struct _ntv_ClientClass ntv_ClientClass;

	typedef void(*ntv_RecvVarProxyFn)(const ntv_CRecvProxyData*, void*, void*);
	typedef void(*ntv_ArrayLengthFn)(void*, int, int);
	typedef void(*ntv_DataTableFn)(const ntv_RecvProp*, void**, void*, int);

	typedef enum _ntv_SendPropType
	{
		DPT_Int = 0,
		DPT_Float,
		DPT_Vector,
		DPT_VectorXY,
		DPT_String,
		DPT_Array,
		DPT_DataTable,
		DPT_Int64,
		DPT_NUMSendPropTypes
	} ntv_SendPropType;

	typedef struct _ntv_DVariant
	{
		union
		{
			float		m_Float;
			long		m_Int;
			const char* m_pString;
			void*	   m_pData;
			float	   m_Vector[3];
			__int64	 m_Int64;
		};
	
		ntv_SendPropType m_Type;
	} ntv_DVariant;

	typedef struct _ntv_CRecvProxyData
	{
		const ntv_RecvProp* m_pRecvProp;
		ntv_DVariant		m_Value;
		int				m_iElement;
		int				m_ObjectID;
	} ntv_CRecvProxyData;

	typedef struct _ntv_ClientClass
	{
		void* m_pCreateFn;
		void* m_pCreateEventFn;
		const char* m_pNetworkname;
		ntv_RecvTable* m_pRecvTable;
		ntv_ClientClass* m_pNext;
		int m_ClassID;
	} ntv_ClientClass;

	typedef struct _ntv_RecvProp
	{
		const char*	 m_pVarName;
		int		 	m_RecvType;
		int				m_Flags;
		int				m_StringBufferSize;
		bool			m_bInsideArray;
		const void*		m_pExtraData;
		ntv_RecvProp*		m_pArrayProp;
		ntv_ArrayLengthFn   m_ArrayLengthProxy;
		ntv_RecvVarProxyFn	m_ProxyFn;
		ntv_DataTableFn	 m_DataTableProxyFn;
		ntv_RecvTable*	  m_pDataTable;
		int				m_Offset;
		int			 m_ElementStride;
		int				m_nElements;
		const char*		m_pParentArrayPropName;
	} ntv_RecvProp;

	typedef struct _ntv_RecvTable
	{
		ntv_RecvProp*   m_pProps;
		int			m_nPropCount;
		void*		m_pDecoder;
		const char* m_pNetTableName;
		bool		m_bInitialized;
		bool		m_bInMainList;
	} ntv_RecvTable;

	typedef struct _ntv_PackedInt
	{
		int val;
	} ntv_PackedInt;
]])

local cast = ffi.cast
local ffi_string = ffi.string

local client_interface = cast("void***", client.create_interface("client_panorama.dll", "VClient018")) or error("ChlClient is nil.")
local get_client_class_head = cast("ntv_ClientClass*(__thiscall*)(void*)", client_interface[0][8])

local netvar_tables = {}
local hooked_props = {}

local function build_netvar_table(recv_table, table_name_override)
	if recv_table.m_nPropCount == 0 then
		return
	end

	local table_name = table_name_override or ffi_string(recv_table.m_pNetTableName)

	for prop_index = 0, recv_table.m_nPropCount - 1 do
		local prop = cast("ntv_RecvProp&", recv_table.m_pProps[prop_index])

		if prop.m_RecvType == 6 and prop.m_pDataTable ~= cast("ntv_RecvTable*", 0) and prop.m_pDataTable.m_nPropCount > 0 then
			build_netvar_table(prop.m_pDataTable, table_name)
		end

		if netvar_tables[table_name] == nil then
			netvar_tables[table_name] = {}
		end

		netvar_tables[table_name][ffi_string(prop.m_pVarName)] = prop
	end
end

local function get_packed_int(proxy_data)
	return cast("ntv_PackedInt*", cast("char*", proxy_data) + 100)
end

local NetvarHook = {}
NetvarHook.__index = NetvarHook

function NetvarHook:new(prop)
	return setmetatable({
		_prop = prop or error("No prop supplied in netvar_hook:new()"),
		_original_func = prop.m_ProxyFn,
		_functions = {}
	}, self)
end

function NetvarHook:bind(callback)
	local value_extractors = {
		[0] = function (proxy_data)
			return proxy_data.m_Value.m_Int
		end,
		function (proxy_data)
			return proxy_data.m_Value.m_Float
		end,
		function (proxy_data)
			return proxy_data.m_Value.m_Vector
		end,
		function (proxy_data)
			return proxy_data.m_Value.m_Vector
		end,
		function (proxy_data)
			return proxy_data.m_Value.m_pString
		end,
		function (proxy_data)
			return proxy_data.m_Value.m_Int
		end,
		[7] = function (proxy_data)
			return proxy_data.m_Value.m_Int64
		end
	}

	self._functions[#self._functions + 1] = callback or error("No function supplied in netvar_hook:bind()")
	self._callback = cast("ntv_RecvVarProxyFn", function (proxy_data, pointer, output)
		for function_index = 1, #self._functions do
			self._functions[function_index](value_extractors[self._prop.m_RecvType](proxy_data), get_packed_int(pointer).val)
		end

		self._original_func(proxy_data, pointer, output)
	end)
	self._prop.m_ProxyFn = self._callback
end

function NetvarHook:unbind()
	self._prop.m_ProxyFn = cast("ntv_RecvVarProxyFn", self._original_func)
	self._functions = {}

	if self._callback then
		self._callback:free()
	end
end

do
	local client_class = get_client_class_head(client_interface)

	while client_class ~= cast("ntv_ClientClass*", 0) do
		if client_class.m_pRecvTable.m_nPropCount ~= 0 then
			build_netvar_table(client_class.m_pRecvTable, nil)
		end

		client_class = client_class.m_pNext
	end
end

client.set_event_callback("shutdown", function ()
	for _, hook in pairs(hooked_props) do
		hook:unbind()
	end
end)

return {
	hook_prop = function (table_name, prop_name, callback)
		local table_props = netvar_tables[table_name] or error("NetVar supplied was not found.")
		local prop = table_props[prop_name] or error("NetVar supplied was not found.")
		local hook = hooked_props[prop]

		if hook == nil then
			hook = NetvarHook:new(prop)
			hooked_props[prop] = hook
		end

		hook:bind(callback)
	end
}
