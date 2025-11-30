local RSGCore = exports['rsg-core']:GetCoreObject()
local SpawnedProps = {}
local isBusy = false
local canPlace = false
local fx_group = "scr_dm_ftb"
local fx_name = "scr_mp_chest_spawn_smoke"
local fx_scale = 1.0
lib.locale()

---------------------------------------------
-- spawn props
---------------------------------------------
Citizen.CreateThread(function()
    while true do
        Wait(150)

        local pos = GetEntityCoords(cache.ped)
        local InRange = false

        for i = 1, #Config.PlayerProps do
            local prop = vector3(Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z)
            local dist = #(pos - prop)
            if dist >= 50.0 then goto continue end

            local hasSpawned = false
            InRange = true

            for z = 1, #SpawnedProps do
                local p = SpawnedProps[z]

                if p.id == Config.PlayerProps[i].id then
                    hasSpawned = true
                end
            end

            if hasSpawned then goto continue end

            local modelHash = Config.PlayerProps[i].hash
            local data = {}
            
            if not HasModelLoaded(modelHash) then
                RequestModel(modelHash)
                while not HasModelLoaded(modelHash) do
                    Wait(1)
                end
            end
            
            data.id = Config.PlayerProps[i].id
            data.obj = CreateObject(modelHash, Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z -1.2, false, false, false)
            SetEntityHeading(data.obj, Config.PlayerProps[i].h)
            SetEntityAsMissionEntity(data.obj, true)
            PlaceObjectOnGroundProperly(data.obj)
            Wait(1000)
            FreezeEntityPosition(data.obj, true)
            SetModelAsNoLongerNeeded(data.obj)

            -- veg modifiy
            local veg_modifier_sphere = 0
            
            if veg_modifier_sphere == nil or veg_modifier_sphere == 0 then
                local veg_radius = 3.0
                local veg_Flags =  1 + 2 + 4 + 8 + 16 + 32 + 64 + 128 + 256
                local veg_ModType = 1
                veg_modifier_sphere = Citizen.InvokeNative(0xFA50F79257745E74, Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z, veg_radius, veg_ModType, veg_Flags, 0)
            else
                Citizen.InvokeNative(0x9CF1836C03FB67A2, Citizen.PointerValueIntInitialized(veg_modifier_sphere), 0)
                veg_modifier_sphere = 0
            end

            local citizenid = RSGCore.Functions.GetPlayerData().citizenid
            if Config.PlayerProps[i].proptype == 'fishtrap' and Config.PlayerProps[i].builder == citizenid then
                local blip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, 1664425300, data.obj)
                Citizen.InvokeNative(0x74F74D3207ED525C, blip, joaat(Config.Blip.blipSprite), true)
                Citizen.InvokeNative(0x9CB1A1623062F402, blip, Config.Blip.blipName)
                Citizen.InvokeNative(0xD38744167B2FA257, blip, Config.Blip.blipScale)
                Citizen.InvokeNative(0x662D364ABF16DE2F, blip, joaat(Config.Blip.blipColour))
            end

            SpawnedProps[#SpawnedProps + 1] = data
            hasSpawned = false

            -- create target for the entity
            exports['rsg-target']:AddTargetEntity(data.obj, {
                options = {
                    {
                        type = 'client',
                        event = 'rex-trapfishing:client:checktrap',
                        icon = "fa-solid fa-fish",
                        label = locale('cl_lang_1'),
                        trapid = data.id,
                    },
                },
                distance = 3
            })
            -- end of target

            ::continue::
        end

        if not InRange then
            Wait(5000)
        end
    end
end)

-----------------------------------------------------------------
-- emtpy trap
-----------------------------------------------------------------
RegisterNetEvent('rex-trapfishing:client:emptytrap', function(data)
    -- do empty trap
    isBusy = true
    LocalPlayer.state:set("inv_busy", true, true) -- lock inventory
    local anim1 = `WORLD_HUMAN_CROUCH_INSPECT`
    FreezeEntityPosition(cache.ped, true)
    TaskStartScenarioInPlace(cache.ped, anim1, 0, true)
    Wait(10000)
    ClearPedTasks(cache.ped)
    FreezeEntityPosition(cache.ped, false)
    TriggerServerEvent('rex-trapfishing:server:emptytrap', data.trapid)
    LocalPlayer.state:set("inv_busy", false, true) -- unlock inventory
    isBusy = false
end)

