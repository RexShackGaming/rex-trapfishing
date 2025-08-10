local RSGCore = exports['rsg-core']:GetCoreObject()
local PropsLoaded = false
lib.locale()

---------------------------------------------
-- use prop
---------------------------------------------
RSGCore.Functions.CreateUseableItem("fishtrap", function(source)
    local src = source
    TriggerClientEvent('rex-trapfishing:client:createprop', src, 'fishtrap', Config.FishTrap, 'fishtrap')
end)

---------------------------------------------
-- count props
---------------------------------------------
RSGCore.Functions.CreateCallback('rex-trapfishing:server:countprop', function(source, cb, proptype)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local result = MySQL.prepare.await("SELECT COUNT(*) as count FROM rex_trapfishing WHERE citizenid = ? AND proptype = ?", { citizenid, proptype })
    if result then
        cb(result)
    else
        cb(nil)
    end
end)

---------------------------------------------
-- cash callback
---------------------------------------------
RSGCore.Functions.CreateCallback('rex-trapfishing:server:cashcallback', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local playercash = Player.PlayerData.money['cash']
    if playercash then
        cb(playercash)
    else
        cb(nil)
    end
end)

---------------------------------------------
-- get all trap data
---------------------------------------------
RSGCore.Functions.CreateCallback('rex-trapfishing:server:getalltrapdata', function(source, cb, propid)
    MySQL.query('SELECT * FROM rex_trapfishing WHERE propid = ?', {propid}, function(result)
        if result[1] then
            cb(result)
        else
            cb(nil)
        end
    end)
end)

---------------------------------------------
-- new prop
---------------------------------------------
RegisterServerEvent('rex-trapfishing:server:newProp')
AddEventHandler('rex-trapfishing:server:newProp', function(proptype, location, heading, hash)
    local src = source
    local propId = math.random(111111, 999999)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local owner = firstname .. ' ' .. lastname

    local PropData =
    {
        id = propId,
        proptype = proptype,
        x = location.x,
        y = location.y,
        z = location.z,
        h = heading,
        hash = hash,
        builder = Player.PlayerData.citizenid,
        buildttime = os.time()
    }

    local PropCount = 0

    for _, v in pairs(Config.PlayerProps) do
        if v.builder == Player.PlayerData.citizenid then
            PropCount = PropCount + 1
        end
    end

    if PropCount >= Config.MaxTraps then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_lang_1'), type = 'inform', duration = 5000 })
    else
        table.insert(Config.PlayerProps, PropData)
        Player.Functions.RemoveItem(proptype, 1)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[proptype], 'remove', 1)
        TriggerEvent('rex-trapfishing:server:saveProp', PropData, propId, citizenid, owner, proptype)
        TriggerEvent('rex-trapfishing:server:updateProps')
    end
end)

---------------------------------------------
-- save props
---------------------------------------------
RegisterServerEvent('rex-trapfishing:server:saveProp')
AddEventHandler('rex-trapfishing:server:saveProp', function(data, propId, citizenid, owner, proptype)
    local datas = json.encode(data)

    MySQL.Async.execute('INSERT INTO rex_trapfishing (properties, propid, citizenid, owner, proptype) VALUES (@properties, @propid, @citizenid, @owner, @proptype)',
    {
        ['@properties'] = datas,
        ['@propid'] = propId,
        ['@citizenid'] = citizenid,
        ['@owner'] = owner,
        ['@proptype'] = proptype
    })
end)

---------------------------------------------
-- update props
---------------------------------------------
RegisterServerEvent('rex-trapfishing:server:updateProps')
AddEventHandler('rex-trapfishing:server:updateProps', function()
    local src = source
    TriggerClientEvent('rex-trapfishing:client:updatePropData', src, Config.PlayerProps)
end)

---------------------------------------------
-- update prop data
---------------------------------------------
CreateThread(function()
    while true do
        Wait(5000)
        if PropsLoaded then
            TriggerClientEvent('rex-trapfishing:client:updatePropData', -1, Config.PlayerProps)
        end
    end
end)

