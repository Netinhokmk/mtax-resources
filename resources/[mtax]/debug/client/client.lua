local visible = false
local debug = { }
local debugLevel = {
    [ 1 ] = 'erro',
    [ 2 ] = 'debug',
    [ 3 ] = 'success',
}

Toggle = function( )
    visible = not visible
    sendNuiMessage({ action = 'toggle', data = visible })
    Server.setDebugVisible( false, visible )
end


addCommandHandler( 'debug', function( )
    Server.isObjectInAcl( function( check )
        if check then
            Toggle( )
        end
    end)
end)

addEventHandler( 'onClientDebugMessage', root, function( message, level, file, line )
    if visible then
        table.insert( debug, { level = debugLevel[ level ], text = message, side = 'client' } )
    end
end)



Client.onDebugMessage = function( message, level, file, line )
    if visible then
        table.insert( debug, { level = debugLevel[ level ], text = message, side = 'server' } )
    end
end


setTimer( function( )
    if visible then
        for i, v in ipairs( debug or { } ) do
            sendNuiMessage({ action = 'addLog', data = v })
        end
        debug = { }
    end
end, 3000, 0 )


local canToggleNuiFocus = true
local NUI_TOGGLE_COOLDOWN = 250

local function lockToggleForCooldown( )
    canToggleNuiFocus = false
    setTimer( function( ) canToggleNuiFocus = true end, NUI_TOGGLE_COOLDOWN, 1 )
end

registerNuiCallback('closeNui', function(data, cb)
    if canToggleNuiFocus and isNuiFocused( ) and visible then
        lockToggleForCooldown( )
        setNuiFocus( false, false )
    end
    cb({ ok = true })
end )


bindKey( 'x', 'down', function( )
    if visible then
        if canToggleNuiFocus and not isNuiFocused( ) then
            lockToggleForCooldown( )
            setNuiFocus( true, true )
            sendNuiMessage({ action = 'toggle', data = true })
        end
    else
        showCursor( not isCursorShowing( ) )
    end
end)