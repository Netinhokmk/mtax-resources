local subscribers = { }


local function isConsoleAdmin( player )
    if not isElement( player ) then
        return false
    end
    local acl = exports['acls']
    local acc = exports['accounts']
    local account = acc:getAccountName( acc:getPlayerAccount( player ) )
    if type( account ) ~= 'string' or account == '' then
        return false
    end
    return acl:isObjectInACLGroup( 'user.'..account, acl:aclGetGroup( 'Console' ) ) == true
end


addEventHandler( 'onDebugMessage', root, function( ... )
    local targets = { }
    for player in pairs( subscribers ) do
        if isElement( player ) then
            targets[ #targets + 1 ] = player
        else
            subscribers[ player ] = nil
        end
    end

    if #targets > 0 then
        Client.onDebugMessage( false, targets, ... )
    end
end)


Server.isObjectInAcl = function( )
    return isConsoleAdmin( client )
end


Server.setDebugVisible = function( visible )
    if not isConsoleAdmin( client ) then
        subscribers[ client ] = nil
        return false
    end
    subscribers[ client ] = visible and true or nil
    return true
end


addEventHandler( 'onPlayerQuit', root, function( )
    subscribers[ source ] = nil
end)
