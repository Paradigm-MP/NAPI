local NetworkEvent = class()

local NetworkEvent_id = 0
function NetworkEvent:__init(name, instance, callback)
    self.name = name
    self.instance = instance
    self.callback = callback
    self.id = NetworkEvent_id
    NetworkEvent_id = NetworkEvent_id + 1
end

function NetworkEvent:Unsubscribe()
    Network:Unsubscribe(self.name, self.id)
end

function NetworkEvent:Receive(source, args, name)
    -- source is nil if this is clientside, otherwise it is the player who sent it
    local player = sPlayers:GetById(source)
    local return_args = {source = source, player = player}
    local is_fetch = false
    local fetch_id

    if args then
        is_fetch = args.__is_fetch
        fetch_id = args.__fetch_id
        args.__is_fetch = nil
        args.__fetch_id = nil
        for k, v in pairs(args) do
            return_args[k] = v 
        end 
    end
    
    local return_value
    if self.callback then
        return_value = self.callback(self.instance, return_args)
    else
        local callback = self.instance
        return_value = callback(return_args)
    end

    if is_fetch then
        Network:Send(name .. "__FetchCallback" .. tostring(fetch_id), player, return_value)
    end
end

Network = class()

function Network:__init()
    self.subs = {}
    self.handlers = {}
end

function Network:Send(name, players, args)
    assert(name ~= nil and type(name) == "string", "cannot Network:Send without valid networkevent")

    assert(type(players) == "number" or type(players) == "table" or is_class_instance(players, Player), 
        "cannot Network:Send without valid player id(s). Specify -1 for all, one id, or a table")
    
    if type(players) == "number" then
        TriggerClientEvent(name, players, args)
    elseif is_class_instance(players, Player) then
        TriggerClientEvent(name, players:GetId(), args)
    elseif type(players) == "table" then
        for _, id in pairs(players) do
            TriggerClientEvent(name, id, args)
        end
    end
end

function Network:Broadcast(name, args)
    self:Send(name, -1, args)
end

--[[
    Subscribe to a network event.

    Example usage:
    Network:Subscribe("PlayerLoaded", function(args)
    end)
]]
function Network:Subscribe(name, instance, callback)
    assert(name ~= nil, "cannot subscribe networkevent without name")
    assert(type(instance) == "table" or type(instance) == "function", "callback function non-existant or no callback instance provided. Function usage is Network:Subscribe(name, instance, callback) or Network:Subscribe(name, callback)")

    if not self.subs[name] then
        self.subs[name] = {}
        RegisterNetEvent(name)
        self.handlers[name] = AddEventHandler(name, function(args)
            for _, networkevent in pairs(self.subs[name]) do
                networkevent:Receive(source, args, name)
            end
        end)
    end

    local networkevent = NetworkEvent(name, instance, callback)
    self.subs[name][networkevent.id] = networkevent

    return networkevent
end

function Network:Unsubscribe(name, id)
    assert(name ~= nil, "cannot unsubscribe networkevent without name")

    assert(self.subs[name] ~= nil and self.subs[name][id] ~= nil, "cannot unsubscribe NetworkEvent that does not exist")
    self.subs[name][id] = nil

    if count_table(self.subs[name]) == 0 then
        RemoveEventHandler(self.handlers[name])
        self.subs[name] = nil
        self.handlers[name] = nil
    end
end

Network = Network()