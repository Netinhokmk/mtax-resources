local C = rawget(_G, "mtaxGuiCompat")
if type(C) ~= "table" or C.ready ~= true then
    if type(outputDebugString) == "function" then
        outputDebugString("[mtax_guicompat] widgets.lua: core.lua is not loaded, so " ..
                          "no widget function was defined. Put core.lua first in client_files.", 2)
    end
    return
end

if C.widgetsReady == true then
    outputDebugString("[mtax_guicompat] widgets.lua: already loaded in this VM; nothing was " ..
                      "redefined. widgets.lua must appear exactly once in client_files.", 2)
    return
end

local define        = C.define
local classes       = C.classes
local resolve       = C.resolve
local resolveTyped  = C.resolveTyped
local newWidget     = C.newWidget
local destroyWidget = C.destroyWidget
local unsupported   = C.unsupported
local warnOnce      = C.warnOnce
local markDirty     = C.markDirty
local layout        = C.layout
local parentBox     = C.parentBox
local fire          = C.fire
local focusW        = C.focus
local blurW         = C.blur
local bringToFront  = C.bringToFront
local moveToBack    = C.moveToBack
local capture       = C.capture
local fillRect      = C.fillRect
local frameRect     = C.frameRect
local drawText      = C.drawText
local drawImage     = C.drawImage
local clip          = C.clip
local innerClip     = C.innerClip
local makeClip      = C.makeClip
local intersect     = C.intersect
local argb          = C.argb
local withAlpha     = C.withAlpha
local num           = C.num
local str           = C.str
local truthy        = C.truthy
local clamp         = C.clamp
local ulen          = C.ulen
local usub          = C.usub
local textWidth     = C.textWidth
local fontHeight    = C.fontHeight
local pointIn       = C.pointIn
local indexOf       = C.indexOf
local siblingList   = C.siblingList
local T             = C.theme
local tick          = C.tick
local nIsElement    = C.natives.isElement
local nDxCreateTexture   = C.natives.dxCreateTexture
local nDxGetMaterialSize = C.natives.dxGetMaterialSize
local nDestroyElement    = C.natives.destroyElement
local nGetElementType    = C.natives.getElementType
local dropInteraction    = C.dropInteraction

local floor, ceil, min, max, abs = math.floor, math.ceil, math.min, math.max, math.abs
local rep, format = string.rep, string.format
local insert, remove, sort, concat = table.insert, table.remove, table.sort, table.concat
local ty, tostr, tonum = type, tostring, tonumber

local PAD       = 4
local BORDER    = 1
local SCROLL_W  = 14
local GRIP      = 6

local function lineH(w)   return fontHeight(w.font) end
local function rowH(w)    return floor(fontHeight(w.font) + 4) end
local function titleH(w)  return max(20, floor(fontHeight(w.font) + 8)) end

local function ct(w, base)
    return withAlpha(base, w._alpha)
end

local function textColour(w)
    if not w._enabled then return ct(w, T.textDisabled) end
    if w.textColor then return ct(w, w.textColor) end
    return ct(w, T.text)
end

local function class(name, def)
    classes[name] = def
    return def
end

local function noteTextChanged(w, oldText)
    if w.text == oldText then return end
    if w.type == "gui-edit" or w.type == "gui-memo" then
        fire("onClientGUIChanged", w)
    end
end

local function noteMoved(w) fire("onClientGUIMove", w) end
local function noteSized(w) fire("onClientGUISize", w) end

local function stopInteracting(w)
    if C.focused ~= nil and C.isUnder(C.focused, w) then blurW() end
    if C.popup ~= nil and C.isUnder(C.popup, w) then
        local pcls = classes[C.popup.type]
        if pcls and pcls.closePopup then pcls.closePopup(C.popup) end
    end
    dropInteraction(w)
end

define("guiSetVisible", function(el, state)
    local w = resolve(el)
    if not w then return false end
    w.visible = truthy(state)
    if not w.visible then stopInteracting(w) end
    markDirty()
    return true
end)

define("guiGetVisible", function(el)
    local w = resolve(el)
    if not w then return false end
    return w.visible
end)

define("guiSetEnabled", function(el, enabled)
    local w = resolve(el)
    if not w then return false end
    w.enabled = truthy(enabled)
    if not w.enabled then stopInteracting(w) end
    markDirty()
    return true
end)

define("guiGetEnabled", function(el)
    local w = resolve(el)
    if not w then return false end
    return w.enabled
end)

define("guiSetAlpha", function(el, alpha)
    local w = resolve(el)
    if not w then return false end
    local a = num(alpha, nil)
    if a == nil then return false end
    w.alpha = clamp(a, 0, 1)
    markDirty()
    return true
end)

define("guiGetAlpha", function(el, effectiveAlpha)
    local w = resolve(el)
    if not w then return false end
    if truthy(effectiveAlpha) then
        layout()
        return w._alpha
    end
    return w.alpha
end)

define("guiSetPosition", function(el, x, y, relative)
    local w = resolve(el)
    if not w then return false end
    local nx, ny = num(x, nil), num(y, nil)
    if nx == nil or ny == nil then return false end
    if truthy(relative) then
        local _, _, pw, ph = parentBox(w)
        nx, ny = nx * pw, ny * ph
    end
    if w.x == nx and w.y == ny then return true end
    w.x, w.y = nx, ny
    markDirty()
    noteMoved(w)
    return true
end)

define("guiGetPosition", function(el, relative)
    local w = resolve(el)
    if not w then return false end
    if truthy(relative) then
        local _, _, pw, ph = parentBox(w)
        if pw == 0 or ph == 0 then return 0, 0 end
        return w.x / pw, w.y / ph
    end
    return w.x, w.y
end)

define("guiSetSize", function(el, width, height, relative)
    local w = resolve(el)
    if not w then return false end
    local nw, nh = num(width, nil), num(height, nil)
    if nw == nil or nh == nil then return false end
    if truthy(relative) then
        local _, _, pw, ph = parentBox(w)
        nw, nh = nw * pw, nh * ph
    end
    if nw < 0 then nw = 0 end
    if nh < 0 then nh = 0 end
    if w.w == nw and w.h == nh then return true end
    w.w, w.h = nw, nh
    w._wrapDirty, w._caretDirty = true, true
    markDirty()
    noteSized(w)
    return true
end)

define("guiGetSize", function(el, relative)
    local w = resolve(el)
    if not w then return false end
    if truthy(relative) then
        local _, _, pw, ph = parentBox(w)
        if pw == 0 or ph == 0 then return 0, 0 end
        return w.w / pw, w.h / ph
    end
    return w.w, w.h
end)

define("guiSetText", function(el, text)
    local w = resolve(el)
    if not w then return false end
    local s = str(text, nil)
    if s == nil then return false end
    local cls = classes[w.type]
    local old = w.text
    if cls and cls.setText then
        cls.setText(w, s)
    else
        w.text = s
    end
    w._wrapDirty, w._caretDirty = true, true
    noteTextChanged(w, old)
    return true
end)

define("guiGetText", function(el)
    local w = resolve(el)
    if not w then return false end
    local cls = classes[w.type]
    if cls and cls.getText then return cls.getText(w) end
    return w.text
end)

define("guiSetFont", function(el, font)
    local w = resolve(el)
    if not w then return false end
    if ty(font) == "string" then
        if not C.GUI_FONTS[font] and not C.DX_FONTS[font] then
            unsupported("guiSetFont(\"" .. font .. "\")",
                "unknown font name; MTA would have failed here too")
            return false
        end
        w.font = font
    elseif nIsElement(font) then
        if nGetElementType(font) ~= "dx-font" then
            unsupported("guiSetFont(<element>)",
                "the element is not a dx-font. MTA wants a gui-font element and the shim wants " ..
                "the dxCreateFont element guiCreateFont returns; anything else is refused.")
            return false
        end
        w.font = font
    else
        return false
    end
    w._wrapDirty, w._caretDirty = true, true
    markDirty()
    return true
end)

define("guiGetFont", function(el)
    local w = resolve(el)
    if not w then return false end
    if ty(w.font) == "string" then return w.font, false end
    return "", w.font
end)

define("guiBringToFront", function(el)
    local w = resolve(el)
    if not w then return false end
    return bringToFront(w)
end)

define("guiMoveToBack", function(el)
    local w = resolve(el)
    if not w then return false end
    return moveToBack(w)
end)

define("guiFocus", function(el)
    local w = resolve(el)
    if not w then return false end
    if not w.enabled or not w.visible then return false end
    return focusW(w)
end)

define("guiBlur", function(el)
    local w = resolve(el)
    if not w then return false end
    if C.focused ~= w then return false end
    return blurW()
end)

local function ceguiBool(v)
    if ty(v) ~= "string" then return truthy(v) end
    local s = v:lower()
    return s == "true" or s == "1" or s == "yes"
end

local function boolStr(b) return b and "True" or "False" end

local function parseColour(v)
    if ty(v) ~= "string" then return nil end
    local hex = v:match("^%s*(%x%x%x%x%x%x%x%x)%s*$")
    if not hex then
        hex = v:match("tl:(%x%x%x%x%x%x%x%x)")
    end
    if not hex then return nil end
    local n = tonum(hex, 16)
    if n == nil then return nil end
    return n
end

local function colourStr(n)
    return format("%08X", floor(n) % 0x100000000)
end

local PROPS = {}

local function prop(name, get, set)
    PROPS[name] = { get = get, set = set }
end

prop("Visible",
    function(w) return boolStr(w.visible) end,
    function(w, v)
        w.visible = ceguiBool(v)
        if not w.visible then stopInteracting(w) end
        markDirty(); return true
    end)

prop("Disabled",
    function(w) return boolStr(not w.enabled) end,
    function(w, v)
        w.enabled = not ceguiBool(v)
        if not w.enabled then stopInteracting(w) end
        markDirty(); return true
    end)

prop("Alpha",
    function(w) return format("%.6f", w.alpha) end,
    function(w, v) local a = num(v, nil); if a == nil then return false end
                   w.alpha = clamp(a, 0, 1); markDirty(); return true end)

prop("InheritsAlpha",
    function(w) return boolStr(w.inheritsAlpha) end,
    function(w, v) w.inheritsAlpha = ceguiBool(v); markDirty(); return true end)

prop("ClippedByParent",
    function(w) return boolStr(w.clippedByParent) end,
    function(w, v) w.clippedByParent = ceguiBool(v); markDirty(); return true end)

prop("MousePassThroughEnabled",
    function(w) return boolStr(w.mousePassThrough) end,
    function(w, v) w.mousePassThrough = ceguiBool(v); return true end)

prop("AlwaysOnTop",
    function(w) return boolStr(w.alwaysOnTop == true) end,
    function(w, v)
        w.alwaysOnTop = ceguiBool(v)
        if w.alwaysOnTop then bringToFront(w) end
        return true
    end)

prop("Text",
    function(w) local cls = classes[w.type]
                return (cls and cls.getText) and cls.getText(w) or w.text end,
    function(w, v)
        local s = str(v, "")
        local old = w.text
        local cls = classes[w.type]
        if cls and cls.setText then cls.setText(w, s) else w.text = s end
        w._wrapDirty, w._caretDirty = true, true
        noteTextChanged(w, old)
        return true
    end)

prop("Font",
    function(w) return ty(w.font) == "string" and w.font or "" end,
    function(w, v)
        if ty(v) ~= "string" then return false end
        if not C.GUI_FONTS[v] and not C.DX_FONTS[v] then return false end
        w.font = v; w._wrapDirty, w._caretDirty = true, true; markDirty(); return true
    end)

prop("NormalTextColour",
    function(w) return colourStr(w.textColor or T.text) end,
    function(w, v) local n = parseColour(v); if n == nil then return false end
                   w.textColor = n; return true end)

prop("ID",
    function(w) return tostr(w.props.ID or "0") end,
    function(w, v) w.props.ID = str(v, "0"); return true end)

