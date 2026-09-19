_MTA_COMPAT = _MTA_COMPAT or {}

function triggerLatentServerEvent(...)
    local args = { ... }
    local at = 1

    local name = args[at]
    at = at + 1
    if type(name) ~= "string" or name == "" then
        return false
    end

    if not isElement(args[at]) and tonumber(args[at]) ~= nil then
        at = at + 1
    end
    if type(args[at]) == "boolean" then
        at = at + 1
    end

    local source = args[at]
    at = at + 1
    if not isElement(source) then
        return false
    end

    _MTA_COMPAT.warnOnce("triggerLatentServerEvent",
        "MTAX has no latent channel; '" .. name .. "' was sent as a normal triggerServerEvent")

    return triggerServerEvent(name, source, unpack(args, at, table.maxn(args))) == true
end

function getLatentEventStatus()
    return false
end

function getLatentEventHandles()
    return {}
end

function cancelLatentEvent()
    return false
end

function isElementSyncer()
    return false
end
