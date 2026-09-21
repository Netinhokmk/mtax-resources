local Settings = config['gerais']
local ResourceName = getResourceName(getThisResource())
local Timers = { }
local Visible = { }

function RemoveResource(rows)
    for i = #rows, 1, -1 do
        if rows[i][1] == ResourceName then
            table.remove(rows, i)
        end
    end
end

function HasPermission(player)
    local acls = getResourceFromName('acls')
    local accounts = getResourceFromName('accounts')

    if not acls or not accounts or getResourceState(acls) ~= 'running' or getResourceState(accounts) ~= 'running' then
        return true
    end

    local ok, account = pcall(function() return exports['accounts']:getPlayerAccount(player) end)
    if not ok or not account then
        return false
    end

    local nameOk, accountName = pcall(function() return exports['accounts']:getAccountName(account) end)
    if not nameOk or type(accountName) ~= 'string' or accountName == '' then
        return false
    end

    for _, groupName in ipairs(Settings['show:panel']['permission']) do
        local groupOk, group = pcall(function() return exports['acls']:aclGetGroup(groupName) end)

        if groupOk and group then
            local memberOk, isMember = pcall(function() return exports['acls']:isObjectInACLGroup('user.'..accountName, group) end)

            if memberOk and isMember then
                return true
            end
        end
    end

    return false
end

function StopUpdate(player)
    if isTimer(Timers[player]) then
        killTimer(Timers[player])
    end

    Timers[player] = nil
    Visible[player] = nil
end

function UpdateData(player)
    if not isElement(player) then
        return
    end

    local _, rows = getPerformanceStats('Lua timing')
    RemoveResource(rows)

    table.sort(rows, function(a, b)
        return tofloor(a[2]) > tofloor(b[2])
    end)

    triggerClientEvent(player, 'mtax:cpumonitor:server', resourceRoot, rows)
end

addCommandHandler(Settings['show:panel']['command'], function(player)
    if not HasPermission(player) then
        return outputChatBox('Você não possui acesso a este comando.', player, 255, 214, 102)
    end

    if Visible[player] then
        StopUpdate(player)
        triggerClientEvent(player, 'mtax:cpumonitor:toggle', resourceRoot, false)
        return
    end

    Visible[player] = true
    UpdateData(player)
    Timers[player] = setTimer(UpdateData, 1000, 0, player)
    triggerClientEvent(player, 'mtax:cpumonitor:toggle', resourceRoot, true)
end)

addEventHandler('onPlayerQuit', root, function()
    StopUpdate(source)
end)

function tofloor( num )
     return tonumber( string.sub( tostring( num ), 0, -2 ) ) or 0
end
