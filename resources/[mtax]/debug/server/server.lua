--# onDebugMessage

addEventHandler( 'onDebugMessage', root, function( ... )
    Client.onDebugMessage( false, getElementsByType( 'player' ), ... )
end)


Server.isObjectInAcl = function( )
    local acl = exports['acls']
    local acc = exports['accounts']
    if acl:isObjectInACLGroup( 'user.'..acc:getAccountName( acc:getPlayerAccount( client ) ), acl:aclGetGroup( 'Everyone' ) ) then
        return true
    end
    return false
end