prop("DragMovingEnabled",
    function(w) return boolStr(w.movable == true) end,
    function(w, v) if w.type ~= "gui-window" then return false end
                   w.movable = ceguiBool(v); return true end)

prop("SizingEnabled",
    function(w) return boolStr(w.sizable == true) end,
    function(w, v) if w.type ~= "gui-window" then return false end
                   w.sizable = ceguiBool(v); return true end)

prop("TitlebarEnabled",
    function(w) return boolStr(w.titleBar ~= false) end,
    function(w, v) if w.type ~= "gui-window" then return false end
                   w.titleBar = ceguiBool(v); markDirty(); return true end)

prop("CloseButtonEnabled",
    function(w) return boolStr(w.closeButton ~= false) end,
    function(w, v) if w.type ~= "gui-window" then return false end
                   w.closeButton = ceguiBool(v); return true end)

prop("MaskText",
    function(w) return boolStr(w.masked == true) end,
    function(w, v) if w.type ~= "gui-edit" then return false end
                   w.masked = ceguiBool(v); w._caretDirty = true; return true end)

prop("MaskCodepoint",
    function(w) return tostr(w.maskCodepoint or 42) end,
    function(w, v)
        if w.type ~= "gui-edit" then return false end
        local n = num(v, nil); if n == nil then return false end
        w.maskCodepoint = floor(n)
        local ok, ch = pcall(utf8.char, w.maskCodepoint)
        w.maskChar = (ok and ch) or "*"
        w._caretDirty = true
        return true
    end)

prop("MaxTextLength",
    function(w) return tostr(w.maxLength or 0) end,
    function(w, v)
        if w.type ~= "gui-edit" and w.type ~= "gui-memo" then return false end
        local n = num(v, nil); if n == nil then return false end
        w.maxLength = max(0, floor(n)); return true
    end)
PROPS["MaxEditTextLength"] = PROPS["MaxTextLength"]

prop("ReadOnly",
    function(w) return boolStr(w.readOnly == true) end,
    function(w, v)
        if w.type ~= "gui-edit" and w.type ~= "gui-memo" then return false end
        w.readOnly = ceguiBool(v); return true
    end)

prop("Selected",
    function(w) return boolStr(w.selected == true) end,
    function(w, v)
        if w.type ~= "gui-checkbox" and w.type ~= "gui-radiobutton" then return false end
        local cls = classes[w.type]
        cls.setSelected(w, ceguiBool(v))
        return true
    end)

prop("CurrentProgress",
    function(w) return format("%.6f", (w.progress or 0) / 100) end,
    function(w, v)
        if w.type ~= "gui-progressbar" then return false end
        local n = num(v, nil); if n == nil then return false end
        w.progress = clamp(n * 100, 0, 100); return true
    end)

prop("WordWrap",
    function(w) return boolStr(w.wrap == true) end,
    function(w, v) w.wrap = ceguiBool(v); w._wrapDirty = true; return true end)

local HORZ_FORMAT_TO_ALIGN = {
    LeftAligned = { "left", false }, HorzCentred = { "center", false },
    RightAligned = { "right", false },
    WordWrapLeftAligned = { "left", true }, WordWrapCentred = { "center", true },
    WordWrapRightAligned = { "right", true },
}
local ALIGN_TO_HORZ_FORMAT = {
    ["left|false"] = "LeftAligned", ["center|false"] = "HorzCentred",
    ["right|false"] = "RightAligned",
    ["left|true"] = "WordWrapLeftAligned", ["center|true"] = "WordWrapCentred",
    ["right|true"] = "WordWrapRightAligned",
}
prop("HorzFormatting",
    function(w) return ALIGN_TO_HORZ_FORMAT[(w.alignX or "left") .. "|" ..
                                            tostr(w.wrap == true)] or "LeftAligned" end,
    function(w, v)
        local m = HORZ_FORMAT_TO_ALIGN[str(v, "")]
        if not m then return false end
        w.alignX, w.wrap = m[1], m[2]; w._wrapDirty = true; return true
    end)

local VERT_FORMAT_TO_ALIGN = {
    TopAligned = "top", VertCentred = "center", BottomAligned = "bottom",
}
local ALIGN_TO_VERT_FORMAT = { top = "TopAligned", center = "VertCentred", bottom = "BottomAligned" }
prop("VertFormatting",
    function(w) return ALIGN_TO_VERT_FORMAT[w.alignY or "top"] or "TopAligned" end,
    function(w, v)
        local m = VERT_FORMAT_TO_ALIGN[str(v, "")]
        if not m then return false end
        w.alignY = m; return true
    end)

prop("SortSettingEnabled",
    function(w) return boolStr(w.sortingEnabled == true) end,
    function(w, v) if w.type ~= "gui-gridlist" then return false end
                   w.sortingEnabled = ceguiBool(v); return true end)
PROPS["SortList"] = PROPS["SortSettingEnabled"]

