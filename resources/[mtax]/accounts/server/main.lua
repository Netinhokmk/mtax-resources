_G.Accounts = {
    logged = { },
    guests = { },
}

local connection = dbConnect( 'sqlite', 'accounts.db' )
local PASSWORD_KEY = 'mtax-accounts-secret-key'

if connection then
    outputDebugString( '[admin] - Database ' .. getResourceName( getThisResource( ) ) .. ' connected successfully', 4, 142, 124, 195)
    dbExec( connection, 'CREATE TABLE IF NOT EXISTS accounts ( id INTEGER PRIMARY KEY, account TEXT, password TEXT, ip TEXT, serial TEXT, data TEXT )' )
else
    outputDebugString('[admin] - Database not found', 4, 244, 67, 54)
    stopResource( getThisResource( ) )
end


addEvent( 'onPlayerLogin', false )
addEvent( 'onPlayerLogout', false )


-- Event


Server.registerAccount = function( name, password )
    local check = getAccount( name, password )
    if check then
        return
    end
    addAccount( name, password )
end


Server.logIn = function( name, password )
    local check = getAccount( name, password )
    if not check then
        return
    end
    logIn( client, check, password )
end


Server.logOut = function( )
    logOut( client )
end


-- Functions


local function isPlayerElement( element )
    return isElement( element ) and getElementType( element ) == 'player'
end

local function isAccountTable( account )
    return type( account ) == 'table' and ( account.guest == true or type( account.id ) == 'number' )
end

local function encodeData( data )
    return toJSON( data or { } )
end

local function decodeData( str )
    if type( str ) ~= 'string' or str == '' then
        return { }
    end
    return fromJSON( str ) or { }
end

local function findAccountByName( name, caseSensitive )
    if type( name ) ~= 'string' or name == '' then
        return false
    end

    local sql = caseSensitive
        and 'SELECT * FROM accounts WHERE account = ? LIMIT 1'
        or 'SELECT * FROM accounts WHERE LOWER( account ) = LOWER( ? ) LIMIT 1'

    local result = dbPoll( dbQuery( connection, sql, name ), -1 )
    return result and result[1] or false
end

local function getGuestAccount( player )
    if not _G.Accounts.guests[player] then
        _G.Accounts.guests[player] = {
            guest = true,
            account = 'guest',
            data = { },
        }
    end
    return _G.Accounts.guests[player]
end

local function isValidDataValue( value )
    local valueType = type( value )
    return valueType == 'string' or valueType == 'number' or valueType == 'boolean' or valueType == 'nil'
end

local function encodePassword( password )
    local encrypted = encodeString( 'tea', password, { key = PASSWORD_KEY } )
    return encodeString( 'base64', encrypted )
end

local function decodePassword( stored )
    local encrypted = decodeString( 'base64', stored )
    local decrypted = decodeString( 'tea', encrypted, { key = PASSWORD_KEY } )
    return decrypted and ( decrypted:gsub( '%z+$', '' ) ) or decrypted
end


function addAccount( name, password, allowCaseVariations )
    if type( name ) ~= 'string' or name == '' then return false end
    if type( password ) ~= 'string' or password == '' then return false end

    if findAccountByName( name, allowCaseVariations == true ) then
        return false
    end

    dbExec( connection, 'INSERT INTO accounts ( account, password, ip, serial, data ) VALUES ( ?, ?, ?, ?, ? )',
        name,
        encodePassword( password ), '', '', encodeData( { } )
    )
    outputDebugString( 'Account registered successfully.', 3 )
    return true
end


function getAccount( name, password )
    local account = findAccountByName( name, false )
    if not account then
        return false
    end

    if password ~= nil then
        if type( password ) ~= 'string' or decodePassword( account.password ) ~= password then
            return false
        end
    end

    return account
end

