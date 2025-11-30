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
    local src = source
    if type(propid) ~= 'number' or propid < 111111 or propid > 999999 then
        cb(nil)
        return
    end
    
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
    
    -- validate proptype
    if type(proptype) ~= 'string' or proptype ~= 'fishtrap' then return end
    
    -- validate location and heading
    if not location or type(location.x) ~= 'number' or type(location.y) ~= 'number' or type(location.z) ~= 'number' then return end
    if type(heading) ~= 'number' then return end
    
    -- Validate hash
    if type(hash) ~= 'number' then return end
    
    -- verify placement distance - player must be within 10 meters of placement location
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local placementCoords = vector3(location.x, location.y, location.z)
    local distance = #(playerCoords - placementCoords)
    if distance > 10.0 then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Too far away to place trap', type = 'error', duration = 5000 })
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local owner = firstname .. ' ' .. lastname

    -- check trap count in DATABASE
    local propCount = MySQL.query.await('SELECT COUNT(*) as count FROM rex_trapfishing WHERE citizenid = ? AND proptype = ?', {citizenid, proptype})
    
    if propCount and propCount[1] and propCount[1].count >= Config.MaxTraps then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_lang_1'), type = 'inform', duration = 5000 })
        return
    end

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

    table.insert(Config.PlayerProps, PropData)
    Player.Functions.RemoveItem(proptype, 1)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[proptype], 'remove', 1)
    TriggerEvent('rex-trapfishing:server:saveProp', PropData, propId, citizenid, owner, proptype)
    TriggerEvent('rex-trapfishing:server:updateProps')
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
    -- always broadcast to all players when called internally
    TriggerClientEvent('rex-trapfishing:client:updatePropData', -1, Config.PlayerProps)
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
RegisterNetEvent('rex-trapfishing:server:addbait', function(propid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- validate propid
    if type(propid) ~= 'number' or propid < 111111 or propid > 999999 then return end
    
    -- verify player has bait item BEFORE doing anything
    if not Player.Functions.GetItemByName('trapbait') then
        TriggerClientEvent('ox_lib:notify', src, {title = 'You no longer have bait', type = 'error', duration = 5000 })
        return
    end
    
    -- atomic bait update with server-side validation
    -- get trap data and verify ownership
    local trapData = MySQL.query.await('SELECT * FROM rex_trapfishing WHERE propid = ?', {propid})
    if not trapData or not trapData[1] then return end
    
    -- verify player owns the trap
    if trapData[1].citizenid ~= Player.PlayerData.citizenid then
        return
    end
    
    -- verify trap isn't full on bait
    if trapData[1].bait >= 100 then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Trap is full with bait', type = 'info', duration = 5000 })
        return
    end
    
    -- calculate new bait amount (server-side, not client)
    local currentBait = trapData[1].bait
    local newBait = currentBait + 10
    if newBait > 100 then
        newBait = 100
    end
    
    -- remove bait from player FIRST (ensure inventory update succeeds before DB update)
    if not Player.Functions.RemoveItem('trapbait', 1) then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Failed to remove bait', type = 'error', duration = 5000 })
        return
    end
    
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['trapbait'], 'remove', 1)
    
    -- use atomic UPDATE with WHERE condition to verify bait hasn't changed
    -- this prevents another request from updating the trap between our read and write
    local updateResult = MySQL.update.await('UPDATE rex_trapfishing SET bait = ? WHERE propid = ? AND bait = ?', {newBait, propid, currentBait})
    
    if not updateResult or updateResult == 0 then
        -- bait value changed between read and write - restore item to player
        Player.Functions.AddItem('trapbait', 1)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['trapbait'], 'add', 1)
        TriggerClientEvent('ox_lib:notify', src, {title = 'Trap data changed, bait not added', type = 'error', duration = 5000 })
        return
    end
    
    -- immediately update client data to reflect bait change (don't wait for 5-second sync)
    TriggerEvent('rex-trapfishing:server:updateProps')
end)

