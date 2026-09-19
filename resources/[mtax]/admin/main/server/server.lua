
local connection = dbConnect( 'sqlite', 'binds.db' )

if connection then
    outputDebugString( '[admin] - Banco de dados ' .. getResourceName( getThisResource( ) ) .. ' conectado com sucesso', 4, 142, 124, 195)
    dbExec( connection, 'CREATE TABLE IF NOT EXISTS bindName ( account TEXT, bind TEXT, cmd TEXT )' )
else
    outputDebugString('[admin] - Banco de dados não encontrado', 4, 244, 67, 54)
    stopResource( getThisResource( ) )
end


Server.saveBind = function( bind, cmd )
    local acc = exports['accounts']
    local account = acc:getAccountName( acc:getPlayerAccount( client ) )
    if not account then
        return false
    end
    local result = dbPoll( dbQuery( connection, 'SELECT * FROM bindName WHERE account = ? AND bind = ?', account, bind ), -1 )
    if result and #result <= 0 then
        dbExec( connection, 'INSERT INTO bindName ( account, bind, cmd ) VALUES ( ?, ?, ? )', account, bind, cmd )
    end
    return bind, cmd
end


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


Server.fly = function( )
    return isConsoleAdmin( client )
end


Server.alpha = function( alpha )
    if not isConsoleAdmin( client ) then
        return false
    end

    alpha = tonumber( alpha )
    if not alpha then
        return false
    end
    alpha = math.max( 0, math.min( 255, math.floor( alpha ) ) )

    local hidden = alpha <= 0
    setElementAlpha( client, alpha )
    setElementCollisionsEnabled( client, not hidden )
    setElementFrozen( client, hidden )
    setPlayerAnticheatEnabled( client, not hidden, 'movement' )
    return true
end


addEvent( 'onPlayerLogin', false )
addEventHandler( 'onPlayerLogin', root, function( player, account )
    local result = dbPoll( dbQuery( connection, 'SELECT * FROM bindName WHERE account = ?', account ), -1 )
    if result and #result > 0 then
        for _, v in ipairs( result or { } ) do
            Client.executeBind( false, player, v.bind, v.cmd )
        end
    end
end)


addEventHandler( 'onResourceStart', resourceRoot, function( )
    setTimer( function( )
        for i, v in ipairs( getElementsByType( 'player' ) ) do
            local account = exports['accounts']:getAccountName( exports['accounts']:getPlayerAccount( v ) )
            local result = dbPoll( dbQuery( connection, 'SELECT * FROM bindName WHERE account = ?', account ), -1 )
            if result and #result > 0 then
                for _, w in ipairs( result or { } ) do
                    Client.executeBind( false, v, w.bind, w.cmd )
                end
            end
        end
    end, 800, 1 )
end)