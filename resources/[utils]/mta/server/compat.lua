_MTA_COMPAT = _MTA_COMPAT or {}

local internal = nil

local function internalDatabase()
    if internal == nil then
        internal = dbConnect("sqlite", "mta_internal.db") or false
        if not internal then
            _MTA_COMPAT.warnOnce("executeSQLQuery", "could not open mta_internal.db; every call returns false")
        end
    end
    return internal
end

function executeSQLQuery(query, ...)
    if type(query) ~= "string" or query == "" then
        return false
    end

    local connection = internalDatabase()
    if not connection then
        return false
    end

    local handle = dbQuery(connection, query, ...)
    if not handle then
        return false
    end

    local rows = dbPoll(handle, -1)
    return type(rows) == "table" and rows or false
end

function triggerLatentClientEvent(...)
    local args = { ... }
    local at = 1
    local sendTo = root

    if type(args[1]) == "table" or isElement(args[1]) then
        sendTo = args[1]
        at = 2
    end

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

    _MTA_COMPAT.warnOnce("triggerLatentClientEvent",
        "MTAX has no latent channel; '" .. name .. "' was sent as a normal triggerClientEvent")

    return triggerClientEvent(sendTo, name, source, unpack(args, at, table.maxn(args))) == true
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

function setElementSyncer(element)
    if not isElement(element) then
        return false
    end
    _MTA_COMPAT.warnOnce("setElementSyncer",
        "the syncer is elected by the server and cannot be set from script; the call was ignored")
    return false
end

function getElementSyncer()
    return false
end