---------------------------------------------
-- destroy prop (ATOMIC - handles empty + destroy in one operation)
---------------------------------------------
RegisterServerEvent('rex-trapfishing:server:destroyProp')
AddEventHandler('rex-trapfishing:server:destroyProp', function(propid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- validate propid
    if type(propid) ~= 'number' or propid < 111111 or propid > 999999 then return end
    
    -- atomic operation - retrieve trap data with all necessary validations
    local trapData = MySQL.query.await('SELECT * FROM rex_trapfishing WHERE propid = ?', {propid})
    if not trapData or not trapData[1] then return end
    
    -- verify trap ownership
    if trapData[1].citizenid ~= Player.PlayerData.citizenid then
        TriggerClientEvent('ox_lib:notify', src, {title = 'You do not own this trap', type = 'error', duration = 5000 })
        return
    end
    
    -- verify trap is fully repaired before allowing pickup
    if trapData[1].quality ~= 100 then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Trap must be fully repaired', type = 'error', duration = 5000 })
        return
    end
    
    -- first empty the trap using server-fetched data (not client-provided)
    local actualCrayfish = trapData[1].crayfish
    local actualLobster = trapData[1].lobster
    local actualCrab = trapData[1].crab
    local actualBluecrab = trapData[1].bluecrab
    
    if actualCrayfish > 0 then
        Player.Functions.AddItem('crayfish', actualCrayfish)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['crayfish'], 'add', actualCrayfish)
        MySQL.update('UPDATE rex_trapfishing SET crayfish = ? WHERE propid = ?', {0, propid})
    end
    if actualLobster > 0 then
        Player.Functions.AddItem('lobster', actualLobster)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['lobster'], 'add', actualLobster)
        MySQL.update('UPDATE rex_trapfishing SET lobster = ? WHERE propid = ?', {0, propid})
    end
    if actualCrab > 0 then
        Player.Functions.AddItem('crab', actualCrab)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['crab'], 'add', actualCrab)
        MySQL.update('UPDATE rex_trapfishing SET crab = ? WHERE propid = ?', {0, propid})
    end
    if actualBluecrab > 0 then
        Player.Functions.AddItem('bluecrab', actualBluecrab)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['bluecrab'], 'add', actualBluecrab)
        MySQL.update('UPDATE rex_trapfishing SET bluecrab = ? WHERE propid = ?', {0, propid})
    end
    
    -- now destroy the trap and give back the item
    for k, v in pairs(Config.PlayerProps) do
        if v.id == propid then
            table.remove(Config.PlayerProps, k)
        end
    end

    TriggerClientEvent('rex-trapfishing:client:removePropObject', src, propid)
    TriggerEvent('rex-trapfishing:server:PropRemoved', propid)
    TriggerEvent('rex-trapfishing:server:updateProps')
    Player.Functions.AddItem('fishtrap', 1)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['fishtrap'], 'add', 1)
end)

---------------------------------------------
-- remove props
---------------------------------------------
RegisterServerEvent('rex-trapfishing:server:PropRemoved')
AddEventHandler('rex-trapfishing:server:PropRemoved', function(propId)
    -- validate propId is a number
    if type(propId) ~= 'number' or propId < 111111 or propId > 999999 then return end
    
    -- delete from database using propid directly (not scanning all records)
    MySQL.Async.execute('DELETE FROM rex_trapfishing WHERE propid = @propid', { ['@propid'] = propId })
    
    -- remove from in-memory table safely
    local keysToRemove = {}
    for k, v in pairs(Config.PlayerProps) do
        if v.id == propId then
            table.insert(keysToRemove, k)
        end
    end
    
    -- remove in reverse order to prevent index shifting issues
    for i = #keysToRemove, 1, -1 do
        table.remove(Config.PlayerProps, keysToRemove[i])
    end
end)

---------------------------------------------
-- empty fishing trap
---------------------------------------------
RegisterServerEvent('rex-trapfishing:server:emptytrap')
AddEventHandler('rex-trapfishing:server:emptytrap', function(propid)
     local src = source
     local Player = RSGCore.Functions.GetPlayer(src)
     if not Player then return end
     
     -- validate propid
     if type(propid) ~= 'number' or propid < 111111 or propid > 999999 then return end
     
     -- always fetch trap data from database server-side - NEVER trust client data for quantities
     local trapData = MySQL.query.await('SELECT * FROM rex_trapfishing WHERE propid = ?', {propid})
     if not trapData or not trapData[1] then return end
     
     if trapData[1].citizenid ~= Player.PlayerData.citizenid then
         return
     end
     
     -- use server-fetched quantities, not client-provided values
     -- this prevents players from modifying catch amounts via client-side scripts
     local actualCrayfish = trapData[1].crayfish
     local actualLobster = trapData[1].lobster
     local actualCrab = trapData[1].crab
     local actualBluecrab = trapData[1].bluecrab
    
     local firstname = Player.PlayerData.charinfo.firstname
     local lastname = Player.PlayerData.charinfo.lastname
     if actualCrayfish > 0 then
         Player.Functions.AddItem('crayfish', actualCrayfish)
         TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['crayfish'], 'add', actualCrayfish)
         MySQL.update('UPDATE rex_trapfishing SET crayfish = ? WHERE propid = ?', {0, propid})
         TriggerEvent('rsg-log:server:CreateLog', 'trapfishing', locale('sv_lang_4'), 'green', firstname..' '..lastname..locale('sv_lang_5')..actualCrayfish..' crayfish')
     end
     if actualLobster > 0 then
         Player.Functions.AddItem('lobster', actualLobster)
         TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['lobster'], 'add', actualLobster)
         MySQL.update('UPDATE rex_trapfishing SET lobster = ? WHERE propid = ?', {0, propid})
         TriggerEvent('rsg-log:server:CreateLog', 'trapfishing', locale('sv_lang_6'), 'green', firstname..' '..lastname..locale('sv_lang_5')..actualLobster..' lobster')
     end
     if actualCrab > 0 then
         Player.Functions.AddItem('crab', actualCrab)
         TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['crab'], 'add', actualCrab)
         MySQL.update('UPDATE rex_trapfishing SET crab = ? WHERE propid = ?', {0, propid})
         TriggerEvent('rsg-log:server:CreateLog', 'trapfishing', locale('sv_lang_7'), 'green', firstname..' '..lastname..locale('sv_lang_5')..actualCrab..' crab')
     end
     if actualBluecrab > 0 then
         Player.Functions.AddItem('bluecrab', actualBluecrab)
         TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['bluecrab'], 'add', actualBluecrab)
         MySQL.update('UPDATE rex_trapfishing SET bluecrab = ? WHERE propid = ?', {0, propid})
         TriggerEvent('rsg-log:server:CreateLog', 'trapfishing', locale('sv_lang_8'), 'green', firstname..' '..lastname..locale('sv_lang_5')..actualBluecrab..' blue crab')
     end
