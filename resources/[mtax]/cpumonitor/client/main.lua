local Fonts = { }

local ScreenWidth, ScreenHeight = guiGetScreenSize()
local ScaleMap = {
    {Height = 480, Scale = 0.7},
    {Height = 576, Scale = 0.8},
    {Height = 600, Scale = 0.9},
    {Height = 768, Scale = 1},
    {Height = 900, Scale = 1.1},
    {Height = 1050, Scale = 1.15},
    {Height = 1080, Scale = 1}
}

function CalculateScale()
    for _, val in ipairs(ScaleMap) do
        if ScreenHeight <= val.Height then
            return val.Scale
        end
    end

    return math.min(math.max(0.75, (ScreenHeight / 768)), 1.2)
end

local Scale = CalculateScale()

local ParentWidth, ParentHeight = 265, 132

GetFont = function(font, size)
    if not Fonts[font] then
        Fonts[font] = {}
    end

    if not Fonts[font][size] then
        Fonts[font][size] = dxCreateFont('fonts/'..font, (size * Scale) * (72 / 96), false, 'cleartype') or 'default-bold'
    end

    return Fonts[font][size]
end

_dxDrawText = dxDrawText
_dxDrawRectangle = dxDrawRectangle
_dxDrawImage = dxDrawImage

function dxDrawText(text, x, y, w, h, ...)
    local x, y, w, h = x * Scale, y * Scale, w * Scale, h * Scale
    return _dxDrawText(text, x, y, x + w, y + h, ...)
end

function dxDrawRectangle( x, y, w, h, ...)
    local x, y, w, h = x * Scale, y * Scale, w * Scale, h * Scale
    return _dxDrawRectangle(x, y, w, h, ...)
end

function dxDrawImage( x, y, w, h, path, ...)
    local x, y, w, h = x * Scale, y * Scale, w * Scale, h * Scale
    return _dxDrawImage(x, y, w, h, path, ...)
end

function GetCursor()
    local cursorX, cursorY = getCursorPosition()

    if not cursorX then
        return -1, -1
    end

    return ((cursorX * ScreenWidth) / Scale), ((cursorY * ScreenHeight) / Scale)
end

function IsCursorOver(x, y, w, h)
    if not isCursorShowing() then
        return false
    end

    local cursorX, cursorY = GetCursor()
    return (cursorX >= x and cursorX <= x + w and cursorY >= y and cursorY <= y + h)
end

local Settings = config['gerais']
local Colors = Settings['colors']
local ResourceName = getResourceName(getThisResource())
local VisibleRows = 3

local Panels = {
    {
        Title = 'Client-side',
        Divider = 23,
        Rows = { },
        Index = 0,
        Moving = false,
        Scrolling = false
    },
    {
        Title = 'Server-side',
        Divider = 4,
        Rows = { },
        Index = 0,
        Moving = false,
        Scrolling = false
    }
}

local Visible = false

function DefaultPosition(divider)
    return (((ScreenWidth / Scale) - ParentWidth) / 1.03), (((ScreenHeight / Scale) - ParentHeight) / divider)
end

for _, panel in ipairs(Panels) do
    panel.X, panel.Y = DefaultPosition(panel.Divider)
end

function RemoveResource(rows)
    for i = #rows, 1, -1 do
        if rows[i][1] == ResourceName then
            table.remove(rows, i)
        end
    end
end

function DrawCard(x, y, w, h)
    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 128))
    dxDrawRectangle(x, y, w, 1, tocolor(112, 112, 112, 51))
    dxDrawRectangle(x, y + h - 1, w, 1, tocolor(112, 112, 112, 51))
    dxDrawRectangle(x, y, 1, h, tocolor(112, 112, 112, 51))
    dxDrawRectangle(x + w - 1, y, 1, h, tocolor(112, 112, 112, 51))
end

function DrawMoveButton(x, y)
    dxDrawRectangle(x, y, 14, 14, tocolor(0, 0, 0, 97))

    for row = 0, 2 do
        for column = 0, 2 do
            dxDrawRectangle(x + 3 + (column * 4), y + 3 + (row * 4), 2, 2, tocolor(255, 255, 255))
        end
    end
end

function DrawResetButton(x, y)
    dxDrawRectangle(x, y, 14, 14, tocolor(0, 0, 0, 97))
    dxDrawRectangle(x + 4, y + 3, 7, 1, tocolor(255, 255, 255))
    dxDrawRectangle(x + 10, y + 3, 1, 8, tocolor(255, 255, 255))
    dxDrawRectangle(x + 4, y + 10, 7, 1, tocolor(255, 255, 255))
    dxDrawRectangle(x + 4, y + 6, 1, 5, tocolor(255, 255, 255))
    dxDrawRectangle(x + 2, y + 5, 5, 1, tocolor(255, 255, 255))
    dxDrawRectangle(x + 3, y + 4, 3, 1, tocolor(255, 255, 255))
end