---------------------------------------------
-- get props
---------------------------------------------
CreateThread(function()
    TriggerEvent('rex-trapfishing:server:getProps')
    PropsLoaded = true
end)

---------------------------------------------
-- get props
---------------------------------------------
RegisterServerEvent('rex-trapfishing:server:getProps')
AddEventHandler('rex-trapfishing:server:getProps', function()
    local result = MySQL.query.await('SELECT * FROM rex_trapfishing')
    if not result[1] then return end
    for i = 1, #result do
        local propData = json.decode(result[i].properties)
        print(locale('sv_lang_2')..propData.proptype..locale('sv_lang_3')..propData.id)
        table.insert(Config.PlayerProps, propData)
    end
end)

---------------------------------------------
-- add bait
---------------------------------------------
RegisterNetEvent('rex-trapfishing:server:addbait', function(propid, newbait)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    -- remove bait from player
    Player.Functions.RemoveItem('trapbait', 1)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['trapbait'], 'remove', 1)
    -- sql update
    MySQL.update('UPDATE rex_trapfishing SET bait = ? WHERE propid = ?', {newbait, propid})
end)

---------------------------------------------
-- distory prop
---------------------------------------------
RegisterServerEvent('rex-trapfishing:server:destroyProp')
AddEventHandler('rex-trapfishing:server:destroyProp', function(propid, item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    for k, v in pairs(Config.PlayerProps) do
        if v.id == propid then
            table.remove(Config.PlayerProps, k)
        end
    end

    TriggerClientEvent('rex-trapfishing:client:removePropObject', src, propid)
    TriggerEvent('rex-trapfishing:server:PropRemoved', propid)
    TriggerEvent('rex-trapfishing:server:updateProps')
    Player.Functions.AddItem(item, 1)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'add', 1)
end)

---------------------------------------------
-- remove props
---------------------------------------------
RegisterServerEvent('rex-trapfishing:server:PropRemoved')
AddEventHandler('rex-trapfishing:server:PropRemoved', function(propId)
    local result = MySQL.query.await('SELECT * FROM rex_trapfishing')
    if not result then return end
    for i = 1, #result do
        local propData = json.decode(result[i].properties)
        if propData.id == propId then
            MySQL.Async.execute('DELETE FROM rex_trapfishing WHERE id = @id', { ['@id'] = result[i].id })
            for k, v in pairs(Config.PlayerProps) do
                if v.id == propId then
                    table.remove(Config.PlayerProps, k)
                end
            end
        end
    end
end)

---------------------------------------------
-- empty fishing trap
---------------------------------------------
RegisterServerEvent('rex-trapfishing:server:emptytrap')
AddEventHandler('rex-trapfishing:server:emptytrap', function(crayfish, lobster, crab, bluecrab, propid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    if crayfish > 0 then
        Player.Functions.AddItem('crayfish', crayfish)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['crayfish'], 'add', crayfish)
        MySQL.update('UPDATE rex_trapfishing SET crayfish = ? WHERE propid = ?', {0, propid})
        TriggerEvent('rsg-log:server:CreateLog', 'trapfishing', locale('sv_lang_4'), 'green', firstname..' '..lastname..locale('sv_lang_5')..crayfish..' crayfish')
    end
    if lobster > 0 then
        Player.Functions.AddItem('lobster', lobster)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['lobster'], 'add', lobster)
        MySQL.update('UPDATE rex_trapfishing SET lobster = ? WHERE propid = ?', {0, propid})
        TriggerEvent('rsg-log:server:CreateLog', 'trapfishing', locale('sv_lang_6'), 'green', firstname..' '..lastname..locale('sv_lang_5')..lobster..' lobster')
    end
    if crab > 0 then
        Player.Functions.AddItem('crab', crab)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['crab'], 'add', crab)
        MySQL.update('UPDATE rex_trapfishing SET crab = ? WHERE propid = ?', {0, propid})
        TriggerEvent('rsg-log:server:CreateLog', 'trapfishing', locale('sv_lang_7'), 'green', firstname..' '..lastname..locale('sv_lang_5')..crab..' crab')
    end
    if bluecrab > 0 then
        Player.Functions.AddItem('bluecrab', bluecrab)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['bluecrab'], 'add', bluecrab)
        MySQL.update('UPDATE rex_trapfishing SET bluecrab = ? WHERE propid = ?', {0, propid})
        TriggerEvent('rsg-log:server:CreateLog', 'trapfishing', locale('sv_lang_8'), 'green', firstname..' '..lastname..locale('sv_lang_5')..bluecrab..' blue crab')
    end
