local TYPE_DISPLAY = _MTA_TEXT.TYPE_DISPLAY
local TYPE_ITEM = _MTA_TEXT.TYPE_ITEM
local KEY_ITEM = _MTA_TEXT.KEY_ITEM
local KEY_ITEMS = _MTA_TEXT.KEY_ITEMS
local KEY_OBSERVERS = _MTA_TEXT.KEY_OBSERVERS
local SYNC = _MTA_TEXT.SYNC

local isDisplay = _MTA_TEXT.isDisplay
local isItem = _MTA_TEXT.isItem
local list = _MTA_TEXT.list
local indexOf = _MTA_TEXT.indexOf

local writing = false

local function write(element, key, value, mode)
    writing = true
    local ok = setElementData(element, key, value, mode)
    writing = false
    return ok == true
end

local function writeState(theTextItem, state)
    return write(theTextItem, KEY_ITEM, state, SYNC)
end

local function resyncItem(theTextItem, ignoredDisplay)
    if not isItem(theTextItem) then
        return
    end

    local wanted = {}
    for _, theDisplay in ipairs(getElementsByType(TYPE_DISPLAY) or {}) do
        if theDisplay ~= ignoredDisplay and indexOf(list(theDisplay, KEY_ITEMS), theTextItem) then
            for _, thePlayer in ipairs(list(theDisplay, KEY_OBSERVERS)) do
                wanted[thePlayer] = true
            end
        end
    end

    for _, thePlayer in ipairs(getElementsByType("player") or {}) do
        local subscribed = hasElementDataSubscriber(theTextItem, KEY_ITEM, thePlayer)
        if wanted[thePlayer] and not subscribed then
            addElementDataSubscriber(theTextItem, KEY_ITEM, thePlayer)
        elseif subscribed and not wanted[thePlayer] then
            removeElementDataSubscriber(theTextItem, KEY_ITEM, thePlayer)
        end
    end
end

local function resyncDisplay(theDisplay, ignoredDisplay)
    for _, theTextItem in ipairs(list(theDisplay, KEY_ITEMS)) do
        resyncItem(theTextItem, ignoredDisplay)
    end
end

local function own(element)
    if isElement(sourceResourceRoot) then
        setElementParent(element, sourceResourceRoot)
    end
end

---@return Element|false
function textCreateDisplay()
    local theDisplay = createElement(TYPE_DISPLAY)
    if not isElement(theDisplay) then
        return false
    end

    own(theDisplay)
    write(theDisplay, KEY_ITEMS, {})
    write(theDisplay, KEY_OBSERVERS, {})
    return theDisplay
end

---@param theDisplay Element
---@return boolean
function textDestroyDisplay(theDisplay)
    if not isDisplay(theDisplay) then
        return false
    end

    return destroyElement(theDisplay) == true
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
    local theTextItem = createElement(TYPE_ITEM)
    if not isElement(theTextItem) then
        return false
    end

    own(theTextItem)

    local wanted = _MTA_TEXT.toPriority(priority)
    if not _MTA_TEXT.isDrawablePriority(wanted) then
        _MTA_COMPAT.warnOnce("textdisplay:priority",
            "a text item was created with priority " .. tostring(wanted) ..
            "; MTA drops such an item on the floor and never sends it, and so does this")
    end

    writeState(theTextItem, {
        text = _MTA_TEXT.toText(text),
        x = tonumber(x) or 0.5,
        y = tonumber(y) or 0.5,
        r = _MTA_TEXT.channel(red, 255),
        g = _MTA_TEXT.channel(green, 255),
        b = _MTA_TEXT.channel(blue, 255),
        a = _MTA_TEXT.channel(alpha, 255),
        scale = tonumber(scale) or 1,
        alignX = _MTA_TEXT.toAlignX(alignX, "left"),
        alignY = _MTA_TEXT.toAlignY(alignY, "top"),
        shadow = _MTA_TEXT.channel(shadowAlpha, 0),
        priority = wanted,
    })
    return theTextItem
end

---@param theTextItem Element
---@return boolean
function textDestroyTextItem(theTextItem)
    if not isItem(theTextItem) then
        return false
    end

    return destroyElement(theTextItem) == true
end

