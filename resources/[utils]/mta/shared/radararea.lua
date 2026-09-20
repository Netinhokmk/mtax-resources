_MTA_RADAR = _MTA_RADAR or {}

_MTA_RADAR.TYPE = "radararea"
_MTA_RADAR.KEY_AREA = "radararea"

_MTA_RADAR.DEFAULT_RED = 255
_MTA_RADAR.DEFAULT_GREEN = 0
_MTA_RADAR.DEFAULT_BLUE = 0
_MTA_RADAR.DEFAULT_ALPHA = 255

local TYPE = _MTA_RADAR.TYPE
local KEY_AREA = _MTA_RADAR.KEY_AREA

---@param value any
---@param fallback number
---@return number
function _MTA_RADAR.channel(value, fallback)
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

---@param value any
---@param fallback number
---@return number
function _MTA_RADAR.size(value, fallback)
    value = tonumber(value)
    if not value or value ~= value then
        return fallback
    end
    return value
end

---@param element any
---@return boolean
function _MTA_RADAR.isArea(element)
    return isElement(element) and getElementType(element) == TYPE
end

---@param args table
---@param index number
---@return number|nil, number|nil, number
function _MTA_RADAR.pair(args, index)
    local first = args[index]
    if type(first) == "userdata" or type(first) == "table" then
        return tonumber(first.x), tonumber(first.y), index + 1
    end
    return tonumber(first), tonumber(args[index + 1]), index + 2
end

---@param value any
---@return number|nil, number|nil, number|nil, number|nil
function _MTA_RADAR.toColor(value)
    if type(value) == "table" then
        local r = tonumber(value[1] or value.r)
        local g = tonumber(value[2] or value.g)
        local b = tonumber(value[3] or value.b)
        local a = tonumber(value[4] or value.a)
        if r and g and b then
            return _MTA_RADAR.channel(r, 255), _MTA_RADAR.channel(g, 255), _MTA_RADAR.channel(b, 255),
                _MTA_RADAR.channel(a, 255)
        end
        return nil
    end

    if type(value) ~= "string" then
        return nil
    end

    local digits = value:match("^#?(%x+)$")
    if not digits then
        return nil
    end

    if #digits == 3 or #digits == 4 then
        local r, g, b, a = digits:match("^(%x)(%x)(%x)(%x?)$")
        return tonumber(r, 16) * 17, tonumber(g, 16) * 17, tonumber(b, 16) * 17,
            a ~= "" and tonumber(a, 16) * 17 or 255
    end

    if #digits == 6 or #digits == 8 then
        local r, g, b, a = digits:match("^(%x%x)(%x%x)(%x%x)(%x?%x?)$")
        return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16),
            a ~= "" and tonumber(a, 16) or 255
    end

    return nil
end

---@param theArea Element
---@return table|nil
function _MTA_RADAR.state(theArea)
    if not _MTA_RADAR.isArea(theArea) then
        return nil
    end

    local state = getElementData(theArea, KEY_AREA)
    if type(state) ~= "table" then
        return nil
    end
    return state
end

---@param theArea Element
---@return number|nil, number|nil, number|nil, number|nil
function _MTA_RADAR.bounds(theArea)
    local state = _MTA_RADAR.state(theArea)
    if not state then
        return nil
    end

    local x, y = getElementPosition(theArea)
    if not x then
        return nil
    end

    local sizeX = _MTA_RADAR.size(state.sizeX, 0)
    local sizeY = _MTA_RADAR.size(state.sizeY, 0)
    local left, right = x, x + sizeX
    local bottom, top = y, y + sizeY
    if sizeX < 0 then
        left, right = right, left
    end
    if sizeY < 0 then
        bottom, top = top, bottom
    end
    return left, bottom, right, top
end

---@param theArea Element
---@return number|false, number?
function getRadarAreaSize(theArea)
    local state = _MTA_RADAR.state(theArea)
    if not state then
        return false
    end
    return _MTA_RADAR.size(state.sizeX, 0), _MTA_RADAR.size(state.sizeY, 0)
end

---@param theArea Element
---@return number|false, number?, number?, number?
function getRadarAreaColor(theArea)
    local state = _MTA_RADAR.state(theArea)
    if not state then
        return false
    end
    return _MTA_RADAR.channel(state.r, _MTA_RADAR.DEFAULT_RED),
        _MTA_RADAR.channel(state.g, _MTA_RADAR.DEFAULT_GREEN),
        _MTA_RADAR.channel(state.b, _MTA_RADAR.DEFAULT_BLUE),
        _MTA_RADAR.channel(state.a, _MTA_RADAR.DEFAULT_ALPHA)
end

---@param theArea Element
---@return boolean
function isRadarAreaFlashing(theArea)
    local state = _MTA_RADAR.state(theArea)
    return state ~= nil and state.flashing == true
end

---@param theArea Element
---@param posX number|table
---@param posY? number
---@return boolean
function isInsideRadarArea(theArea, posX, posY)
    posX, posY = _MTA_RADAR.pair({ posX, posY }, 1)
    if not posX or not posY then
        return false
    end

    local left, bottom, right, top = _MTA_RADAR.bounds(theArea)
    if not left then
        return false
    end
    return posX >= left and posX <= right and posY >= bottom and posY <= top
end
