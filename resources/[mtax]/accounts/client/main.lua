


addCommandHandler( 'register', function( cmd, account, password )
    if not ( account and password ) then
        return
    end
    Server.registerAccount( false, account, password )
end)


addCommandHandler( 'login', function( cmd, account, password )
    if not ( account and password ) then
        return
    end
    Server.logIn( false, account, password )
end)


addCommandHandler( 'logout', function()
    Server.logOut( false )
end)


addCommandHandler( 'myaccount', function(  )
    Server.account( function( account )
        iprint( account )
    end)
end)


local cachedMoney = 0

getPlayerMoney = function( element )
    if element ~= nil and element ~= localPlayer then
        return false
    end
    Server.getPlayerMoney( function( money )
        cachedMoney = tonumber( money ) or 0
    end )
    return cachedMoney
end