_MTA_COMPAT = _MTA_COMPAT or {}

local KEY_AREA = _MTA_RADAR.KEY_AREA

local channel = _MTA_RADAR.channel
local pair = _MTA_RADAR.pair
local size = _MTA_RADAR.size
local state = _MTA_RADAR.state

local function write(theArea, values)
    return setElementData(theArea, KEY_AREA, values) == true
end

---@param startX number|table
---@param startY number
---@param sizeX number
---@param sizeY number
---@param red? number
---@param green? number
---@param blue? number
---@param alpha? number
---@return Element|false
function createRadarArea(...)
    local args = { ... }
    local startX, startY, next = pair(args, 1)
    local sizeX, sizeY, tail = pair(args, next)
    local red, green, blue, alpha = args[tail], args[tail + 1], args[tail + 2], args[tail + 3]
    if not startX or not startY then
        return false
    end

    local theArea = createElement(_MTA_RADAR.TYPE)
    if not isElement(theArea) then
        return false
    end

    setElementPosition(theArea, startX, startY, 0)
    write(theArea, {
        sizeX = size(sizeX, 0),
        sizeY = size(sizeY, 0),
        r = channel(red, _MTA_RADAR.DEFAULT_RED),
        g = channel(green, _MTA_RADAR.DEFAULT_GREEN),
        b = channel(blue, _MTA_RADAR.DEFAULT_BLUE),
        a = channel(alpha, _MTA_RADAR.DEFAULT_ALPHA),
        flashing = false,
    })
    return theArea
end

---@param theArea Element
---@param sizeX number|table
---@param sizeY? number
---@return boolean
function setRadarAreaSize(theArea, ...)
    local sizeX, sizeY = pair({ ... }, 1)
    local values = state(theArea)
    if not values or not sizeX or not sizeY then
        return false
    end

    values.sizeX = size(sizeX, 0)
    values.sizeY = size(sizeY, 0)
    return write(theArea, values)
end

---@param theArea Element
---@param red number
---@param green number
---@param blue number
---@param alpha number
---@return boolean
function setRadarAreaColor(theArea, red, green, blue, alpha)
    local values = state(theArea)
    if not values then
        return false
    end

    if not tonumber(red) or not tonumber(green) or not tonumber(blue) or not tonumber(alpha) then
        return false
    end

    values.r = channel(red, _MTA_RADAR.DEFAULT_RED)
    values.g = channel(green, _MTA_RADAR.DEFAULT_GREEN)
    values.b = channel(blue, _MTA_RADAR.DEFAULT_BLUE)
    values.a = channel(alpha, _MTA_RADAR.DEFAULT_ALPHA)
    return write(theArea, values)
end

---@param theArea Element
---@param flashing boolean
---@return boolean
function setRadarAreaFlashing(theArea, flashing)
    local values = state(theArea)
    if not values or type(flashing) ~= "boolean" then
        return false
    end

    values.flashing = flashing
    return write(theArea, values)
end
