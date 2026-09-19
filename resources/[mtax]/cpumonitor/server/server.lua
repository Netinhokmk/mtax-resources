
local watchers = { }


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


Server.checkACL = function( )
    return isConsoleAdmin( client )
end


Server.setStatsVisible = function( visible )
    if isTimer( watchers[ client ] ) then
        killTimer( watchers[ client ] )
    end
    watchers[ client ] = nil

    if visible then
        if not isConsoleAdmin( client ) then
            return false
        end
        watchers[ client ] = setTimer( function( player )
            if not isElement( player ) then
                return
            end
            local _, rows_server = getPerformanceStats( 'Lua timing' )
            Client.stats( false, player, rows_server )
        end, 1000, 0, client )
    end
    return true
end


addEventHandler( 'onPlayerQuit', root, function( )
    if isTimer( watchers[ source ] ) then
        killTimer( watchers[ source ] )
    end
    watchers[ source ] = nil
end)