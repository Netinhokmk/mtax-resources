_G.Accounts = {
    logged = { },
    guests = { },
    records = { },
}

local connection = dbConnect( 'sqlite', 'accounts.db' )

local LEGACY_PASSWORD_KEY = 'mtax-accounts-secret-key'
local MIGRATION_PARKED = '$argon2id$parked'

local NAME_MAX_LENGTH = Config.NameMaxLength
local PASSWORD_MAX_LENGTH = Config.PasswordMaxLength
local LOGIN_RATE = Config.LoginRate
local REGISTER_RATE = Config.RegisterRate
local ATTEMPT_TTL = Config.AttemptTTL
local ATTEMPT_SWEEP = Config.AttemptSweep
local MIGRATION_INTERVAL = Config.MigrationInterval

if connection then
    outputDebugString( '[admin] - Database ' .. getResourceName( getThisResource( ) ) .. ' connected successfully', 4, 142, 124, 195)
    dbExec( connection, 'CREATE TABLE IF NOT EXISTS accounts ( id INTEGER PRIMARY KEY, account TEXT, password TEXT, ip TEXT, serial TEXT, data TEXT )' )
else
    outputDebugString('[admin] - Database not found', 4, 244, 67, 54)
    stopResource( getThisResource( ) )
end


addEvent( 'onPlayerLogin', false )
addEvent( 'onPlayerLogout', false )


local function isPlayerElement( element )
    return isElement( element ) and getElementType( element ) == 'player'
end

local function notify( player, text, color )
    if not Config.Chat or not isPlayerElement( player ) or type( text ) ~= 'string' then
        return false
    end

    local chat = getResourceFromName( 'chat' )
    if not chat or getResourceState( chat ) ~= 'running' then
        return false
    end

    color = color or Config.Color.Info
    return exports['chat']:outputChatBox( text, player, color[1], color[2], color[3] ) == true
end

local function isReservedName( name )
    if type( name ) ~= 'string' then
        return false
    end

    local lowered = name:lower( )
    for _, reserved in ipairs( Config.ReservedNames ) do
        if lowered == reserved:lower( ) then
            return true
        end
    end

    return false
end


local Attempts = { }

local function attemptIdentity( player )
    local serial = getPlayerSerial( player )
    if type( serial ) == 'string' and serial ~= '' then
        return serial
    end

    local ip = getPlayerIP( player )
    if type( ip ) == 'string' and ip ~= '' then
        return ip
    end

    return false
end

local function allowAttempt( player, kind, rule )
    local identity = attemptIdentity( player )
    if not identity then
        return false
    end

    local now = getTickCount( )
    local bucket = Attempts[identity]

    if not bucket then
        bucket = { }
        Attempts[identity] = bucket
    end

    local state = bucket[kind]
    if not state then
        state = { since = now, hits = 0, last = 0, blockedUntil = 0 }
        bucket[kind] = state
    end

    if now < state.blockedUntil then
        return false
    end

    if now - state.last < rule.Interval then
        return false
    end

    if now - state.since > rule.Window then
        state.since = now
        state.hits = 0
    end

    state.hits = state.hits + 1
    state.last = now

    if state.hits > rule.Burst then
        state.blockedUntil = now + rule.Cooldown
        state.hits = 0
        state.since = now
        return false
    end

    return true
end

local function clearAttempts( player, kind )
    local identity = attemptIdentity( player )
    local bucket = identity and Attempts[identity]
    if bucket then
        bucket[kind] = nil
    end
end

setTimer( function( )
    local now = getTickCount( )
    for identity, bucket in pairs( Attempts ) do
        local alive = false
        for kind, state in pairs( bucket ) do
            if now < state.blockedUntil or now - state.last < ATTEMPT_TTL then
                alive = true
            else
                bucket[kind] = nil
            end
        end
        if not alive then
            Attempts[identity] = nil
        end
    end
end, ATTEMPT_SWEEP, 0 )


-- Event