prop("RowCount",
    function(w) return w.type == "gui-gridlist" and tostr(#w.rows) or "0" end,
    nil)

prop("AbsoluteWidth",  function(w) return format("%.6f", w.w) end, nil)
prop("AbsoluteHeight", function(w) return format("%.6f", w.h) end, nil)
prop("AbsoluteXPosition", function(w) return format("%.6f", w.x) end, nil)
prop("AbsoluteYPosition", function(w) return format("%.6f", w.y) end, nil)

C.PROPS = PROPS

define("guiSetProperty", function(el, property, value)
    local w = resolve(el)
    if not w then return false end
    local name = str(property, nil)
    if name == nil then return false end
    local p = PROPS[name]
    if p == nil then
        unsupported("guiSetProperty(\"" .. name .. "\")",
            "not in the shim's CEGUI property allowlist (see README.md); returning false")
        return false
    end
    if p.set == nil then
        unsupported("guiSetProperty(\"" .. name .. "\")",
            "read-only in the shim; CEGUI would not accept a write here either")
        return false
    end
    local ok, r = pcall(p.set, w, value)
    if not ok then return false end
    return r ~= false
end)

define("guiGetProperty", function(el, property)
    local w = resolve(el)
    if not w then return false end
    local name = str(property, nil)
    if name == nil then return false end
    local p = PROPS[name]
    if p == nil then
        unsupported("guiGetProperty(\"" .. name .. "\")",
            "not in the shim's CEGUI property allowlist (see README.md); returning false")
        return false
    end
    local ok, r = pcall(p.get, w)
    if not ok or r == nil then return false end
    return tostr(r)
end)

define("guiGetProperties", function(el)
    local w = resolve(el)
    if not w then return false end
    unsupported("guiGetProperties",
        "returns only the shim's " .. "allowlist, not CEGUI's full property set")
    local out = {}
    local names = {}
    for name in pairs(PROPS) do names[#names + 1] = name end
    sort(names)                       -- deterministic, never hash order
    for i = 1, #names do
        local ok, v = pcall(PROPS[names[i]].get, w)
        if ok and v ~= nil then out[names[i]] = tostr(v) end
    end
    return out
end)

local function windowTitleRect(w)
    local h = w.titleBar ~= false and titleH(w) or 0
    return w._ax, w._ay, w._aw, h
end

local function windowCloseRect(w)
    if w.titleBar == false or w.closeButton == false then return nil end
    local th = titleH(w)
    local s = th - 8
    if s <= 0 or w._aw < s + 8 then return nil end
    return w._ax + w._aw - s - 4, w._ay + 4, s, s
end

local function windowGrip(w, x, y)
    if not w.sizable then return nil end
    local x1, y1, x2, y2 = w._ax, w._ay, w._ax + w._aw, w._ay + w._ah
    if not pointIn(x, y, x1 - GRIP, y1 - GRIP, x2 + GRIP, y2 + GRIP) then return nil end
    local L = x <= x1 + GRIP
    local R = x >= x2 - GRIP
    local Tp = y <= y1 + GRIP
    local B = y >= y2 - GRIP
    if L and Tp then return "size-nw" end
    if R and Tp then return "size-ne" end
    if L and B  then return "size-sw" end
    if R and B  then return "size-se" end
    if L then return "size-w" end
    if R then return "size-e" end
    if Tp then return "size-n" end
    if B then return "size-s" end
    return nil
end

class("gui-window", {
    draw = function(w)
        local cl = clip(w)
        local x, y, ww, hh = w._ax, w._ay, w._aw, w._ah
        fillRect(x, y, ww, hh, ct(w, T.windowBody), cl)
        local th = w.titleBar ~= false and titleH(w) or 0
        if th > 0 then
            fillRect(x, y, ww, th, ct(w, T.windowTitle), cl)
            local bx, by, bw, bh = windowCloseRect(w)
            local textRight = bx and (bx - 4) or (x + ww - PAD)
            drawText(w.text, x + PAD + 2, y, textRight, y + th,
                     ct(w, T.windowTitleText), w.font, "left", "center", false, cl)
            if bx then
                local hovered = C.hovered == w
                                and pointIn(C.cursorX, C.cursorY, bx, by, bx + bw, by + bh)
                fillRect(bx, by, bw, bh, ct(w, hovered and T.closeHover or T.closeNormal), cl)
                local cx, cy = bx + bw / 2, by + bh / 2
                local s = max(2, floor(bw * 0.28))
                fillRect(cx - s, cy - 1, s * 2, 2, ct(w, T.closeGlyph), cl)
                fillRect(cx - 1, cy - s, 2, s * 2, ct(w, T.closeGlyph), cl)
            end
        end
        frameRect(x, y, ww, hh, BORDER, ct(w, T.windowBorder), cl)
        if w.sizable then
            local g = ct(w, T.grip)
            for i = 1, 3 do
                fillRect(x + ww - 3 - i * 4, y + hh - 4, 3, 3, g, cl)
                fillRect(x + ww - 4,         y + hh - 3 - i * 4, 3, 3, g, cl)
            end
        end
    end,

    onMouseDown = function(w, button, x, y)
        if button ~= "left" then return end
        local bx, by, bw, bh = windowCloseRect(w)
        if bx and pointIn(x, y, bx, by, bx + bw, by + bh) then
            unsupported("window close button",
                "MTA's onClientGUIClose is commented out (CClientGame.cpp:2730) so the X " ..
                "does nothing there either. Hide the window from your own handler.")
            w._closePressed = true
            return
        end
        local grip = windowGrip(w, x, y)
        if grip then
            capture(w, grip)
            w._dragX, w._dragY = x, y
            w._dragW, w._dragH = w.w, w.h
            w._dragOX, w._dragOY = w.x, w.y
            C.logicalCursor = C.cursorTypeNames[grip] or "default"
            return
        end
        local th = w.titleBar ~= false and titleH(w) or 0
        if w.movable and th > 0 and y < w._ay + th then
            capture(w, "move")
            w._dragX, w._dragY = x - w._ax, y - w._ay
            C.logicalCursor = "sizing_move"
        end
    end,

    onDrag = function(w, x, y)
        local mode = C.captureMode
        if mode == "move" then
            local px, py = parentBox(w)
            local nx, ny = x - w._dragX - px, y - w._dragY - py
            if nx ~= w.x or ny ~= w.y then
                w.x, w.y = nx, ny
                markDirty()
                noteMoved(w)
            end
            return
        end
        if mode == nil or mode:sub(1, 5) ~= "size-" then return end
        local dx, dy = x - w._dragX, y - w._dragY
        local nx, ny, nw, nh = w._dragOX, w._dragOY, w._dragW, w._dragH
        local edge = mode:sub(6)
        if edge:find("e") then nw = w._dragW + dx end
        if edge:find("s") then nh = w._dragH + dy end
        if edge:find("w") then nw = w._dragW - dx; nx = w._dragOX + dx end
        if edge:find("n") then nh = w._dragH - dy; ny = w._dragOY + dy end
        local minW, minH = 40, max(24, titleH(w) + 8)
        if nw < minW then
            if edge:find("w") then nx = nx - (minW - nw) end
            nw = minW
        end
        if nh < minH then
            if edge:find("n") then ny = ny - (minH - nh) end
            nh = minH
        end
        local moved = (nx ~= w.x or ny ~= w.y)
        local sized = (nw ~= w.w or nh ~= w.h)
        w.x, w.y, w.w, w.h = nx, ny, nw, nh
        if moved or sized then markDirty() end
        if moved then noteMoved(w) end
        if sized then w._wrapDirty = true; noteSized(w) end
    end,

    onDragEnd = function(w)
        C.logicalCursor = "default"
    end,

    onMouseUp = function(w)
        w._closePressed = nil
    end,

    onEnter = function(w) end,
    onLeave = function(w) C.logicalCursor = "default" end,
})

define("guiCreateWindow", function(x, y, width, height, titleBarText, relative)
    local w = newWidget("gui-window", x, y, width, height, relative, nil, {
        text = str(titleBarText, ""),
        movable = true,
        sizable = true,
        titleBar = true,
        closeButton = true,
        font = "default-bold-small",
    })
    if not w then return false end
    return w.el
end)

define("guiWindowSetMovable", function(el, status)
    local w = resolveTyped(el, "gui-window")
    if not w then return false end
    w.movable = truthy(status)
    return true
end)

define("guiWindowSetSizable", function(el, status)
    local w = resolveTyped(el, "gui-window")
    if not w then return false end
    w.sizable = truthy(status)
    return true
end)

define("guiWindowIsMovable", function(el)
    local w = resolveTyped(el, "gui-window")
    if not w then return false end
    return w.movable == true
end)

define("guiWindowIsSizable", function(el)
    local w = resolveTyped(el, "gui-window")
    if not w then return false end
    return w.sizable == true
end)

class("gui-label", {
    draw = function(w)
        drawText(w.text, w._ax, w._ay, w._ax + w._aw, w._ay + w._ah,
                 textColour(w), w.font, w.alignX or "left", w.alignY or "top",
                 w.wrap == true, clip(w))
    end,
})

define("guiCreateLabel", function(x, y, width, height, text, relative, parent)
    local w = newWidget("gui-label", x, y, width, height, relative, parent, {
        text = str(text, ""),
        alignX = "left",
        alignY = "top",
        wrap = false,
    })
    if not w then return false end
    return w.el
end)

define("guiLabelSetColor", function(el, r, g, b)
    local w = resolveTyped(el, "gui-label")
    if not w then return false end
    local rr, gg, bb = num(r, nil), num(g, nil), num(b, nil)
    if rr == nil or gg == nil or bb == nil then return false end
    w.textColor = argb(255, rr, gg, bb)
    return true
end)

define("guiLabelGetColor", function(el)
    local w = resolveTyped(el, "gui-label")
    if not w then return false end
    local c = w.textColor
    if c == nil then
        unsupported("guiLabelGetColor on a label with no explicit colour",
            "answers the shim's theme colour; MTA answers the player's CEGUI skin colour, " ..
            "which MTAX cannot read")
        c = T.text
    end
    return floor(c / 0x10000) % 256, floor(c / 0x100) % 256, c % 256
end)

local VALID_VALIGN = { top = true, center = true, bottom = true }
define("guiLabelSetVerticalAlign", function(el, align)
    local w = resolveTyped(el, "gui-label")
    if not w then return false end
    local a = str(align, "")
    if not VALID_VALIGN[a] then return false end
    w.alignY = a
    return true
end)

local VALID_HALIGN = { left = true, center = true, right = true }
define("guiLabelSetHorizontalAlign", function(el, align, wordwrap)
    local w = resolveTyped(el, "gui-label")
    if not w then return false end
    local a = str(align, "")
    if not VALID_HALIGN[a] then return false end
    w.alignX = a
    w.wrap = truthy(wordwrap)
    w._wrapDirty = true
    return true
end)

define("guiLabelGetTextExtent", function(el)
    local w = resolveTyped(el, "gui-label")
    if not w then return false end
    return textWidth(w.text, w.font)
end)

define("guiLabelGetFontHeight", function(el)
    local w = resolveTyped(el, "gui-label")
    if not w then return false end
    return fontHeight(w.font)
end)

class("gui-button", {
    draw = function(w)
        local cl = clip(w)
        local bg
        if not w._enabled then
            bg = T.buttonDisabled
        elseif C.pressed == w and C.hovered == w then
            bg = T.buttonPushed
        elseif C.hovered == w then
            bg = T.buttonHover
        else
            bg = T.buttonNormal
        end
        fillRect(w._ax, w._ay, w._aw, w._ah, ct(w, bg), cl)
        frameRect(w._ax, w._ay, w._aw, w._ah, BORDER, ct(w, T.buttonBorder), cl)
        drawText(w.text, w._ax + PAD, w._ay, w._ax + w._aw - PAD, w._ay + w._ah,
                 textColour(w), w.font, "center", "center", false, cl)
    end,
})

define("guiCreateButton", function(x, y, width, height, text, relative, parent)
    local w = newWidget("gui-button", x, y, width, height, relative, parent, {
        text = str(text, ""),
    })
    if not w then return false end
    return w.el
end)

local function loadTexture(w, path)
    if ty(path) ~= "string" or path == "" then return false end
    local ok, tex = pcall(nDxCreateTexture, path)
    if not ok or tex == false or tex == nil or not nIsElement(tex) then
        return false
    end
    if w.texture ~= nil and nIsElement(w.texture) then
        nDestroyElement(w.texture)
    end
    w.texture = tex
    w.path = path
    return true
end

class("gui-staticimage", {
    draw = function(w)
        if w.texture == nil then return end
        drawImage(w._ax, w._ay, w._aw, w._ah, w.texture,
                  withAlpha(argb(255, 255, 255, 255), w._alpha), clip(w))
    end,
    dispose = function(w)
        if w.texture ~= nil and nIsElement(w.texture) then
            nDestroyElement(w.texture)
        end
        w.texture = nil
    end,
})

define("guiCreateStaticImage", function(x, y, width, height, path, relative, parent)
    local w = newWidget("gui-staticimage", x, y, width, height, relative, parent, {})
    if not w then return false end
    if not loadTexture(w, path) then
        destroyWidget(w)
        return false
    end
    return w.el
end)

define("guiStaticImageLoadImage", function(el, filename)
    local w = resolveTyped(el, "gui-staticimage")
    if not w then return false end
    return loadTexture(w, filename) and true or false
end)

define("guiStaticImageGetNativeSize", function(el)
    local w = resolveTyped(el, "gui-staticimage")
    if not w or w.texture == nil then return false end
    local ok, tw, th = pcall(nDxGetMaterialSize, w.texture)
    if not ok or ty(tw) ~= "number" then return false end
    return tw, th
end)

local function editVisibleText(w)
    if w.masked then
        return rep(w.maskChar or "*", ulen(w.text))
    end
    return w.text
end

local function editReflow(w)
    if not w._caretDirty then return end
    w._caretDirty = false
    local vis = editVisibleText(w)
    local n = ulen(vis)
    if w.caret > n then w.caret = n end
    if w.caret < 0 then w.caret = 0 end
    local view = w._aw - PAD * 2 - BORDER * 2
    if view <= 0 then w.scrollChar = 1; return end
    local first = w.scrollChar or 1
    if first > w.caret + 1 then first = w.caret + 1 end
    if first < 1 then first = 1 end
    local guard = 0
    while first <= w.caret and guard <= n do
        if textWidth(usub(vis, first, w.caret), w.font) <= view then break end
        first = first + 1
        guard = guard + 1
    end
    while first > 1 and textWidth(usub(vis, first - 1, n), w.font) <= view do
        first = first - 1
    end
    w.scrollChar = first
    w._vis = vis
end

local function editInsert(w, text)
    if w.readOnly then return end
    if ty(text) ~= "string" or text == "" then return end
    text = text:gsub("[\r\n]", " ")
    local old = w.text
    local n = ulen(w.text)
    local add = ulen(text)
    if w.maxLength and w.maxLength > 0 then
        local room = w.maxLength - n
        if room <= 0 then return end
        if add > room then text = usub(text, 1, room); add = room end
    end
    w.text = usub(w.text, 1, w.caret) .. text .. usub(w.text, w.caret + 1, n)
    w.caret = w.caret + add
    w._caretDirty = true
    noteTextChanged(w, old)
end

local function editBackspace(w)
    if w.readOnly or w.caret <= 0 then return end
    local old = w.text
    local n = ulen(w.text)
    w.text = usub(w.text, 1, w.caret - 1) .. usub(w.text, w.caret + 1, n)
    w.caret = w.caret - 1
    w._caretDirty = true
    noteTextChanged(w, old)
end

local function editDelete(w)
    if w.readOnly then return end
    local n = ulen(w.text)
    if w.caret >= n then return end
    local old = w.text
    w.text = usub(w.text, 1, w.caret) .. usub(w.text, w.caret + 2, n)
    w._caretDirty = true
    noteTextChanged(w, old)
end

local function caretVisible()
    return (floor(tick() / 500) % 2) == 0
end

class("gui-edit", {
    reflow = editReflow,

    draw = function(w)
        editReflow(w)
        local cl = clip(w)
        fillRect(w._ax, w._ay, w._aw, w._ah, ct(w, T.fieldBg), cl)
        frameRect(w._ax, w._ay, w._aw, w._ah, BORDER,
                  ct(w, (C.focused == w) and T.fieldBorderFocus or T.fieldBorder), cl)
        local inner = innerClip(w, PAD, BORDER, PAD, BORDER)
        local vis = w._vis or editVisibleText(w)
        local first = w.scrollChar or 1
        local shown = usub(vis, first)
        local tx = w._ax + PAD
        local ty1, ty2 = w._ay + BORDER, w._ay + w._ah - BORDER
        drawText(shown, tx, ty1, w._ax + w._aw - PAD, ty2,
                 textColour(w), w.font, "left", "center", false, inner)
        if C.focused == w and w._enabled and not w.readOnly and caretVisible() then
            local cx = tx + textWidth(usub(vis, first, w.caret), w.font)
            local h = fontHeight(w.font)
            fillRect(cx, w._ay + (w._ah - h) / 2, 1, h, ct(w, T.caret), inner)
        end
    end,

    setText = function(w, s)
        w.text = s:gsub("[\r\n]", " ")
        if w.maxLength and w.maxLength > 0 and ulen(w.text) > w.maxLength then
            w.text = usub(w.text, 1, w.maxLength)
        end
        w.caret = ulen(w.text)
        w._caretDirty = true
    end,

    onMouseDown = function(w, button, x, y)
        if button ~= "left" then return end
        editReflow(w)
        local vis = w._vis or editVisibleText(w)
        local first = w.scrollChar or 1
        local n = ulen(vis)
        local relX = x - (w._ax + PAD)
        local best, bestD = first - 1, math.huge
        for i = first - 1, n do
            local d = abs(textWidth(usub(vis, first, i), w.font) - relX)
            if d < bestD then best, bestD = i, d else break end
        end
        w.caret = clamp(best, 0, n)
        w._caretDirty = true
    end,

    onDoubleClick = function(w)
        unsupported("edit double-click word select",
            "CEGUI selects the word under the cursor; MTAX exposes no text selection primitives")
    end,

    onKey = function(w, key)
        local n = ulen(w.text)
        if key == "arrow_l" then
            if C.shiftHeld() then
                unsupported("shift+arrow selection in an edit box",
                    "there is no selection model; the caret moves without selecting")
            end
            w.caret = max(0, w.caret - 1); w._caretDirty = true
        elseif key == "arrow_r" then
            w.caret = min(n, w.caret + 1); w._caretDirty = true
        elseif key == "home" then
            w.caret = 0; w._caretDirty = true
        elseif key == "end" then
            w.caret = n; w._caretDirty = true
        elseif key == "backspace" then
            editBackspace(w)
        elseif key == "delete" then
            editDelete(w)
        elseif key == "enter" or key == "num_enter" then
            fire("onClientGUIAccepted", w)
        elseif key == "c" and C.ctrlHeld() then
            unsupported("Ctrl+C in an edit box",
                "no selection exists, so the WHOLE field is copied instead of a selection")
            C.setClipboard(w.text)
        elseif key == "x" and C.ctrlHeld() then
            unsupported("Ctrl+X in an edit box",
                "no selection exists, so the WHOLE field is cut instead of a selection")
            if not w.readOnly then
                C.setClipboard(w.text)
                local old = w.text
                w.text, w.caret, w._caretDirty = "", 0, true
                noteTextChanged(w, old)
            end
        elseif key == "a" and C.ctrlHeld() then
            unsupported("Ctrl+A in an edit box", "there is no selection to make")
        end
    end,

    onCharacter = function(w, ch)
        if C.ctrlHeld() then return end
        editInsert(w, ch)
    end,

    onPaste = function(w, text)
        editInsert(w, text)
    end,
})

define("guiCreateEdit", function(x, y, width, height, text, relative, parent)
    local w = newWidget("gui-edit", x, y, width, height, relative, parent, {
        text = "",
        caret = 0,
        masked = false,
        maskChar = "*",
        maskCodepoint = 42,
        maxLength = 0,
        readOnly = false,
        scrollChar = 1,
        _caretDirty = true,
    })
    if not w then return false end
    local s = str(text, "")
    w.text = s:gsub("[\r\n]", " ")
    w.caret = ulen(w.text)
    return w.el
end)

local function editSetCaret(el, index)
    local w = resolveTyped(el, "gui-edit")
    if not w then return false end
    local i = num(index, nil)
    if i == nil then return false end
    w.caret = clamp(floor(i), 0, ulen(w.text))
    w._caretDirty = true
    return true
end
define("guiEditSetCaretIndex", editSetCaret)
define("guiEditSetCaratIndex", editSetCaret)

define("guiEditGetCaretIndex", function(el)
    local w = resolveTyped(el, "gui-edit")
    if not w then return false end
    return w.caret
end)

define("guiEditSetMasked", function(el, status)
    local w = resolveTyped(el, "gui-edit")
    if not w then return false end
    w.masked = truthy(status)
    w._caretDirty = true
    return true
end)

define("guiEditIsMasked", function(el)
    local w = resolveTyped(el, "gui-edit")
    if not w then return false end
    return w.masked == true
end)

define("guiEditSetMaxLength", function(el, length)
    local w = resolveTyped(el, "gui-edit")
    if not w then return false end
    local n = num(length, nil)
    if n == nil then return false end
    w.maxLength = max(0, floor(n))
    if w.maxLength > 0 and ulen(w.text) > w.maxLength then
        local old = w.text
        w.text = usub(w.text, 1, w.maxLength)
        w.caret = min(w.caret, w.maxLength)
        w._caretDirty = true
        noteTextChanged(w, old)
    end
    return true
end)

define("guiEditGetMaxLength", function(el)
    local w = resolveTyped(el, "gui-edit")
    if not w then return false end
    return w.maxLength or 0
end)

define("guiEditSetReadOnly", function(el, status)
    local w = resolveTyped(el, "gui-edit")
    if not w then return false end
    w.readOnly = truthy(status)
    return true
end)

define("guiEditIsReadOnly", function(el)
    local w = resolveTyped(el, "gui-edit")
    if not w then return false end
    return w.readOnly == true
end)

local function memoWrap(w)
    if not w._wrapDirty and w._lines then return w._lines end
    w._wrapDirty = false
    local view = w._aw - PAD * 2 - SCROLL_W - BORDER * 2
    local lines = {}
    local starts = {}         -- character index (0-based) each visual line begins at
    local consumed = 0
    local textLen = ulen(w.text)
    if view <= 8 then
        w._lines, w._lineStarts = { w.text }, { 0 }
        return w._lines
    end
    for hard in (w.text .. "\n"):gmatch("([^\n]*)\n") do
        local hardLen = ulen(hard)
        if hardLen == 0 then
            lines[#lines + 1] = ""
            starts[#starts + 1] = consumed
        else
            local pos = 1
            while pos <= hardLen do
                local remaining = hardLen - pos + 1
                local fit
                if textWidth(usub(hard, pos, hardLen), w.font) <= view then
                    fit = remaining
                else
                    local lo, hi = 1, remaining
                    while lo < hi do
                        local mid = (lo + hi + 1) // 2
                        if textWidth(usub(hard, pos, pos + mid - 1), w.font) <= view then
                            lo = mid
                        else
                            hi = mid - 1
                        end
                    end
                    fit = max(1, lo)
                end

                if pos + fit - 1 < hardLen then
                    local slice = usub(hard, pos, pos + fit - 1)
                    local lastSpace = nil
                    for i = ulen(slice), 1, -1 do
                        if usub(slice, i, i) == " " then lastSpace = i; break end
                    end
                    if lastSpace and lastSpace > 1 then fit = lastSpace end
                end
                lines[#lines + 1] = usub(hard, pos, pos + fit - 1)
                starts[#starts + 1] = consumed + pos - 1
                pos = pos + fit
            end
        end
        consumed = consumed + hardLen + 1
    end
    if #lines == 0 then lines[1] = ""; starts[1] = 0 end
    w._lines, w._lineStarts = lines, starts
    return lines
end

local function memoVisibleLines(w)
    local lh = lineH(w)
    if lh <= 0 then return 1 end
    return max(1, floor((w._ah - BORDER * 2) / lh))
end

local function memoMaxScroll(w)
    return max(0, #memoWrap(w) - memoVisibleLines(w))
end

local function memoClampScroll(w)
    w.scrollLine = clamp(floor(w.scrollLine or 0), 0, memoMaxScroll(w))
end

local function memoCaretLine(w)
    local lines, starts = memoWrap(w), w._lineStarts
    local n = #lines
    for i = n, 1, -1 do
        if w.caret >= starts[i] then
            return i, w.caret - starts[i]
        end
    end
    return 1, w.caret
end

local function memoInsert(w, text)
    if w.readOnly then return end
    if ty(text) ~= "string" or text == "" then return end
    local old = w.text
    local n = ulen(w.text)
    local add = ulen(text)
    if w.maxLength and w.maxLength > 0 then
        local room = w.maxLength - n
        if room <= 0 then return end
        if add > room then text = usub(text, 1, room); add = room end
    end
    w.text = usub(w.text, 1, w.caret) .. text .. usub(w.text, w.caret + 1, n)
    w.caret = w.caret + add
    w._wrapDirty = true
    noteTextChanged(w, old)
end

class("gui-memo", {
    draw = function(w)
        local cl = clip(w)
        fillRect(w._ax, w._ay, w._aw, w._ah, ct(w, T.fieldBg), cl)
        frameRect(w._ax, w._ay, w._aw, w._ah, BORDER,
                  ct(w, (C.focused == w) and T.fieldBorderFocus or T.fieldBorder), cl)

        local lines = memoWrap(w)
        memoClampScroll(w)
        local lh = lineH(w)
        local vis = memoVisibleLines(w)
        local inner = innerClip(w, BORDER, BORDER, SCROLL_W + BORDER, BORDER)
        local x1 = w._ax + PAD
        local x2 = w._ax + w._aw - SCROLL_W - PAD
        local col = textColour(w)
        local caretLine, caretCol = memoCaretLine(w)

        for i = 1, vis do
            local li = w.scrollLine + i
            local line = lines[li]
            if line == nil then break end
            local ly = w._ay + BORDER + (i - 1) * lh
            drawText(line, x1, ly, x2, ly + lh, col, w.font, "left", "top", false, inner)
            if C.focused == w and w._enabled and not w.readOnly and li == caretLine
               and caretVisible() then
                local cx = x1 + textWidth(usub(line, 1, caretCol), w.font)
                fillRect(cx, ly, 1, lh, ct(w, T.caret), inner)
            end
        end

        local sx = w._ax + w._aw - SCROLL_W - BORDER
        local sy = w._ay + BORDER
        local sh = w._ah - BORDER * 2
        fillRect(sx, sy, SCROLL_W, sh, ct(w, T.scrollTrack), cl)
        local total = #lines
        if total > vis then
            local thumbH = max(16, sh * vis / total)
            local range = sh - thumbH
            local mx = memoMaxScroll(w)
            local tYy = sy + (mx > 0 and (w.scrollLine / mx * range) or 0)
            fillRect(sx + 1, tYy, SCROLL_W - 2, thumbH, ct(w, T.scrollThumb), cl)
        end
    end,

    setText = function(w, s)
        w.text = s
        if w.maxLength and w.maxLength > 0 and ulen(w.text) > w.maxLength then
            w.text = usub(w.text, 1, w.maxLength)
        end
        w.caret = ulen(w.text)
        w._wrapDirty = true
    end,

    onWheel = function(w, delta)
        local before = w.scrollLine or 0
        w.scrollLine = before + delta * 3
        memoClampScroll(w)
        return w.scrollLine ~= before
    end,

    onMouseDown = function(w, button, x, y)
        if button ~= "left" then return end
        local lines = memoWrap(w)
        local lh = lineH(w)
        local sx = w._ax + w._aw - SCROLL_W - BORDER
        if x >= sx then
            local vis = memoVisibleLines(w)
            local mid = w._ay + w._ah / 2
            w.scrollLine = (w.scrollLine or 0) + (y < mid and -vis or vis)
            memoClampScroll(w)
            fire("onClientGUIScroll", w)
            return
        end
        local li = (w.scrollLine or 0) + floor((y - w._ay - BORDER) / lh) + 1
        li = clamp(li, 1, #lines)
        local line = lines[li]
        local relX = x - (w._ax + PAD)
        local best, bestD = 0, math.huge
        for i = 0, ulen(line) do
            local d = abs(textWidth(usub(line, 1, i), w.font) - relX)
            if d < bestD then best, bestD = i, d else break end
        end
        w.caret = clamp((w._lineStarts[li] or 0) + best, 0, ulen(w.text))
    end,

    onKey = function(w, key)
        local n = ulen(w.text)
        if key == "arrow_l" then
            w.caret = max(0, w.caret - 1)
        elseif key == "arrow_r" then
            w.caret = min(n, w.caret + 1)
        elseif key == "arrow_u" or key == "arrow_d" then
            local li, col = memoCaretLine(w)
            local target = li + (key == "arrow_u" and -1 or 1)
            local lines = memoWrap(w)
            target = clamp(target, 1, #lines)
            w.caret = clamp((w._lineStarts[target] or 0) + min(col, ulen(lines[target])), 0, n)
        elseif key == "home" then
            local li = memoCaretLine(w)
            w.caret = w._lineStarts[li] or 0
        elseif key == "end" then
            local li = memoCaretLine(w)
            local lines = memoWrap(w)
            w.caret = clamp((w._lineStarts[li] or 0) + ulen(lines[li] or ""), 0, n)
        elseif key == "pgup" then
            w.scrollLine = (w.scrollLine or 0) - memoVisibleLines(w); memoClampScroll(w)
        elseif key == "pgdn" then
            w.scrollLine = (w.scrollLine or 0) + memoVisibleLines(w); memoClampScroll(w)
        elseif key == "backspace" then
            if not w.readOnly and w.caret > 0 then
                local old = w.text
                w.text = usub(w.text, 1, w.caret - 1) .. usub(w.text, w.caret + 1, n)
                w.caret = w.caret - 1
                w._wrapDirty = true
                noteTextChanged(w, old)
            end
        elseif key == "delete" then
            if not w.readOnly and w.caret < n then
                local old = w.text
                w.text = usub(w.text, 1, w.caret) .. usub(w.text, w.caret + 2, n)
                w._wrapDirty = true
                noteTextChanged(w, old)
            end
        elseif key == "enter" or key == "num_enter" then
            memoInsert(w, "\n")
        elseif key == "c" and C.ctrlHeld() then
            unsupported("Ctrl+C in a memo",
                "no selection exists, so the WHOLE memo is copied")
            C.setClipboard(w.text)
        end

        local li = memoCaretLine(w)
        local vis = memoVisibleLines(w)
        if li <= (w.scrollLine or 0) then w.scrollLine = li - 1 end
        if li > (w.scrollLine or 0) + vis then w.scrollLine = li - vis end
        memoClampScroll(w)
    end,

    onCharacter = function(w, ch)
        if C.ctrlHeld() then return end
        memoInsert(w, ch)
    end,

    onPaste = function(w, text)
        memoInsert(w, text)
    end,
})

define("guiCreateMemo", function(x, y, width, height, text, relative, parent)
    local w = newWidget("gui-memo", x, y, width, height, relative, parent, {
        text = str(text, ""),
        caret = 0,
        readOnly = false,
        scrollLine = 0,
        maxLength = 0,
        _wrapDirty = true,
    })
    if not w then return false end
    w.caret = ulen(w.text)
    return w.el
end)

local function memoSetCaret(el, index)
    local w = resolveTyped(el, "gui-memo")
    if not w then return false end
    local i = num(index, nil)
    if i == nil then return false end
    w.caret = clamp(floor(i), 0, ulen(w.text))
    return true
end
define("guiMemoSetCaretIndex", memoSetCaret)
define("guiMemoSetCaratIndex", memoSetCaret)

define("guiMemoGetCaretIndex", function(el)
    local w = resolveTyped(el, "gui-memo")
    if not w then return false end
    return w.caret
end)

define("guiMemoSetReadOnly", function(el, status)
    local w = resolveTyped(el, "gui-memo")
    if not w then return false end
    w.readOnly = truthy(status)
    return true
end)

define("guiMemoIsReadOnly", function(el)
    local w = resolveTyped(el, "gui-memo")
    if not w then return false end
    return w.readOnly == true
end)

define("guiMemoSetVerticalScrollPosition", function(el, position)
    local w = resolveTyped(el, "gui-memo")
    if not w then return false end
    local p = num(position, nil)
    if p == nil then return false end
    local mx = memoMaxScroll(w)
    w.scrollLine = floor(clamp(p / 100, 0, 1) * mx + 0.5)
    memoClampScroll(w)
    return true
end)

define("guiMemoGetVerticalScrollPosition", function(el)
    local w = resolveTyped(el, "gui-memo")
    if not w then return false end
    local mx = memoMaxScroll(w)
    if mx <= 0 then return 0 end
    return (w.scrollLine or 0) / mx * 100
end)

local function boxSize(w) return min(16, max(10, floor(fontHeight(w.font)))) end

class("gui-checkbox", {
    draw = function(w)
        local cl = clip(w)
        local s = boxSize(w)
        local bx = w._ax
        local by = w._ay + (w._ah - s) / 2
        fillRect(bx, by, s, s, ct(w, T.fieldBg), cl)
        frameRect(bx, by, s, s, BORDER,
                  ct(w, C.hovered == w and T.fieldBorderFocus or T.fieldBorder), cl)
        if w.selected then
            fillRect(bx + 3, by + 3, s - 6, s - 6, ct(w, w._enabled and T.check or T.textDisabled), cl)
        end
        drawText(w.text, bx + s + 5, w._ay, w._ax + w._aw, w._ay + w._ah,
                 textColour(w), w.font, "left", "center", false, cl)
    end,

    setSelected = function(w, state)
        w.selected = state and true or false
    end,

    onMouseUp = function(w, button, x, y, over)
        if button ~= "left" or not over then return end
        w.selected = not w.selected
    end,
})

define("guiCreateCheckBox", function(x, y, width, height, text, selected, relative, parent)
    local w = newWidget("gui-checkbox", x, y, width, height, relative, parent, {
        text = str(text, ""),
        selected = truthy(selected),
    })
    if not w then return false end
    return w.el
end)

define("guiCheckBoxSetSelected", function(el, state)
    local w = resolveTyped(el, "gui-checkbox")
    if not w then return false end
    w.selected = truthy(state)
    return true
end)

define("guiCheckBoxGetSelected", function(el)
    local w = resolveTyped(el, "gui-checkbox")
    if not w then return false end
    return w.selected == true
end)

local function radioSelect(w, state)
    if not state then
        w.selected = false
        return
    end
    w.selected = true
    local list = siblingList(w)
    for i = 1, #list do
        local s = list[i]
        if s ~= w and s.type == "gui-radiobutton" and s.groupId == w.groupId then
            s.selected = false
        end
    end
end

class("gui-radiobutton", {
    draw = function(w)
        local cl = clip(w)
        local s = boxSize(w)
        local bx = w._ax
        local by = w._ay + (w._ah - s) / 2

        fillRect(bx, by, s, s, ct(w, T.fieldBg), cl)
        frameRect(bx, by, s, s, BORDER,
                  ct(w, C.hovered == w and T.fieldBorderFocus or T.fieldBorder), cl)
        if w.selected then
            local i = floor(s / 4)
            fillRect(bx + i, by + i, s - i * 2, s - i * 2,
                     ct(w, w._enabled and T.check or T.textDisabled), cl)
        end
        drawText(w.text, bx + s + 5, w._ay, w._ax + w._aw, w._ay + w._ah,
                 textColour(w), w.font, "left", "center", false, cl)
    end,

    setSelected = radioSelect,

    onMouseUp = function(w, button, x, y, over)
        if button ~= "left" or not over then return end
        radioSelect(w, true)
    end,
})

define("guiCreateRadioButton", function(x, y, width, height, text, relative, parent)
    local w = newWidget("gui-radiobutton", x, y, width, height, relative, parent, {
        text = str(text, ""),
        selected = false,
        groupId = 0,
    })
    if not w then return false end
    return w.el
end)

define("guiRadioButtonSetSelected", function(el, state)
    local w = resolveTyped(el, "gui-radiobutton")
    if not w then return false end
    radioSelect(w, truthy(state))
    return true
end)

define("guiRadioButtonGetSelected", function(el)
    local w = resolveTyped(el, "gui-radiobutton")
    if not w then return false end
    return w.selected == true
end)

class("gui-progressbar", {
    draw = function(w)
        local cl = clip(w)
        fillRect(w._ax, w._ay, w._aw, w._ah, ct(w, T.progressBg), cl)
        local p = clamp(w.progress or 0, 0, 100) / 100
        if p > 0 then
            fillRect(w._ax + BORDER, w._ay + BORDER,
                     (w._aw - BORDER * 2) * p, w._ah - BORDER * 2,
                     ct(w, T.progressFill), cl)
        end
        frameRect(w._ax, w._ay, w._aw, w._ah, BORDER, ct(w, T.fieldBorder), cl)
    end,
})

define("guiCreateProgressBar", function(x, y, width, height, relative, parent)
    local w = newWidget("gui-progressbar", x, y, width, height, relative, parent, {
        progress = 0,
    })
    if not w then return false end
    return w.el
end)

define("guiProgressBarSetProgress", function(el, progress)
    local w = resolveTyped(el, "gui-progressbar")
    if not w then return false end
    local p = num(progress, nil)
    if p == nil then return false end
    w.progress = clamp(p, 0, 100)
    return true
end)

define("guiProgressBarGetProgress", function(el)
    local w = resolveTyped(el, "gui-progressbar")
    if not w then return false end
    return w.progress or 0
end)

local function scrollbarGeometry(w)
    local horiz = w.horizontal == true
    local trackLen = horiz and w._aw or w._ah
    local thumbLen = max(16, trackLen * 0.25)
    local range = max(0, trackLen - thumbLen)
    local pos = clamp(w.position or 0, 0, 100) / 100
    local off = range * pos
    return horiz, trackLen, thumbLen, range, off
end

class("gui-scrollbar", {
    draw = function(w)
        local cl = clip(w)
        fillRect(w._ax, w._ay, w._aw, w._ah, ct(w, T.scrollTrack), cl)
        local horiz, _, thumbLen, _, off = scrollbarGeometry(w)
        local hot = (C.hovered == w or C.captured == w)
        local col = ct(w, hot and T.scrollThumbHover or T.scrollThumb)
        if horiz then
            fillRect(w._ax + off, w._ay + 1, thumbLen, w._ah - 2, col, cl)
        else
            fillRect(w._ax + 1, w._ay + off, w._aw - 2, thumbLen, col, cl)
        end
        frameRect(w._ax, w._ay, w._aw, w._ah, BORDER, ct(w, T.panelBorder), cl)
    end,

    onMouseDown = function(w, button, x, y)
        if button ~= "left" then return end
        local horiz, trackLen, thumbLen, range, off = scrollbarGeometry(w)
        local local1 = horiz and (x - w._ax) or (y - w._ay)
        if local1 >= off and local1 < off + thumbLen then
            capture(w, "thumb")
            w._grabOff = local1 - off
        else
            local step = (local1 < off) and -10 or 10
            local before = w.position or 0
            w.position = clamp(before + step, 0, 100)
            if w.position ~= before then fire("onClientGUIScroll", w) end
        end
    end,

    onDrag = function(w, x, y)
        if C.captureMode ~= "thumb" then return end
        local horiz, trackLen, thumbLen, range = scrollbarGeometry(w)
        if range <= 0 then return end
        local local1 = (horiz and (x - w._ax) or (y - w._ay)) - (w._grabOff or 0)
        local before = w.position or 0
        w.position = clamp(local1 / range * 100, 0, 100)
        if w.position ~= before then fire("onClientGUIScroll", w) end
    end,

    onWheel = function(w, delta)
        local before = w.position or 0
        w.position = clamp(before + delta * 5, 0, 100)
        return w.position ~= before
    end,
})

define("guiCreateScrollBar", function(x, y, width, height, horizontal, relative, parent)
    local w = newWidget("gui-scrollbar", x, y, width, height, relative, parent, {
        horizontal = truthy(horizontal),
        position = 0,
    })
    if not w then return false end
    return w.el
end)

define("guiScrollBarSetScrollPosition", function(el, amount)
    local w = resolveTyped(el, "gui-scrollbar")
    if not w then return false end
    local a = num(amount, nil)
    if a == nil then return false end
    w.position = clamp(a, 0, 100)
    return true
end)

define("guiScrollBarGetScrollPosition", function(el)
    local w = resolveTyped(el, "gui-scrollbar")
    if not w then return false end
    return w.position or 0
end)

local function paneContentExtent(w)
    local mx, my = 0, 0
    local kids = w.children
    for i = 1, #kids do
        local c = kids[i]
        local r = c.x + c.w
        local b = c.y + c.h
        if r > mx then mx = r end
        if b > my then my = b end
    end
    return mx, my
end

local function paneViewSize(w)
    local vw = w._aw - (w.vbar and SCROLL_W or 0)
    local vh = w._ah - (w.hbar and SCROLL_W or 0)
    return max(0, vw), max(0, vh)
end

class("gui-scrollpane", {
    childArea = function(w)
        local cw, ch = paneContentExtent(w)
        local vw, vh = paneViewSize(w)
        local offX = max(0, cw - vw) * (clamp(w.scrollX or 0, 0, 1))
        local offY = max(0, ch - vh) * (clamp(w.scrollY or 0, 0, 1))
        return w._ax - offX, w._ay - offY, vw, vh
    end,

    clipArea = function(w)
        local vw, vh = paneViewSize(w)
        return w._ax, w._ay, w._ax + vw, w._ay + vh
    end,

    draw = function(w)
        local cl = clip(w)
        fillRect(w._ax, w._ay, w._aw, w._ah, ct(w, T.panelBg), cl)
        frameRect(w._ax, w._ay, w._aw, w._ah, BORDER, ct(w, T.panelBorder), cl)
    end,

    drawAfter = function(w)
        local cl = clip(w)
        local cw, ch = paneContentExtent(w)
        local vw, vh = paneViewSize(w)
        if w.vbar then
            local sx = w._ax + w._aw - SCROLL_W
            fillRect(sx, w._ay, SCROLL_W, vh, ct(w, T.scrollTrack), cl)
            if ch > vh and ch > 0 then
                local th = max(16, vh * vh / ch)
                fillRect(sx + 1, w._ay + (vh - th) * clamp(w.scrollY or 0, 0, 1),
                         SCROLL_W - 2, th, ct(w, T.scrollThumb), cl)
            end
        end
        if w.hbar then
            local sy = w._ay + w._ah - SCROLL_W
            fillRect(w._ax, sy, vw, SCROLL_W, ct(w, T.scrollTrack), cl)
            if cw > vw and cw > 0 then
                local tw = max(16, vw * vw / cw)
                fillRect(w._ax + (vw - tw) * clamp(w.scrollX or 0, 0, 1), sy + 1,
                         tw, SCROLL_W - 2, ct(w, T.scrollThumb), cl)
            end
        end
    end,

    onWheel = function(w, delta)
        local cw, ch = paneContentExtent(w)
        local vw, vh = paneViewSize(w)
        local span = max(1, ch - vh)
        local before = w.scrollY or 0
        w.scrollY = clamp(before + delta * (lineH(w) * 3 / span), 0, 1)
        if w.scrollY ~= before then markDirty(); return true end
        return false
    end,
})

define("guiCreateScrollPane", function(x, y, width, height, relative, parent)
    local w = newWidget("gui-scrollpane", x, y, width, height, relative, parent, {
        scrollX = 0, scrollY = 0, hbar = true, vbar = true,
    })
    if not w then return false end
    return w.el
end)

define("guiScrollPaneSetScrollBars", function(el, horizontal, vertical)
    local w = resolveTyped(el, "gui-scrollpane")
    if not w then return false end
    w.hbar = truthy(horizontal)
    w.vbar = truthy(vertical)
    markDirty()
    return true
end)

local function paneScroll(field)
    return function(el, amount)
        local w = resolveTyped(el, "gui-scrollpane")
        if not w then return false end
        local a = num(amount, nil)
        if a == nil then return false end
        w[field] = clamp(a / 100, 0, 1)
        markDirty()
        return true
    end
end
local function paneScrollGet(field)
    return function(el)
        local w = resolveTyped(el, "gui-scrollpane")
        if not w then return false end
        return (w[field] or 0) * 100
    end
end

define("guiScrollPaneSetHorizontalScrollPosition", paneScroll("scrollX"))
define("guiScrollPaneGetHorizontalScrollPosition", paneScrollGet("scrollX"))
define("guiScrollPaneSetVerticalScrollPosition", paneScroll("scrollY"))
define("guiScrollPaneGetVerticalScrollPosition", paneScrollGet("scrollY"))

local function glHeaderH(w) return floor(fontHeight(w.font) + 6) end
local function glRowH(w)    return rowH(w) end

local function glViewRect(w)
    local hh = glHeaderH(w)
    local x1 = w._ax + BORDER
    local y1 = w._ay + BORDER + hh
    local x2 = w._ax + w._aw - BORDER - (w.vbar and SCROLL_W or 0)
    local y2 = w._ay + w._ah - BORDER - (w.hbar and SCROLL_W or 0)
    return x1, y1, x2, y2
end

local function glVisibleRows(w)
    local _, y1, _, y2 = glViewRect(w)
    local rh = glRowH(w)
    if rh <= 0 then return 1 end
    return max(1, floor((y2 - y1) / rh))
end

local function glMaxScroll(w)
    return max(0, #w.rows - glVisibleRows(w))
end

local function glClampScroll(w)
    w.scrollRow = clamp(floor(w.scrollRow or 0), 0, glMaxScroll(w))
end

local function glColumnPixels(w)
    local out = w._colPx
    if out == nil then out = {}; w._colPx = out end
    local x1 = glViewRect(w)
    local cx = x1 - (w.scrollPixelX or 0)
    local n = #w.columns
    for i = 1, n do
        local cw = w.columns[i].width * w._aw
        local slot = out[i]
        if slot == nil then slot = {}; out[i] = slot end
        slot.x, slot.w = cx, cw
        cx = cx + cw
    end
    for i = #out, n + 1, -1 do out[i] = nil end
    return out
end

local function glCell(w, row, col, create)
    local r = w.rows[row]
    if r == nil then return nil end
    if col == nil or col < 1 or col > #w.columns then return nil end
    local c = r.cells[col]
    if c == nil and create then
        c = { text = "", data = nil, colour = nil }
        r.cells[col] = c
    end
    return c
end

local function glClearSelection(w)
    for i = #w.selection, 1, -1 do w.selection[i] = nil end
end

local function glSelectedIndex(w, row)
    for i = 1, #w.selection do
        if w.selection[i].row == row then return i end
    end
    return nil
end

local function glSelect(w, row, col, additive)
    if not additive or w.selectionMode == 0 then
        glClearSelection(w)
        w.selection[1] = { row = row, col = col }
        return
    end
    local at = glSelectedIndex(w, row)
    if at ~= nil then
        remove(w.selection, at)
        return
    end
    w.selection[#w.selection + 1] = { row = row, col = col }
end

local function glSortBy(w, colIndex)
    if not w.sortingEnabled then return end
    if w.sortColumn == colIndex then
        w.sortAscending = not w.sortAscending
    else
        w.sortColumn = colIndex
        w.sortAscending = true
    end
    local asc = w.sortAscending
    local decorated = {}
    for i = 1, #w.rows do decorated[i] = { row = w.rows[i], i = i } end
    sort(decorated, function(a, b)
        local ca = a.row.cells[colIndex]
        local cb = b.row.cells[colIndex]
        local ta = ca and ca.text or ""
        local tb = cb and cb.text or ""
        local na = (ca and ca.number) and tonum(ta) or nil
        local nb = (cb and cb.number) and tonum(tb) or nil
        local lt
        if na ~= nil and nb ~= nil then
            if na == nb then return a.i < b.i end
            lt = na < nb
        else
            if ta == tb then return a.i < b.i end
            lt = ta < tb
        end
        if asc then return lt end
        return not lt
    end)
    local newRows = {}
    for i = 1, #decorated do newRows[i] = decorated[i].row end
    w.rows = newRows
    glClearSelection(w)
end

class("gui-gridlist", {
    draw = function(w)
        local cl = clip(w)
        fillRect(w._ax, w._ay, w._aw, w._ah, ct(w, T.panelBg), cl)

        local hh = glHeaderH(w)
        local x1, y1, x2, y2 = glViewRect(w)
        local cols = glColumnPixels(w)
        local headerClip = innerClip(w, BORDER, BORDER,
                                     BORDER + (w.vbar and SCROLL_W or 0),
                                     w._ah - BORDER - hh)

        fillRect(w._ax + BORDER, w._ay + BORDER, w._aw - BORDER * 2, hh,
                 ct(w, T.headerBg), cl)
        for i = 1, #cols do
            local c = cols[i]
            drawText(w.columns[i].title, c.x + PAD, w._ay + BORDER,
                     c.x + c.w - PAD, w._ay + BORDER + hh,
                     ct(w, T.text), w.font, "left", "center", false, headerClip)
            if i > 1 then
                fillRect(c.x, w._ay + BORDER, 1, hh, ct(w, T.panelBorder), headerClip)
            end
        end

        glClampScroll(w)
        local rh = glRowH(w)
        local visible = glVisibleRows(w)
        local bodyClip = w._bodyT
        if bodyClip == nil then bodyClip = {}; w._bodyT = bodyClip end
        bodyClip[1], bodyClip[2], bodyClip[3], bodyClip[4] =
            intersect(x1, y1, x2, y2, w._cx1, w._cy1, w._cx2, w._cy2)

        for i = 1, visible do
            local ri = w.scrollRow + i
            local row = w.rows[ri]
            if row == nil then break end
            local ry = y1 + (i - 1) * rh
            local selected = false
            for s = 1, #w.selection do
                if w.selection[s].row == ri then selected = true; break end
            end
            if selected then
                fillRect(x1, ry, x2 - x1, rh, ct(w, T.rowSelected), bodyClip)
            elseif ri % 2 == 0 then
                fillRect(x1, ry, x2 - x1, rh, ct(w, T.rowAlt), bodyClip)
            end
            for ci = 1, #cols do
                local cell = row.cells[ci]
                if cell then
                    local col = cell.colour and ct(w, cell.colour) or textColour(w)
                    drawText(cell.text, cols[ci].x + PAD, ry,
                             cols[ci].x + cols[ci].w - PAD, ry + rh,
                             col, w.font, "left", "center", false, bodyClip)
                end
            end
        end

        if w.vbar then
            local sx = w._ax + w._aw - BORDER - SCROLL_W
            fillRect(sx, y1, SCROLL_W, y2 - y1, ct(w, T.scrollTrack), cl)
            local total = #w.rows
            if total > visible and total > 0 then
                local th = max(16, (y2 - y1) * visible / total)
                local mxs = glMaxScroll(w)
                local off = mxs > 0 and ((y2 - y1 - th) * w.scrollRow / mxs) or 0
                fillRect(sx + 1, y1 + off, SCROLL_W - 2, th, ct(w, T.scrollThumb), cl)
            end
        end
        if w.hbar then
            local sy = w._ay + w._ah - BORDER - SCROLL_W
            fillRect(x1, sy, x2 - x1, SCROLL_W, ct(w, T.scrollTrack), cl)
        end

        frameRect(w._ax, w._ay, w._aw, w._ah, BORDER, ct(w, T.panelBorder), cl)
    end,

    onMouseDown = function(w, button, x, y)
        if button ~= "left" then return end
        local hh = glHeaderH(w)
        local x1, y1, x2, y2 = glViewRect(w)

        if y < w._ay + BORDER + hh then
            if not w.sortingEnabled then return end
            local cols = glColumnPixels(w)
            for i = 1, #cols do
                if x >= cols[i].x and x < cols[i].x + cols[i].w then
                    glSortBy(w, i)
                    return
                end
            end
            return
        end

        if w.vbar and x >= w._ax + w._aw - BORDER - SCROLL_W then
            local visible = glVisibleRows(w)
            local mid = (y1 + y2) / 2
            w.scrollRow = (w.scrollRow or 0) + (y < mid and -visible or visible)
            glClampScroll(w)
            fire("onClientGUIScroll", w)
            return
        end

        if y < y1 or y >= y2 then return end
        local rh = glRowH(w)
        local ri = (w.scrollRow or 0) + floor((y - y1) / rh) + 1
        if w.rows[ri] == nil then
            glClearSelection(w)
            return
        end
        local cols = glColumnPixels(w)
        local ci = 1
        for i = 1, #cols do
            if x >= cols[i].x and x < cols[i].x + cols[i].w then ci = i; break end
        end
        glSelect(w, ri, ci, w.selectionMode == 1 and C.ctrlHeld())
    end,

    onWheel = function(w, delta)
        local before = w.scrollRow or 0
        w.scrollRow = before + delta * 3
        glClampScroll(w)
        return w.scrollRow ~= before
    end,

    dispose = function(w)
        w.rows, w.columns, w.selection = {}, {}, {}
    end,
})

define("guiCreateGridList", function(x, y, width, height, relative, parent)
    local w = newWidget("gui-gridlist", x, y, width, height, relative, parent, {
        columns = {},
        rows = {},
        selection = {},
        selectionMode = 0,
        sortingEnabled = true,
        sortColumn = nil,
        sortAscending = true,
        scrollRow = 0,
        scrollPixelX = 0,
        hbar = false,
        vbar = true,
    })
    if not w then return false end
    return w.el
end)

local function gl(el) return resolveTyped(el, "gui-gridlist") end

define("guiGridListSetSortingEnabled", function(el, enabled)
    local w = gl(el); if not w then return false end
    w.sortingEnabled = truthy(enabled)
    return true
end)

define("guiGridListIsSortingEnabled", function(el)
    local w = gl(el); if not w then return false end
    return w.sortingEnabled == true
end)

-- Returns the new column's 1-based index.
define("guiGridListAddColumn", function(el, title, width)
    local w = gl(el); if not w then return false end
    local ww = num(width, nil)
    if ww == nil then return false end
    w.columns[#w.columns + 1] = { title = str(title, ""), width = max(0, ww) }
    return #w.columns
end)

define("guiGridListRemoveColumn", function(el, columnIndex)
    local w = gl(el); if not w then return false end
    local i = num(columnIndex, nil)
    if i == nil then return false end
    i = floor(i)
    if w.columns[i] == nil then return false end
    local n = #w.columns
    remove(w.columns, i)
    -- NOT table.remove: `cells` is deliberately sparse (a cell only exists once
    -- something wrote to it), and table.remove RAISES "position out of bounds"
    -- whenever the position is past the border `#` reports for a table with
    -- holes -- which is every gridlist where column 1 was never filled in. The
    -- shift is written out over the KNOWN column count instead.
    for r = 1, #w.rows do
        local cells = w.rows[r].cells
        for c = i, n - 1 do cells[c] = cells[c + 1] end
        cells[n] = nil
    end
    glClearSelection(w)
    return true
end)

define("guiGridListSetColumnWidth", function(el, columnIndex, width, relative)
    local w = gl(el); if not w then return false end
    local i, ww = num(columnIndex, nil), num(width, nil)
    if i == nil or ww == nil then return false end
    local col = w.columns[floor(i)]
    if col == nil then return false end
    if truthy(relative) then
        col.width = max(0, ww)
    else
        col.width = (w.w > 0) and max(0, ww / w.w) or 0
    end
    return true
end)

define("guiGridListGetColumnWidth", function(el, columnIndex, relative)
    local w = gl(el); if not w then return false end
    local i = num(columnIndex, nil)
    if i == nil then return false end
    local col = w.columns[floor(i)]
    if col == nil then return false end
    if truthy(relative) then return col.width end
    return col.width * w.w
end)

define("guiGridListSetColumnTitle", function(el, columnIndex, title)
    local w = gl(el); if not w then return false end
    local i = num(columnIndex, nil)
    if i == nil then return false end
    local col = w.columns[floor(i)]
    if col == nil then return false end
    col.title = str(title, "")
    return true
end)

define("guiGridListGetColumnTitle", function(el, columnIndex)
    local w = gl(el); if not w then return false end
    local i = num(columnIndex, nil)
    if i == nil then return false end
    local col = w.columns[floor(i)]
    if col == nil then return false end
    return col.title
end)

define("guiGridListSetScrollBars", function(el, horizontalBar, verticalBar)
    local w = gl(el); if not w then return false end
    w.hbar = truthy(horizontalBar)
    w.vbar = truthy(verticalBar)
    return true
end)

define("guiGridListGetRowCount", function(el)
    local w = gl(el); if not w then return false end
    return #w.rows
end)

define("guiGridListGetColumnCount", function(el)
    local w = gl(el); if not w then return false end
    return #w.columns
end)

define("guiGridListAddRow", function(el)
    local w = gl(el); if not w then return false end
    w.rows[#w.rows + 1] = { cells = {} }
    return #w.rows - 1
end)

define("guiGridListInsertRowAfter", function(el, rowIndex)
    local w = gl(el); if not w then return false end
    local i = num(rowIndex, nil)
    if i == nil then return false end
    local at = floor(i) + 2                 -- 0-based "after" -> 1-based insert position
    if at < 1 then at = 1 end
    if at > #w.rows + 1 then at = #w.rows + 1 end
    insert(w.rows, at, { cells = {} })
    return at - 1
end)

define("guiGridListRemoveRow", function(el, rowIndex)
    local w = gl(el); if not w then return false end
    local i = num(rowIndex, nil)
    if i == nil then return false end
    local at = floor(i) + 1
    if w.rows[at] == nil then return false end
    remove(w.rows, at)
    for s = #w.selection, 1, -1 do
        local sel = w.selection[s]
        if sel.row == at then remove(w.selection, s)
        elseif sel.row > at then sel.row = sel.row - 1 end
    end
    glClampScroll(w)
    return true
end)

define("guiGridListAutoSizeColumn", function(el, columnIndex)
    local w = gl(el); if not w then return false end
    local i = num(columnIndex, nil)
    if i == nil then return false end
    i = floor(i)
    local col = w.columns[i]
    if col == nil then return false end
    local widest = textWidth(col.title, w.font)
    for r = 1, #w.rows do
        local cell = w.rows[r].cells[i]
        if cell then
            local cw = textWidth(cell.text, w.font)
            if cw > widest then widest = cw end
        end
    end
    col.width = (w.w > 0) and ((widest + PAD * 3) / w.w) or 0
    return true
end)

define("guiGridListClear", function(el)
    local w = gl(el); if not w then return false end
    for i = #w.rows, 1, -1 do w.rows[i] = nil end
    glClearSelection(w)
    w.scrollRow = 0
    return true
end)

define("guiGridListSetItemText", function(el, rowIndex, columnIndex, text, section, number)
    local w = gl(el); if not w then return false end
    local r, c = num(rowIndex, nil), num(columnIndex, nil)
    if r == nil or c == nil then return false end
    local cell = glCell(w, floor(r) + 1, floor(c), true)
    if cell == nil then return false end
    cell.text = str(text, "")
    cell.section = truthy(section)
    cell.number = truthy(number)
    return true
end)

define("guiGridListGetItemText", function(el, rowIndex, columnIndex)
    local w = gl(el); if not w then return false end
    local r, c = num(rowIndex, nil), num(columnIndex, nil)
    if r == nil or c == nil then return false end
    local cell = glCell(w, floor(r) + 1, floor(c), false)
    if cell == nil then return "" end
    return cell.text
end)

define("guiGridListSetItemData", function(el, rowIndex, columnIndex, data)
    local w = gl(el); if not w then return false end
    local r, c = num(rowIndex, nil), num(columnIndex, nil)
    if r == nil or c == nil then return false end
    local cell = glCell(w, floor(r) + 1, floor(c), true)
    if cell == nil then return false end
    cell.data = data
    return true
end)

define("guiGridListGetItemData", function(el, rowIndex, columnIndex)
    local w = gl(el); if not w then return false end
    local r, c = num(rowIndex, nil), num(columnIndex, nil)
    if r == nil or c == nil then return false end
    local cell = glCell(w, floor(r) + 1, floor(c), false)
    if cell == nil or cell.data == nil then return false end
    return cell.data
end)

define("guiGridListSetItemColor", function(el, rowIndex, columnIndex, r, g, b, a)
    local w = gl(el); if not w then return false end
    local ri, ci = num(rowIndex, nil), num(columnIndex, nil)
    if ri == nil or ci == nil then return false end
    local rr, gg, bb = num(r, nil), num(g, nil), num(b, nil)
    if rr == nil or gg == nil or bb == nil then return false end
    local cell = glCell(w, floor(ri) + 1, floor(ci), true)
    if cell == nil then return false end
    cell.colour = argb(num(a, 255), rr, gg, bb)
    return true
end)

define("guiGridListGetItemColor", function(el, rowIndex, columnIndex)
    local w = gl(el); if not w then return false end
    local ri, ci = num(rowIndex, nil), num(columnIndex, nil)
    if ri == nil or ci == nil then return false end
    local cell = glCell(w, floor(ri) + 1, floor(ci), false)
    local c = (cell and cell.colour) or T.text
    return floor(c / 0x10000) % 256, floor(c / 0x100) % 256, c % 256,
           floor(c / 0x1000000) % 256
end)

define("guiGridListSetSelectionMode", function(el, mode)
    local w = gl(el); if not w then return false end
    local m = num(mode, nil)
    if m == nil then return false end
    m = floor(m)
    if m ~= 0 and m ~= 1 then
        unsupported("guiGridListSetSelectionMode(" .. m .. ")",
            "only mode 0 (single row) and mode 1 (multi row) are emulated; " ..
            "column, cell and nominated modes fall back to mode 0")
        w.selectionMode = 0
    else
        w.selectionMode = m
    end
    glClearSelection(w)
    return true
end)

define("guiGridListGetSelectionMode", function(el)
    local w = gl(el); if not w then return false end
    return w.selectionMode or 0
end)

define("guiGridListGetSelectedItem", function(el)
    local w = gl(el); if not w then return false end
    local sel = w.selection[1]
    if sel == nil then return -1, -1 end
    return sel.row - 1, sel.col
end)

define("guiGridListGetSelectedItems", function(el)
    local w = gl(el); if not w then return false end
    local out = {}
    for i = 1, #w.selection do
        out[i] = { row = w.selection[i].row - 1, column = w.selection[i].col - 1 }
    end
    return out
end)

define("guiGridListGetSelectedCount", function(el)
    local w = gl(el); if not w then return false end
    return #w.selection
end)

define("guiGridListSetSelectedItem", function(el, rowIndex, columnIndex)
    local w = gl(el); if not w then return false end
    local r, c = num(rowIndex, nil), num(columnIndex, nil)
    if r == nil or c == nil then return false end
    r, c = floor(r) + 1, floor(c)
    if r < 1 then glClearSelection(w); return true end
    if w.rows[r] == nil then return false end
    glSelect(w, r, max(1, c), false)
    local visible = glVisibleRows(w)
    if r - 1 < (w.scrollRow or 0) then w.scrollRow = r - 1 end
    if r > (w.scrollRow or 0) + visible then w.scrollRow = r - visible end
    glClampScroll(w)
    return true
end)

define("guiGridListSetHorizontalScrollPosition", function(el, position)
    local w = gl(el); if not w then return false end
    local p = num(position, nil)
    if p == nil then return false end
    local cols = #w.columns
    local total = 0
    for i = 1, cols do total = total + w.columns[i].width * w.w end
    local x1, _, x2 = glViewRect(w)
    w.scrollPixelX = max(0, total - (x2 - x1)) * clamp(p / 100, 0, 1)
    return true
end)

define("guiGridListGetHorizontalScrollPosition", function(el)
    local w = gl(el); if not w then return false end
    local total = 0
    for i = 1, #w.columns do total = total + w.columns[i].width * w.w end
    local x1, _, x2 = glViewRect(w)
    local span = max(0, total - (x2 - x1))
    if span <= 0 then return 0 end
    return clamp((w.scrollPixelX or 0) / span, 0, 1) * 100
end)

define("guiGridListSetVerticalScrollPosition", function(el, position)
    local w = gl(el); if not w then return false end
    local p = num(position, nil)
    if p == nil then return false end
    w.scrollRow = floor(clamp(p / 100, 0, 1) * glMaxScroll(w) + 0.5)
    glClampScroll(w)
    return true
end)

define("guiGridListGetVerticalScrollPosition", function(el)
    local w = gl(el); if not w then return false end
    local mx = glMaxScroll(w)
    if mx <= 0 then return 0 end
    return (w.scrollRow or 0) / mx * 100
end)

local function cbStripH(w) return floor(fontHeight(w.font) + 8) end

local function cbListRect(w)
    local top = w._ay + cbStripH(w)
    local rh = rowH(w)
    local rowsH = #w.items * rh
    local avail = max(rh, w._ah - cbStripH(w))
    local h = min(rowsH, avail)
    local _, sh = C.screen()
    if top + h > sh then h = max(rh, sh - top) end
    if top >= sh then h = 0 end
    return w._ax, top, w._aw, h
end

local function cbClose(w)
    if C.popup == w then C.popup = nil end
    w.open = false
end

local function cbSetDisplay(w, s)
    w.display = s
    w.text = s
end

local function cbSyncDisplay(w)
    local item = (w.selected >= 0) and w.items[w.selected + 1] or nil
    cbSetDisplay(w, item or w.caption)
end

class("gui-combobox", {
    hitBox = function(w)
        return w._ax, w._ay, w._ax + w._aw, w._ay + cbStripH(w)
    end,

    draw = function(w)
        local cl = clip(w)
        local sh = cbStripH(w)
        fillRect(w._ax, w._ay, w._aw, sh, ct(w, T.fieldBg), cl)
        frameRect(w._ax, w._ay, w._aw, sh, BORDER,
                  ct(w, (C.focused == w) and T.fieldBorderFocus or T.fieldBorder), cl)
        local label = w.display or w.caption
        drawText(label, w._ax + PAD, w._ay, w._ax + w._aw - sh, w._ay + sh,
                 textColour(w), w.font, "left", "center", false, cl)

        local ax = w._ax + w._aw - sh / 2
        local ay = w._ay + sh / 2
        for i = 0, 3 do
            fillRect(ax - 4 + i, ay - 2 + i, (4 - i) * 2, 1, textColour(w), cl)
        end
    end,

    drawPopup = function(w)
        local lx, ly, lw, lh = cbListRect(w)
        local sw, sh = C.screen()
        local cl = w._popT
        if cl == nil then cl = {}; w._popT = cl end
        cl[1], cl[2], cl[3], cl[4] = 0, 0, sw, sh
        fillRect(lx, ly, lw, lh, ct(w, T.panelBg), cl)
        frameRect(lx, ly, lw, lh, BORDER, ct(w, T.panelBorder), cl)
        local rh = rowH(w)
        local visible = max(1, floor(lh / rh))
        local listClip = w._listT
        if listClip == nil then listClip = {}; w._listT = listClip end
        listClip[1], listClip[2], listClip[3], listClip[4] =
            intersect(lx, ly, lx + lw, ly + lh, 0, 0, sw, sh)
        for i = 1, visible do
            local idx = (w.listScroll or 0) + i
            local item = w.items[idx]
            if item == nil then break end
            local ry = ly + (i - 1) * rh
            if idx - 1 == w.selected then
                fillRect(lx + 1, ry, lw - 2, rh, ct(w, T.rowSelected), listClip)
            elseif C.cursorY >= ry and C.cursorY < ry + rh
                   and C.cursorX >= lx and C.cursorX < lx + lw then
                fillRect(lx + 1, ry, lw - 2, rh, ct(w, T.rowHover), listClip)
            end
            drawText(item, lx + PAD, ry, lx + lw - PAD, ry + rh,
                     textColour(w), w.font, "left", "center", false, listClip)
        end
    end,

    hitPopup = function(w, x, y)
        if not w.open then return nil end
        local lx, ly, lw, lh = cbListRect(w)
        if pointIn(x, y, lx, ly, lx + lw, ly + lh) then return w end
        return nil
    end,

    closePopup = cbClose,

    setText = function(w, s) cbSetDisplay(w, s) end,
    getText = function(w) return w.display or w.caption end,

    onWheel = function(w, delta)
        if not w.open then return false end
        local before = w.listScroll or 0
        local lx, ly, lw, lh = cbListRect(w)
        local visible = max(1, floor(lh / rowH(w)))
        w.listScroll = clamp(before + delta, 0, max(0, #w.items - visible))
        return w.listScroll ~= before
    end,

    onMouseDown = function(w, button, x, y)
        if button ~= "left" then return end
        if w.open then
            local lx, ly, lw, lh = cbListRect(w)
            if pointIn(x, y, lx, ly, lx + lw, ly + lh) then
                local idx = (w.listScroll or 0) + floor((y - ly) / rowH(w)) + 1
                if w.items[idx] then
                    w.selected = idx - 1
                    cbSyncDisplay(w)
                    cbClose(w)
                    fire("onClientGUIComboBoxAccepted", w)
                end
                return
            end
            cbClose(w)
            return
        end

        local prev = C.popup
        if prev and prev ~= w and not prev.destroyed then
            local pcls = classes[prev.type]
            if pcls and pcls.closePopup then pcls.closePopup(prev) end
        end
        w.open = true
        w.listScroll = 0
        C.popup = w
    end,

    dispose = function(w)
        if C.popup == w then C.popup = nil end
    end,
})

define("guiCreateComboBox", function(x, y, width, height, caption, relative, parent)
    local cap = str(caption, "")
    local w = newWidget("gui-combobox", x, y, width, height, relative, parent, {
        items = {},
        selected = -1,
        caption = cap,
        display = cap,
        open = false,
        listScroll = 0,
    })
    if not w then return false end
    cbSetDisplay(w, w.caption)
    return w.el
end)

local function cb(el) return resolveTyped(el, "gui-combobox") end

define("guiComboBoxAddItem", function(el, value)
    local w = cb(el); if not w then return false end
    w.items[#w.items + 1] = str(value, "")
    return #w.items - 1
end)

define("guiComboBoxRemoveItem", function(el, itemId)
    local w = cb(el); if not w then return false end
    local i = num(itemId, nil)
    if i == nil then return false end
    i = floor(i) + 1
    if w.items[i] == nil then return false end
    remove(w.items, i)
    if w.selected == i - 1 then w.selected = -1
    elseif w.selected > i - 1 then w.selected = w.selected - 1 end
    cbSyncDisplay(w)
    return true
end)

define("guiComboBoxClear", function(el)
    local w = cb(el); if not w then return false end
    for i = #w.items, 1, -1 do w.items[i] = nil end
    w.selected = -1
    w.listScroll = 0
    cbSyncDisplay(w)
    return true
end)

define("guiComboBoxGetSelected", function(el)
    local w = cb(el); if not w then return false end
    return w.selected
end)

define("guiComboBoxSetSelected", function(el, itemIndex)
    local w = cb(el); if not w then return false end
    local i = num(itemIndex, nil)
    if i == nil then return false end
    i = floor(i)
    if i == -1 then w.selected = -1; cbSyncDisplay(w); return true end
    if w.items[i + 1] == nil then return false end
    w.selected = i
    cbSyncDisplay(w)
    return true
end)

define("guiComboBoxGetItemText", function(el, itemId)
    local w = cb(el); if not w then return false end
    local i = num(itemId, nil)
    if i == nil then return false end
    i = floor(i)
    if i == -1 then return w.display or w.caption end
    local t = w.items[i + 1]
    if t == nil then return false end
    return t
end)

define("guiComboBoxSetItemText", function(el, itemId, text)
    local w = cb(el); if not w then return false end
    local i = num(itemId, nil)
    if i == nil then return false end
    i = floor(i)
    if w.items[i + 1] == nil then return false end
    w.items[i + 1] = str(text, "")
    if w.selected == i then cbSyncDisplay(w) end
    return true
end)

define("guiComboBoxGetItemCount", function(el)
    local w = cb(el); if not w then return false end
    return #w.items
end)

define("guiComboBoxSetOpen", function(el, state)
    local w = cb(el); if not w then return false end
    if truthy(state) then
        local prev = C.popup
        if prev and prev ~= w and not prev.destroyed then
            local pcls = classes[prev.type]
            if pcls and pcls.closePopup then pcls.closePopup(prev) end
        end
        w.open = true
        w.listScroll = 0
        C.popup = w
    else
        cbClose(w)
    end
    return true
end)

define("guiComboBoxIsOpen", function(el)
    local w = cb(el); if not w then return false end
    return w.open == true
end)

local function tpStripH(w) return floor(fontHeight(w.font) + 10) end

local function tpTabRects(w)
    local out = {}
    local x = w._ax
    local h = tpStripH(w)
    for i = 1, #w.children do
        local tab = w.children[i]
        if tab.type == "gui-tab" then
            local tw = textWidth(tab.text, w.font) + PAD * 4
            out[#out + 1] = { x = x, w = tw, h = h, tab = tab }
            x = x + tw
        end
    end
    return out
end

class("gui-tabpanel", {
    childArea = function(w)
        local sh = tpStripH(w)
        return w._ax, w._ay + sh, w._aw, max(0, w._ah - sh)
    end,

    clipArea = function(w)
        local sh = tpStripH(w)
        return w._ax, w._ay + sh, w._ax + w._aw, w._ay + w._ah
    end,

    childVisible = function(w, child)
        if child.type ~= "gui-tab" then return true end
        return w.selected == child
    end,

    reflow = function(w)
        local sh = tpStripH(w)
        local cw, ch = w._aw, max(0, w._ah - sh)
        local firstTab = nil
        for i = 1, #w.children do
            local tab = w.children[i]
            if tab.type == "gui-tab" then
                tab.x, tab.y, tab.w, tab.h = 0, 0, cw, ch
                if firstTab == nil then firstTab = tab end
            end
        end
        if w.selected == nil or w.selected.destroyed or w.selected.parent ~= w then
            w.selected = firstTab
        end
    end,

    draw = function(w)
        local cl = clip(w)
        local sh = tpStripH(w)
        fillRect(w._ax, w._ay, w._aw, sh, ct(w, T.tabStrip), cl)
        fillRect(w._ax, w._ay + sh, w._aw, w._ah - sh, ct(w, T.panelBg), cl)
        local rects = tpTabRects(w)
        for i = 1, #rects do
            local r = rects[i]
            local active = (r.tab == w.selected)
            fillRect(r.x, w._ay, r.w, sh, ct(w, active and T.tabActive or T.tabInactive), cl)
            frameRect(r.x, w._ay, r.w, sh, BORDER, ct(w, T.panelBorder), cl)
            drawText(r.tab.text, r.x + PAD, w._ay, r.x + r.w - PAD, w._ay + sh,
                     textColour(w), w.font, "center", "center", false, cl)
        end
        frameRect(w._ax, w._ay + sh, w._aw, w._ah - sh, BORDER, ct(w, T.panelBorder), cl)
    end,

    onMouseDown = function(w, button, x, y)
        if button ~= "left" then return end
        if y >= w._ay + tpStripH(w) then return end
        local rects = tpTabRects(w)
        for i = 1, #rects do
            local r = rects[i]
            if x >= r.x and x < r.x + r.w then
                if w.selected ~= r.tab then
                    w.selected = r.tab
                    markDirty()
                    fire("onClientGUITabSwitched", w)
                end
                return
            end
        end
    end,
})

class("gui-tab", {
    draw = function(w)
    end,
})

define("guiCreateTabPanel", function(x, y, width, height, relative, parent)
    local w = newWidget("gui-tabpanel", x, y, width, height, relative, parent, {
        selected = nil,
        font = "default-bold-small",
    })
    if not w then return false end
    return w.el
end)

define("guiCreateTab", function(text, parent)
    local p = resolveTyped(parent, "gui-tabpanel")
    if not p then return false end
    local w = newWidget("gui-tab", 0, 0, 0, 0, false, p.el, {
        text = str(text, ""),
    })
    if not w then return false end
    if p.selected == nil then p.selected = w end
    markDirty()
    return w.el
end)

define("guiGetSelectedTab", function(tabPanel)
    local p = resolveTyped(tabPanel, "gui-tabpanel")
    if not p then return false end
    if p.selected == nil or p.selected.destroyed then return false end
    return p.selected.el
end)

define("guiSetSelectedTab", function(tabPanel, theTab)
    local p = resolveTyped(tabPanel, "gui-tabpanel")
    if not p then return false end
    local t = resolveTyped(theTab, "gui-tab")
    if not t or t.parent ~= p then return false end
    if p.selected == t then return true end
    p.selected = t
    markDirty()
    fire("onClientGUITabSwitched", p)
    return true
end)

define("guiDeleteTab", function(tabToDelete, tabPanel)
    local t = resolveTyped(tabToDelete, "gui-tab")
    if not t then return false end
    local p = resolveTyped(tabPanel, "gui-tabpanel")
    if not p or t.parent ~= p then return false end
    local wasSelected = (p.selected == t)
    destroyWidget(t)
    if wasSelected then
        p.selected = nil
        for i = 1, #p.children do
            if p.children[i].type == "gui-tab" then p.selected = p.children[i]; break end
        end
        markDirty()
        fire("onClientGUITabSwitched", p)
    end
    return true
end)

define("guiCreateBrowser", function()
    unsupported("guiCreateBrowser",
        "not reproducible. Rewrite to NUI (ui_page + registerNuiCallback) or DUI " ..
        "(createDui + dxDrawImage). Returns false, as MTA does on failure.")
    return false
end)

define("guiGetBrowser", function()
    unsupported("guiGetBrowser", "guiCreateBrowser is not emulated, so there is never a browser")
    return false
end)

C.widgetsReady = true
C.info("widgets loaded: " .. #C.definedNames .. " gui* functions defined.")
