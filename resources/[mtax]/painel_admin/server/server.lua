local NUI_ACTIONS = {
	'getPlayers',
	'moderatePlayer', 'spectatePlayer', 'slapPlayer', 'shoutPlayer',
	'setPlayerStat', 'resetPlayerStats',
	'givePlayerWeapon', 'givePlayerVehicle', 'givePlayerJetpack',
	'warpToPlayer', 'warpPlayerToMe',
	'vehicleMaintenance', 'setVehicleDimension', 'teleportPlayerToInterior',
	'getVehicleCustomization', 'vehicleCustomizeAction',

	'getResources', 'resourceLifecycle', 'refreshResources', 'executeCommand', 'getActionLog',

	'getServerSettings', 'setServerPassword',
	'setWeather', 'setTime', 'setGravity', 'setGameSpeed', 'setWaveHeight', 'setFpsLimit',
	'sendWelcomeMessage', 'shutdownServer', 'clearChat',

	'getBans', 'searchBans', 'banRowAction', 'banByField', 'refreshBans',

	'getAclGroups', 'aclGroupAction',
};

local DB = nil
local PlayerRegistry = {}
local PlayerRegistryById = {}
local PanelOpen = {}
local ShoutTarget = {}
local nextPlayerId = 0
local CurrentWeather = nil
local ActionLog = {}

local Handlers = {}

local BuildPlayerRecord, BuildPlayerList, BuildResourceList, findResource, resourceIsRunning
local QueryBans, QueryAclGroups, QueryServerSettings
local BroadcastPlayers, BroadcastResources, BroadcastBans, BroadcastAclGroups, BroadcastServerSettings, BroadcastActionLog
local getPlayerSerial, getPlayerAccountName, getPlayerGroups, getPlayerAcDetected, PushActionLog

local function isAdmin(player)
	if not player or not isElement(player) or getElementType(player) ~= 'player' then
		return false
	end

	local accOk, account = pcall(function() return exports['accounts']:getPlayerAccount(player) end)
	if not accOk or not account then return false end

	local guestOk, isGuest = pcall(function() return exports['accounts']:isGuestAccount(account) end)
	if not guestOk or isGuest then return false end

	local nameOk, accountName = pcall(function() return exports['accounts']:getAccountName(account) end)
	if not nameOk or type(accountName) ~= 'string' or accountName == '' then return false end

	local objectName = 'user.' .. accountName
	local acls = exports['acls']

	for _, groupName in ipairs(Config.AdminGroups) do
		local groupOk, group = pcall(function() return acls:aclGetGroup(groupName) end)
		if groupOk and group then
			local memberOk, isMember = pcall(function() return acls:isObjectInACLGroup(objectName, group) end)
			if memberOk and isMember then
				return true
			end
		end
	end

	return false
end


local function registerPlayer(player)
	nextPlayerId = nextPlayerId + 1
	PlayerRegistry[player] = nextPlayerId
	PlayerRegistryById[nextPlayerId] = player
end

local function unregisterPlayer(player)
	local id = PlayerRegistry[player]
	if id then
		PlayerRegistryById[id] = nil
		PlayerRegistry[player] = nil
	end
	PanelOpen[player] = nil
	ShoutTarget[player] = nil
end

getPlayerSerial = function(player)
	if not player or not isElement(player) or getElementType(player) ~= 'player' then
		return 'N/A'
	end

	local ok, serial = pcall(function() return exports['accounts']:getPlayerSerial(player) end)
	if ok and type(serial) == 'string' and serial ~= '' then
		return serial
	end
	return 'N/A'
end

getPlayerAccountName = function(player)
	if not player or not isElement(player) or getElementType(player) ~= 'player' then
		return 'Guest'
	end

	local accOk, account = pcall(function() return exports['accounts']:getPlayerAccount(player) end)
	if not accOk or not account then return 'Guest' end

	local guestOk, isGuest = pcall(function() return exports['accounts']:isGuestAccount(account) end)
	if not guestOk or isGuest then return 'Guest' end

	local nameOk, accountName = pcall(function() return exports['accounts']:getAccountName(account) end)
	if not nameOk or type(accountName) ~= 'string' or accountName == '' then return 'Guest' end

	return accountName
end

