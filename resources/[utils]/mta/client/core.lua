local SHIM = "mtax_guicompat"
local VERSION = "1.0.0"

local function bail(reason)
    if type(outputDebugString) == "function" then
        outputDebugString("[" .. SHIM .. "] NOT LOADED: " .. reason, 2)
    end
end

if type(guiCreateWindow) == "function" then
    bail("guiCreateWindow already exists as a global. This MTAX build appears to " ..
         "provide a real GUI, so the emulation layer stands down. Remove " ..
         SHIM .. " from client_files.")
    return
end

if type(rawget(_G, "mtaxGuiCompat")) == "table" then
    bail("already loaded in this VM (mtaxGuiCompat exists). core.lua must appear " ..
         "exactly once in client_files.")
    return
end

if type(rawget(_G, "mtaxGuiCompat")) ~= "nil" then
    bail("the global 'mtaxGuiCompat' is taken by something that is not this shim.")
    return
end

local REQUIRED = {
    "outputDebugString", "getTickCount",
    "createElement", "destroyElement", "isElement", "getElementID",
    "getElementType", "setElementParent", "getRootElement", "getResourceRootElement",
    "getThisResource",
    "addEvent", "addEventHandler", "removeEventHandler", "triggerEvent",
    "getScreenSize", "isCursorShowing", "getCursorPosition", "getKeyState",
    "dxDrawRectangle", "dxDrawText", "dxDrawImage", "dxDrawImageSection",
    "dxGetTextWidth", "dxGetFontHeight", "dxCreateFont", "dxCreateTexture",
    "dxGetMaterialSize",
}

local missing = nil
for i = 1, #REQUIRED do
    if type(rawget(_G, REQUIRED[i])) ~= "function" then
        missing = (missing and (missing .. ", ") or "") .. REQUIRED[i]
    end
end
if missing then
    bail("this VM is missing the MTAX function(s) the shim is built on: " .. missing ..
         ". The shim is CLIENT-ONLY; make sure it is listed in client_files and " ..
         "never in server_files or shared_files.")
    return
end

local nOutputDebugString    = outputDebugString
local nGetTickCount         = getTickCount
local nCreateElement        = createElement
local nDestroyElement       = destroyElement
local nIsElement            = isElement
local nGetElementID         = getElementID
local nGetElementType       = getElementType
local nSetElementParent     = setElementParent
local nGetRootElement       = getRootElement
local nGetResourceRootElement = getResourceRootElement
local nGetThisResource      = getThisResource
local nAddEvent             = addEvent
local nAddEventHandler      = addEventHandler
local nRemoveEventHandler   = removeEventHandler
local nTriggerEvent         = triggerEvent
local nGetScreenSize        = getScreenSize
local nIsCursorShowing      = isCursorShowing
local nGetCursorPosition    = getCursorPosition
local nGetKeyState          = getKeyState
local nDxDrawRectangle      = dxDrawRectangle
local nDxDrawText           = dxDrawText
local nDxDrawImage          = dxDrawImage
local nDxDrawImageSection   = dxDrawImageSection
local nDxGetTextWidth       = dxGetTextWidth
local nDxGetFontHeight      = dxGetFontHeight
local nDxCreateFont         = dxCreateFont
local nDxCreateTexture      = dxCreateTexture
local nDxGetMaterialSize    = dxGetMaterialSize
local nSetClipboard         = type(setClipboard) == "function" and setClipboard or nil
local nFileExists           = type(fileExists) == "function" and fileExists or nil

local floor, ceil, min, max, abs = math.floor, math.ceil, math.min, math.max, math.abs
local sub, gsub, find, rep, byte, format = string.sub, string.gsub, string.find,
                                           string.rep, string.byte, string.format
local concat, insert, remove = table.concat, table.insert, table.remove
local tostr, tonum, ty = tostring, tonumber, type

local M = {
    _NAME = SHIM,
    _VERSION = VERSION,
}
_G.mtaxGuiCompat = M

local RESERVED = {
    -- core.lua
    "guiCreateFont", "guiSetInputEnabled", "guiGetInputEnabled",
    "guiSetInputMode", "guiGetInputMode", "guiGetCursorType",
    -- widgets.lua: generic
    "guiSetVisible", "guiGetVisible", "guiSetEnabled", "guiGetEnabled",
    "guiSetAlpha", "guiGetAlpha", "guiSetPosition", "guiGetPosition",
    "guiSetSize", "guiGetSize", "guiSetText", "guiGetText",
    "guiSetFont", "guiGetFont", "guiBringToFront", "guiMoveToBack",
    "guiSetProperty", "guiGetProperty", "guiGetProperties", "guiFocus", "guiBlur",
    -- widgets.lua: window
    "guiCreateWindow", "guiWindowSetMovable", "guiWindowSetSizable",
    "guiWindowIsMovable", "guiWindowIsSizable",
    -- widgets.lua: label
    "guiCreateLabel", "guiLabelSetColor", "guiLabelGetColor",
    "guiLabelSetVerticalAlign", "guiLabelSetHorizontalAlign",
    "guiLabelGetTextExtent", "guiLabelGetFontHeight",
    -- widgets.lua: button / staticimage
    "guiCreateButton",
    "guiCreateStaticImage", "guiStaticImageLoadImage", "guiStaticImageGetNativeSize",
    -- widgets.lua: edit
    "guiCreateEdit", "guiEditSetCaretIndex", "guiEditGetCaretIndex",
    "guiEditSetCaratIndex", "guiEditSetMasked", "guiEditIsMasked",
    "guiEditSetMaxLength", "guiEditGetMaxLength", "guiEditSetReadOnly",
    "guiEditIsReadOnly",
    -- widgets.lua: memo
    "guiCreateMemo", "guiMemoSetCaretIndex", "guiMemoGetCaretIndex",
    "guiMemoSetCaratIndex", "guiMemoSetReadOnly", "guiMemoIsReadOnly",
    "guiMemoSetVerticalScrollPosition", "guiMemoGetVerticalScrollPosition",
    -- widgets.lua: checkbox / radiobutton / progressbar
    "guiCreateCheckBox", "guiCheckBoxSetSelected", "guiCheckBoxGetSelected",
    "guiCreateRadioButton", "guiRadioButtonSetSelected", "guiRadioButtonGetSelected",
    "guiCreateProgressBar", "guiProgressBarSetProgress", "guiProgressBarGetProgress",
    -- widgets.lua: scrollbar / scrollpane
    "guiCreateScrollBar", "guiScrollBarSetScrollPosition", "guiScrollBarGetScrollPosition",
    "guiCreateScrollPane", "guiScrollPaneSetScrollBars",
    "guiScrollPaneSetHorizontalScrollPosition", "guiScrollPaneGetHorizontalScrollPosition",
    "guiScrollPaneSetVerticalScrollPosition", "guiScrollPaneGetVerticalScrollPosition",
    -- widgets.lua: gridlist
    "guiCreateGridList", "guiGridListSetSortingEnabled", "guiGridListIsSortingEnabled",
    "guiGridListAddColumn", "guiGridListRemoveColumn", "guiGridListSetColumnWidth",
    "guiGridListGetColumnWidth", "guiGridListSetColumnTitle", "guiGridListGetColumnTitle",
    "guiGridListSetScrollBars", "guiGridListGetRowCount", "guiGridListGetColumnCount",
    "guiGridListAddRow", "guiGridListInsertRowAfter", "guiGridListRemoveRow",
    "guiGridListAutoSizeColumn", "guiGridListClear", "guiGridListSetItemText",
    "guiGridListGetItemText", "guiGridListSetItemData", "guiGridListGetItemData",
    "guiGridListSetItemColor", "guiGridListGetItemColor", "guiGridListSetSelectionMode",
    "guiGridListGetSelectionMode", "guiGridListGetSelectedItem", "guiGridListGetSelectedItems",
    "guiGridListGetSelectedCount", "guiGridListSetSelectedItem",
    "guiGridListSetHorizontalScrollPosition", "guiGridListGetHorizontalScrollPosition",
    "guiGridListSetVerticalScrollPosition", "guiGridListGetVerticalScrollPosition",
    -- widgets.lua: combobox
    "guiCreateComboBox", "guiComboBoxAddItem", "guiComboBoxRemoveItem", "guiComboBoxClear",
    "guiComboBoxGetSelected", "guiComboBoxSetSelected", "guiComboBoxGetItemText",
    "guiComboBoxSetItemText", "guiComboBoxGetItemCount", "guiComboBoxSetOpen",
    "guiComboBoxIsOpen",
    -- widgets.lua: tabpanel / tab
    "guiCreateTabPanel", "guiCreateTab", "guiGetSelectedTab", "guiSetSelectedTab",
    "guiDeleteTab",
    -- widgets.lua: not reproducible, defined only as logged no-ops
    "guiCreateBrowser", "guiGetBrowser",
}