---------------------------------------------
-- trap info menu
---------------------------------------------
RegisterNetEvent('rex-trapfishing:client:checktrap', function(data)

    RSGCore.Functions.TriggerCallback('rex-trapfishing:server:getalltrapdata', function(result)

        local id = result[1].id
        local propid = result[1].propid
        local citizenid = result[1].citizenid
        local owner = result[1].owner
        local crayfish = result[1].crayfish
        local lobster = result[1].lobster
        local crab = result[1].crab
        local bluecrab = result[1].bluecrab
        local bait = result[1].bait
        local quality = result[1].quality
        local repaircost = (100 - result[1].quality) * Config.RepairCost

        if quality > 50 then 
            colorScheme = 'green'
        end
        
        if quality <= 50 and quality > 10 then
            colorScheme = 'yellow'
        end
        
        if quality <= 10 then
            colorScheme = 'red'
        end

        lib.registerContext({
            id = 'trapinfo',
            title = locale('cl_lang_2'),
            options = {
                {
                    title = locale('cl_lang_3')..propid,
                    icon = 'fa-solid fa-fingerprint',
                },
                {
                    title = locale('cl_lang_4')..owner..' ('..citizenid..')',
                    icon = 'fa-solid fa-user',
                },
                {
                    title = locale('cl_lang_5')..quality,
                    progress = quality,
                    colorScheme = colorScheme,
                    icon = 'fa-solid fa-hashtag',
                },
                {
                    title = locale('cl_lang_6').. crayfish,
                    progress = crayfish * 10,
                    colorScheme = 'green',
                    icon = 'fa-solid fa-hashtag',
                },
                {
                    title = locale('cl_lang_7').. lobster,
                    progress = lobster * 10,
                    colorScheme = 'green',
                    icon = 'fa-solid fa-hashtag',
                },
                {
                    title = locale('cl_lang_8').. crab,
                    progress = crab * 10,
                    colorScheme = 'green',
                    icon = 'fa-solid fa-hashtag',
                },
                {
                    title = locale('cl_lang_9').. bluecrab,
                    progress = bluecrab * 10,
                    colorScheme = 'green',
                    icon = 'fa-solid fa-hashtag',
                },
                {
                    title = locale('cl_lang_10')..bait,
                    progress = bait,
                    colorScheme = 'green',
                    icon = 'fa-solid fa-hashtag',
                },
                {
                    title = locale('cl_lang_11'),
                    icon = 'fa-solid fa-fish-fins',
                    event = 'rex-trapfishing:client:addbait',
                    args = { trapid = data.trapid },
                    arrow = true
                },
                {
                    title = locale('cl_lang_12'),
                    icon = 'fa-solid fa-rotate',
                    event = 'rex-trapfishing:client:emptytrap',
                    args = { trapid = data.trapid },
                    arrow = true
                },
                {
                    title = locale('cl_lang_13')..repaircost..locale('cl_lang_14'),
                    icon = 'fa-solid fa-screwdriver-wrench',
                    event = 'rex-trapfishing:client:repairtrap',
                    args = { trapid = data.trapid },
                    arrow = true
                },
                {
                    title = locale('cl_lang_15'),
                    icon = 'fa-solid fa-box-open',
                    event = 'rex-trapfishing:client:pickuptrap',
                    args = { trapid = data.trapid, entity = data.entity},
                    arrow = true
                },
            }
        })
        lib.showContext('trapinfo')

    end, data.trapid)
end)

---------------------------------------------
-- repair trap
---------------------------------------------
RegisterNetEvent('rex-trapfishing:client:repairtrap', function(data)

     LocalPlayer.state:set("inv_busy", true, true) -- lock inventory
     lib.progressBar({
         duration = Config.RepairTime,
         position = 'bottom',
         useWhileDead = false,
         canCancel = false,
         disableControl = true,
         disable = {
             move = true,
             mouse = true,
         },
         label = locale('cl_lang_16'),
     })
     TriggerServerEvent('rex-trapfishing:server:repairtrap', data.trapid)
     LocalPlayer.state:set("inv_busy", false, true) -- unlock inventory

 end)

---------------------------------------------
-- add bait
---------------------------------------------
RegisterNetEvent('rex-trapfishing:client:addbait')
AddEventHandler('rex-trapfishing:client:addbait', function(data)

    RSGCore.Functions.TriggerCallback('rex-trapfishing:server:getalltrapdata', function(result)

        local bait = result[1].bait

        if bait >= 100 then
            lib.notify({ title = locale('cl_lang_18'), type = 'info', duration = 7000 })
            return
        end

        local hasItem = RSGCore.Functions.HasItem('trapbait', 1)

         if hasItem then
             isBusy = true
             LocalPlayer.state:set("inv_busy", true, true) -- lock inventory
             local anim1 = `WORLD_HUMAN_CROUCH_INSPECT`
             FreezeEntityPosition(cache.ped, true)
             TaskStartScenarioInPlace(cache.ped, anim1, 0, true)
             Wait(10000)
             ClearPedTasks(cache.ped)
             FreezeEntityPosition(cache.ped, false)
             TriggerServerEvent('rex-trapfishing:server:addbait', data.trapid)
             LocalPlayer.state:set("inv_busy", false, true) -- unlock inventory
             isBusy = false
         else
             lib.notify({ title = locale('cl_lang_19'), type = 'error', duration = 7000 })
         end

    end, data.trapid)

end)

