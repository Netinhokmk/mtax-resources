resource_name = "accounts"
resource_version = "1.0.0"
resource_author = "MTAX"

shared_files = {
    ":tunnel/shared/main.lua",
    "config.lua",
}

client_files = {
    "client/main.lua",
}

server_files = {
    "server/main.lua",
}


exports = {
    'addAccount',
    'copyAccountData',
    'getAccount',
    'getAccountByID',
    'getAccountData',
    'getAccountID',
    'getAccountIP',
    'getAccountName',
    'getAccountPlayer',
    'getAccounts',
    'getAccountSerial',
    'getAccountsByData',
    'getAccountsByIP',
    'getAccountsBySerial',
    'getAllAccountData',
    'getPlayerAccount',
    'getPlayerMoney',
    'givePlayerMoney',
    'isGuestAccount',
    'logIn',
    'logOut',
    'removeAccount',
    'setAccountData',
    'setAccountName',
    'setAccountPassword',
    'setPlayerMoney',
    'takePlayerMoney',
    'getPlayerSerial'
}