end)

---------------------------------------------
-- repair trap
---------------------------------------------
RegisterNetEvent('rex-trapfishing:server:repairtrap', function(propid, repaircost)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    Player.Functions.RemoveMoney('cash', repaircost, 'repair-equipment')
    MySQL.update('UPDATE rex_trapfishing SET quality = ? WHERE propid = ?', {100, propid})
end)

---------------------------------------------
-- trap upkeep system
---------------------------------------------
lib.cron.new(Config.CronJob, function ()

    local result = MySQL.query.await('SELECT * FROM rex_trapfishing')

    if not result then goto continue end

    for i = 1, #result do

        local crayfishchance = math.random(1,100)
        local lobsterchance = math.random(1,100)
        local crabchance = math.random(1,100)
        local bluecrabchance = math.random(1,100)

        local quality = result[i].quality
        local propid = result[i].propid
        local owner = result[i].owner
        local crayfish = result[i].crayfish
        local lobster = result[i].lobster
        local crab = result[i].crab
        local bluecrab = result[i].bluecrab
        local bait = result[i].bait

        -- check trap maintanance
        if quality > 0 then
            MySQL.update('UPDATE rex_trapfishing SET quality = ? WHERE propid = ?', {quality-1, propid})
        else
            for k, v in pairs(Config.PlayerProps) do
                if v.id == propid then
                    table.remove(Config.PlayerProps, k)
                end
            end
            TriggerEvent('rex-trapfishing:server:updateProps')
            TriggerEvent('rsg-log:server:CreateLog', 'rextrapfishing', locale('sv_lang_9'), 'red', locale('sv_lang_10')..propid..locale('sv_lang_11')..owner..locale('sv_lang_12'))
            MySQL.Async.execute('DELETE FROM rex_trapfishing WHERE propid = ?', {propid})
        end

        if crayfish < Config.MaxCatch and crayfishchance > 100-Config.CrayfishChance and bait > 0 then
            MySQL.update('UPDATE rex_trapfishing SET crayfish = ? WHERE propid = ?', {crayfish+1, propid})
            if bait > 0 then
                MySQL.update('UPDATE rex_trapfishing SET bait = ? WHERE propid = ?', {bait-1, propid})
            end
        end

        if lobster < Config.MaxCatch and lobsterchance > 100-Config.LobsterChance and bait > 0 then
            MySQL.update('UPDATE rex_trapfishing SET lobster = ? WHERE propid = ?', {lobster+1, propid})
            if bait > 0 then
                MySQL.update('UPDATE rex_trapfishing SET bait = ? WHERE propid = ?', {bait-1, propid})
            end
        end

        if crab < Config.MaxCatch and crabchance > 100-Config.CrabChance and bait > 0 then
            MySQL.update('UPDATE rex_trapfishing SET crab = ? WHERE propid = ?', {crab+1, propid})
            if bait > 0 then
                MySQL.update('UPDATE rex_trapfishing SET bait = ? WHERE propid = ?', {bait-1, propid})
            end
        end

        if bluecrab < Config.MaxCatch and bluecrabchance > 100-Config.BlueCrabChance and bait > 0 then
            MySQL.update('UPDATE rex_trapfishing SET bluecrab = ? WHERE propid = ?', {bluecrab+1, propid})
            if bait > 0 then
                MySQL.update('UPDATE rex_trapfishing SET bait = ? WHERE propid = ?', {bait-1, propid})
            end
        end

        if bait > 0 then
            MySQL.update('UPDATE rex_trapfishing SET bait = ? WHERE propid = ?', {bait-1, propid})
        end

    end

    ::continue::

    if Config.EnableServerNotify then
        print(locale('sv_lang_13'))
    end

end)