---@param theDisplay Element
---@param theTextItem Element
---@return boolean
function textDisplayAddText(theDisplay, theTextItem)
    if not isDisplay(theDisplay) or not isItem(theTextItem) then
        return false
    end

    local items = list(theDisplay, KEY_ITEMS)
    local at = indexOf(items, theTextItem)
    if at then
        table.remove(items, at)
    end
    items[#items + 1] = theTextItem

    write(theDisplay, KEY_ITEMS, items)
    resyncItem(theTextItem)
    return true
end

---@param theDisplay Element
---@param theTextItem Element
---@return boolean
function textDisplayRemoveText(theDisplay, theTextItem)
    if not isDisplay(theDisplay) or not isItem(theTextItem) then
        return false
    end

    local items = list(theDisplay, KEY_ITEMS)
    local at = indexOf(items, theTextItem)
    if at then
        table.remove(items, at)
        write(theDisplay, KEY_ITEMS, items)
    end

    resyncItem(theTextItem)
    return true
end

---@param theDisplay Element
---@param thePlayer Element
---@return boolean
function textDisplayAddObserver(theDisplay, thePlayer)
    if not isDisplay(theDisplay) then
        return false
    end
    if not isElement(thePlayer) or getElementType(thePlayer) ~= "player" then
        return false
    end

    local observers = list(theDisplay, KEY_OBSERVERS)
    local at = indexOf(observers, thePlayer)
    if at then
        table.remove(observers, at)
    end
    observers[#observers + 1] = thePlayer

    write(theDisplay, KEY_OBSERVERS, observers)
    resyncDisplay(theDisplay)
    return true
end

---@param theDisplay Element
---@param thePlayer Element
---@return boolean
function textDisplayRemoveObserver(theDisplay, thePlayer)
    if not isDisplay(theDisplay) then
        return false
    end
    if not isElement(thePlayer) or getElementType(thePlayer) ~= "player" then
        return false
    end

    local observers = list(theDisplay, KEY_OBSERVERS)
    local at = indexOf(observers, thePlayer)
    if at then
        table.remove(observers, at)
        write(theDisplay, KEY_OBSERVERS, observers)
    end

    resyncDisplay(theDisplay)
    return true
end

local function setField(theTextItem, apply)
    local state = _MTA_TEXT.state(theTextItem)
    if not state then
        return false
    end

    apply(state)
    return writeState(theTextItem, state)
end

---@param theTextItem Element
---@param text string
---@return boolean
function textItemSetText(theTextItem, text)
    if type(text) ~= "string" then
        return false
    end
    return setField(theTextItem, function(state)
        state.text = _MTA_TEXT.toText(text)
    end)
end

---@param theTextItem Element
---@param scale number
---@return boolean
function textItemSetScale(theTextItem, scale)
    scale = tonumber(scale)
    if not scale then
        return false
    end
    return setField(theTextItem, function(state)
        state.scale = scale
    end)
end

---@param theTextItem Element
---@param x number
---@param y number
---@return boolean
function textItemSetPosition(theTextItem, x, y)
    x, y = tonumber(x), tonumber(y)
    if not x or not y then
        return false
    end
    return setField(theTextItem, function(state)
        state.x = x
        state.y = y
    end)
end

---@param theTextItem Element
---@param red number
---@param green number
---@param blue number
---@param alpha number
---@return boolean
function textItemSetColor(theTextItem, red, green, blue, alpha)
    if not tonumber(red) or not tonumber(green) or not tonumber(blue) or not tonumber(alpha) then
        return false
    end
    return setField(theTextItem, function(state)
        state.r = _MTA_TEXT.channel(red, 255)
        state.g = _MTA_TEXT.channel(green, 255)
        state.b = _MTA_TEXT.channel(blue, 255)
        state.a = _MTA_TEXT.channel(alpha, 255)
    end)
end

---@param theTextItem Element
---@param priority string|number
---@return boolean
function textItemSetPriority(theTextItem, priority)
    if priority == nil then
        return false
    end
    return setField(theTextItem, function(state)
        state.priority = _MTA_TEXT.toPriority(priority)
    end)
end

local function forget(element)
    if isDisplay(element) then
        resyncDisplay(element, element)
        return
    end

    if not isItem(element) then
        return
    end

    for _, theDisplay in ipairs(getElementsByType(TYPE_DISPLAY) or {}) do
        local items = list(theDisplay, KEY_ITEMS)
        local at = indexOf(items, element)
        if at then
            table.remove(items, at)
            write(theDisplay, KEY_ITEMS, items)
        end
    end
end

addEventHandler("onElementDestroy", root, function()
    forget(source)
end)

addEventHandler("onPlayerQuit", root, function()
    for _, theDisplay in ipairs(getElementsByType(TYPE_DISPLAY) or {}) do
        local observers = list(theDisplay, KEY_OBSERVERS)
        local at = indexOf(observers, source)
        if at then
            table.remove(observers, at)
            write(theDisplay, KEY_OBSERVERS, observers)
        end
    end
end)

addEventHandler("onElementDataChange", root, function(key)
    if writing then
        return
    end

    local watched = false
    if key == KEY_ITEM and isItem(source) then
        watched = true
    elseif isDisplay(source) and (key == KEY_ITEMS or key == KEY_OBSERVERS) then
        watched = true
    end

    if watched then
        _MTA_COMPAT.warnOnce("textdisplay:" .. key,
            "'" .. key .. "' was written outside [mtax]/textdisplay; use the text* API or the " ..
            "subscription set stops matching what is on screen")
    end
end)
