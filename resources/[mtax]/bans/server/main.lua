_G.Bans = {
    records = {},
    index   = {},
    nextId  = 1,
}

local connection = dbConnect("sqlite", "bans.db")

local SLOTS = { "ip", "username", "serial" }

local REASON_MAX_LENGTH = Config.ReasonMaxLength
local NICK_MAX_LENGTH = Config.NickMaxLength
local VALUE_MAX_LENGTH = Config.ValueMaxLength

local KIND = {}
for _, kind in ipairs(Config.Identifiers) do
    KIND[kind] = true
end

if connection then
    dbExec(connection, "CREATE TABLE IF NOT EXISTS bans ( id INTEGER PRIMARY KEY, ip TEXT, username TEXT, " ..
        "serial TEXT, nick TEXT, reason TEXT, admin TEXT, banTime INTEGER, unbanTime INTEGER )")
else
    outputDebugString("[bans] - Database not found", 4, 244, 67, 54)
    stopResource(getThisResource())
end

addEvent("onBan", false)
addEvent("onUnban", false)
addEvent("onPlayerBan", false)


local function isPlayerElement(element)
    return isElement(element) and getElementType(element) == "player"
end

local function stamp()
    local time = getRealTime()
    return type(time) == "table" and tonumber(time.timestamp) or 0
end

local function text(value, limit)
    if type(value) ~= "string" then
        return ""
    end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return #value > limit and value:sub(1, limit) or value
end

local function identifier(value, fallback)
    value = text(value, VALUE_MAX_LENGTH)
    if value == "" then
        return ""
    end

    local kind, rest = value:match("^([%a][%w_]*):(.+)$")
    if kind and KIND[kind:lower()] and rest ~= "" then
        return kind:lower() .. ":" .. rest
    end

    return fallback .. ":" .. value
end

local function present(value, fallback)
    if type(value) ~= "string" or value == "" then
        return false
    end

    local kind, rest = value:match("^([%a][%w_]*):(.+)$")
    if kind == fallback then
        return rest
    end
    return value
end

local function responsibleName(responsible)
    if isPlayerElement(responsible) then
        return getPlayerName(responsible) or "Console"
    end

    local name = text(responsible, NICK_MAX_LENGTH)
    return name ~= "" and name or "Console"
end

local function playerIdentifier(thePlayer, kind)
    for _, value in ipairs(getPlayerIdentifiers(thePlayer) or {}) do
        local found = value:match("^" .. kind .. ":(.+)$")
        if found then
            return found
        end
    end
    return ""
end


