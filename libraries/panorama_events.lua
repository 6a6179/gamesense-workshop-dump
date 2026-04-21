local panorama_bridge = panorama.loadstring([[
    let RegisteredEvents = {};
    let EventQueue = [];

    function _registerEvent(event){
        if ( typeof RegisteredEvents[event] != 'undefined' ) return;
        RegisteredEvents[event] = $.RegisterForUnhandledEvent(event, (...data)=>{
            EventQueue.push([event, data]);
        })
    }

    function _UnRegisterEvent(event){
        if ( typeof RegisteredEvents[event] == 'undefined' ) return;
        $.UnregisterForUnhandledEvent(event, RegisteredEvents[event]);
        delete RegisteredEvents[event];
    }

    function _getEventQueue(){
        let Queue = EventQueue;
        EventQueue = [];
        return Queue;
    }

    function _shutdown(){
        for ( event in RegisteredEvents ) {
            _UnRegisterEvent(event);
        }
    }

    return  {
        register: _registerEvent,
        unRegister: _UnRegisterEvent,
        getQueue: _getEventQueue,
        shutdown: _shutdown
    }
]])()

local event_dispatcher = {
    callbacks = {},
}
local last_poll_timestamp = client.timestamp()

client.set_event_callback("post_render", function()
    if client.timestamp() - last_poll_timestamp > 10 then
        local queued_events = panorama_bridge.getQueue()

        for event_index = 0, queued_events.length - 1 do
            local queued_event = queued_events[event_index]

            if queued_event then
                local event_name = queued_event[0]
                local event_arguments = {}

                for argument_index = 0, queued_event[1].length - 1 do
                    event_arguments[argument_index + 1] = queued_event[1][argument_index]
                end

                event_dispatcher.callbacks[event_name] = event_dispatcher.callbacks[event_name] or {}

                for _, callback in ipairs(event_dispatcher.callbacks[event_name]) do
                    callback(unpack(event_arguments))
                end
            end
        end

        last_poll_timestamp = client.timestamp()
    end
end)

client.set_event_callback("shutdown", function()
    panorama_bridge.shutdown()
end)

function event_dispatcher.register_event(event_name, callback)
    panorama_bridge.register(event_name)

    event_dispatcher.callbacks[event_name] = event_dispatcher.callbacks[event_name] or {}

    table.insert(event_dispatcher.callbacks[event_name], callback)

    return callback
end

function event_dispatcher.unregister_event(event_name, callback)
    panorama_bridge.unRegister(event_name)

    event_dispatcher.callbacks[event_name] = event_dispatcher.callbacks[event_name] or {}

    for index, registered_callback in ipairs(event_dispatcher.callbacks[event_name]) do
        if registered_callback == callback then
            table.remove(event_dispatcher.callbacks[event_name], index)
        end
    end
end

return event_dispatcher
