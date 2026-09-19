local TYPE = _MTA_TEAMS.TYPE
local KEY_TEAM = _MTA_TEAMS.KEY_TEAM
local KEY_NAME = _MTA_TEAMS.KEY_NAME
local KEY_COLOR = _MTA_TEAMS.KEY_COLOR
local KEY_FRIENDLY_FIRE = _MTA_TEAMS.KEY_FRIENDLY_FIRE

local isTeam = _MTA_TEAMS.isTeam
local toColor = _MTA_TEAMS.toColor
local toFriendlyFire = _MTA_TEAMS.toFriendlyFire

addEvent("onPlayerTeamChange", false)

local writing = false

local function write(element, key, value)
    writing = true
    local ok = setElementData(element, key, value)
    writing = false
    return ok == true
end

local function channel(value, fallback)
    value = tonumber(value)
    if not value then
        return fallback
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

local MAX_NAME = 255

---@param theName string
---@param red? number
---@param green? number
---@param blue? number
---@return Element|false
function createTeam(theName, red, green, blue)
    if type(theName) ~= "string" or theName == "" then
        return false
    end

    theName = theName:sub(1, MAX_NAME)
    if getTeamFromName(theName) then
        return false
    end

    local theTeam = createElement(TYPE)
    if not isElement(theTeam) then
        return false
    end

    if isElement(sourceResourceRoot) then
        setElementParent(theTeam, sourceResourceRoot)
    end

    write(theTeam, KEY_NAME, theName)
    write(theTeam, KEY_COLOR, { channel(red, 255), channel(green, 255), channel(blue, 255) })
    write(theTeam, KEY_FRIENDLY_FIRE, true)
    return theTeam
end

---@param thePlayer Element
---@param theTeam? Element
---@return boolean
function setPlayerTeam(thePlayer, theTeam)
    if not isElement(thePlayer) or getElementType(thePlayer) ~= "player" then
        return false
    end
    if theTeam ~= nil and theTeam ~= false and not isTeam(theTeam) then
        return false
    end

    local newTeam = isTeam(theTeam) and theTeam or nil
    local oldTeam = getPlayerTeam(thePlayer) or nil
    if oldTeam == newTeam then
        return false
    end

    if not triggerEvent("onPlayerTeamChange", thePlayer, oldTeam, newTeam) then
        return false
    end

    return write(thePlayer, KEY_TEAM, newTeam)
end

---@param theTeam Element
---@param theName string
---@return boolean
function setTeamName(theTeam, theName)
    if not isTeam(theTeam) or type(theName) ~= "string" or theName == "" then
        return false
    end
    return write(theTeam, KEY_NAME, theName:sub(1, MAX_NAME))
end

---@param theTeam Element
---@param red number
---@param green number
---@param blue number
---@return boolean
function setTeamColor(theTeam, red, green, blue)
    if not isTeam(theTeam) then
        return false
    end
    if not tonumber(red) or not tonumber(green) or not tonumber(blue) then
        return false
    end
    return write(theTeam, KEY_COLOR, { channel(red, 255), channel(green, 255), channel(blue, 255) })
end

---@param theTeam Element
---@param state boolean
---@return boolean
function setTeamFriendlyFire(theTeam, state)
    if not isTeam(theTeam) or type(state) ~= "boolean" then
        return false
    end
    return write(theTeam, KEY_FRIENDLY_FIRE, state)
end

local function adopt(theTeam)
    if not isTeam(theTeam) then
        return
    end

    local theName = getElementData(theTeam, KEY_NAME)
    if type(theName) ~= "string" or theName == "" then
        outputDebugString("[teams] a <team> has no name attribute and was left alone; MTA rejects the tag", 2)
        return
    end
    if #theName > MAX_NAME then
        write(theTeam, KEY_NAME, theName:sub(1, MAX_NAME))
    end

    local color = getElementData(theTeam, KEY_COLOR)
    if type(color) ~= "table" then
        local r, g, b = toColor(color)
        r = channel(getElementData(theTeam, "colorR"), r)
        g = channel(getElementData(theTeam, "colorG"), g)
        b = channel(getElementData(theTeam, "colorB"), b)
        write(theTeam, KEY_COLOR, { r, g, b })
    end

    local friendlyFire = getElementData(theTeam, KEY_FRIENDLY_FIRE)
    if type(friendlyFire) ~= "boolean" then
        write(theTeam, KEY_FRIENDLY_FIRE, toFriendlyFire(friendlyFire))
    end
end

addEventHandler("onElementCreated", root, function()
    adopt(source)
end)

addEventHandler("onResourceStart", resourceRoot, function()
    for _, theTeam in ipairs(getElementsByType(TYPE) or {}) do
        adopt(theTeam)
    end
end)

addEventHandler("onElementDestroy", root, function()
    if not isTeam(source) then
        return
    end
    for _, thePlayer in ipairs(getPlayersInTeam(source) or {}) do
        write(thePlayer, KEY_TEAM, nil)
    end
end)

addEventHandler("onElementDataChange", root, function(key)
    if writing then
        return
    end

    local watched = false
    if key == KEY_TEAM and getElementType(source) == "player" then
        watched = true
    elseif isTeam(source) and (key == KEY_NAME or key == KEY_COLOR or key == KEY_FRIENDLY_FIRE) then
        watched = true
    end

    if watched then
        _MTA_COMPAT.warnOnce("teams:" .. key,
            "'" .. key .. "' was written outside [mtax]/teams; use the team API or the subsystem drifts")
    end
end)

addEventHandler("onPlayerDamage", root, function(attacker)
    if not isElement(attacker) or getElementType(attacker) ~= "player" or attacker == source then
        return
    end

    local theTeam = getPlayerTeam(source)
    if not theTeam or getPlayerTeam(attacker) ~= theTeam then
        return
    end
    if getTeamFriendlyFire(theTeam) then
        return
    end

    cancelEvent()
end)