---------------------------------------------
-- pickup trap
---------------------------------------------
RegisterNetEvent('rex-trapfishing:client:pickuptrap', function(data)

    RSGCore.Functions.TriggerCallback('rex-trapfishing:server:getalltrapdata', function(result)

        local crayfish = result[1].crayfish
        local lobster = result[1].lobster
        local crab = result[1].crab
        local bluecrab = result[1].bluecrab
        local quality = result[1].quality

        if quality ~= 100 then
            lib.notify({ title = locale('cl_lang_20'), type = 'info', duration = 7000 })
            return
        end

        LocalPlayer.state:set("inv_busy", true, true) -- lock inventory
        lib.progressBar({
            duration = Config.CollectTime,
            position = 'bottom',
            useWhileDead = false,
            canCancel = false,
            disableControl = true,
            disable = {
                move = true,
                mouse = true,
            },
            label = locale('cl_lang_21'),
        })
        LocalPlayer.state:set("inv_busy", false, true) -- unlock inventory

        local propcoords = GetEntityCoords(data.entity)
        local fxcoords = vector3(propcoords.x, propcoords.y, propcoords.z)
        UseParticleFxAsset(fx_group)
        smoke = StartParticleFxNonLoopedAtCoord(fx_name, fxcoords, 0.0, 0.0, 0.0, fx_scale, false, false, false, true)
        TriggerServerEvent('rex-trapfishing:server:destroyProp', data.trapid)

    end, data.trapid)

end)

---------------------------------------------
-- place prop
---------------------------------------------
RegisterNetEvent('rex-trapfishing:client:placeNewProp')
AddEventHandler('rex-trapfishing:client:placeNewProp', function(proptype, pHash, item, pos, heading)

    RSGCore.Functions.TriggerCallback('rex-trapfishing:server:countprop', function(result)

        if proptype == 'fishtrap' and result >= Config.MaxTraps then
            lib.notify({ title = locale('cl_lang_22'), description = locale('cl_lang_23'), type = 'error', duration = 7000 })
            return
        end

        if not isBusy then

            local water = Citizen.InvokeNative(0x5BA7A68A346A5A91, pos.x, pos.y, pos.z)

            for k,v in pairs(Config.WaterTypes) do 
                if water == Config.WaterTypes[k]["waterhash"] then
                    canPlace = true
                    break
                end
            end

            if canPlace and water ~= false then
                isBusy = true
                LocalPlayer.state:set("inv_busy", true, true) -- lock inventory
                local anim1 = `WORLD_HUMAN_CROUCH_INSPECT`
                FreezeEntityPosition(cache.ped, true)
                TaskStartScenarioInPlace(cache.ped, anim1, 0, true)
                Wait(10000)
                ClearPedTasks(cache.ped)
                FreezeEntityPosition(cache.ped, false)
                TriggerServerEvent('rex-trapfishing:server:newProp', proptype, pos, heading, pHash)
                LocalPlayer.state:set("inv_busy", false, true) -- unlock inventory
                isBusy = false
                canPlace = true
            else
                lib.notify({ title = locale('cl_lang_24'), type = 'error', duration = 7000 })
            end
            
        else
            lib.notify({ title = locale('cl_lang_25'), type = 'error', duration = 7000 })
        end

    end, proptype)

end)

---------------------------------------------
-- update props
---------------------------------------------
RegisterNetEvent('rex-trapfishing:client:updatePropData')
AddEventHandler('rex-trapfishing:client:updatePropData', function(data)
    Config.PlayerProps = data
end)

---------------------------------------------
-- remove prop object
---------------------------------------------
RegisterNetEvent('rex-trapfishing:client:removePropObject')
AddEventHandler('rex-trapfishing:client:removePropObject', function(prop)
    for i = 1, #SpawnedProps do
        local o = SpawnedProps[i]

        if o.id == prop then
            SetEntityAsMissionEntity(o.obj, false)
            FreezeEntityPosition(o.obj, false)
            DeleteObject(o.obj)
        end
    end
end)

---------------------------------------------
-- clean up
---------------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for i = 1, #SpawnedProps do
        local props = SpawnedProps[i].obj

        SetEntityAsMissionEntity(props, false)
        FreezeEntityPosition(props, false)
        DeleteObject(props)
    end
end)
