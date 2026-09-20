local TYPE_DISPLAY = _MTA_TEXT.TYPE_DISPLAY
local KEY_ITEMS = _MTA_TEXT.KEY_ITEMS
local KEY_OBSERVERS = _MTA_TEXT.KEY_OBSERVERS

local list = _MTA_TEXT.list
local indexOf = _MTA_TEXT.indexOf
local state = _MTA_TEXT.state
local isDrawablePriority = _MTA_TEXT.isDrawablePriority

local function draw()
    local width, height = getScreenSize()
    if not width then
        return
    end

    local drawn = {}
    for _, theDisplay in ipairs(getElementsByType(TYPE_DISPLAY) or {}) do
        if indexOf(list(theDisplay, KEY_OBSERVERS), localPlayer) then
            for _, theTextItem in ipairs(list(theDisplay, KEY_ITEMS)) do
                if not drawn[theTextItem] then
                    drawn[theTextItem] = true

                    local item = state(theTextItem)
                    if item and isDrawablePriority(item.priority) then
                        local x = item.x * width
                        local y = item.y * height
                        local scale = item.scale

                        if item.shadow > 0 then
                            local offset = math.max(1, math.floor(scale))
                            dxDrawText(item.text, x + offset, y + offset, x + offset, y + offset,
                                tocolor(0, 0, 0, item.a * item.shadow / 255), scale, "default",
                                item.alignX, item.alignY, false, false, false)
                        end

                        dxDrawText(item.text, x, y, x, y, tocolor(item.r, item.g, item.b, item.a),
                            scale, "default", item.alignX, item.alignY, false, false, false)
                    end
                end
            end
        end
    end
end

addEventHandler("onClientRender", root, draw)