Server.registerAccount = function( name, password )
    local player = client
    if not isPlayerElement( player ) then
        return false
    end

    if type( name ) ~= 'string' or name == '' or type( password ) ~= 'string' or password == '' then
        notify( player, Config.Text.UsageRegister )
        return false
    end

    if #name > NAME_MAX_LENGTH then
        notify( player, string.format( Config.Text.NameTooLong, NAME_MAX_LENGTH ), Config.Color.Bad )
        return false
    end

    if #password > PASSWORD_MAX_LENGTH then
        notify( player, string.format( Config.Text.PasswordTooLong, PASSWORD_MAX_LENGTH ), Config.Color.Bad )
        return false
    end

    if isReservedName( name ) then
        notify( player, Config.Text.NameReserved, Config.Color.Bad )
        return false
    end

    if not allowAttempt( player, 'register', REGISTER_RATE ) then
        notify( player, Config.Text.TooManyTries, Config.Color.Bad )
        return false
    end

    if getAccount( name ) then
        notify( player, Config.Text.NameTaken, Config.Color.Bad )
        return false
    end

    if not addAccount( name, password ) then
        notify( player, Config.Text.RegisterFailed, Config.Color.Bad )
        return false
    end

    notify( player, string.format( Config.Text.Registered, name ), Config.Color.Good )
    return true
end


Server.logIn = function( name, password )
    local player = client
    if not isPlayerElement( player ) then
        return false
    end

    if type( name ) ~= 'string' or name == '' or type( password ) ~= 'string' or password == '' then
        notify( player, Config.Text.UsageLogin )
        return false
    end

    if _G.Accounts.logged[player] then
        notify( player, Config.Text.AlreadyLoggedIn, Config.Color.Bad )
        return false
    end

    if not allowAttempt( player, 'login', LOGIN_RATE ) then
        notify( player, Config.Text.TooManyTries, Config.Color.Bad )
        return false
    end

    local account = getAccount( name )
    if not account then
        notify( player, Config.Text.LoginFailed, Config.Color.Bad )
        return false
    end

    if getAccountPlayer( account ) then
        notify( player, Config.Text.AccountInUse, Config.Color.Bad )
        return false
    end

    if not logIn( player, account, password ) then
        notify( player, Config.Text.LoginFailed, Config.Color.Bad )
        return false
    end

    clearAttempts( player, 'login' )
    notify( player, string.format( Config.Text.LoggedIn, getAccountName( account ) ), Config.Color.Good )
    return true
end


Server.logOut = function( )
    local player = client
    if not isPlayerElement( player ) then
        return false
    end

    if not logOut( player ) then
        notify( player, Config.Text.NotLoggedIn, Config.Color.Bad )
        return false
    end

    notify( player, Config.Text.LoggedOut )
    return true
end


-- Functions


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

local function adopt( row )
    if type( row ) ~= 'table' or type( row.id ) ~= 'number' then
        return false
    end

    local record = _G.Accounts.records[row.id]
    if not record then
        return row
    end

    for key, value in pairs( row ) do
        record[key] = value
    end
    return record
end

local function releaseRecord( id )
    for _, logged in pairs( _G.Accounts.logged ) do
        if logged.id == id then
            return
        end
    end
    _G.Accounts.records[id] = nil
end

local function findAccountByName( name, caseSensitive )
    if type( name ) ~= 'string' or name == '' then
        return false
    end

    local sql = caseSensitive
        and 'SELECT * FROM accounts WHERE account = ? LIMIT 1'
        or 'SELECT * FROM accounts WHERE LOWER( account ) = LOWER( ? ) LIMIT 1'

    local result = dbPoll( dbQuery( connection, sql, name ), -1 )
    return adopt( result and result[1] )
end

local function getGuestAccount( player )
    if not _G.Accounts.guests[player] then
        _G.Accounts.guests[player] = {
            guest = true,
            account = 'guest',
            player = player,
            data = { },
        }
    end
    return _G.Accounts.guests[player]
end

local function resolve( account )
    if not isAccountTable( account ) then
        return false
    end

    if account.guest then
        if isPlayerElement( account.player ) then
            return getGuestAccount( account.player )
        end
        return account
    end

    return _G.Accounts.records[account.id] or account
end

local function isValidDataValue( value )
    local valueType = type( value )
    return valueType == 'string' or valueType == 'number' or valueType == 'boolean' or valueType == 'nil'
end

