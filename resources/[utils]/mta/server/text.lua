_MTA_COMPAT = _MTA_COMPAT or {}

local isDisplay = _MTA_TEXT.isDisplay
local state = _MTA_TEXT.state
local list = _MTA_TEXT.list
local indexOf = _MTA_TEXT.indexOf

local function owner()
    if not getResourceFromName("textdisplay") then
        _MTA_COMPAT.warnOnce("textdisplay",
            "the [mtax]/textdisplay resource is not running; every text display call fails and nothing is drawn")
        return nil
    end
    return exports["textdisplay"]
end

---@return Element|false
function textCreateDisplay()
    local host = owner()
    return host and host:textCreateDisplay() or false
end

---@param theDisplay Element
---@return boolean
function textDestroyDisplay(theDisplay)
    local host = owner()
    return host and host:textDestroyDisplay(theDisplay) == true or false
end

---@param text? string
---@param x? number
---@param y? number
---@param priority? string|number
---@param red? number
---@param green? number
---@param blue? number
---@param alpha? number
---@param scale? number
---@param alignX? string
---@param alignY? string
---@param shadowAlpha? number
---@return Element|false
function textCreateTextItem(text, x, y, priority, red, green, blue, alpha, scale, alignX, alignY,
                            shadowAlpha)
    local host = owner()
    return host and host:textCreateTextItem(text, x, y, priority, red, green, blue, alpha, scale,
        alignX, alignY, shadowAlpha) or false
end

---@param theTextItem Element
---@return boolean
function textDestroyTextItem(theTextItem)
    local host = owner()
    return host and host:textDestroyTextItem(theTextItem) == true or false
end

---@param theDisplay Element
---@param theTextItem Element
---@return boolean
function textDisplayAddText(theDisplay, theTextItem)
    local host = owner()
    return host and host:textDisplayAddText(theDisplay, theTextItem) == true or false
end

---@param theDisplay Element
---@param theTextItem Element
---@return boolean
function textDisplayRemoveText(theDisplay, theTextItem)
    local host = owner()
    return host and host:textDisplayRemoveText(theDisplay, theTextItem) == true or false
end

---@param theDisplay Element
---@param thePlayer Element
---@return boolean
function textDisplayAddObserver(theDisplay, thePlayer)
    local host = owner()
    return host and host:textDisplayAddObserver(theDisplay, thePlayer) == true or false
end

---@param theDisplay Element
---@param thePlayer Element
---@return boolean
function textDisplayRemoveObserver(theDisplay, thePlayer)
    local host = owner()
    return host and host:textDisplayRemoveObserver(theDisplay, thePlayer) == true or false
end

---@param theTextItem Element
---@param text string
---@return boolean
function textItemSetText(theTextItem, text)
    local host = owner()
    return host and host:textItemSetText(theTextItem, text) == true or false
end

---@param theTextItem Element
---@param scale number
---@return boolean
function textItemSetScale(theTextItem, scale)
    local host = owner()
    return host and host:textItemSetScale(theTextItem, scale) == true or false
end

---@param theTextItem Element
---@param x number|Vector2
---@param y? number
---@return boolean
function textItemSetPosition(theTextItem, x, y)
    local meta = type(x) == "table" and getmetatable(x) or nil
    if meta and rawget(meta, "__vecSize") then
        x, y = x.x, x.y
    end

    local host = owner()
    return host and host:textItemSetPosition(theTextItem, x, y) == true or false
end

---@param theTextItem Element
---@param red number
---@param green number
---@param blue number
---@param alpha number
---@return boolean
function textItemSetColor(theTextItem, red, green, blue, alpha)
    local host = owner()
    return host and host:textItemSetColor(theTextItem, red, green, blue, alpha) == true or false
end

---@param theTextItem Element
---@param priority string|number
---@return boolean
function textItemSetPriority(theTextItem, priority)
    local host = owner()
    return host and host:textItemSetPriority(theTextItem, priority) == true or false
end

---@param theDisplay Element
---@param thePlayer Element
---@return boolean
function textDisplayIsObserver(theDisplay, thePlayer)
    if not isDisplay(theDisplay) then
        return false
    end
    if not isElement(thePlayer) or getElementType(thePlayer) ~= "player" then
        return false
    end
    return indexOf(list(theDisplay, _MTA_TEXT.KEY_OBSERVERS), thePlayer) ~= nil
end

---@param theDisplay Element
---@return table|false
function textDisplayGetObservers(theDisplay)
    if not isDisplay(theDisplay) then
        return false
    end
    return list(theDisplay, _MTA_TEXT.KEY_OBSERVERS)
end

---@param theTextItem Element
---@return string|false
function textItemGetText(theTextItem)
    local item = state(theTextItem)
    return item and item.text or false
end

---@param theTextItem Element
---@return number|false
function textItemGetScale(theTextItem)
    local item = state(theTextItem)
    return item and item.scale or false
end

---@param theTextItem Element
---@return number|false, number?
function textItemGetPosition(theTextItem)
    local item = state(theTextItem)
    if not item then
        return false
    end
    return item.x, item.y
end

---@param theTextItem Element
---@return number|false, number?, number?, number?
function textItemGetColor(theTextItem)
    local item = state(theTextItem)
    if not item then
        return false
    end
    return item.r, item.g, item.b, item.a
end

---@param theTextItem Element
---@return number|false
function textItemGetPriority(theTextItem)
    local item = state(theTextItem)
    if not item then
        return false
    end
    return item.priority
end