local taken = nil
for i = 1, #RESERVED do
    if rawget(_G, RESERVED[i]) ~= nil then
        taken = (taken and (taken .. ", ") or "") .. RESERVED[i]
    end
end
if taken then
    _G.mtaxGuiCompat = nil
    bail("refusing to define anything because these globals already exist: " .. taken ..
         ". The shim never shadows a real MTAX global.")
    return
end

M.RESERVED = RESERVED

local definedNames = {}
local function define(name, fn)
    _G[name] = fn
    definedNames[#definedNames + 1] = name
end
M.define = define
M.definedNames = definedNames

local unsupportedSeen, unsupportedOrder = {}, {}

local function unsupported(what, why)
    if unsupportedSeen[what] then return end
    unsupportedSeen[what] = why or ""
    unsupportedOrder[#unsupportedOrder + 1] = what
    nOutputDebugString("[" .. SHIM .. "] UNSUPPORTED " .. what ..
                       (why and (": " .. why) or ""), 2)
end
M.unsupported = unsupported
M.unsupportedSeen = unsupportedSeen
M.unsupportedOrder = unsupportedOrder

local warnedOnce = {}
local function warnOnce(key, msg)
    if warnedOnce[key] then return end
    warnedOnce[key] = true
    nOutputDebugString("[" .. SHIM .. "] " .. msg, 2)
end
M.warnOnce = warnOnce

local function info(msg)
    nOutputDebugString("[" .. SHIM .. "] " .. msg, 3)
end
M.info = info

function M.report()
    if #unsupportedOrder == 0 then
        info("no unsupported gui* call was reached this session.")
        return
    end
    info("unsupported gui* calls reached this session (" .. #unsupportedOrder .. "):")
    for i = 1, #unsupportedOrder do
        local k = unsupportedOrder[i]
        info("  - " .. k .. (unsupportedSeen[k] ~= "" and ("  -- " .. unsupportedSeen[k]) or ""))
    end
end

local function num(v, dflt)
    local n = tonum(v)
    if n == nil or n ~= n then return dflt end   -- n ~= n filters NaN
    return n
end
M.num = num

local function truthy(v)
    if v == nil or v == false then return false end
    return true
end
M.truthy = truthy

local function str(v, dflt)
    local t = ty(v)
    if t == "string" then return v end
    if t == "number" then return tostr(v) end
    return dflt
end
M.str = str

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
M.clamp = clamp

local u8 = utf8

local function ulen(s)
    if ty(s) ~= "string" then return 0 end
    if u8 then
        local ok, n = pcall(u8.len, s)
        if ok and ty(n) == "number" then return n end
    end
    return #s
end
M.ulen = ulen

local function uoffset(s, i)
    if not u8 then return clamp(i, 1, #s + 1) end
    local ok, o = pcall(u8.offset, s, i)
    if ok and ty(o) == "number" then return o end
    return clamp(i, 1, #s + 1)
end

local function usub(s, i, j)
    if ty(s) ~= "string" or s == "" then return "" end
    local n = ulen(s)
    if i < 1 then i = 1 end
    if j == nil or j > n then j = n end
    if i > j then return "" end
    local a = uoffset(s, i)
    local b = (j >= n) and (#s + 1) or uoffset(s, j + 1)
    if ty(a) ~= "number" or ty(b) ~= "number" then return "" end
    return sub(s, a, b - 1)
end
M.usub = usub

local function argb(a, r, g, b)
    a = floor(clamp(num(a, 255), 0, 255))
    r = floor(clamp(num(r, 255), 0, 255))
    g = floor(clamp(num(g, 255), 0, 255))
    b = floor(clamp(num(b, 255), 0, 255))
    return a * 0x1000000 + r * 0x10000 + g * 0x100 + b
end
M.argb = argb

local function withAlpha(color, mul)
    if mul >= 0.999 then return color end
    if mul <= 0 then return color % 0x1000000 end
    local a = floor(color / 0x1000000) % 256
    return floor(a * mul + 0.5) * 0x1000000 + (color % 0x1000000)
end
M.withAlpha = withAlpha

local T = {
    windowFrame      = argb(235,  38,  38,  42),
    windowBody       = argb(225,  28,  28,  32),
    windowTitle      = argb(245,  52,  52,  60),
    windowTitleText  = argb(255, 235, 235, 240),
    windowBorder     = argb(255,  72,  72,  82),
    closeNormal      = argb(255, 150,  60,  60),
    closeHover       = argb(255, 200,  70,  70),
    closeGlyph       = argb(255, 245, 235, 235),
    grip             = argb(120, 120, 120, 135),

    text             = argb(255, 226, 226, 232),
    textDisabled     = argb(255, 128, 128, 136),

    buttonNormal     = argb(255,  62,  62,  72),
    buttonHover      = argb(255,  82,  82,  96),
    buttonPushed     = argb(255,  44,  44,  52),
    buttonDisabled   = argb(255,  46,  46,  50),
    buttonBorder     = argb(255,  96,  96, 110),

    fieldBg          = argb(235,  18,  18,  22),
    fieldBorder      = argb(255,  86,  86,  98),
    fieldBorderFocus = argb(255, 120, 160, 220),
    caret            = argb(255, 235, 235, 240),

    panelBg          = argb(210,  26,  26,  30),
    panelBorder      = argb(255,  70,  70,  80),

    headerBg         = argb(255,  46,  46,  54),
    rowAlt           = argb(40,  255, 255, 255),
    rowSelected      = argb(255,  46,  86, 140),
    rowHover         = argb(60,  255, 255, 255),

    progressBg       = argb(235,  20,  20,  24),
    progressFill     = argb(255,  70, 140, 200),

    scrollTrack      = argb(200,  22,  22,  26),
    scrollThumb      = argb(255,  86,  86,  98),
    scrollThumbHover = argb(255, 116, 116, 132),

    tabStrip         = argb(235,  34,  34,  40),
    tabInactive      = argb(255,  48,  48,  56),
    tabActive        = argb(255,  70,  70,  84),

    check            = argb(255, 120, 190, 250),
}
M.theme = T

local GUI_FONTS = {
    ["default-normal"]     = { dx = "default",      scale = 0.80,
        note = "CEGUI tahoma.ttf 9pt -> MTAX \"default\" Tahoma 15px, scaled 0.80" },
    ["default-small"]      = { dx = "default",      scale = 0.62,
        note = "CEGUI tahoma.ttf 7pt -> MTAX \"default\" scaled 0.62 (MTAX has no small variant)" },
    ["default-bold-small"] = { dx = "default-bold", scale = 0.71,
        note = "CEGUI tahomabd.ttf 8pt -> MTAX \"default-bold\" scaled 0.71" },
    ["clear-normal"]       = { dx = "clear",        scale = 0.80,
        note = "CEGUI verdana.ttf 9pt -> MTAX \"clear\" which is Segoe UI, NOT Verdana" },
    ["sans"]               = { dx = "sans",         scale = 0.80,
        note = "CEGUI cgui/sans.ttf 9pt -> MTAX \"sans\" which is Verdana" },
    ["unifont"]            = { dx = "unifont",      scale = 0.80,
        note = "CEGUI cgui/unifont.ttf (full BMP fallback) -> MTAX \"unifont\" which is Verdana, Latin-1 only" },
    ["sa-header"]          = { dx = "pricedown",    scale = 1.00,
        note = "CEGUI cgui/saheader.ttf -> MTAX \"pricedown\" which is Tahoma bold; the SA face is unavailable" },
    ["sa-gothic"]          = { dx = "bankgothic",   scale = 1.00,
        note = "CEGUI cgui/sagothic.ttf -> MTAX \"bankgothic\" which is Tahoma bold; the SA face is unavailable" },
}
M.GUI_FONTS = GUI_FONTS

local DX_FONTS = {
    ["default"] = true, ["default-bold"] = true, ["clear"] = true, ["arial"] = true,
    ["sans"] = true, ["pricedown"] = true, ["bankgothic"] = true, ["diploma"] = true,
    ["beckett"] = true, ["unifont"] = true,
}
M.DX_FONTS = DX_FONTS

local DEFAULT_FONT_NAME = "default-normal"
M.DEFAULT_FONT_NAME = DEFAULT_FONT_NAME

local customFonts = {}          -- [i] = { element = el, path = ..., size = pt }
M.customFonts = customFonts

local function resolveFont(fontSpec)
    if fontSpec == nil then
        local f = GUI_FONTS[DEFAULT_FONT_NAME]
        return f.dx, f.scale
    end
    if ty(fontSpec) == "string" then
        local f = GUI_FONTS[fontSpec]
        if f then return f.dx, f.scale end
        if DX_FONTS[fontSpec] then return fontSpec, 1.0 end
        -- Unknown: MTAX would silently make it Tahoma 15. Say so, once.
        unsupported("guiSetFont(\"" .. fontSpec .. "\")",
            "not one of MTA's 8 CEGUI GUI font names and not one of MTAX's 10 dx font " ..
            "names; MTAX will silently rasterise it as Tahoma 15px")
        return "default", 1.0
    end
    -- A dx-font element from guiCreateFont.
    if nIsElement(fontSpec) then return fontSpec, 1.0 end
    local f = GUI_FONTS[DEFAULT_FONT_NAME]
    return f.dx, f.scale
end
M.resolveFont = resolveFont

local function textWidth(text, fontSpec)
    local f, s = resolveFont(fontSpec)
    local ok, w = pcall(nDxGetTextWidth, text or "", s, f, false)
    return (ok and ty(w) == "number") and w or 0
end
M.textWidth = textWidth

local fontHeightCache = setmetatable({}, { __mode = "k" })

local function fontHeight(fontSpec)
    local key = fontSpec
    if key == nil then key = "\0default" end
    local cached = fontHeightCache[key]
    if cached then return cached end
    local f, s = resolveFont(fontSpec)
    local ok, h = pcall(nDxGetFontHeight, s, f)
    if not (ok and ty(h) == "number" and h > 0) then return 12 end
    fontHeightCache[key] = h
    return h
end
M.fontHeight = fontHeight
M.flushFontMetrics = function()
    for k in pairs(fontHeightCache) do fontHeightCache[k] = nil end
end

local FONT_PX_PER_UNIT = 1.75      -- renderapi.cpp:309
define("guiCreateFont", function(filepath, size)
    if ty(filepath) ~= "string" or filepath == "" then return false end
    local pt = num(size, 9)
    if pt ~= pt or pt <= 0 then pt = 9 end
    local wantedPx = pt * 4 / 3
    local unit = floor(clamp(wantedPx / FONT_PX_PER_UNIT + 0.5, 5, 150))
    if nFileExists and not nFileExists(filepath) then
        return false
    end
    local ok, el = pcall(nDxCreateFont, filepath, unit, false, "cleartype")
    if not ok or not el or el == false or not nIsElement(el) then return false end
    customFonts[#customFonts + 1] = { element = el, path = filepath, size = pt }
    return el
end)

local widgetsById = {}          -- ["mtaxgui#7"] = widget record
local handleCache = setmetatable({}, { __mode = "k" })
local nextHandleId = 0

M.widgetsById = widgetsById

local ID_PREFIX = "mtaxgui#"
M.ID_PREFIX = ID_PREFIX

local function resolve(value)
    if value == nil then return nil end
    local t = ty(value)
    if t ~= "userdata" and t ~= "table" then return nil end
    local cached = handleCache[value]
    if cached ~= nil then
        if not cached.destroyed and nIsElement(value) then return cached end
        handleCache[value] = nil
    end
    if not nIsElement(value) then return nil end
    local id = nGetElementID(value)
    if ty(id) ~= "string" then return nil end
    local w = widgetsById[id]
    if w == nil or w.destroyed then return nil end
    if w.el == nil or w.el ~= value then return nil end
    handleCache[value] = w
    return w
end
M.resolve = resolve

local function resolveTyped(value, wanted)
    local w = resolve(value)
    if w == nil then return nil end
    if wanted ~= nil and w.type ~= wanted then return nil end
    return w
end
M.resolveTyped = resolveTyped

local topLevel = {}             -- ordered, back-to-front
M.topLevel = topLevel

local classes = {}              -- [typeName] = class table
M.classes = classes

local layout

local layoutDirty = true
local screenW, screenH = 800, 600
do
    local w, h = nGetScreenSize()
    if ty(w) == "number" and w > 0 then screenW, screenH = w, h end
end
M.screen = function() return screenW, screenH end

local function markDirty()
    layoutDirty = true
end
M.markDirty = markDirty

local function indexOf(list, v)
    for i = 1, #list do
        if list[i] == v then return i end
    end
    return nil
end
M.indexOf = indexOf

local function siblingList(w)
    return w.parent and w.parent.children or topLevel
end
M.siblingList = siblingList

local function newWidget(typeName, x, y, w, h, relative, parentValue, init)
    local parent = parentValue ~= nil and resolve(parentValue) or nil
    if parentValue ~= nil and parent == nil then
        parent = nil
    end

    x, y, w, h = num(x, 0), num(y, 0), num(w, 0), num(h, 0)
    if truthy(relative) then
        local pw, ph = screenW, screenH
        if parent then
            layout()
            local cls = classes[parent.type]
            if cls and cls.childArea then
                local _, _, aw, ah = cls.childArea(parent)
                pw, ph = aw, ah
            else
                pw, ph = parent._aw, parent._ah
            end
        end
        x, y, w, h = x * pw, y * ph, w * pw, h * ph
    end

    nextHandleId = nextHandleId + 1
    local id = ID_PREFIX .. nextHandleId
    local el = nCreateElement(typeName, id)
    if el == false or el == nil or not nIsElement(el) then
        nOutputDebugString("[" .. SHIM .. "] createElement(\"" .. typeName ..
                           "\") failed; the widget could not be created.", 1)
        return false
    end

    local rec = {
        id = id,
        el = el,
        type = typeName,
        parent = parent,
        children = {},
        x = x, y = y, w = w, h = h,
        visible = true,
        enabled = true,
        alpha = 1.0,
        text = "",
        font = DEFAULT_FONT_NAME,
        clippedByParent = true,
        inheritsAlpha = true,
        mousePassThrough = false,
        destroyed = false,
        props = {},
        -- layout cache, filled by layout()
        _ax = x, _ay = y, _aw = w, _ah = h,
        _cx1 = 0, _cy1 = 0, _cx2 = screenW, _cy2 = screenH,
        _alpha = 1.0, _enabled = true, _visible = true,
    }
    if init then
        for k, v in pairs(init) do rec[k] = v end
    end

    widgetsById[id] = rec
    handleCache[el] = rec

    if parent then
        parent.children[#parent.children + 1] = rec
        nSetElementParent(el, parent.el)
    else
        topLevel[#topLevel + 1] = rec
    end

    markDirty()
    return rec
end
M.newWidget = newWidget

local function unlink(w)
    if w.destroyed then return end
    w.destroyed = true

    local list = siblingList(w)
    local i = indexOf(list, w)
    if i then remove(list, i) end
    w.parent = nil

    for j = 1, #w.children do
        w.children[j].parent = nil
    end
    w.children = {}

    widgetsById[w.id] = nil
    if w.el ~= nil then handleCache[w.el] = nil end
    w.el = nil

    if M.focused == w then M.focused = nil end
    if M.hovered == w then M.hovered = nil end
    if M.captured == w then M.captured = nil; M.captureMode = nil end
    if M.pressed == w then M.pressed = nil; M.pressedButton = nil; M.pressX, M.pressY = nil, nil end
    if M.popup == w then M.popup = nil end

    local cls = classes[w.type]
    if cls and cls.dispose then pcall(cls.dispose, w) end

    markDirty()
end
M.unlink = unlink

local function destroyWidget(w)
    if w == nil or w.destroyed then return false end
    local el = w.el
    if el ~= nil and nIsElement(el) then
        nDestroyElement(el)          -- fires onClientElementDestroy for the subtree
    end
    if not w.destroyed then unlink(w) end   -- belt and braces
    return true
end
M.destroyWidget = destroyWidget

local function intersect(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2)
    if bx1 > ax1 then ax1 = bx1 end
    if by1 > ay1 then ay1 = by1 end
    if bx2 < ax2 then ax2 = bx2 end
    if by2 < ay2 then ay2 = by2 end
    return ax1, ay1, ax2, ay2
end
M.intersect = intersect

local function layoutNode(w, px, py, pw, ph, cx1, cy1, cx2, cy2, alpha, enabled, visible)
    w._ax = px + w.x
    w._ay = py + w.y
    w._aw = w.w
    w._ah = w.h
    w._alpha = w.inheritsAlpha and (alpha * w.alpha) or w.alpha
    w._enabled = enabled and w.enabled
    w._visible = visible and w.visible
    w._cx1, w._cy1, w._cx2, w._cy2 = cx1, cy1, cx2, cy2

    local cls = classes[w.type]
    if cls and cls.reflow then cls.reflow(w) end

    local n = #w.children
    if n == 0 then return end

    -- Where children's (x, y) are measured from, and how big "relative 1.0" is.
    local kx, ky, kw, kh = w._ax, w._ay, w._aw, w._ah
    if cls and cls.childArea then kx, ky, kw, kh = cls.childArea(w) end

    -- What children are clipped to.
    local bx1, by1, bx2, by2 = w._ax, w._ay, w._ax + w._aw, w._ay + w._ah
    if cls and cls.clipArea then bx1, by1, bx2, by2 = cls.clipArea(w) end
    local nx1, ny1, nx2, ny2 = intersect(cx1, cy1, cx2, cy2, bx1, by1, bx2, by2)

    local childVisible = cls and cls.childVisible
    for i = 1, n do
        local c = w.children[i]
        local vis = w._visible
        if childVisible and not childVisible(w, c) then vis = false end
        if c.clippedByParent then
            layoutNode(c, kx, ky, kw, kh, nx1, ny1, nx2, ny2, w._alpha, w._enabled, vis)
        else
            layoutNode(c, kx, ky, kw, kh, 0, 0, screenW, screenH, w._alpha, w._enabled, vis)
        end
    end
end

layout = function()
    if not layoutDirty then return end
    layoutDirty = false
    for i = 1, #topLevel do
        layoutNode(topLevel[i], 0, 0, screenW, screenH, 0, 0, screenW, screenH, 1.0, true, true)
    end
end
M.layout = layout

local function parentBox(w)
    layout()
    local p = w.parent
    if not p then return 0, 0, screenW, screenH end
    local cls = classes[p.type]
    if cls and cls.childArea then return cls.childArea(p) end
    return p._ax, p._ay, p._aw, p._ah
end
M.parentBox = parentBox

local function fillRect(x, y, w, h, color, cl)
    local x1, y1, x2, y2 = x, y, x + w, y + h
    if cl then x1, y1, x2, y2 = intersect(x1, y1, x2, y2, cl[1], cl[2], cl[3], cl[4]) end
    if x2 <= x1 or y2 <= y1 then return end
    nDxDrawRectangle(x1, y1, x2 - x1, y2 - y1, color)
end
M.fillRect = fillRect

local function frameRect(x, y, w, h, t, color, cl)
    if w <= 0 or h <= 0 then return end
    t = t or 1
    fillRect(x,         y,         w, t,     color, cl)
    fillRect(x,         y + h - t, w, t,     color, cl)
    fillRect(x,         y + t,     t, h - t * 2, color, cl)
    fillRect(x + w - t, y + t,     t, h - t * 2, color, cl)
end
M.frameRect = frameRect

local function drawText(text, x1, y1, x2, y2, color, fontSpec, alignX, alignY, wrap, cl)
    if text == nil or text == "" then return end
    local f, s = resolveFont(fontSpec)
    local bx1, by1, bx2, by2 = x1, y1, x2, y2
    if cl then bx1, by1, bx2, by2 = intersect(bx1, by1, bx2, by2, cl[1], cl[2], cl[3], cl[4]) end
    if bx2 <= bx1 or by2 <= by1 then return end
    nDxDrawText(text, bx1, by1, bx2, by2, color, s, f,
                alignX or "left", alignY or "top", true, wrap or false, false, false)
end
M.drawText = drawText

local materialSizeCache = setmetatable({}, { __mode = "k" })

local function materialSize(image)
    local cached = materialSizeCache[image]
    if cached then return cached[1], cached[2] end
    local ok, w, h = pcall(nDxGetMaterialSize, image)
    if not ok or ty(w) ~= "number" or ty(h) ~= "number" or w <= 0 or h <= 0 then
        return nil, nil
    end
    materialSizeCache[image] = { w, h }
    return w, h
end
M.materialSize = materialSize

local function drawImage(x, y, w, h, image, color, cl)
    if image == nil or w <= 0 or h <= 0 then return end
    local x1, y1, x2, y2 = x, y, x + w, y + h
    local cx1, cy1, cx2, cy2 = x1, y1, x2, y2
    if cl then cx1, cy1, cx2, cy2 = intersect(cx1, cy1, cx2, cy2, cl[1], cl[2], cl[3], cl[4]) end
    if cx2 <= cx1 or cy2 <= cy1 then return end
    if cx1 == x1 and cy1 == y1 and cx2 == x2 and cy2 == y2 then
        nDxDrawImage(x1, y1, w, h, image, 0, 0, 0, color)
        return
    end
    local tw, th = materialSize(image)
    if tw == nil then
        -- No measurable source (a raw path, a shader): draw the clipped rect and
        -- accept the stretch rather than overdrawing outside the clip.
        nDxDrawImage(cx1, cy1, cx2 - cx1, cy2 - cy1, image, 0, 0, 0, color)
        return
    end
    local u  = (cx1 - x1) / w * tw
    local v  = (cy1 - y1) / h * th
    local uw = (cx2 - cx1) / w * tw
    local vh = (cy2 - cy1) / h * th
    nDxDrawImageSection(cx1, cy1, cx2 - cx1, cy2 - cy1, u, v, uw, vh, image, 0, 0, 0, color)
end
M.drawImage = drawImage

local function drawNode(w)
    if not w._visible then return end
    if w._cx2 <= w._cx1 or w._cy2 <= w._cy1 then return end
    local cls = classes[w.type]
    if cls and cls.draw then cls.draw(w) end
    local kids = w.children
    for i = 1, #kids do
        drawNode(kids[i])
    end
    if cls and cls.drawAfter then cls.drawAfter(w) end
end
M.drawNode = drawNode

M.popup = nil

local function renderPass()
    local sw, sh = nGetScreenSize()
    if ty(sw) == "number" and sw > 0 and (sw ~= screenW or sh ~= screenH) then
        screenW, screenH = sw, sh
        M.flushFontMetrics()
        markDirty()
    end
    if M.cursorX < 0 and nIsCursorShowing() then
        local rx, ry = nGetCursorPosition()
        if ty(rx) == "number" and ty(ry) == "number" then
            M.cursorX, M.cursorY = rx * screenW, ry * screenH
        end
    end
    layout()
    for i = 1, #topLevel do
        drawNode(topLevel[i])
    end
    local pop = M.popup
    if pop and not pop.destroyed and pop._visible then
        local cls = classes[pop.type]
        if cls and cls.drawPopup then cls.drawPopup(pop) end
    end
end

local function pointIn(x, y, x1, y1, x2, y2)
    return x >= x1 and x < x2 and y >= y1 and y < y2
end
M.pointIn = pointIn

local function hitIn(w, x, y)
    if not w._visible then return nil end
    if not pointIn(x, y, w._cx1, w._cy1, w._cx2, w._cy2) then return nil end
    local kids = w.children
    for i = #kids, 1, -1 do
        local r = hitIn(kids[i], x, y)
        if r then return r end
    end
    if w.mousePassThrough then return nil end
    local cls = classes[w.type]
    if cls and cls.hitBox then
        local bx1, by1, bx2, by2 = cls.hitBox(w)
        if pointIn(x, y, bx1, by1, bx2, by2) then return w end
        return nil
    end
    if pointIn(x, y, w._ax, w._ay, w._ax + w._aw, w._ay + w._ah) then return w end
    return nil
end

local function hitTest(x, y)
    layout()
    local pop = M.popup
    if pop and not pop.destroyed and pop._visible then
        local cls = classes[pop.type]
        if cls and cls.hitPopup then
            local r = cls.hitPopup(pop, x, y)
            if r then return r end
        end
    end
    for i = #topLevel, 1, -1 do
        local r = hitIn(topLevel[i], x, y)
        if r then return r end
    end
    return nil
end
M.hitTest = hitTest

local function effectivelyEnabled(w)
    layout()
    return w._enabled == true
end
M.effectivelyEnabled = effectivelyEnabled

local GUI_EVENTS = {
    "onClientGUIClick",             -- button, state, absoluteX, absoluteY
    "onClientGUIDoubleClick",       -- button, state, absoluteX, absoluteY
    "onClientGUIMouseDown",         -- button, absoluteX, absoluteY
    "onClientGUIMouseUp",           -- button, absoluteX, absoluteY
    "onClientGUIScroll",            -- (source only)
    "onClientGUIChanged",           -- (source only)
    "onClientGUIAccepted",          -- (source only)
    "onClientGUITabSwitched",       -- (source only)
    "onClientGUIComboBoxAccepted",  -- (source only)
    "onClientGUIMove",              -- (none)
    "onClientGUISize",              -- (none)
    "onClientGUIFocus",             -- (none)
    "onClientGUIBlur",              -- (none)
    -- MTA fires these three ON GUI ELEMENTS as well (they are the GUI-scoped
    -- variants declared at CClientGame.cpp:2737-2739 and fired from
    -- CClientGame::OnMouseMove/OnMouseEnters/OnMouseLeaves).
    "onClientMouseEnter",           -- screenX, screenY
    "onClientMouseLeave",           -- screenX, screenY
    "onClientMouseMove",            -- screenX, screenY
}
M.GUI_EVENTS = GUI_EVENTS

-- DELIBERATELY NOT REGISTERED, and why:
--   onClientGUIClose      -- commented out at CClientGame.cpp:2730, never fires on MTA either
--   onClientGUIKeyDown    -- commented out at CClientGame.cpp:2731, same
--   onClientGUIClicked    -- named in SetEvents, never registered in AddEvents
--   onClientGUIStateChanged -- same
-- The converter must not "fix" MTA's own dead events.

for i = 1, #GUI_EVENTS do
    nAddEvent(GUI_EVENTS[i], true)
end

local function fire(eventName, w, ...)
    if w == nil or w.destroyed or w.el == nil then return end
    if not nIsElement(w.el) then return end
    nTriggerEvent(eventName, w.el, ...)
end
M.fire = fire

M.focused = nil

local function blur()
    local old = M.focused
    if old == nil then return false end
    M.focused = nil
    if not old.destroyed then
        local cls = classes[old.type]
        if cls and cls.onBlur then cls.onBlur(old) end
        fire("onClientGUIBlur", old)
    end
    return true
end
M.blur = blur

local function focus(w)
    if w == nil or w.destroyed then return blur() end
    if M.focused == w then return true end
    blur()
    M.focused = w
    local cls = classes[w.type]
    if cls and cls.onFocus then cls.onFocus(w) end
    fire("onClientGUIFocus", w)
    return true
end
M.focus = focus

-- isUnder(node, root) -- node is root or one of its descendants.
local function isUnder(node, root)
    while node ~= nil do
        if node == root then return true end
        node = node.parent
    end
    return false
end
M.isUnder = isUnder

local function dropInteraction(w)
    if w == nil then return end
    local hov = M.hovered
    if hov ~= nil and isUnder(hov, w) then
        M.hovered = nil
        if not hov.destroyed then
            local cls = classes[hov.type]
            if cls and cls.onLeave then cls.onLeave(hov) end
            fire("onClientMouseLeave", hov, M.cursorX, M.cursorY)
        end
    end
    if M.pressed ~= nil and isUnder(M.pressed, w) then
        M.pressed = nil
        M.pressedButton = nil
        M.pressX, M.pressY = nil, nil
    end
    local cap = M.captured
    if cap ~= nil and isUnder(cap, w) then
        M.captured = nil
        M.captureMode = nil
        if not cap.destroyed then
            local cls = classes[cap.type]
            if cls and cls.onDragEnd then cls.onDragEnd(cap) end
        end
    end
end
M.dropInteraction = dropInteraction

local function raiseAlwaysOnTop(list)
    local pinned = nil
    for i = 1, #list do
        if list[i].alwaysOnTop then
            pinned = pinned or {}
            pinned[#pinned + 1] = list[i]
        end
    end
    if pinned == nil then return end
    for k = 1, #pinned do
        local p = pinned[k]
        local at = indexOf(list, p)
        if at then remove(list, at) end
        list[#list + 1] = p
    end
end

local function bringToFront(w)
    if w == nil or w.destroyed then return false end
    local list = siblingList(w)
    local i = indexOf(list, w)
    if i == nil then return false end
    if i ~= #list then
        remove(list, i)
        list[#list + 1] = w
    end
    raiseAlwaysOnTop(list)
    if w.parent then bringToFront(w.parent) end
    markDirty()
    return true
end
M.bringToFront = bringToFront

local function moveToBack(w)
    if w == nil or w.destroyed then return false end
    local list = siblingList(w)
    local i = indexOf(list, w)
    if i == nil then return false end
    if i ~= 1 then
        remove(list, i)
        insert(list, 1, w)
    end
    markDirty()
    return true
end
M.moveToBack = moveToBack

M.cursorX, M.cursorY = -1, -1
M.hovered = nil
M.captured = nil        -- widget holding the drag
M.captureMode = nil     -- class-defined string, e.g. "move" / "size-se" / "thumb"
M.pressed = nil         -- widget that received the current mouse-down
M.pressedButton = nil
M.pressX, M.pressY = nil, nil   -- where that mouse-down landed

local handlers = {}     -- { {name = , element = , fn = } }

local function addHandler(name, element, fn)
    if nAddEventHandler(name, element, fn) then
        handlers[#handlers + 1] = { name = name, element = element, fn = fn }
        return true
    end
    return false
end
M.addHandler = addHandler

local function removeAllHandlers()
    for i = #handlers, 1, -1 do
        local h = handlers[i]
        pcall(nRemoveEventHandler, h.name, h.element, h.fn)
        handlers[i] = nil
    end
end
M.removeAllHandlers = removeAllHandlers

local root = nGetRootElement()
local resourceRoot = nGetResourceRootElement()
local thisResource = nGetThisResource()
M.root = root

local function updateHover(x, y)
    local hit = hitTest(x, y)
    local old = M.hovered
    if hit ~= old then
        if old and not old.destroyed then
            local cls = classes[old.type]
            if cls and cls.onLeave then cls.onLeave(old) end
            fire("onClientMouseLeave", old, x, y)
        end
        M.hovered = hit
        if hit then
            local cls = classes[hit.type]
            if cls and cls.onEnter then cls.onEnter(hit) end
            fire("onClientMouseEnter", hit, x, y)
        end
    end
    if hit then
        fire("onClientMouseMove", hit, x, y)
    end
end

local function onCursorMove(relX, relY, absX, absY)
    absX = num(absX, nil)
    absY = num(absY, nil)
    if absX == nil or absY == nil then
        local rx, ry = num(relX, nil), num(relY, nil)
        if rx == nil then return end
        absX, absY = rx * screenW, ry * screenH
    end
    M.cursorX, M.cursorY = absX, absY

    local cap = M.captured
    if cap and not cap.destroyed then
        local cls = classes[cap.type]
        if cls and cls.onDrag then cls.onDrag(cap, absX, absY) end
        return
    end
    updateHover(absX, absY)
end

local function releaseCapture()
    local cap = M.captured
    if cap and not cap.destroyed then
        local cls = classes[cap.type]
        if cls and cls.onDragEnd then cls.onDragEnd(cap) end
    end
    M.captured = nil
    M.captureMode = nil
end
M.releaseCapture = releaseCapture

local function capture(w, mode)
    M.captured = w
    M.captureMode = mode
end
M.capture = capture

local function onMouseDown(button, x, y)
    local hit = hitTest(x, y)

    local pop = M.popup
    if pop and not pop.destroyed then
        local cls = classes[pop.type]
        local inPopup = cls and cls.hitPopup and cls.hitPopup(pop, x, y) or nil
        if inPopup == nil and hit ~= pop then
            if cls and cls.closePopup then cls.closePopup(pop) end
        end
    end

    M.pressed = hit
    M.pressedButton = button
    M.pressX, M.pressY = x, y

    if hit == nil then
        blur()
        return
    end
    if not effectivelyEnabled(hit) then
        return
    end

    focus(hit)
    if button == "left" then bringToFront(hit) end

    local cls = classes[hit.type]
    if cls and cls.onMouseDown then cls.onMouseDown(hit, button, x, y) end

    fire("onClientGUIMouseDown", hit, button, x, y)
    fire("onClientGUIClick", hit, button, "down", x, y)
end

local CLICK_TOLERANCE = 6

local function onMouseUp(button, x, y)
    local cap = M.captured
    if cap then releaseCapture() end

    local target = M.pressed
    local pressX, pressY = M.pressX, M.pressY
    M.pressed = nil
    M.pressedButton = nil
    M.pressX, M.pressY = nil, nil

    if target == nil or target.destroyed then return end
    if not effectivelyEnabled(target) then return end

    local over = (hitTest(x, y) == target)

    local cls = classes[target.type]
    if cls and cls.onMouseUp then cls.onMouseUp(target, button, x, y, over) end

    fire("onClientGUIMouseUp", target, button, x, y)

    local within = pressX == nil
        or (abs(x - pressX) <= CLICK_TOLERANCE and abs(y - pressY) <= CLICK_TOLERANCE)
    if within then
        fire("onClientGUIClick", target, button, "up", x, y)
    end
end

local function onClick(button, state, absX, absY)
    if ty(button) ~= "string" or ty(state) ~= "string" then return end
    local x, y = num(absX, M.cursorX), num(absY, M.cursorY)
    if x < 0 then return end
    M.cursorX, M.cursorY = x, y
    if state == "down" then
        onMouseDown(button, x, y)
    elseif state == "up" then
        onMouseUp(button, x, y)
    end
end

local function onDoubleClick(button, absX, absY)
    if ty(button) ~= "string" then return end
    local x, y = num(absX, M.cursorX), num(absY, M.cursorY)
    if x < 0 then return end
    local hit = hitTest(x, y)
    if hit == nil or not effectivelyEnabled(hit) then return end
    local cls = classes[hit.type]
    if cls and cls.onDoubleClick then cls.onDoubleClick(hit, button, x, y) end
    fire("onClientGUIDoubleClick", hit, button, "up", x, y)
end

local function routeWheel(delta)
    if not nIsCursorShowing() then return end
    local x, y = M.cursorX, M.cursorY
    if x < 0 then return end

    local pop = M.popup
    if pop and not pop.destroyed then
        local cls = classes[pop.type]
        if cls and cls.hitPopup and cls.hitPopup(pop, x, y) and cls.onWheel then
            if cls.onWheel(pop, delta) then fire("onClientGUIScroll", pop) end
            return
        end
    end

    local w = hitTest(x, y)
    while w do
        if effectivelyEnabled(w) then
            local cls = classes[w.type]
            if cls and cls.onWheel and cls.onWheel(w, delta) then
                fire("onClientGUIScroll", w)
                return
            end
        end
        w = w.parent
    end
end

local function shiftHeld()
    return nGetKeyState("lshift") or nGetKeyState("rshift")
end
M.shiftHeld = shiftHeld

local function ctrlHeld()
    return nGetKeyState("lctrl") or nGetKeyState("rctrl")
end
M.ctrlHeld = ctrlHeld

local function onKey(key, down)
    if ty(key) ~= "string" then return end

    if down and key == "mouse_wheel_up" then    routeWheel(-1) return end
    if down and key == "mouse_wheel_down" then  routeWheel(1)  return end

    if key == "mouse1" or key == "mouse2" or key == "mouse3"
       or key == "mouse4" or key == "mouse5" then
        return
    end

    if not down then return end
    local f = M.focused
    if f == nil or f.destroyed then return end
    if not effectivelyEnabled(f) then return end
    local cls = classes[f.type]
    if cls and cls.onKey then cls.onKey(f, key) end
end

local function onCharacter(character)
    if ty(character) ~= "string" or character == "" then return end
    local f = M.focused
    if f == nil or f.destroyed then return end
    if not effectivelyEnabled(f) then return end
    local cls = classes[f.type]
    if cls and cls.onCharacter then cls.onCharacter(f, character) end
end

local function onPaste(text)
    if ty(text) ~= "string" or text == "" then return end
    local f = M.focused
    if f == nil or f.destroyed then return end
    if not effectivelyEnabled(f) then return end
    local cls = classes[f.type]
    if cls and cls.onPaste then cls.onPaste(f, text) end
end

M.setClipboard = function(text)
    if nSetClipboard == nil then
        unsupported("clipboard write", "setClipboard is not available in this MTAX build")
        return false
    end
    local ok, r = pcall(nSetClipboard, ty(text) == "string" and text or "")
    return ok and r or false
end

local inputEnabled = false
local inputMode = "allow_binds"
local VALID_INPUT_MODES = {
    allow_binds = true, no_binds = true, no_binds_when_editing = true,
}

local INPUT_MODE_WARNING =
    "guiSetInputMode / guiSetInputEnabled cannot do on MTAX what they do on MTA. " ..
    "MTA suppresses key binds while a GUI edit box has focus; MTAX dispatches every " ..
    "key to bindKey and onClientKey before any Lua handler can object, and cancelEvent " ..
    "on onClientKey is IGNORED (research/events.json: cancelHonoured = \"ignored\"). " ..
    "The shim only records the mode so guiGetInputMode round-trips. Typing into a " ..
    "shim edit box WILL still trigger the player's binds. If you need the game to stop " ..
    "responding, call toggleAllControls(false) yourself while the panel is open."

define("guiSetInputEnabled", function(enabled)
    warnOnce("inputmode", INPUT_MODE_WARNING)
    unsupported("guiSetInputEnabled", "recorded but not enforced; MTAX cannot suppress binds")
    inputEnabled = truthy(enabled)
    inputMode = inputEnabled and "no_binds" or "allow_binds"
    return true
end)

define("guiGetInputEnabled", function()
    return inputEnabled
end)

define("guiSetInputMode", function(mode)
    warnOnce("inputmode", INPUT_MODE_WARNING)
    unsupported("guiSetInputMode", "recorded but not enforced; MTAX cannot suppress binds")
    if ty(mode) ~= "string" or not VALID_INPUT_MODES[mode] then return false end
    inputMode = mode
    inputEnabled = (mode ~= "allow_binds")
    return true
end)

define("guiGetInputMode", function()
    return inputMode
end)

local cursorTypeNames = {
    ["move"]      = "sizing_move",
    ["size-n"]    = "sizing_ns",   ["size-s"]  = "sizing_ns",
    ["size-w"]    = "sizing_ew",   ["size-e"]  = "sizing_ew",
    ["size-nw"]   = "sizing_nwse", ["size-se"] = "sizing_nwse",
    ["size-ne"]   = "sizing_nesw", ["size-sw"] = "sizing_nesw",
}
M.cursorTypeNames = cursorTypeNames
M.logicalCursor = "default"

define("guiGetCursorType", function()
    if not nIsCursorShowing() then return "none" end
    unsupported("guiGetCursorType",
        "returns the cursor the shim WOULD show; MTAX has no way to change the drawn cursor image")
    return M.logicalCursor or "default"
end)

addHandler("onClientRender", root, renderPass)
addHandler("onClientCursorMove", root, onCursorMove)
addHandler("onClientClick", root, onClick)
addHandler("onClientDoubleClick", root, onDoubleClick)
addHandler("onClientKey", root, onKey)
addHandler("onClientCharacter", root, onCharacter)
addHandler("onClientPaste", root, onPaste)

addHandler("onClientElementDestroy", root, function()
    local w = resolve(source)
    if w then unlink(w) end
end)

local stopped = false
local function shutdown()
    if stopped then return end
    stopped = true
    for i = #topLevel, 1, -1 do
        local w = topLevel[i]
        if w and not w.destroyed then destroyWidget(w) end
    end
    for _, w in pairs(widgetsById) do
        if not w.destroyed then unlink(w) end
    end
    for k in pairs(widgetsById) do widgetsById[k] = nil end
    for i = #customFonts, 1, -1 do
        local f = customFonts[i]
        if f ~= nil and f.element ~= nil and nIsElement(f.element) then
            pcall(nDestroyElement, f.element)
        end
        customFonts[i] = nil
    end
    for i = #topLevel, 1, -1 do topLevel[i] = nil end
    M.focused, M.hovered, M.captured, M.pressed, M.popup = nil, nil, nil, nil, nil
    M.captureMode, M.pressedButton = nil, nil
    M.pressX, M.pressY = nil, nil
    removeAllHandlers()
    M.report()
end
M.shutdown = shutdown

addHandler("onClientResourceStop", root, function(resourceName)
    local mine = false
    if ty(resourceName) == "string" then
        mine = (resourceName == thisResource)
    elseif resourceRoot ~= nil and nIsElement(resourceRoot) then
        mine = (source == resourceRoot)
    end
    if mine then shutdown() end
end)

M.fillRect = fillRect
M.frameRect = frameRect
M.drawText = drawText
M.drawImage = drawImage

M.clip = function(w)
    local t = w._clipT
    if t == nil then t = {}; w._clipT = t end
    t[1], t[2], t[3], t[4] = w._cx1, w._cy1, w._cx2, w._cy2
    return t
end
M.clipOf = M.clip

M.innerClip = function(w, insetL, insetT, insetR, insetB)
    local t = w._innerT
    if t == nil then t = {}; w._innerT = t end
    local x1 = w._ax + (insetL or 0)
    local y1 = w._ay + (insetT or 0)
    local x2 = w._ax + w._aw - (insetR or 0)
    local y2 = w._ay + w._ah - (insetB or 0)
    x1, y1, x2, y2 = intersect(x1, y1, x2, y2, w._cx1, w._cy1, w._cx2, w._cy2)
    t[1], t[2], t[3], t[4] = x1, y1, x2, y2
    return t
end

M.makeClip = function(x1, y1, x2, y2)
    return { x1, y1, x2, y2 }
end

M.tick = nGetTickCount

M.natives = {
    isElement = nIsElement,
    getElementID = nGetElementID,
    getElementType = nGetElementType,
    createElement = nCreateElement,
    destroyElement = nDestroyElement,
    setElementParent = nSetElementParent,
    dxCreateTexture = nDxCreateTexture,
    dxGetMaterialSize = nDxGetMaterialSize,
    getCursorPosition = nGetCursorPosition,
    isCursorShowing = nIsCursorShowing,
    outputDebugString = nOutputDebugString,
}

M.ready = true

info("core loaded (v" .. VERSION .. "). This is an EMULATION of MTA's CEGUI GUI, " ..
     "not an equivalent. See mtax_guicompat/README.md for the fidelity table.")
