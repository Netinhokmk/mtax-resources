local FLUSH_INTERVAL = 250
local FLUSH_SIZE = 20

local subscribers = { }
local buffer = { }
local bufferSize = 0
local flushTimer = nil


local function isObjectInAcl( player )
    if not isElement( player ) then
        return false
    end
    local acl = exports['acls']
    local acc = exports['accounts']
    local account = acc:getAccountName( acc:getPlayerAccount( player ) )
    if type( account ) ~= 'string' or account == '' then
        return false
    end
    return acl:isObjectInACLGroup( 'user.'..account, acl:aclGetGroup( 'Everyone' ) ) == true
end


local function getTargets( )
    local targets = { }
    for player in pairs( subscribers ) do
        if isElement( player ) then
            targets[ #targets + 1 ] = player
        else
            subscribers[ player ] = nil
        end
    end
    return targets
end


local function flush( )
    if isTimer( flushTimer ) then
        killTimer( flushTimer )
    end
    flushTimer = nil

    if bufferSize == 0 then
        return
    end

    local messages = buffer
    buffer = { }
    bufferSize = 0

    local targets = getTargets( )
    if #targets > 0 then
        Client.onDebugMessage( false, targets, messages )
    end
end


addEventHandler( 'onDebugMessage', root, function( message, level, file, line )
    if not next( subscribers ) then
        return
    end

    bufferSize = bufferSize + 1
    buffer[ bufferSize ] = { message, level, file, line }

    if bufferSize >= FLUSH_SIZE then
        flush( )
    elseif not isTimer( flushTimer ) then
        flushTimer = setTimer( flush, FLUSH_INTERVAL, 1 )
    end
end)


addEventHandler( 'onPlayerQuit', root, function( )
    subscribers[ source ] = nil
end)


Server.isObjectInAcl = function( )
    return isObjectInAcl( client )
end


Server.setDebugVisible = function( visible )
    if not isObjectInAcl( client ) then
        subscribers[ client ] = nil
        return false
    end
    subscribers[ client ] = visible and true or nil
    return true
end
