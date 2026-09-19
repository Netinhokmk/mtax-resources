_MTA_COMPAT = _MTA_COMPAT or {}

local function bans()
    if not getResourceFromName("bans") then
        _MTA_COMPAT.warnOnce("bans",
            "the [mtax]/bans resource is not running; no ban is recorded and nobody is refused at connect")
        return nil
    end
    return exports["bans"]
end

---@param ip? string
---@param username? string
---@param serial? string
---@param responsible? Element|string
---@param reason? string
---@param seconds? number
---@return table|false
function addBan(ip, username, serial, responsible, reason, seconds)
    local owner = bans()
    return owner and owner:addBan(ip, username, serial, responsible, reason, seconds) or false
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
    local owner = bans()
    return owner and owner:banPlayer(thePlayer, byIP, byUsername, bySerial, responsible, reason, seconds) or false
end

---@param theBan table
---@param responsible? Element|string
---@return boolean
function removeBan(theBan, responsible)
    local owner = bans()
    return owner and owner:removeBan(theBan, responsible) == true or false
end

---@return table
function getBans()
    local owner = bans()
    return owner and owner:getBans() or {}
end

---@return boolean
function reloadBans()
    local owner = bans()
    return owner and owner:reloadBans() == true or false
end

---@param value any
---@return boolean
function isBan(value)
    local owner = bans()
    return owner and owner:isBan(value) == true or false
end

---@param theBan table
---@return string|false
function getBanIP(theBan)
    local owner = bans()
    return owner and owner:getBanIP(theBan) or false
end

---@param theBan table
---@return string|false
function getBanUsername(theBan)
    local owner = bans()
    return owner and owner:getBanUsername(theBan) or false
end

---@param theBan table
---@return string|false
function getBanSerial(theBan)
    local owner = bans()
    return owner and owner:getBanSerial(theBan) or false
end

---@param theBan table
---@return string|false
function getBanNick(theBan)
    local owner = bans()
    return owner and owner:getBanNick(theBan) or false
end

---@param theBan table
---@return string|false
function getBanReason(theBan)
    local owner = bans()
    return owner and owner:getBanReason(theBan) or false
end

---@param theBan table
---@return string|false
function getBanAdmin(theBan)
    local owner = bans()
    return owner and owner:getBanAdmin(theBan) or false
end

---@param theBan table
---@return number|false
function getBanTime(theBan)
    local owner = bans()
    return owner and owner:getBanTime(theBan) or false
end

---@param theBan table
---@return number|false
function getUnbanTime(theBan)
    local owner = bans()
    return owner and owner:getUnbanTime(theBan) or false
end

---@param theBan table
---@param theTime number
---@return boolean
function setUnbanTime(theBan, theTime)
    local owner = bans()
    return owner and owner:setUnbanTime(theBan, theTime) == true or false
end

---@param theBan table
---@param theReason string
---@return boolean
function setBanReason(theBan, theReason)
    local owner = bans()
    return owner and owner:setBanReason(theBan, theReason) == true or false
end

---@param theBan table
---@param theAdmin Element|string
---@return boolean
function setBanAdmin(theBan, theAdmin)
    local owner = bans()
    return owner and owner:setBanAdmin(theBan, theAdmin) == true or false
end

---@param theBan table
---@param theNick string
---@return boolean
function setBanNick(theBan, theNick)
    local owner = bans()
    return owner and owner:setBanNick(theBan, theNick) == true or false
end

-- The owner triggers these on the root and on the banned player; every VM that wants to
-- listen has to know the name first.
addEvent("onBan", false)
addEvent("onUnban", false)
addEvent("onPlayerBan", false)
