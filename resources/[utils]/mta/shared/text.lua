_MTA_TEXT = _MTA_TEXT or {}

_MTA_TEXT.TYPE_DISPLAY = "textdisplay"
_MTA_TEXT.TYPE_ITEM = "textitem"

_MTA_TEXT.KEY_ITEM = "textitem"
_MTA_TEXT.KEY_ITEMS = "items"
_MTA_TEXT.KEY_OBSERVERS = "observers"

_MTA_TEXT.SYNC = "subscribe"

_MTA_TEXT.MAX_TEXT = 1024

_MTA_TEXT.PRIORITY_LOW = 0
_MTA_TEXT.PRIORITY_MEDIUM = 1
_MTA_TEXT.PRIORITY_HIGH = 2

local TYPE_DISPLAY = _MTA_TEXT.TYPE_DISPLAY
local TYPE_ITEM = _MTA_TEXT.TYPE_ITEM
local KEY_ITEM = _MTA_TEXT.KEY_ITEM
local MAX_TEXT = _MTA_TEXT.MAX_TEXT

---@param element any
---@return boolean
function _MTA_TEXT.isDisplay(element)
    return isElement(element) and getElementType(element) == TYPE_DISPLAY
end

---@param element any
---@return boolean
function _MTA_TEXT.isItem(element)
    return isElement(element) and getElementType(element) == TYPE_ITEM
end

---@param value any
---@param fallback number
---@return number
function _MTA_TEXT.channel(value, fallback)
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
---@return number
function _MTA_TEXT.toPriority(value)
    if type(value) == "string" then
        if value == "high" then
            return _MTA_TEXT.PRIORITY_HIGH
        end
        if value == "medium" then
            return _MTA_TEXT.PRIORITY_MEDIUM
        end
        return _MTA_TEXT.PRIORITY_LOW
    end

    local number = tonumber(value)
    if not number then
        return _MTA_TEXT.PRIORITY_LOW
    end
    return math.floor(number)
end

---@param priority number
---@return boolean
function _MTA_TEXT.isDrawablePriority(priority)
    return priority == _MTA_TEXT.PRIORITY_LOW
        or priority == _MTA_TEXT.PRIORITY_MEDIUM
        or priority == _MTA_TEXT.PRIORITY_HIGH
end

---@param value any
---@param default string
---@return string
function _MTA_TEXT.toAlignX(value, default)
    if value == "center" or value == "right" or value == "left" then
        return value
    end
    return default
end

---@param value any
---@param default string
---@return string
function _MTA_TEXT.toAlignY(value, default)
    if value == "center" or value == "bottom" or value == "top" then
        return value
    end
    return default
end

---@param value any
---@return string
function _MTA_TEXT.toText(value)
    if type(value) ~= "string" then
        return ""
    end
    return value:sub(1, MAX_TEXT)
end

---@param theTextItem Element
---@return table|nil
function _MTA_TEXT.state(theTextItem)
    if not _MTA_TEXT.isItem(theTextItem) then
        return nil
    end

    local state = getElementData(theTextItem, KEY_ITEM)
    if type(state) ~= "table" then
        return nil
    end
    return state
end

---@param element Element
---@param key string
---@return table
function _MTA_TEXT.list(element, key)
    if not isElement(element) then
        return {}
    end

    local stored = getElementData(element, key)
    if type(stored) ~= "table" then
        return {}
    end

    local alive = {}
    for _, entry in ipairs(stored) do
        if isElement(entry) then
            alive[#alive + 1] = entry
        end
    end
    return alive
end

---@param list table
---@param wanted any
---@return number|nil
function _MTA_TEXT.indexOf(list, wanted)
    for index, entry in ipairs(list) do
        if entry == wanted then
            return index
        end
    end
    return nil
end