local function indexRecord(record)
    for _, slot in ipairs(SLOTS) do
        local value = record[slot]
        if value ~= "" then
            local bucket = _G.Bans.index[value]
            if not bucket then
                bucket = {}
                _G.Bans.index[value] = bucket
            end
            bucket[#bucket + 1] = record.id
        end
    end
end

local function unindexRecord(record)
    for _, slot in ipairs(SLOTS) do
        local value = record[slot]
        local bucket = value ~= "" and _G.Bans.index[value]
        if bucket then
            for position = #bucket, 1, -1 do
                if bucket[position] == record.id then
                    table.remove(bucket, position)
                end
            end
            if #bucket == 0 then
                _G.Bans.index[value] = nil
            end
        end
    end
end

local function fromRow(row)
    return {
        id        = tonumber(row.id) or 0,
        ip        = type(row.ip) == "string" and row.ip or "",
        username  = type(row.username) == "string" and row.username or "",
        serial    = type(row.serial) == "string" and row.serial or "",
        nick      = type(row.nick) == "string" and row.nick or "",
        reason    = type(row.reason) == "string" and row.reason or "",
        admin     = type(row.admin) == "string" and row.admin or "Console",
        banTime   = tonumber(row.banTime) or 0,
        unbanTime = tonumber(row.unbanTime) or 0,
    }
end

local function copy(record)
    return {
        id        = record.id,
        ip        = present(record.ip, Config.Slot.ip) or "",
        username  = present(record.username, Config.Slot.username) or "",
        serial    = present(record.serial, Config.Slot.serial) or "",
        nick      = record.nick,
        reason    = record.reason,
        admin     = record.admin,
        banTime   = record.banTime,
        unbanTime = record.unbanTime,
    }
end

local function isExpired(record, at)
    return record.unbanTime > 0 and at >= record.unbanTime
end

local function forget(record)
    unindexRecord(record)
    _G.Bans.records[record.id] = nil
    if connection then
        dbExec(connection, "DELETE FROM bans WHERE id = ?", record.id)
    end
end

local function resolve(theBan)
    if type(theBan) ~= "table" then
        return false
    end

    local id = tonumber(theBan.id)
    if not id then
        return false
    end
    return _G.Bans.records[id] or false
end


---@return boolean
function reloadBans()
    if not connection then
        return false
    end

    _G.Bans.records = {}
    _G.Bans.index = {}
    _G.Bans.nextId = 1

    local rows = dbPoll(dbQuery(connection, "SELECT * FROM bans"), -1) or {}
    local at = stamp()

    for _, row in ipairs(rows) do
        local record = fromRow(row)
        if record.id > 0 then
            if record.id >= _G.Bans.nextId then
                _G.Bans.nextId = record.id + 1
            end

            if isExpired(record, at) then
                dbExec(connection, "DELETE FROM bans WHERE id = ?", record.id)
            else
                _G.Bans.records[record.id] = record
                indexRecord(record)
            end
        end
    end

    return true
end

---@param value any
---@return boolean
function isBan(value)
    return resolve(value) ~= false
end

---@return table
function getBans()
    local list = {}
    for _, record in pairs(_G.Bans.records) do
        list[#list + 1] = copy(record)
    end

    table.sort(list, function(first, second) return first.id < second.id end)
    return list
end


---@param ip? string
---@param username? string
---@param serial? string
---@param responsible? Element|string
---@param reason? string
---@param seconds? number
---@return table|false
function addBan(ip, username, serial, responsible, reason, seconds)
    if not connection then
        return false
    end

    local record = {
        id        = _G.Bans.nextId,
        ip        = identifier(ip, Config.Slot.ip),
        username  = identifier(username, Config.Slot.username),
        serial    = identifier(serial, Config.Slot.serial),
        nick      = "",
        reason    = text(reason, REASON_MAX_LENGTH),
        admin     = responsibleName(responsible),
        banTime   = stamp(),
        unbanTime = 0,
    }

    if record.ip == "" and record.username == "" and record.serial == "" then
        return false
    end

    local duration = tonumber(seconds)
    if duration and duration > 0 then
        record.unbanTime = record.banTime + math.floor(duration)
    end

    _G.Bans.nextId = _G.Bans.nextId + 1
    _G.Bans.records[record.id] = record
    indexRecord(record)

    dbExec(connection, "INSERT INTO bans ( id, ip, username, serial, nick, reason, admin, banTime, unbanTime ) " ..
        "VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ? )",
        record.id, record.ip, record.username, record.serial, record.nick, record.reason, record.admin,
        record.banTime, record.unbanTime)

    local source = isPlayerElement(responsible) and responsible or root
    triggerEvent("onBan", source, copy(record))

    if not _G.Bans.records[record.id] then
        return false
    end
    return copy(record)
end

---@param thePlayer Element
---@param byIP? boolean
---@param byUsername? boolean
---@param bySerial? boolean
---@param responsible? Element|string
---@param reason? string
---@param seconds? number
---@return table|false
function banPlayer(thePlayer, byIP, byUsername, bySerial, responsible, reason, seconds)
    if not isPlayerElement(thePlayer) then
        return false
    end

    if byIP == nil then byIP = true end
    if byUsername == nil then byUsername = false end
    if bySerial == nil then bySerial = false end

    local theBan = addBan(
        byIP == true and getPlayerIP(thePlayer) or nil,
        byUsername == true and playerIdentifier(thePlayer, Config.Slot.username) or nil,
        bySerial == true and playerIdentifier(thePlayer, Config.Slot.serial) or nil,
        responsible, reason, seconds)

    if not theBan then
        return false
    end

    local record = resolve(theBan)
    record.nick = text(getPlayerName(thePlayer), NICK_MAX_LENGTH)
    if connection then
        dbExec(connection, "UPDATE bans SET nick = ? WHERE id = ?", record.nick, record.id)
    end

    triggerEvent("onPlayerBan", thePlayer, copy(record), isPlayerElement(responsible) and responsible or nil)

    if not _G.Bans.records[record.id] then
        return false
    end

    kickPlayer(thePlayer, isPlayerElement(responsible) and responsible or record.admin,
        record.reason ~= "" and record.reason or Config.Text.Refused)
    return copy(record)
end

---@param theBan table
---@param responsible? Element|string
---@return boolean
function removeBan(theBan, responsible)
    local record = resolve(theBan)
    if not record then
        return false
    end

    forget(record)
    triggerEvent("onUnban", isPlayerElement(responsible) and responsible or root, copy(record))
    return true
end


local function getter(slot, fallback)
    return function(theBan)
        local record = resolve(theBan)
        return record and present(record[slot], fallback) or false
    end
end

getBanIP = getter("ip", Config.Slot.ip)
getBanUsername = getter("username", Config.Slot.username)
getBanSerial = getter("serial", Config.Slot.serial)

---@param theBan table
---@return string|false
function getBanNick(theBan)
    local record = resolve(theBan)
    return record and record.nick or false
end

---@param theBan table
---@return string|false
function getBanReason(theBan)
    local record = resolve(theBan)
    return record and record.reason or false
end

---@param theBan table
---@return string|false
function getBanAdmin(theBan)
    local record = resolve(theBan)
    return record and record.admin or false
end

---@param theBan table
---@return number|false
function getBanTime(theBan)
    local record = resolve(theBan)
    return record and record.banTime or false
end

---@param theBan table
---@return number|false
function getUnbanTime(theBan)
    local record = resolve(theBan)
    return record and record.unbanTime or false
end


local function setter(slot, column, prepare)
    return function(theBan, value)
        local record = resolve(theBan)
        local prepared = record and prepare(value)
        if not record or prepared == nil then
            return false
        end

        record[slot] = prepared
        if connection then
            dbExec(connection, "UPDATE bans SET " .. column .. " = ? WHERE id = ?", prepared, record.id)
        end
        return true
    end
end

setBanReason = setter("reason", "reason", function(value)
    return type(value) == "string" and text(value, REASON_MAX_LENGTH) or nil
end)

setBanAdmin = setter("admin", "admin", function(value)
    return (isPlayerElement(value) or type(value) == "string") and responsibleName(value) or nil
end)

setBanNick = setter("nick", "nick", function(value)
    return type(value) == "string" and text(value, NICK_MAX_LENGTH) or nil
end)

setUnbanTime = setter("unbanTime", "unbanTime", function(value)
    local time = tonumber(value)
    return time and time >= 0 and math.floor(time) or nil
end)


local function matchIdentifiers(identifiers)
    local at = stamp()
    local stale = {}
    local hit = false

    for _, value in ipairs(identifiers) do
        for _, id in ipairs(_G.Bans.index[value] or {}) do
            local record = _G.Bans.records[id]
            if record then
                if isExpired(record, at) then
                    stale[#stale + 1] = record
                elseif not hit then
                    hit = record
                end
            end
        end
    end

    for _, record in ipairs(stale) do
        forget(record)
    end
    return hit
end

local function refusal(record)
    local message = Config.Text.Refused
    if record.unbanTime > 0 then
        local time = getRealTime(record.unbanTime)
        if type(time) == "table" then
            message = string.format(Config.Text.WithTime, string.format("%04d-%02d-%02d %02d:%02d",
                time.year + 1900, time.month + 1, time.monthday, time.hour, time.minute))
        end
    end

    if record.reason ~= "" then
        message = message .. string.format(Config.Text.Reason, record.reason)
    end
    return message
end

addEventHandler("onPlayerConnect", root, function(nick, ip, password, identifiers)
    if type(identifiers) ~= "table" then
        identifiers = {}
    end

    local candidates = {}
    for _, value in ipairs(identifiers) do
        candidates[#candidates + 1] = value
    end
    if type(ip) == "string" and ip ~= "" then
        candidates[#candidates + 1] = Config.Slot.ip .. ":" .. ip
    end

    local record = matchIdentifiers(candidates)
    if record then
        outputDebugString("[bans] - refused " .. tostring(nick) .. " (ban #" .. record.id .. ")", 3)
        cancelEvent(true, refusal(record))
    end
end)

addEventHandler("onResourceStart", resourceRoot, function()
    reloadBans()

    if Config.SweepInterval > 0 then
        setTimer(function()
            local at = stamp()
            local stale = {}
            for _, record in pairs(_G.Bans.records) do
                if isExpired(record, at) then
                    stale[#stale + 1] = record
                end
            end
            for _, record in ipairs(stale) do
                forget(record)
            end
        end, Config.SweepInterval, 0)
    end
end)
