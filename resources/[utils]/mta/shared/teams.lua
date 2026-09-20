_MTA_TEAMS = _MTA_TEAMS or {}

_MTA_TEAMS.TYPE = "team"
_MTA_TEAMS.KEY_TEAM = "team"
_MTA_TEAMS.KEY_NAME = "name"
_MTA_TEAMS.KEY_COLOR = "color"
_MTA_TEAMS.KEY_FRIENDLY_FIRE = "friendlyfire"

local TYPE = _MTA_TEAMS.TYPE
local KEY_TEAM = _MTA_TEAMS.KEY_TEAM
local KEY_NAME = _MTA_TEAMS.KEY_NAME
local KEY_COLOR = _MTA_TEAMS.KEY_COLOR
local KEY_FRIENDLY_FIRE = _MTA_TEAMS.KEY_FRIENDLY_FIRE

local function channel(value)
    value = tonumber(value)
    if not value then
        return nil
    end
    value = math.floor(value)
    if value < 0 then
        return 0
    end
    if value > 255 then
        return 255
    end
    return value
end

---@param value any
---@return number, number, number
function _MTA_TEAMS.toColor(value)
    if type(value) == "table" then
        local r = channel(value[1] or value.r)
        local g = channel(value[2] or value.g)
        local b = channel(value[3] or value.b)
        if r and g and b then
            return r, g, b
        end
        return 255, 255, 255
    end

    if type(value) == "string" then
        local digits = value:match("^#(%x+)$")
        if digits then
            if #digits == 3 or #digits == 4 then
                local r, g, b = digits:match("^(%x)(%x)(%x)")
                return tonumber(r, 16) * 17, tonumber(g, 16) * 17, tonumber(b, 16) * 17
            end
            if #digits == 6 or #digits == 8 then
                local r, g, b = digits:match("^(%x%x)(%x%x)(%x%x)")
                return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
            end
        end
    end

    return 255, 255, 255
end

---@param value any
---@return boolean
function _MTA_TEAMS.toFriendlyFire(value)
    if type(value) == "boolean" then
        return value
    end
    if value == "false" or value == "0" or value == 0 then
        return false
    end
    if value == nil then
        return true
    end
    return true
end

---@param element any
---@return boolean
function _MTA_TEAMS.isTeam(element)
    return isElement(element) and getElementType(element) == TYPE
end

local isTeam = _MTA_TEAMS.isTeam

---@param theTeam Element
---@return table|false
function getPlayersInTeam(theTeam)
    if not isTeam(theTeam) then
        return false
    end

    local found = {}
    for _, player in ipairs(getElementsByType("player") or {}) do
        if getElementData(player, KEY_TEAM) == theTeam then
            found[#found + 1] = player
        end
    end
    return found
end

---@param theTeam Element
---@return number|false
function countPlayersInTeam(theTeam)
    local players = getPlayersInTeam(theTeam)
    return players and #players or false
end

---@param thePlayer Element
---@return Element|false
function getPlayerTeam(thePlayer)
    if not isElement(thePlayer) or getElementType(thePlayer) ~= "player" then
        return false
    end

    local theTeam = getElementData(thePlayer, KEY_TEAM)
    return isTeam(theTeam) and theTeam or false
end

---@param theName string
---@return Element|false
function getTeamFromName(theName)
    if type(theName) ~= "string" or theName == "" then
        return false
    end

    for _, theTeam in ipairs(getElementsByType(TYPE) or {}) do
        if getElementData(theTeam, KEY_NAME) == theName then
            return theTeam
        end
    end
    return false
end

---@param theTeam Element
---@return string|false
function getTeamName(theTeam)
    if not isTeam(theTeam) then
        return false
    end

    local theName = getElementData(theTeam, KEY_NAME)
    return type(theName) == "string" and theName or false
end

---@param theTeam Element
---@return number|false, number?, number?
function getTeamColor(theTeam)
    if not isTeam(theTeam) then
        return false
    end
    return _MTA_TEAMS.toColor(getElementData(theTeam, KEY_COLOR))
end

---@param theTeam Element
---@return boolean
function getTeamFriendlyFire(theTeam)
    if not isTeam(theTeam) then
        return false
    end
    return _MTA_TEAMS.toFriendlyFire(getElementData(theTeam, KEY_FRIENDLY_FIRE))
end