local function hashPassword( password )
    local hashed = passwordHash( password )
    return type( hashed ) == 'string' and hashed or false
end

local function isHashedPassword( stored )
    return type( stored ) == 'string' and stored:sub( 1, 7 ) == '$argon2'
end

local function decodeLegacyPassword( stored )
    if type( stored ) ~= 'string' or stored == '' then
        return false
    end

    local encrypted = decodeString( 'base64', stored )
    if type( encrypted ) ~= 'string' then
        return false
    end

    local decrypted = decodeString( 'tea', encrypted, { key = LEGACY_PASSWORD_KEY } )
    if type( decrypted ) ~= 'string' then
        return false
    end

    return ( decrypted:gsub( '%z+$', '' ) )
end

local function verifyPassword( account, password )
    if type( password ) ~= 'string' or password == '' then
        return false
    end

    local stored = account.password

    if isHashedPassword( stored ) then
        return passwordVerify( password, stored ) == true
    end

    if decodeLegacyPassword( stored ) ~= password then
        return false
    end

    local upgraded = hashPassword( password )
    if upgraded then
        dbExec( connection, 'UPDATE accounts SET password = ? WHERE id = ?', upgraded, account.id )
        account.password = upgraded
    end

    return true
end

local migrationTimer

local function migrateLegacyPassword( )
    local pending = dbPoll( dbQuery( connection,
        'SELECT id, password FROM accounts WHERE password NOT LIKE ? LIMIT 1', '$argon2%' ), -1 )
    local row = pending and pending[1]

    if not row then
        if isTimer( migrationTimer ) then
            killTimer( migrationTimer )
        end
        migrationTimer = nil
        return
    end

    local plain = decodeLegacyPassword( row.password )
    local hashed = type( plain ) == 'string' and hashPassword( plain ) or false

    if not hashed then
        outputDebugString( 'Account ' .. tostring( row.id ) .. ' has an unreadable password, parked.', 2 )
        hashed = MIGRATION_PARKED
    end

    dbExec( connection, 'UPDATE accounts SET password = ? WHERE id = ?', hashed, row.id )

    local record = _G.Accounts.records[row.id]
    if record then
        record.password = hashed
    end
end

if connection then
    migrationTimer = setTimer( migrateLegacyPassword, MIGRATION_INTERVAL, 0 )
end