function DrawScrollBar(panel, x, y, w, h)
    local maxIndex = #panel.Rows - VisibleRows
    local thumbHeight = math.max(10, h * (VisibleRows / #panel.Rows))
    local track = h - thumbHeight

    if panel.Scrolling then
        if getKeyState('mouse1') and isCursorShowing() then
            local _, cursorY = GetCursor()
            local offset = math.min(math.max(0, cursorY - y - (thumbHeight / 2)), track)

            panel.Index = math.floor(((offset / track) * maxIndex) + 0.5)
        else
            panel.Scrolling = false
        end
    end

    dxDrawRectangle(x, y, w, h, tocolor(10, 10, 10, 100))
    dxDrawRectangle(x, y + (track * (panel.Index / maxIndex)), w, thumbHeight, tocolor(Colors['color:server'][1], Colors['color:server'][2], Colors['color:server'][3]))
end

function RenderPanel(panel)
    local rows = panel.Rows
    local maxIndex = math.max(0, #rows - VisibleRows)

    if panel.Index > maxIndex then
        panel.Index = maxIndex
    end

    if panel.Moving then
        if getKeyState('mouse1') and isCursorShowing() then
            local cursorX, cursorY = GetCursor()
            panel.X, panel.Y = cursorX - 10, cursorY - 5
        else
            panel.Moving = false
        end
    end

    if IsCursorOver(panel.X, panel.Y, ParentWidth, ParentHeight) then
        DrawMoveButton(panel.X, panel.Y)
        DrawResetButton(panel.X, panel.Y + 17)
    end

    dxDrawText(panel.Title..' '..Colors['hex:server']..'('..#rows..')', panel.X + 17, panel.Y + 10, 87, 14, tocolor(255, 255, 255), 1.0, GetFont('roboto-bold.ttf', 12), 'left', 'center', false, false, false, true)
    DrawCard(panel.X + 17, panel.Y + 26, 230, 100)

    if #rows > VisibleRows then
        DrawScrollBar(panel, panel.X + 254, panel.Y + 26, 3, 100)
    end

    local fontRobotoRegular = GetFont('roboto-regular.ttf', 15)

    for i = 1, VisibleRows do
        local value = rows[i + panel.Index]

        if value then
            local status = Settings['get:status'][1](value[2])
            local color = Colors[status]
            local textColor = (status ~= 'color:error' and tocolor(255, 255, 255) or tocolor(color[1], color[2], color[3]))

            dxDrawText(value[1], panel.X + 55, panel.Y + 17 + (i * 26), 119, 13, textColor, 1.0, fontRobotoRegular, 'left', 'center', true)
            dxDrawText(value[2], panel.X + 188, panel.Y + 17 + (i * 26), 54, 13, textColor, 1.0, fontRobotoRegular, 'right', 'center', true)
            dxDrawImage(panel.X + 33, panel.Y + 15 + (i * 26), 16, 16, 'images/status.png', 0, 0, 0, tocolor(color[1], color[2], color[3], math.abs(math.sin(getTickCount() / 1500)) * 255))
        end
    end
end

RenderCpuMonitor = function()
    local _, rows = getPerformanceStats('Lua timing')
    RemoveResource(rows)

    table.sort(rows, function(a, b)
        return tofloor(a[2]) > tofloor(b[2])
    end)

    Panels[1].Rows = rows

    for _, panel in ipairs(Panels) do
        if #panel.Rows ~= 0 then
            RenderPanel(panel)
        end
    end
end

function ScrollPanel(key)
    for _, panel in ipairs(Panels) do
        if #panel.Rows > VisibleRows and IsCursorOver(panel.X + 17, panel.Y + 26, 230, 100) then
            local index = panel.Index + (key == 'mouse_wheel_down' and 1 or -1)
            panel.Index = math.min(math.max(0, index), #panel.Rows - VisibleRows)
        end
    end
end

function OpenPanel()
    if Visible then
        return
    end

    Visible = true
    addEventHandler('onClientRender', root, RenderCpuMonitor)
    bindKey('mouse_wheel_up', 'down', ScrollPanel)
    bindKey('mouse_wheel_down', 'down', ScrollPanel)
end

function ClosePanel()
    if not Visible then
        return
    end

    Visible = false
    removeEventHandler('onClientRender', root, RenderCpuMonitor)
    unbindKey('mouse_wheel_up', 'down', ScrollPanel)
    unbindKey('mouse_wheel_down', 'down', ScrollPanel)

    for _, panel in ipairs(Panels) do
        panel.Moving = false
        panel.Scrolling = false
    end
end

addEvent('mtax:cpumonitor:toggle', true)
addEventHandler('mtax:cpumonitor:toggle', resourceRoot, function(state)
    if state then
        OpenPanel()
        return
    end

    ClosePanel()
end)

addEvent('mtax:cpumonitor:server', true)
addEventHandler('mtax:cpumonitor:server', resourceRoot, function(rows)
    Panels[2].Rows = rows or { }
end)

addEventHandler('onClientClick', root, function(button, state)
    if not Visible or button ~= 'left' then
        return
    end

    if state == 'up' then
        for _, panel in ipairs(Panels) do
            panel.Moving = false
            panel.Scrolling = false
        end

        return
    end

    for _, panel in ipairs(Panels) do
        if #panel.Rows ~= 0 then
            if IsCursorOver(panel.X, panel.Y, 14, 14) then
                panel.Moving = true
            elseif IsCursorOver(panel.X, panel.Y + 17, 14, 14) then
                panel.X, panel.Y = DefaultPosition(panel.Divider)
            elseif #panel.Rows > VisibleRows and IsCursorOver(panel.X + 254, panel.Y + 26, 3, 100) then
                panel.Scrolling = true
            end
        end
    end
end)

addEventHandler('onClientResourceStop', resourceRoot, ClosePanel)

function tofloor( num )
     return tonumber( string.sub( tostring( num ), 0, -2 ) ) or 0
end