function getAccountByID( id )
    id = tonumber( id )
    if not id then return false end

    local result = dbPoll( dbQuery( connection, 'SELECT * FROM accounts WHERE id = ? LIMIT 1', id ), -1 )
    return result and result[1] or false
end

function getAccountID( account )
    if not isAccountTable( account ) or account.guest then
        return false
    end
    return account.id
end

function getAccountName( account )
    if not isAccountTable( account ) then
        return false
    end
    return account.account
end

function getPlayerSerial ( player )
    if not isPlayerElement( player ) then
        return false
    end
    local infos = getPlayerIdentifiers( player )
    for _, id in ipairs( infos ) do
        local mtax = id:match( "^mtax:(.+)$" )
        if mtax then
            return mtax
        end
    end
    return false
end

function getAccountIP( account )
    if not isAccountTable( account ) or account.guest then
        return false
    end
    return account.ip
end

function getAccountSerial( account )
    if not isAccountTable( account ) or account.guest then
        return false
    end
    return account.serial
end

function getAccountPlayer( account )
    if not isAccountTable( account ) then
        return false
    end

    if account.guest then
        for player, guest in pairs( _G.Accounts.guests ) do
            if guest == account and not _G.Accounts.logged[player] then
                return player
            end
        end
        return false
    end

    for player, logged in pairs( _G.Accounts.logged ) do
        if logged == account then
            return player
        end
    end
    return false
end

function getAccounts( )
    return dbPoll( dbQuery( connection, 'SELECT * FROM accounts' ), -1 )
end

function getAccountsByData( dataName, value )
    if type( dataName ) ~= 'string' then return false end

    local results = { }
    for _, account in pairs( getAccounts( ) ) do
        local data = decodeData( account.data )
        if data[dataName] == value then
            table.insert( results, account )
        end
    end
    return results
end

function getAccountsByIP( ip )
    if type( ip ) ~= 'string' or ip == '' then return false end
    return dbPoll( dbQuery( connection, 'SELECT * FROM accounts WHERE ip = ?', ip ), -1 )
end

function getAccountsBySerial( serial )
    if type( serial ) ~= 'string' or serial == '' then return false end
    return dbPoll( dbQuery( connection, 'SELECT * FROM accounts WHERE serial = ?', serial ), -1 )
end

function getAccountData( account, key )
    if not isAccountTable( account ) or type( key ) ~= 'string' then
        return false
    end

    if account.guest then
        local value = account.data[key]
        return value ~= nil and value or false
    end

    local data = decodeData( account.data )
    return data[key] ~= nil and data[key] or false
end

function getAllAccountData( account )
    if not isAccountTable( account ) then
        return false
    end

    if account.guest then
        return account.data
    end

    return decodeData( account.data )
end

function setAccountData( account, key, value )
    if not isAccountTable( account ) or type( key ) ~= 'string' or not isValidDataValue( value ) then
        return false
    end

    if value == false then
        value = nil
    end

    if account.guest then
        account.data[key] = value
        return true
    end

    local data = decodeData( account.data )
    data[key] = value
    account.data = encodeData( data )
    dbExec( connection, 'UPDATE accounts SET data = ? WHERE id = ?', account.data, account.id )

    return true
end

function copyAccountData( theAccount, fromAccount )
    if not isAccountTable( theAccount ) or not isAccountTable( fromAccount ) then
        return false
    end

    local fromData = getAllAccountData( fromAccount )

    for key, value in pairs( fromData ) do
        setAccountData( theAccount, key, value )
    end

    return true
end

function getPlayerAccount( player )
    if not isPlayerElement( player ) then
        return false
    end

    return _G.Accounts.logged[player] or getGuestAccount( player )
end

function isGuestAccount( account )
    if not isAccountTable( account ) then
        return false
    end
    return account.guest == true
end