end)

---------------------------------------------
-- repair trap
---------------------------------------------
RegisterNetEvent('rex-trapfishing:server:repairtrap', function(propid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- validate propid
    if type(propid) ~= 'number' or propid < 111111 or propid > 999999 then return end
    
    -- get trap data to verify ownership and current quality
    local trapData = MySQL.query.await('SELECT * FROM rex_trapfishing WHERE propid = ?', {propid})
    if not trapData or not trapData[1] then return end
    
    -- verify player owns the trap
    if trapData[1].citizenid ~= Player.PlayerData.citizenid then
        return
    end
    
    -- calculate actual repair cost based on damage
    local currentQuality = trapData[1].quality
    local repaircost = (100 - currentQuality) * Config.RepairCost
    
    -- check if player has enough money
    local playerCash = Player.PlayerData.money['cash']
    if playerCash < repaircost then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Not enough money', type = 'error', duration = 5000 })
        return
    end
    
     -- remove money and repair trap
     Player.Functions.RemoveMoney('cash', repaircost, 'repair-equipment')
     MySQL.update('UPDATE rex_trapfishing SET quality = ? WHERE propid = ?', {100, propid})
     
     -- immediately update client data to reflect repair (don't wait for 5-second sync)
     TriggerEvent('rex-trapfishing:server:updateProps')
     
     local firstname = Player.PlayerData.charinfo.firstname
     local lastname = Player.PlayerData.charinfo.lastname
     TriggerEvent('rsg-log:server:CreateLog', 'trapfishing', 'Trap Repaired', 'green', firstname..' '..lastname..' repaired trap '..propid..' for $'..repaircost)
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
            -- safely remove from table without breaking iteration
            local keysToRemove = {}
            for k, v in pairs(Config.PlayerProps) do
                if v.id == propid then
                    table.insert(keysToRemove, k)
                end
            end
            
            -- remove in reverse order to prevent index shifting
            for i = #keysToRemove, 1, -1 do
                table.remove(Config.PlayerProps, keysToRemove[i])
            end
            
            TriggerEvent('rex-trapfishing:server:updateProps')
            TriggerEvent('rsg-log:server:CreateLog', 'rextrapfishing', locale('sv_lang_9'), 'red', locale('sv_lang_10')..propid..locale('sv_lang_11')..owner..locale('sv_lang_12'))
            MySQL.Async.execute('DELETE FROM rex_trapfishing WHERE propid = ?', {propid})
        end

          -- rrack if bait was used this cycle
          local baitUsedThisCycle = false
          local baitupdates = 0
          
          if crayfish < Config.MaxCatch and crayfishchance > 100-Config.CrayfishChance and bait > baitupdates then
              MySQL.update('UPDATE rex_trapfishing SET crayfish = ? WHERE propid = ?', {crayfish+1, propid})
              baitUsedThisCycle = true
              baitupdates = baitupdates + 1
          end

          if lobster < Config.MaxCatch and lobsterchance > 100-Config.LobsterChance and bait > baitupdates then
              MySQL.update('UPDATE rex_trapfishing SET lobster = ? WHERE propid = ?', {lobster+1, propid})
              baitUsedThisCycle = true
              baitupdates = baitupdates + 1
          end

          if crab < Config.MaxCatch and crabchance > 100-Config.CrabChance and bait > baitupdates then
              MySQL.update('UPDATE rex_trapfishing SET crab = ? WHERE propid = ?', {crab+1, propid})
              baitUsedThisCycle = true
              baitupdates = baitupdates + 1
          end

          if bluecrab < Config.MaxCatch and bluecrabchance > 100-Config.BlueCrabChance and bait > baitupdates then
              MySQL.update('UPDATE rex_trapfishing SET bluecrab = ? WHERE propid = ?', {bluecrab+1, propid})
              baitUsedThisCycle = true
              baitupdates = baitupdates + 1
          end

          -- update bait only once per cycle to prevent double deductions
          if baitupdates > 0 then
              -- bait was used by catches
              local newbait = bait - baitupdates
              MySQL.update('UPDATE rex_trapfishing SET bait = ? WHERE propid = ?', {newbait, propid})
          elseif bait > 0 then
              -- natural decay if no catches
              MySQL.update('UPDATE rex_trapfishing SET bait = ? WHERE propid = ?', {bait-1, propid})
          end

    end

    ::continue::

    if Config.EnableServerNotify then
        print(locale('sv_lang_13'))
    end

end)
