local TYPE = _MTA_RADAR.TYPE

local channel = _MTA_RADAR.channel
local size = _MTA_RADAR.size
local state = _MTA_RADAR.state

local FLASH_CYCLE = 1000

local function flashFactor()
    local phase = (getTickCount() % FLASH_CYCLE) / FLASH_CYCLE
    if phase >= 0.5 then
        return (phase - 0.5) * 2
    end
    return 1 - phase * 2
end

local function draw()
    local factor = nil
    local dimension = getElementDimension(localPlayer)

    for _, theArea in ipairs(getElementsByType(TYPE) or {}) do
        local values = state(theArea)
        if values and getElementDimension(theArea) == dimension then
            local x, y = getElementPosition(theArea)
            if x then
                local alpha = channel(values.a, _MTA_RADAR.DEFAULT_ALPHA)
                if values.flashing == true then
                    factor = factor or flashFactor()
                    alpha = math.floor(alpha * factor)
                end

                if alpha > 0 then
                    dxDrawRadarArea(x, y, size(values.sizeX, 0), size(values.sizeY, 0),
                        tocolor(channel(values.r, _MTA_RADAR.DEFAULT_RED),
                            channel(values.g, _MTA_RADAR.DEFAULT_GREEN),
                            channel(values.b, _MTA_RADAR.DEFAULT_BLUE), alpha))
                end
            end
        end
    end
end

addEventHandler("onClientRender", root, draw)