function addAccount( name, password, allowCaseVariations )
    if type( name ) ~= 'string' or name == '' or #name > NAME_MAX_LENGTH then return false end
    if type( password ) ~= 'string' or password == '' or #password > PASSWORD_MAX_LENGTH then return false end
    if isReservedName( name ) then return false end

    if findAccountByName( name, allowCaseVariations == true ) then
        return false
    end

    local hashed = hashPassword( password )
    if not hashed then
        return false
    end

    dbExec( connection, 'INSERT INTO accounts ( account, password, ip, serial, data ) VALUES ( ?, ?, ?, ?, ? )',
        name,
        hashed, '', '', encodeData( { } )
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
        if type( password ) ~= 'string' or not verifyPassword( account, password ) then
            return false
        end
    end

    return account
end

function getAccountByID( id )
    id = tonumber( id )
    if not id then return false end

    local result = dbPoll( dbQuery( connection, 'SELECT * FROM accounts WHERE id = ? LIMIT 1', id ), -1 )
    return adopt( result and result[1] )
end

function getAccountID( account )
    local record = resolve( account )
    if not record or record.guest then
        return false
    end
    return record.id
end

function getAccountName( account )
    local record = resolve( account )
    if not record then
        return false
    end
    return record.account
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
    local record = resolve( account )
    if not record or record.guest then
        return false
    end
    return record.ip
end

function getAccountSerial( account )
    local record = resolve( account )
    if not record or record.guest then
        return false
    end
    return record.serial
end

function getAccountPlayer( account )
    if not isAccountTable( account ) then
        return false
    end

    if account.guest then
        local player = account.player
        if isPlayerElement( player ) and not _G.Accounts.logged[player] then
            return player
        end
        return false
    end

    for player, logged in pairs( _G.Accounts.logged ) do
        if logged.id == account.id then
            if isPlayerElement( player ) then
                return player
            end
            _G.Accounts.logged[player] = nil
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
    local record = resolve( account )
    if not record or type( key ) ~= 'string' then
        return false
    end

    if record.guest then
        local value = record.data[key]
        return value ~= nil and value or false
    end

    local data = decodeData( record.data )
    return data[key] ~= nil and data[key] or false
end

function getAllAccountData( account )
    local record = resolve( account )
    if not record then
        return false
    end

    if record.guest then
        return record.data
    end

    return decodeData( record.data )
end

function setAccountData( account, key, value )
    local record = resolve( account )
    if not record or type( key ) ~= 'string' or not isValidDataValue( value ) then
        return false
    end

    if value == false then
        value = nil
    end

    if record.guest then
        record.data[key] = value
        return true
    end

    local data = decodeData( record.data )
    data[key] = value
    record.data = encodeData( data )
    dbExec( connection, 'UPDATE accounts SET data = ? WHERE id = ?', record.data, record.id )

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

    local record = getAccountByID( account.id )
    if not record then
        return false
    end

    if getAccountPlayer( record ) then
        return false
    end

    if not verifyPassword( record, password ) then
        return false
    end

    record.ip = ( type( getPlayerIP ) == 'function' and getPlayerIP( player ) ) or ''
    record.serial = ( type( getPlayerSerial ) == 'function' and getPlayerSerial( player ) ) or ''
    dbExec( connection, 'UPDATE accounts SET ip = ?, serial = ? WHERE id = ?', record.ip, record.serial, record.id )
    setElementData( player, 'logged', true )
    _G.Accounts.records[record.id] = record
    _G.Accounts.logged[player] = record
    setTimer( function( player, record )
        if not isPlayerElement( player ) or _G.Accounts.logged[player] ~= record then
            return
        end
        triggerEvent( 'onPlayerLogin', player, player, record.account )
    end, 2000, 1, player, record )
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
    setElementData( player, 'logged', false )
    releaseRecord( account.id )

    triggerEvent( 'onPlayerLogout', player, account, getPlayerAccount( player ) )

    return true
end

function removeAccount( account )
    local record = resolve( account )
    if not record or record.guest then
        return false
    end

    local player = getAccountPlayer( record )
    if player then
        logOut( player )
    end

    dbExec( connection, 'DELETE FROM accounts WHERE id = ?', record.id )
    _G.Accounts.records[record.id] = nil
    return true
end

function setAccountName( account, name, allowCaseVariations )
    local record = resolve( account )
    if not record or record.guest then return false end
    if type( name ) ~= 'string' or name == '' or #name > NAME_MAX_LENGTH then return false end
    if isReservedName( name ) then return false end

    local existing = findAccountByName( name, allowCaseVariations == true )
    if existing and existing.id ~= record.id then
        return false
    end

    dbExec( connection, 'UPDATE accounts SET account = ? WHERE id = ?', name, record.id )
    record.account = name
    return true
end

function setAccountPassword( account, password )
    local record = resolve( account )
    if not record or record.guest then return false end
    if type( password ) ~= 'string' or password == '' or #password > PASSWORD_MAX_LENGTH then return false end

    local hashed = hashPassword( password )
    if not hashed then
        return false
    end

    dbExec( connection, 'UPDATE accounts SET password = ? WHERE id = ?', hashed, record.id )
    record.password = hashed
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


addEventHandler( 'onPlayerJoin', root, function( )
    local player = source

    setTimer( function( player )
        if not isPlayerElement( player ) or _G.Accounts.logged[player] then
            return
        end

        notify( player, Config.Text.WelcomeRegister )
        notify( player, Config.Text.WelcomeLogin )
    end, Config.WelcomeDelay, 1, player )
end )


addEventHandler( 'onPlayerQuit', root, function( )
    local player = source

    setTimer( function( player )
        local account = _G.Accounts.logged[player]
        logOut( player )
        _G.Accounts.logged[player] = nil
        _G.Accounts.guests[player] = nil
        if account then
            releaseRecord( account.id )
        end
    end, 300, 1, player )
end )


Server.account = function( )
    local playerAcc = getPlayerAccount( client )
    local account = getAccountName( playerAcc )
    return account
end