getPlayerGroups = function(player)
	local accountName = getPlayerAccountName(player)
	if accountName == 'Guest' then return {} end

	local ok, groups = pcall(function() return exports['acls']:aclObjectGetGroups('user.' .. accountName) end)
	if not ok or type(groups) ~= 'table' then return {} end

	local names = {}
	for _, group in ipairs(groups) do
		if type(group) == 'table' and type(group.name) == 'string' then
			names[#names + 1] = group.name
		end
	end
	table.sort(names)
	return names
end

getPlayerAcDetected = function(player)
	local ok, violations = pcall(getPlayerAnticheatViolations, player)
	if not ok or type(violations) ~= 'table' then return 'None' end

	local active = {}
	for _, v in ipairs(violations) do
		if type(v) == 'table' and type(v.name) == 'string' and (tonumber(v.count) or 0) > 0 then
			active[#active + 1] = v
		end
	end
	if #active == 0 then return 'None' end

	table.sort(active, function(a, b) return (tonumber(a.count) or 0) > (tonumber(b.count) or 0) end)

	local names = {}
	for i = 1, math.min(3, #active) do
		names[#names + 1] = active[i].name
	end
	return table.concat(names, ', ')
end

BuildPlayerRecord = function(player)
	local x, y, z = getElementPosition(player)
	local weaponId = getPedWeapon and getPedWeapon(player) or 0
	local weaponName = 'None'
	if weaponId and weaponId > 0 and getWeaponNameFromID then
		weaponName = getWeaponNameFromID(weaponId) or 'None'
	end
	local vehicle = getPedOccupiedVehicle(player)
	local vehicleName = 'None'
	local vehicleHealthPct = 0
	if vehicle then
		vehicleName = (getVehicleName and getVehicleName(vehicle)) or 'Vehicle'
		vehicleHealthPct = math.floor((getElementHealth(vehicle) or 0) / 10)
	end

	local moneyOk, money = pcall(function() return exports['accounts']:getPlayerMoney(player) end)
	local moneyValue = (moneyOk and type(money) == 'number') and money or 0

	return {
		id = PlayerRegistry[player],
		name = getPlayerName(player),
		accountName = getPlayerAccountName(player),
		groups = getPlayerGroups(player),
		acDetected = getPlayerAcDetected(player),
		ip = getPlayerIP(player) or 'N/A',
		serial = getPlayerSerial(player),
		version = (getPlayerVersion and getPlayerVersion(player)) or 'N/A',
		frozen = isElementFrozen(player) and true or false,
		muted = isPlayerMuted(player) and true or false,
		jetpack = (isPedWearingJetpack and isPedWearingJetpack(player)) and true or false,
		health = math.floor(getElementHealth(player) or 0),
		armour = math.floor((getPedArmor and getPedArmor(player)) or 0),
		skin = tostring(getElementModel(player) or 0),
		weapon = weaponName,
		money = moneyValue,
		ping = getPlayerPing(player) or 0,
		area = 'Unknown',
		pos = string.format('%.1f, %.1f, %.1f', x or 0, y or 0, z or 0),
		dimension = getElementDimension(player) or 0,
		interior = getElementInterior(player) or 0,
		vehicle = vehicleName,
		vehicleHealth = vehicleHealthPct,
	}
end

BuildPlayerList = function()
	local list = {}
	for player, _ in pairs(PlayerRegistry) do
		list[#list + 1] = BuildPlayerRecord(player)
	end
	return list
end

findResource = function(name)
	if getResourceFromName then
		local ok, res = pcall(getResourceFromName, name)
		if ok and res then return res end
	end
	for _, res in ipairs(getResources()) do
		if type(res) == 'string' then
			if res == name then return res end
		elseif getResourceName and getResourceName(res) == name then
			return res
		end
	end
	return nil
end

resourceIsRunning = function(resourceElement)
	if not resourceElement then return false end
	local ok, result = pcall(getResourceLastStartTime, resourceElement)
	return ok and result and result ~= 'never' and result ~= false
end

BuildResourceList = function()
	local list = {}
	for i, res in ipairs(getResources()) do
		local resourceElement = type(res) == 'string' and findResource(res) or res
		local name = type(res) == 'string' and res or ((getResourceName and getResourceName(res)) or tostring(res))

		list[#list + 1] = {
			id = i - 1,
			name = name,
			state = resourceIsRunning(resourceElement) and 'running' or 'loaded',
			author = (resourceElement and getResourceInfo and getResourceInfo(resourceElement, 'author')) or 'Unknown',
			version = (resourceElement and getResourceInfo and getResourceInfo(resourceElement, 'version')) or '1.0.0',
			fullName = (resourceElement and getResourceInfo and getResourceInfo(resourceElement, 'description')) or name,
		}
	end
	return list
end

local function bans()
	return getResourceFromName('bans') and exports['bans'] or nil
end

local function banDate(record)
	local ok, t = pcall(getRealTime, record.banTime)
	if ok and type(t) == 'table' then
		return string.format('%04d-%02d-%02d', (t.year or 0) + 1900, (t.month or 0) + 1, t.monthday or 1)
	end
	return 'N/A'
end

local function banRow(record)
	return {
		id = record.id,
		name = record.nick ~= '' and record.nick or (record.username ~= '' and record.username or 'N/A'),
		ip = record.ip ~= '' and record.ip or 'N/A',
		serial = record.serial ~= '' and record.serial or 'N/A',
		by = record.admin,
		date = banDate(record),
	}
end

local function banList()
	local owner = bans()
	if not owner then return {} end

	local records = owner:getBans()
	table.sort(records, function(a, b) return a.id > b.id end)

	local list = {}
	for index, record in ipairs(records) do
		if index > 200 then break end
		list[#list + 1] = banRow(record)
	end
	return list
end

local function findBan(id)
	local owner = bans()
	if not owner then return nil end

	for _, record in ipairs(owner:getBans()) do
		if record.id == tonumber(id) then return record end
	end
	return nil
end

local function legacyValue(value)
	if type(value) ~= 'string' then return nil end
	value = value:gsub('^%s+', ''):gsub('%s+$', '')
	if value == '' or value == 'N/A' or value == 'liberado' then return nil end
	return value
end

local function importLegacyBans()
	local owner = bans()
	if not DB or not owner then return end

	local done = dbPoll(dbQuery(DB, "SELECT value FROM server_settings WHERE key = 'bansImported'"), -1) or {}
	if done[1] then return end

	local ok, legacy = pcall(function() return dbPoll(dbQuery(DB, 'SELECT * FROM bans'), -1) end)
	if not ok or type(legacy) ~= 'table' then legacy = {} end
	local imported = 0

	for _, row in ipairs(legacy) do
		local ip, serial = legacyValue(row.ip), legacyValue(row.serial)
		if ip or serial then
			local theBan = owner:addBan(ip, nil, serial, row.admin or 'Console', row.reason or '')
			if theBan then
				if type(row.name) == 'string' and row.name ~= '' then
					owner:setBanNick(theBan, row.name)
				end
				imported = imported + 1
			end
		end
	end

	dbExec(DB, "INSERT OR REPLACE INTO server_settings (key, value) VALUES ('bansImported', ?)", tostring(imported))
	if imported > 0 then
		outputDebugString('[mtax-admin] ' .. imported .. ' ban(s) importados para [mtax]/bans', 3)
	end
end

QueryBans = function()
	return banList()
end

QueryServerSettings = function()
	local q = dbQuery(DB, "SELECT value FROM server_settings WHERE key = 'password'")
	local rows = dbPoll(q, -1) or {}
	return {
		password = rows[1] and rows[1].value or '',
		weatherId = CurrentWeather and CurrentWeather.id or 0,
		serverName = getServerName and getServerName() or '',
		onlinePlayers = #getElementsByType('player'),
		maxPlayers = (getMaxPlayers and getMaxPlayers()) or 32,
	}
end

local function aclGroupHandle(name)
	return { __type = 'aclgroup', name = name }
end

QueryAclGroups = function()
	local ok, groups = pcall(function() return exports['acls']:aclGroupList() end)
	if not ok or type(groups) ~= 'table' then return {} end

	local list = {}
	for _, group in ipairs(groups) do
		if type(group) == 'table' and type(group.name) == 'string' then
			local objOk, objects = pcall(function() return exports['acls']:aclGroupListObjects(aclGroupHandle(group.name)) end)
			list[#list + 1] = {
				name = group.name,
				objects = (objOk and type(objects) == 'table') and objects or {},
			}
		end
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

local function broadcastToOpenAdmins(eventName, payload)
	for player, isOpen in pairs(PanelOpen) do
		if isOpen and isElement(player) then
			triggerClientEvent(player, eventName, player, payload)
		end
	end
end

local function anyPanelOpen()
	for player, isOpen in pairs(PanelOpen) do
		if isOpen and isElement(player) then return true end
	end
	return false
end

BroadcastPlayers = function() broadcastToOpenAdmins('mtax:admin:setPlayers', BuildPlayerList()) end
BroadcastResources = function() broadcastToOpenAdmins('mtax:admin:setResources', BuildResourceList()) end
BroadcastBans = function() broadcastToOpenAdmins('mtax:admin:setBans', QueryBans()) end
BroadcastAclGroups = function() broadcastToOpenAdmins('mtax:admin:setAclGroups', QueryAclGroups()) end
BroadcastServerSettings = function() broadcastToOpenAdmins('mtax:admin:setServerSettings', QueryServerSettings()) end
BroadcastActionLog = function() broadcastToOpenAdmins('mtax:admin:setActionLog', ActionLog) end

PushActionLog = function(text)
	table.insert(ActionLog, 1, text)
	if #ActionLog > 30 then
		table.remove(ActionLog, 31)
	end
	BroadcastActionLog()
end

function Handlers.getPlayers() return BuildPlayerList() end
function Handlers.getResources() return BuildResourceList() end
function Handlers.getBans() return QueryBans() end
function Handlers.getAclGroups() return QueryAclGroups() end
function Handlers.getServerSettings() return QueryServerSettings() end
function Handlers.getActionLog() return ActionLog end

function Handlers.moderatePlayer(admin, data)
	local target = PlayerRegistryById[data.id]
	if not target or not isElement(target) then return { ok = false, message = 'Jogador não encontrado.' } end

	local targetName = getPlayerName(target) or 'N/A'

	if data.action == 'kick' then
		kickPlayer(target, admin, 'Expulso pelo painel administrativo')
	elseif data.action == 'ban' then
		local owner = bans()
		if not owner then return { ok = false, message = 'O resource [mtax]/bans não está rodando.' } end

		if not owner:banPlayer(target, true, false, true, admin, 'Banido pelo painel administrativo') then
			return { ok = false, message = 'Não foi possível banir o jogador.' }
		end
		BroadcastBans()
	elseif data.action == 'mute' then
		setPlayerMuted(target, not isPlayerMuted(target))
	elseif data.action == 'freeze' then
		setElementFrozen(target, not isElementFrozen(target))
	else
		return { ok = false, message = 'Ação de moderação desconhecida.' }
	end

	BroadcastPlayers()
	return { ok = true, message = data.action .. ' aplicado a ' .. targetName }
end

function Handlers.spectatePlayer(admin, data)
	local target = PlayerRegistryById[data.id]
	if not target then return { ok = false, message = 'Jogador não encontrado.' } end
	setCameraTarget(admin, target)
	return { ok = true, message = 'Espectando ' .. getPlayerName(target) }
end

function Handlers.slapPlayer(admin, data)
	local target = PlayerRegistryById[data.id]
	if not target then return { ok = false, message = 'Jogador não encontrado.' } end
	local amount = tonumber(data.amount) or 20
	setElementHealth(target, math.max(0, (getElementHealth(target) or 0) - amount))
	local vx, vy, vz = getElementVelocity(target)
	setElementVelocity(target, vx or 0, vy or 0, (vz or 0) + 0.3)
	BroadcastPlayers()
	return { ok = true, message = 'Slap de ' .. amount .. ' aplicado em ' .. getPlayerName(target) }
end

function Handlers.shoutPlayer(admin, data)
	local target = PlayerRegistryById[data.id]
	if not target then return { ok = false, message = 'Jogador não encontrado.' } end
	ShoutTarget[admin] = target
	if outputChatBox then
		outputChatBox('Sua próxima mensagem será enviada como SHOUT para ' .. getPlayerName(target), admin)
	end
	return { ok = true, message = 'Modo shout ativado para ' .. getPlayerName(target) }
end

function Handlers.setPlayerStat(admin, data)
	local target = PlayerRegistryById[data.id]
	if not target then return { ok = false, message = 'Jogador não encontrado.' } end
	local value = data.value

	if data.stat == 'health' then
		local n = tonumber(value)
		if not n then return { ok = false, message = 'Valor inválido.' } end
		setElementHealth(target, math.max(0, math.min(100, n)))
	elseif data.stat == 'armour' then
		local n = tonumber(value)
		if not n then return { ok = false, message = 'Valor inválido.' } end
		setPedArmor(target, math.max(0, math.min(100, n)))
	elseif data.stat == 'skin' then
		local n = tonumber(value)
		if not n then return { ok = false, message = 'Skin ID inválido.' } end
		setElementModel(target, n)
	elseif data.stat == 'money' then
		local n = tonumber(value)
		if not n then return { ok = false, message = 'Valor inválido.' } end
		local callOk, result = pcall(function() return exports['accounts']:setPlayerMoney(target, math.max(0, n)) end)
		if not callOk then return { ok = false, message = "Falha ao comunicar com o resource 'accounts' (está rodando?)." } end
		if result == false then return { ok = false, message = 'Jogador está em uma conta guest — sem conta para salvar dinheiro.' } end
	else
		return { ok = false, message = 'Stat desconhecida.' }
	end

	BroadcastPlayers()
	return { ok = true, message = data.stat .. ' atualizado para ' .. getPlayerName(target) }
end

function Handlers.resetPlayerStats(admin, data)
	local target = PlayerRegistryById[data.id]
	if not target then return { ok = false, message = 'Jogador não encontrado.' } end
	setElementHealth(target, 100)
	setPedArmor(target, 0)
	BroadcastPlayers()
	return { ok = true, message = 'Stats resetados para ' .. getPlayerName(target) }
end

function Handlers.givePlayerWeapon(admin, data)
	local target = PlayerRegistryById[data.id]
	if not target then return { ok = false, message = 'Jogador não encontrado.' } end
	local weaponId = tonumber(data.weapon)
	if not weaponId or weaponId < 1 or weaponId > 46 then return { ok = false, message = 'Arma desconhecida.' } end
	giveWeapon(target, weaponId, 250, true)
	BroadcastPlayers()
	return { ok = true, message = 'Arma entregue a ' .. getPlayerName(target) }
end

function Handlers.givePlayerVehicle(admin, data)
	local target = PlayerRegistryById[data.id]
	if not target then return { ok = false, message = 'Jogador não encontrado.' } end
	local model = tonumber(data.model)
	if not model or model < 400 or model > 611 then return { ok = false, message = 'Veículo desconhecido.' } end
	local x, y, z = getElementPosition(target)
	local vehicle = createVehicle(model, x + 3, y, z)
	if not vehicle then return { ok = false, message = 'Falha ao criar o veículo.' } end
	warpPedIntoVehicle(target, vehicle)
	BroadcastPlayers()
	return { ok = true, message = 'Veículo entregue a ' .. getPlayerName(target) }
end

function Handlers.givePlayerJetpack(admin, data)
	local target = PlayerRegistryById[data.id]
	if not target or not isElement(target) then return { ok = false, message = 'Jogador não encontrado.' } end
	local wantJetpack = not isPedWearingJetpack(target)
	if not setPedWearingJetpack(target, wantJetpack) then
		return { ok = false, message = 'Não foi possível alternar o jetpack (jogador está em um veículo?).' }
	end
	BroadcastPlayers()
	return { ok = true, message = (wantJetpack and 'JetPack ativado para ' or 'JetPack removido de ') .. getPlayerName(target) }
end

function Handlers.warpToPlayer(admin, data)
	local target = PlayerRegistryById[data.id]
	if not target then return { ok = false, message = 'Jogador não encontrado.' } end
	local x, y, z = getElementPosition(target)
	setElementPosition(admin, x, y, z + 1, true)
	return { ok = true, message = 'Você foi teleportado até ' .. getPlayerName(target) }
end

function Handlers.warpPlayerToMe(admin, data)
	local target = PlayerRegistryById[data.id]
	if not target then return { ok = false, message = 'Jogador não encontrado.' } end
	local x, y, z = getElementPosition(admin)
	setElementPosition(target, x, y, z + 1, true)
	return { ok = true, message = getPlayerName(target) .. ' foi teleportado até você.' }
end

function Handlers.vehicleMaintenance(admin, data)
	local target = PlayerRegistryById[data.id]
	if not target then return { ok = false, message = 'Jogador não encontrado.' } end
	local vehicle = getPedOccupiedVehicle(target)
	if not vehicle then return { ok = false, message = getPlayerName(target) .. ' não está em um veículo.' } end

	if data.action == 'repair' then
		fixVehicle(vehicle)
	elseif data.action == 'explode' then
		setElementHealth(vehicle, 0)
	elseif data.action == 'destroy' then
		destroyElement(vehicle)
	else
		return { ok = false, message = 'Ação de veículo desconhecida.' }
	end

	BroadcastPlayers()
	return { ok = true, message = data.action .. ' aplicado ao veículo de ' .. getPlayerName(target) }
end

local function buildVehicleCustomization(vehicle)
	local r1, g1, b1, r2, g2, b2, r3, g3, b3, r4, g4, b4 = getVehicleColor(vehicle, true)
	local hr, hg, hb = getVehicleHeadLightColor(vehicle)

	local slots = {}
	for slot = 0, 16 do
		local slotName = getVehicleUpgradeSlotName(slot)
		if type(slotName) == 'string' then
			local current = getVehicleUpgradeOnSlot(vehicle, slot) or 0
			local compatible = getVehicleCompatibleUpgrades(vehicle, slot) or {}
			local options = {}
			for _, upgradeId in ipairs(compatible) do
				local upgradeName = getVehicleUpgradeSlotName(upgradeId)
				options[#options + 1] = { id = upgradeId, name = type(upgradeName) == 'string' and upgradeName or ('Upgrade ' .. upgradeId) }
			end
			if #options > 0 or current ~= 0 then
				slots[#slots + 1] = { slot = slot, name = slotName, current = current, options = options }
			end
		end
	end

	return {
		ok = true,
		vehicleName = (getVehicleName and getVehicleName(vehicle)) or 'Vehicle',
		slots = slots,
		colors = { r1 or 0, g1 or 0, b1 or 0, r2 or 0, g2 or 0, b2 or 0, r3 or 0, g3 or 0, b3 or 0, r4 or 0, g4 or 0, b4 or 0 },
		paintjob = getVehiclePaintjob(vehicle) or 3,
		plate = getVehiclePlateText(vehicle) or '',
		headlight = { r = hr or 255, g = hg or 255, b = hb or 255 },
	}
end

function Handlers.getVehicleCustomization(admin, data)
	local target = PlayerRegistryById[data.id]
	if not target or not isElement(target) then return { ok = false, message = 'Jogador não encontrado.' } end
	local vehicle = getPedOccupiedVehicle(target)
	if not vehicle then return { ok = false, message = getPlayerName(target) .. ' não está em um veículo.' } end
	return buildVehicleCustomization(vehicle)
end

function Handlers.vehicleCustomizeAction(admin, data)
	local target = PlayerRegistryById[data.id]
	if not target or not isElement(target) then return { ok = false, message = 'Jogador não encontrado.' } end
	local vehicle = getPedOccupiedVehicle(target)
	if not vehicle then return { ok = false, message = getPlayerName(target) .. ' não está em um veículo.' } end

	if data.action == 'setUpgrades' then
		for slotKey, upgradeId in pairs(data.upgrades or {}) do
			local slot = tonumber(slotKey)
			local newId = tonumber(upgradeId) or 0
			if slot then
				local currentId = getVehicleUpgradeOnSlot(vehicle, slot) or 0
				if newId ~= currentId then
					if currentId ~= 0 then removeVehicleUpgrade(vehicle, currentId) end
					if newId ~= 0 then addVehicleUpgrade(vehicle, newId) end
				end
			end
		end
	elseif data.action == 'upgradeAll' then
		addVehicleUpgrade(vehicle, 'all')
	elseif data.action == 'removeAll' then
		for _, upgradeId in ipairs(getVehicleUpgrades(vehicle) or {}) do
			removeVehicleUpgrade(vehicle, upgradeId)
		end
	elseif data.action == 'setColors' then
		local c = data.colors
		if type(c) == 'table' and #c >= 12 then
			setVehicleColor(vehicle, c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
		end
	elseif data.action == 'setPaintjob' then
		local paintjob = tonumber(data.paintjob)
		if paintjob then setVehiclePaintjob(vehicle, paintjob) end
	elseif data.action == 'setPlate' then
		local plate = tostring(data.plate or ''):sub(1, 8)
		if plate ~= '' then setVehiclePlateText(vehicle, plate) end
	elseif data.action == 'setHeadlightColor' then
		local r, g, b = tonumber(data.r), tonumber(data.g), tonumber(data.b)
		if r and g and b then setVehicleHeadLightColor(vehicle, r, g, b) end
	else
		return { ok = false, message = 'Ação de customização desconhecida.' }
	end

	BroadcastPlayers()
	return buildVehicleCustomization(vehicle)
end

function Handlers.setVehicleDimension(admin, data)
	local target = PlayerRegistryById[data.id]
	if not target or not isElement(target) then return { ok = false, message = 'Jogador não encontrado.' } end
	local dimension = tonumber(data.dimension)
	if not dimension then return { ok = false, message = 'Dimensão inválida.' } end

	setElementDimension(target, dimension)

	local vehicle = getPedOccupiedVehicle(target)
	if vehicle then
		setElementDimension(vehicle, dimension)
		for seat = 0, 8 do
			local occupant = getVehicleOccupant(vehicle, seat)
			if occupant and occupant ~= target then
				setElementDimension(occupant, dimension)
			end
		end
		return { ok = true, message = 'Dimensão definida para ' .. dimension .. ' (veículo e ocupantes incluídos).' }
	end

	return { ok = true, message = 'Dimensão definida para ' .. dimension }
end

function Handlers.teleportPlayerToInterior(admin, data)
	local target = PlayerRegistryById[data.id]
	if not target or not isElement(target) then return { ok = false, message = 'Jogador não encontrado.' } end
	local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
	local interior = tonumber(data.interior)
	if not x or not y or not z or not interior then return { ok = false, message = 'Interior inválido.' } end
	setElementInterior(target, interior)
	setElementPosition(target, x, y, z)
	BroadcastPlayers()
	return { ok = true, message = getPlayerName(target) .. ' foi teleportado para o interior.' }
end

function Handlers.resourceLifecycle(admin, data)
	local resourceElement = findResource(data.name)
	if not resourceElement then
		PushActionLog(tostring(data.name) .. ': ' .. tostring(data.action) .. ' → resource não encontrado')
		return { ok = false, message = "Resource '" .. tostring(data.name) .. "' não encontrado." }
	end

	local ok, result
	if data.action == 'start' then
		ok, result = pcall(startResource, resourceElement)
	elseif data.action == 'restart' then
		ok, result = pcall(restartResource, resourceElement)
	elseif data.action == 'stop' then
		ok, result = pcall(stopResource, resourceElement)
	else
		return { ok = false, message = 'Ação de resource desconhecida.' }
	end

	BroadcastResources()
	if ok and result then
		PushActionLog(data.name .. ': ' .. data.action .. ' → agendado por ' .. getPlayerName(admin))
		return { ok = true, message = data.action .. ' agendado para ' .. data.name }
	end
	PushActionLog(data.name .. ': ' .. data.action .. ' → falhou')
	return { ok = false, message = 'Falha ao ' .. data.action .. ' ' .. tostring(data.name) }
end

function Handlers.refreshResources(admin, data)
	pcall(refreshResources)
	BroadcastResources()
	PushActionLog('Refresh list → atualizado por ' .. getPlayerName(admin))
	return { ok = true, message = 'Lista de resources atualizada.' }
end

function Handlers.executeCommand(admin, data)
	local command, args = tostring(data.command or ''):match('^(%S+)%s*(.*)$')
	if not command then return { ok = false, message = 'Comando vazio.' } end

	if data.scope == 'client' then
		triggerClientEvent(admin, 'mtax:admin:runClientCommand', admin, command, args)
		PushActionLog('[client] ' .. getPlayerName(admin) .. ': ' .. tostring(data.command))
		return { ok = true, message = 'Enviado para o seu cliente.' }
	end

	local ok, result = pcall(executeCommandHandler, command, admin, args)
	local status = ok and (result and 'executado' or 'comando não encontrado') or 'erro'
	PushActionLog('[server] ' .. getPlayerName(admin) .. ': ' .. tostring(data.command) .. ' → ' .. status)
	if not ok then return { ok = false, message = tostring(result) } end
	return { ok = result == true, message = result and 'Executado.' or 'Comando não encontrado.' }
end

function Handlers.setServerPassword(admin, data)
	local password = data.password or ''
	setServerPassword(password)
	dbExec(DB, "INSERT OR REPLACE INTO server_settings (key, value) VALUES ('password', ?)", password)
	BroadcastServerSettings()
	return { ok = true, message = 'Senha atualizada.' }
end

function Handlers.setWeather(admin, data)
	local id = tonumber(data.id) or 0
	local blended = data.blended and true or false
	if blended then setWeatherBlended(id) else setWeather(id) end
	CurrentWeather = { id = id, blended = blended }
	BroadcastServerSettings()
	return { ok = true, message = 'Clima definido para ' .. id }
end

function Handlers.setTime(admin, data)
	local hour, minute = tostring(data.value or ''):match('^(%d+):(%d+)$')
	if not hour then return { ok = false, message = 'Formato esperado HH:MM.' } end
	setTime(tonumber(hour), tonumber(minute))
	return { ok = true, message = 'Horário definido.' }
end

function Handlers.setGravity(admin, data)
	local value = tonumber(data.value)
	if not value then return { ok = false, message = 'Valor inválido.' } end
	setGravity(value)
	return { ok = true, message = 'Gravidade definida.' }
end

function Handlers.setGameSpeed(admin, data)
	local value = tonumber(data.value)
	if not value then return { ok = false, message = 'Valor inválido.' } end
	setGameSpeed(value)
	return { ok = true, message = 'Velocidade do jogo definida.' }
end

function Handlers.setWaveHeight(admin, data)
	local value = tonumber(data.value)
	if not value then return { ok = false, message = 'Valor inválido.' } end
	setWaveHeight(value)
	return { ok = true, message = 'Altura das ondas definida.' }
end

function Handlers.setFpsLimit(admin, data)
	local limit = tonumber(data.value)
	if not limit then return { ok = false, message = 'Valor inválido.' } end
	for _, player in ipairs(getElementsByType('player')) do
		triggerClientEvent(player, 'mtax:admin:setFpsLimit', player, limit)
	end

	return { ok = true, message = 'FPS limit definido para ' .. limit }
end

function Handlers.sendWelcomeMessage(admin, data)
	if not outputChatBox then return { ok = false, message = 'outputChatBox indisponível nesta build.' } end
	for _, player in ipairs(getElementsByType('player')) do
		outputChatBox(tostring(data.message or ''), player)
	end
	return { ok = true, message = 'Mensagem enviada.' }
end

function Handlers.shutdownServer(admin, data)
	shutdown('Desligado pelo painel administrativo por ' .. getPlayerName(admin))
	return { ok = true, message = 'Desligando o servidor...' }
end

function Handlers.clearChat(admin, data)
	if not outputChatBox then return { ok = false, message = 'outputChatBox indisponível nesta build.' } end
	for _, player in ipairs(getElementsByType('player')) do
		for _ = 1, 30 do
			outputChatBox('', player)
		end
	end
	return { ok = true, message = 'Chat limpo.' }
end

function Handlers.searchBans(admin, data)
	local field = data.type == 'IP' and 'ip' or (data.type == 'Serial' and 'serial' or 'name')
	local query = tostring(data.query or ''):lower()

	local list = {}
	for _, row in ipairs(banList()) do
		if query == '' or tostring(row[field]):lower():find(query, 1, true) then
			list[#list + 1] = row
		end
	end
	return list
end

function Handlers.banRowAction(admin, data)
	local owner = bans()
	if not owner then return { ok = false, message = 'O resource [mtax]/bans não está rodando.' } end

	local record = findBan(data.id)
	if not record then return { ok = false, message = 'Registro de ban não encontrado.' } end

	local row = banRow(record)
	if data.action == 'details' then
		return { ok = true, message = string.format('%s — IP %s — Serial %s — banido por %s em %s', row.name, row.ip, row.serial, row.by, row.date) }
	elseif data.action == 'unban' then
		owner:removeBan(record, admin)
	elseif data.action == 'unbanIp' or data.action == 'unbanSerial' then
		local keepIp = data.action == 'unbanSerial' and record.ip ~= '' and record.ip or nil
		local keepSerial = data.action == 'unbanIp' and record.serial ~= '' and record.serial or nil
		local keepUsername = record.username ~= '' and record.username or nil

		owner:removeBan(record, admin)
		if keepIp or keepSerial or keepUsername then
			local replacement = owner:addBan(keepIp, keepUsername, keepSerial, admin, record.reason)
			if replacement and record.nick ~= '' then
				owner:setBanNick(replacement, record.nick)
			end
		end
	else
		return { ok = false, message = 'Ação de ban desconhecida.' }
	end

	BroadcastBans()
	return { ok = true, message = data.action .. ' aplicado.' }
end

function Handlers.banByField(admin, data)
	local owner = bans()
	if not owner then return { ok = false, message = 'O resource [mtax]/bans não está rodando.' } end

	local record = findBan(data.id)
	if not record then return { ok = false, message = 'Registro não encontrado.' } end

	local value = data.field == 'ip' and record.ip or record.serial
	if value == '' then return { ok = false, message = 'Esse registro não tem ' .. tostring(data.field) .. '.' } end

	local theBan = owner:addBan(data.field == 'ip' and value or nil, nil, data.field == 'serial' and value or nil,
		admin, 'Ban de ' .. tostring(data.field) .. ' pelo painel')
	if theBan and record.nick ~= '' then
		owner:setBanNick(theBan, record.nick)
	end

	BroadcastBans()
	return { ok = true, message = tostring(data.field) .. ' banido.' }
end

function Handlers.refreshBans(admin, data)
	BroadcastBans()
	return { ok = true, message = 'Lista de bans atualizada.' }
end

function Handlers.aclGroupAction(admin, data)
	local action, group, value = data.action, data.group, data.value
	local acls = exports['acls']

	local ok, result

	if action == 'createGroup' then
		if not value or value == '' then return { ok = false, message = 'Nome do grupo é obrigatório.' } end
		ok, result = pcall(function() return acls:aclCreateGroup(value) end)
	elseif action == 'destroyGroup' then
		if not group then return { ok = false, message = 'Nenhum grupo selecionado.' } end
		ok, result = pcall(function() return acls:aclDestroyGroup(aclGroupHandle(group)) end)
	elseif action == 'addObject' then
		if not group then return { ok = false, message = 'Nenhum grupo selecionado.' } end
		ok, result = pcall(function() return acls:aclGroupAddObject(aclGroupHandle(group), value) end)
	elseif action == 'removeObject' then
		if not group then return { ok = false, message = 'Nenhum grupo selecionado.' } end
		ok, result = pcall(function() return acls:aclGroupRemoveObject(aclGroupHandle(group), value) end)
	else
		return { ok = false, message = 'Ação de ACL desconhecida.' }
	end

	if not ok then
		return { ok = false, message = "Falha ao comunicar com o resource 'acls' (está rodando?): " .. tostring(result) }
	end
	if result == false then
		return { ok = false, message = action .. ' falhou — confira se o grupo envolvido existe.' }
	end

	BroadcastAclGroups()
	return { ok = true, message = action .. ' aplicado.' }
end

local function respond(admin, requestId, result)
	triggerClientEvent(admin, 'mtax:admin:response', admin, requestId, result)
end

addEvent('mtax:admin:requestToggle', true)
addEventHandler('mtax:admin:requestToggle', root, function()
	local admin = client
	if not isAdmin(admin) then
		if outputChatBox then outputChatBox('Você não tem permissão para abrir o painel administrativo.', admin) end
		return
	end
	local nowOpen = not PanelOpen[admin]
	PanelOpen[admin] = nowOpen
	triggerClientEvent(admin, 'mtax:admin:setVisible', admin, nowOpen)
	if nowOpen then
		BroadcastPlayers()
		BroadcastResources()
		BroadcastBans()
		BroadcastAclGroups()
		BroadcastServerSettings()
		BroadcastActionLog()
	end
end)

addEvent('mtax:admin:closePanel', true)
addEventHandler('mtax:admin:closePanel', root, function()
	PanelOpen[client] = false
end)


setTimer(function()
	if anyPanelOpen() then
		BroadcastPlayers()
	end
end, 5000, 0)

for _, action in ipairs(NUI_ACTIONS) do
	local eventName = 'mtax:admin:nui:' .. action
	addEvent(eventName, true)
	addEventHandler(eventName, root, function(requestId, data)
		local admin = client
		if not isAdmin(admin) then
			respond(admin, requestId, { ok = false, message = 'Sem permissão.' })
			return
		end
		local handler = Handlers[action]
		if not handler then
			respond(admin, requestId, { ok = false, message = 'Ação desconhecida: ' .. action })
			return
		end
		local ok, result = pcall(handler, admin, data or {})
		if not ok then
			outputDebugString('[mtax-admin] erro em ' .. action .. ': ' .. tostring(result))
			respond(admin, requestId, { ok = false, message = 'Erro interno.' })
			return
		end
		respond(admin, requestId, result)
	end)
end



local function logOnlineCount()
	local online = #getElementsByType('player')
	outputDebugString(online .. '/' .. getMaxPlayers() .. ' jogadores online')
end

addEventHandler('onPlayerJoin', root, function()
	registerPlayer(source)

	if CurrentWeather then
		if CurrentWeather.blended then setWeatherBlended(CurrentWeather.id) else setWeather(CurrentWeather.id) end
	end

	logOnlineCount()
	BroadcastPlayers()
	BroadcastServerSettings()
end)


addEventHandler('onPlayerQuit', root, function()
	unregisterPlayer(source)
	logOnlineCount()
	BroadcastPlayers()
	BroadcastServerSettings()
end)

addEventHandler('onResourceStart', resourceRoot, function()
	DB = dbConnect('sqlite', Config.Database)
	dbExec(DB, 'CREATE TABLE IF NOT EXISTS server_settings (key TEXT PRIMARY KEY, value TEXT)')
	importLegacyBans()

	for _, p in ipairs(getElementsByType('player')) do
		registerPlayer(p)
	end
end)