function logIn( player, account, password )
    if not isPlayerElement( player ) then return false end
    if not isAccountTable( account ) or account.guest then return false end
    if type( password ) ~= 'string' then return false end

    if _G.Accounts.logged[player] then
        return false
    end

    if getAccountPlayer( account ) then
        return false
    end

    if decodePassword( account.password ) ~= password then
        return false
    end

    local previousAccount = getPlayerAccount( player )

    account.ip = ( type( getPlayerIP ) == 'function' and getPlayerIP( player ) ) or ''
    account.serial = ( type( getPlayerSerial ) == 'function' and getPlayerSerial( player ) ) or ''
    dbExec( connection, 'UPDATE accounts SET ip = ?, serial = ? WHERE id = ?', account.ip, account.serial, account.id )
    setElementData( player, 'logged', true )
    _G.Accounts.logged[player] = account
    setTimer( function( player, account )
        triggerEvent( 'onPlayerLogin', player, player, account.account )
    end, 2000, 1, player, account )
    outputDebugString( 'Account logged in successfully.', 3 )
    return true
end

function logOut( player )
    if not isPlayerElement( player ) then return false end

    local account = _G.Accounts.logged[player]
    if not account then
        return false
    end

    _G.Accounts.logged[player] = nil

    triggerEvent( 'onPlayerLogout', player, account, getPlayerAccount( player ) )

    return true
end

function removeAccount( account )
    if not isAccountTable( account ) or account.guest then
        return false
    end

    local player = getAccountPlayer( account )
    if player then
        logOut( player )
    end

    dbExec( connection, 'DELETE FROM accounts WHERE id = ?', account.id )
    return true
end

function setAccountName( account, name, allowCaseVariations )
    if not isAccountTable( account ) or account.guest then return false end
    if type( name ) ~= 'string' or name == '' then return false end

    local existing = findAccountByName( name, allowCaseVariations == true )
    if existing and existing.id ~= account.id then
        return false
    end

    dbExec( connection, 'UPDATE accounts SET account = ? WHERE id = ?', name, account.id )
    account.account = name
    return true
end

function setAccountPassword( account, password )
    if not isAccountTable( account ) or account.guest then return false end
    if type( password ) ~= 'string' or password == '' then return false end

    local encoded = encodePassword( password )
    dbExec( connection, 'UPDATE accounts SET password = ? WHERE id = ?', encoded, account.id )
    account.password = encoded
    return true
end


function givePlayerMoney( player, amount )
    if not isPlayerElement( player ) then return false end
    if type( amount ) ~= 'number' or amount <= 0 then return false end

    local account = getPlayerAccount( player )
    if not account or account.guest then return false end

    local currentMoney = getAccountData( account, 'money' ) or 0
    setAccountData( account, 'money', currentMoney + amount )

    return true
end


function setPlayerMoney ( player, amount )
    if not isPlayerElement( player ) then return false end
    if type( amount ) ~= 'number' or amount < 0 then return false end

    local account = getPlayerAccount( player )
    if not account or account.guest then return false end

    setAccountData( account, 'money', amount )

    return true
end


function takePlayerMoney( player, amount )
    if not isPlayerElement( player ) then return false end
    if type( amount ) ~= 'number' or amount <= 0 then return false end

    local account = getPlayerAccount( player )
    if not account or account.guest then return false end

    local currentMoney = getAccountData( account, 'money' ) or 0
    if currentMoney < amount then
        return false
    end

    setAccountData( account, 'money', currentMoney - amount )

    return true
end


function getPlayerMoney( player )
    if not isPlayerElement( player ) then return false end

    local account = getPlayerAccount( player )
    if not account or account.guest then return false end

    return getAccountData( account, 'money' ) or 0
end


Server.getPlayerMoney = function( )
    return getPlayerMoney( client )
end


addEventHandler( 'onPlayerQuit', root, function( )
    setTimer( function( source )
        logOut( source )
        Accounts.guests[source] = nil
    end, 300, 1, source )
end )


Server.account = function( )
    local playerAcc = getPlayerAccount( client )
    local account = getAccountName( playerAcc )
    return account
end