local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local deployedSpikeStrips = {}
local deployedSpikeBoxes = {}

-- Initialize
CreateThread(function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

-- Update player data on job update
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

-- Check if player is police
local function IsPolice()
    if not PlayerData.job then return false end
    for _, job in ipairs(Config.PoliceJobs) do
        if PlayerData.job.name == job then
            return true
        end
    end
    return false
end

-- Helper function to play animation
local function PlayAnimation(animDict, animName, duration)
    if not Config.UseAnimations then return end
    
    local ped = PlayerPedId()
    
    -- Request animation dictionary
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(1)
    end
    
    -- Play animation
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, duration, 1, 0, false, false, false)
    
    -- Wait for animation to complete
    Wait(duration)
    
    -- Clear animation
    ClearPedTasks(ped)
    RemoveAnimDict(animDict)
end

-- Deploy spike strip
local function DeploySpikeStrip()
    if not IsPolice() then
        QBCore.Functions.Notify('You are not authorized to use this item', 'error')
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    -- Calculate placement position
    local forwardVector = GetEntityForwardVector(ped)
    local placeCoords = vector3(
        coords.x + forwardVector.x * Config.PlacementDistance,
        coords.y + forwardVector.y * Config.PlacementDistance,
        coords.z
    )

    -- Ground check
    local groundZ = 0.0
    local foundGround, groundZ = GetGroundZFor_3dCoord(placeCoords.x, placeCoords.y, placeCoords.z + 1.0, false)
    if foundGround then
        placeCoords = vector3(placeCoords.x, placeCoords.y, groundZ)
    end

    -- Play placement animation
    if Config.UseAnimations then
        QBCore.Functions.Notify('Placing spike strip...', 'primary')
        PlayAnimation(Config.PlaceAnimation.dict, Config.PlaceAnimation.anim, Config.PlaceAnimation.duration)
    end

    -- Load model
    local model = GetHashKey(Config.SpikeStripModel)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(1)
    end

    -- Load spike strip animation dictionary
    local stingerDict = "p_ld_stinger_s"
    RequestAnimDict(stingerDict)
    while not HasAnimDictLoaded(stingerDict) do
        Wait(1)
    end

    -- Create spike strip object
    local spikeStrip = CreateObject(model, placeCoords.x, placeCoords.y, placeCoords.z, true, true, false)
    SetEntityHeading(spikeStrip, heading)
    PlaceObjectOnGroundProperly(spikeStrip)
    FreezeEntityPosition(spikeStrip, true)

    -- Wait a frame to ensure entity is properly created
    Wait(100)
    
    -- Play deployment animation
    PlayEntityAnim(spikeStrip, "p_stinger_s_deploy", stingerDict, 1000.0, false, true, false, 0.0, 0)

    -- Add to deployed list
    local netId = NetworkGetNetworkIdFromEntity(spikeStrip)
    deployedSpikeStrips[netId] = {
        object = spikeStrip,
        coords = GetEntityCoords(spikeStrip),
        deployer = GetPlayerServerId(PlayerId())
    }

    -- Register with qb-target for pickup
    exports['qb-target']:AddTargetEntity(spikeStrip, {
        options = {
            {
                type = "client",
                event = "muffin_spikestrip:client:pickupSpikeStrip",
                icon = "fas fa-hand-paper",
                label = "Pick up Spike Strip",
                canInteract = function()
                    return IsPolice()
                end
            }
        },
        distance = 3.0
    })

    -- Notify server
    TriggerServerEvent('muffin_spikestrip:server:deploySpikeStrip', netId, GetEntityCoords(spikeStrip))
    
    QBCore.Functions.Notify('Spike strip deployed', 'success')
    
    -- Clean up loaded assets
    SetModelAsNoLongerNeeded(model)
    RemoveAnimDict(stingerDict)
end

-- Deploy spike box
local function DeploySpikeBox()
    if not IsPolice() then
        QBCore.Functions.Notify('You are not authorized to use this item', 'error')
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    -- Calculate placement position (closer than regular spike strips)
    local forwardVector = GetEntityForwardVector(ped)
    local placeCoords = vector3(
        coords.x + forwardVector.x * Config.SpikeBoxPlacementDistance,
        coords.y + forwardVector.y * Config.SpikeBoxPlacementDistance,
        coords.z
    )

    -- Ground check
    local groundZ = 0.0
    local foundGround, groundZ = GetGroundZFor_3dCoord(placeCoords.x, placeCoords.y, placeCoords.z + 1.0, false)
    if foundGround then
        placeCoords = vector3(placeCoords.x, placeCoords.y, groundZ)
    end

    -- Play placement animation
    if Config.UseAnimations then
        QBCore.Functions.Notify('Placing spike box...', 'primary')
        PlayAnimation(Config.PlaceAnimation.dict, Config.PlaceAnimation.anim, Config.PlaceAnimation.duration)
    end

    -- Load model
    local model = GetHashKey(Config.SpikeBoxModel)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(1)
    end

    -- Create spike box object
    local spikeBox = CreateObject(model, placeCoords.x, placeCoords.y, placeCoords.z, true, true, false)
    SetEntityHeading(spikeBox, heading)
    PlaceObjectOnGroundProperly(spikeBox)
    FreezeEntityPosition(spikeBox, true)

    -- Wait a frame to ensure entity is properly created
    Wait(100)

    -- Add to deployed list
    local netId = NetworkGetNetworkIdFromEntity(spikeBox)
    deployedSpikeBoxes[netId] = {
        object = spikeBox,
        coords = GetEntityCoords(spikeBox),
        heading = heading,
        deployer = GetPlayerServerId(PlayerId()),
        activated = false,
        spikeStrip1 = nil,  -- First row of spikes
        spikeStrip2 = nil,  -- Second row of spikes
        spikeStrip3 = nil   -- Third row of spikes
    }

    -- Register with qb-target for pickup and activation
    exports['qb-target']:AddTargetEntity(spikeBox, {
        options = {
            {
                type = "client",
                event = "muffin_spikestrip:client:toggleSpikeBoxLocal",
                icon = "fas fa-power-off",
                label = "Toggle Spike Box",
                canInteract = function()
                    return IsPolice()
                end
            },
            {
                type = "client",
                event = "muffin_spikestrip:client:pickupSpikeBox",
                icon = "fas fa-hand-paper",
                label = "Pick up Spike Box",
                canInteract = function()
                    return IsPolice()
                end
            }
        },
        distance = 3.0
    })

    -- Notify server
    TriggerServerEvent('muffin_spikestrip:server:deploySpikeBox', netId, GetEntityCoords(spikeBox), heading)
    
    QBCore.Functions.Notify('Spike box deployed', 'success')
    SetModelAsNoLongerNeeded(model)
end

-- Pick up spike strip
RegisterNetEvent('muffin_spikestrip:client:pickupSpikeStrip', function(data)
    local entity = data.entity
    local netId = NetworkGetNetworkIdFromEntity(entity)
    
    if deployedSpikeStrips[netId] then
        -- Play pickup animation
        if Config.UseAnimations then
            QBCore.Functions.Notify('Picking up spike strip...', 'primary')
            PlayAnimation(Config.PickupAnimation.dict, Config.PickupAnimation.anim, Config.PickupAnimation.duration)
        end
        
        -- Remove from qb-target
        exports['qb-target']:RemoveTargetEntity(entity)
        
        -- Delete object
        DeleteEntity(entity)
        
        -- Remove from list
        deployedSpikeStrips[netId] = nil
        
        -- Notify server
        TriggerServerEvent('muffin_spikestrip:server:pickupSpikeStrip', netId)
        
        QBCore.Functions.Notify('Spike strip picked up', 'success')
    end
end)

-- Pick up spike box
RegisterNetEvent('muffin_spikestrip:client:pickupSpikeBox', function(data)
    local entity = data.entity
    local netId = NetworkGetNetworkIdFromEntity(entity)
    
    if deployedSpikeBoxes[netId] then
        -- If spike box has active spike strips, remove them first
        if deployedSpikeBoxes[netId].spikeStrip1 then
            DeleteEntity(deployedSpikeBoxes[netId].spikeStrip1)
        end
        if deployedSpikeBoxes[netId].spikeStrip2 then
            DeleteEntity(deployedSpikeBoxes[netId].spikeStrip2)
        end
        if deployedSpikeBoxes[netId].spikeStrip3 then
            DeleteEntity(deployedSpikeBoxes[netId].spikeStrip3)
        end
        
        -- Play pickup animation
        if Config.UseAnimations then
            QBCore.Functions.Notify('Picking up spike box...', 'primary')
            PlayAnimation(Config.PickupAnimation.dict, Config.PickupAnimation.anim, Config.PickupAnimation.duration)
        end
        
        -- Remove from qb-target
        exports['qb-target']:RemoveTargetEntity(entity)
        
        -- Delete object
        DeleteEntity(entity)
        
        -- Remove from list
        deployedSpikeBoxes[netId] = nil
        
        -- Notify server
        TriggerServerEvent('muffin_spikestrip:server:pickupSpikeBox', netId)
        
        QBCore.Functions.Notify('Spike box picked up', 'success')
    end
end)

-- Toggle spike box locally (triggers server event)
RegisterNetEvent('muffin_spikestrip:client:toggleSpikeBoxLocal', function(data)
    local entity = data.entity
    local netId = NetworkGetNetworkIdFromEntity(entity)
    
    if deployedSpikeBoxes[netId] then
        TriggerServerEvent('muffin_spikestrip:server:activateSpikeBox', netId)
    end
end)

-- Toggle spike box (called from server)
RegisterNetEvent('muffin_spikestrip:client:toggleSpikeBox', function(netId, activated)
    if deployedSpikeBoxes[netId] then
        deployedSpikeBoxes[netId].activated = activated
        local boxData = deployedSpikeBoxes[netId]
        
        if activated then
            -- Deploy spike strips sequentially with animations
            CreateThread(function()
                -- Deploy first row of spike strips (closest to box)
                local forwardVector = GetEntityForwardVector(boxData.object)
                local spikeCoords1 = vector3(
                    boxData.coords.x + forwardVector.x * Config.SpikeBoxDeployDistance1,
                    boxData.coords.y + forwardVector.y * Config.SpikeBoxDeployDistance1,
                    boxData.coords.z
                )
                
                -- Deploy second row of spike strips (middle)
                local spikeCoords2 = vector3(
                    boxData.coords.x + forwardVector.x * Config.SpikeBoxDeployDistance2,
                    boxData.coords.y + forwardVector.y * Config.SpikeBoxDeployDistance2,
                    boxData.coords.z
                )
                
                -- Deploy third row of spike strips (furthest from box)
                local spikeCoords3 = vector3(
                    boxData.coords.x + forwardVector.x * Config.SpikeBoxDeployDistance3,
                    boxData.coords.y + forwardVector.y * Config.SpikeBoxDeployDistance3,
                    boxData.coords.z
                )
                
                -- Ground check for first spike strip
                local groundZ1 = 0.0
                local foundGround1, groundZ1 = GetGroundZFor_3dCoord(spikeCoords1.x, spikeCoords1.y, spikeCoords1.z + 1.0, false)
                if foundGround1 then
                    spikeCoords1 = vector3(spikeCoords1.x, spikeCoords1.y, groundZ1)
                end
                
                -- Ground check for second spike strip
                local groundZ2 = 0.0
                local foundGround2, groundZ2 = GetGroundZFor_3dCoord(spikeCoords2.x, spikeCoords2.y, spikeCoords2.z + 1.0, false)
                if foundGround2 then
                    spikeCoords2 = vector3(spikeCoords2.x, spikeCoords2.y, groundZ2)
                end
                
                -- Ground check for third spike strip
                local groundZ3 = 0.0
                local foundGround3, groundZ3 = GetGroundZFor_3dCoord(spikeCoords3.x, spikeCoords3.y, spikeCoords3.z + 1.0, false)
                if foundGround3 then
                    spikeCoords3 = vector3(spikeCoords3.x, spikeCoords3.y, groundZ3)
                end
                
                -- Load spike strip model
                local model = GetHashKey(Config.SpikeStripModel)
                RequestModel(model)
                while not HasModelLoaded(model) do
                    Wait(1)
                end
                
                -- Load spike strip animation dictionary
                local stingerDict = "p_ld_stinger_s"
                RequestAnimDict(stingerDict)
                while not HasAnimDictLoaded(stingerDict) do
                    Wait(1)
                end
                
                -- FIRST SPIKE STRIP
                local spikeStrip1 = CreateObject(model, spikeCoords1.x, spikeCoords1.y, spikeCoords1.z, true, true, false)
                SetEntityHeading(spikeStrip1, boxData.heading)
                PlaceObjectOnGroundProperly(spikeStrip1)
                FreezeEntityPosition(spikeStrip1, true)
                
                -- Wait a moment for entity to be fully created
                Wait(50)
                
                -- Play deployment animation for first spike strip
                PlayEntityAnim(spikeStrip1, "p_stinger_s_deploy", stingerDict, 1000.0, false, true, false, 0.0, 0)
                boxData.spikeStrip1 = spikeStrip1
                
                QBCore.Functions.Notify('First row deployed...', 'primary')
                
                -- Wait for first animation to complete (1 second)
                Wait(Config.SpikeDeployDelay)
                
                -- SECOND SPIKE STRIP
                local spikeStrip2 = CreateObject(model, spikeCoords2.x, spikeCoords2.y, spikeCoords2.z, true, true, false)
                SetEntityHeading(spikeStrip2, boxData.heading)
                PlaceObjectOnGroundProperly(spikeStrip2)
                FreezeEntityPosition(spikeStrip2, true)
                
                -- Wait a moment for entity to be fully created
                Wait(50)
                
                -- Play deployment animation for second spike strip
                PlayEntityAnim(spikeStrip2, "p_stinger_s_deploy", stingerDict, 1000.0, false, true, false, 0.0, 0)
                boxData.spikeStrip2 = spikeStrip2
                
                QBCore.Functions.Notify('Second row deployed...', 'primary')
                
                -- Wait for second animation to complete (1 second)
                Wait(Config.SpikeDeployDelay)
                
                -- THIRD SPIKE STRIP
                local spikeStrip3 = CreateObject(model, spikeCoords3.x, spikeCoords3.y, spikeCoords3.z, true, true, false)
                SetEntityHeading(spikeStrip3, boxData.heading)
                PlaceObjectOnGroundProperly(spikeStrip3)
                FreezeEntityPosition(spikeStrip3, true)
                
                -- Wait a moment for entity to be fully created
                Wait(50)
                
                -- Play deployment animation for third spike strip
                PlayEntityAnim(spikeStrip3, "p_stinger_s_deploy", stingerDict, 1000.0, false, true, false, 0.0, 0)
                boxData.spikeStrip3 = spikeStrip3
                
                QBCore.Functions.Notify('Third row deployed - All spikes active!', 'success')
                
                -- Clean up loaded assets
                SetModelAsNoLongerNeeded(model)
                RemoveAnimDict(stingerDict)
            end)
        else
            -- Retract spike strips sequentially with animations
            CreateThread(function()
                if boxData.spikeStrip1 or boxData.spikeStrip2 or boxData.spikeStrip3 then
                    -- Load animation dictionary for retraction
                    local stingerDict = "p_ld_stinger_s"
                    RequestAnimDict(stingerDict)
                    while not HasAnimDictLoaded(stingerDict) do
                        Wait(1)
                    end
                    
                    -- Retract in reverse order (third, second, first)
                    
                    -- RETRACT THIRD SPIKE STRIP
                    if boxData.spikeStrip3 then
                        PlayEntityAnim(boxData.spikeStrip3, "p_stinger_s_idle_deployed", stingerDict, 500.0, false, true, false, 0.0, 0)
                        QBCore.Functions.Notify('Retracting third row...', 'primary')
                        Wait(500)
                        DeleteEntity(boxData.spikeStrip3)
                        boxData.spikeStrip3 = nil
                    end
                    
                    -- RETRACT SECOND SPIKE STRIP
                    if boxData.spikeStrip2 then
                        PlayEntityAnim(boxData.spikeStrip2, "p_stinger_s_idle_deployed", stingerDict, 500.0, false, true, false, 0.0, 0)
                        QBCore.Functions.Notify('Retracting second row...', 'primary')
                        Wait(500)
                        DeleteEntity(boxData.spikeStrip2)
                        boxData.spikeStrip2 = nil
                    end
                    
                    -- RETRACT FIRST SPIKE STRIP
                    if boxData.spikeStrip1 then
                        PlayEntityAnim(boxData.spikeStrip1, "p_stinger_s_idle_deployed", stingerDict, 500.0, false, true, false, 0.0, 0)
                        QBCore.Functions.Notify('Retracting first row...', 'primary')
                        Wait(500)
                        DeleteEntity(boxData.spikeStrip1)
                        boxData.spikeStrip1 = nil
                    end
                    
                    RemoveAnimDict(stingerDict)
                    QBCore.Functions.Notify('All spikes retracted!', 'success')
                else
                    -- No spike strips to retract
                    QBCore.Functions.Notify('Spike box deactivated - no spikes deployed!', 'primary')
                end
            end)
        end
    end
end)

-- Sync spike strips from server
RegisterNetEvent('muffin_spikestrip:client:syncSpikeStrips', function(serverSpikeStrips)
    for netId, data in pairs(serverSpikeStrips) do
        if not deployedSpikeStrips[netId] then
            -- Create spike strip object
            local model = GetHashKey(Config.SpikeStripModel)
            RequestModel(model)
            while not HasModelLoaded(model) do
                Wait(1)
            end

            local spikeStrip = CreateObject(model, data.coords.x, data.coords.y, data.coords.z, true, true, false)
            SetEntityHeading(spikeStrip, data.heading or 0.0)
            PlaceObjectOnGroundProperly(spikeStrip)
            FreezeEntityPosition(spikeStrip, true)

            -- Wait a frame to ensure entity is properly created
            Wait(100)

            deployedSpikeStrips[netId] = {
                object = spikeStrip,
                coords = data.coords,
                deployer = data.deployer
            }

            -- Add to qb-target
            exports['qb-target']:AddTargetEntity(spikeStrip, {
                options = {
                    {
                        type = "client",
                        event = "muffin_spikestrip:client:pickupSpikeStrip",
                        icon = "fas fa-hand-paper",
                        label = "Pick up Spike Strip",
                        canInteract = function()
                            return IsPolice()
                        end
                    }
                },
                distance = 3.0
            })

            SetModelAsNoLongerNeeded(model)
        end
    end
end)

-- Sync spike boxes from server
RegisterNetEvent('muffin_spikestrip:client:syncSpikeBoxes', function(serverSpikeBoxes)
    for netId, data in pairs(serverSpikeBoxes) do
        if not deployedSpikeBoxes[netId] then
            -- Create spike box object
            local model = GetHashKey(Config.SpikeBoxModel)
            RequestModel(model)
            while not HasModelLoaded(model) do
                Wait(1)
            end

            local spikeBox = CreateObject(model, data.coords.x, data.coords.y, data.coords.z, true, true, false)
            SetEntityHeading(spikeBox, data.heading)
            PlaceObjectOnGroundProperly(spikeBox)
            FreezeEntityPosition(spikeBox, true)

            -- Wait a frame to ensure entity is properly created
            Wait(100)

            deployedSpikeBoxes[netId] = {
                object = spikeBox,
                coords = data.coords,
                heading = data.heading,
                deployer = data.deployer,
                activated = data.activated or false,
                spikeStrip1 = nil,
                spikeStrip2 = nil,
                spikeStrip3 = nil
            }

            -- Add to qb-target
            exports['qb-target']:AddTargetEntity(spikeBox, {
                options = {
                    {
                        type = "client",
                        event = "muffin_spikestrip:client:toggleSpikeBoxLocal",
                        icon = "fas fa-power-off",
                        label = "Toggle Spike Box",
                        canInteract = function()
                            return IsPolice()
                        end
                    },
                    {
                        type = "client",
                        event = "muffin_spikestrip:client:pickupSpikeBox",
                        icon = "fas fa-hand-paper",
                        label = "Pick up Spike Box",
                        canInteract = function()
                            return IsPolice()
                        end
                    }
                },
                distance = 3.0
            })

            SetModelAsNoLongerNeeded(model)
        end
    end
end)

-- Remove spike strip (called from server)
RegisterNetEvent('muffin_spikestrip:client:removeSpikeStrip', function(netId)
    if deployedSpikeStrips[netId] then
        local entity = deployedSpikeStrips[netId].object
        exports['qb-target']:RemoveTargetEntity(entity)
        DeleteEntity(entity)
        deployedSpikeStrips[netId] = nil
    end
end)

-- Remove spike box (called from server)
RegisterNetEvent('muffin_spikestrip:client:removeSpikeBox', function(netId)
    if deployedSpikeBoxes[netId] then
        local boxData = deployedSpikeBoxes[netId]
        
        -- Remove all spike strips if active
        if boxData.spikeStrip1 then
            DeleteEntity(boxData.spikeStrip1)
        end
        if boxData.spikeStrip2 then
            DeleteEntity(boxData.spikeStrip2)
        end
        if boxData.spikeStrip3 then
            DeleteEntity(boxData.spikeStrip3)
        end
        
        -- Remove box
        exports['qb-target']:RemoveTargetEntity(boxData.object)
        DeleteEntity(boxData.object)
        deployedSpikeBoxes[netId] = nil
    end
end)

-- Enhanced tire damage system (now checks all three spike strips from spike boxes)
CreateThread(function()
    local lastSpikeHit = {}
    
    while true do
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        
        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == playerPed then
            local vehicleCoords = GetEntityCoords(vehicle)
            local vehicleSpeed = GetEntitySpeed(vehicle)
            
            if vehicleSpeed > Config.SpeedThreshold then
                -- Check regular spike strips
                for netId, spikeData in pairs(deployedSpikeStrips) do
                    local distance = #(vehicleCoords - spikeData.coords)
                    
                    if distance < Config.DamageDistance then
                        if not lastSpikeHit[netId] or GetGameTimer() - lastSpikeHit[netId] > 100 then
                            if math.random() < Config.TirePopChance then
                                -- Pop tires logic (same as before)
                                local spikeCoords = spikeData.coords
                                local vehForward = GetEntityForwardVector(vehicle)
                                local vehRight = vector3(vehForward.y, -vehForward.x, 0.0)
                                
                                local tiresToCheck = {
                                    {index = 0, offset = vector3(-0.8, 1.2, 0)},
                                    {index = 1, offset = vector3(0.8, 1.2, 0)},
                                    {index = 4, offset = vector3(-0.8, -1.2, 0)},
                                    {index = 5, offset = vector3(0.8, -1.2, 0)}
                                }
                                
                                local tiresOverSpike = 0
                                local tiresToPop = {}
                                
                                for _, tire in ipairs(tiresToCheck) do
                                    local tirePos = vehicleCoords + 
                                        (vehForward * tire.offset.y) + 
                                        (vehRight * tire.offset.x)
                                    
                                    local tireDistance = #(tirePos - spikeCoords)
                                    
                                    if tireDistance < 2.5 then
                                        tiresOverSpike = tiresOverSpike + 1
                                        table.insert(tiresToPop, tire.index)
                                    end
                                end
                                
                                local tiresPopped = false
                                
                                if tiresOverSpike >= 3 then
                                    for _, tireIndex in ipairs({0, 1, 4, 5}) do
                                        if not IsVehicleTyreBurst(vehicle, tireIndex, false) then
                                            SetVehicleTyreBurst(vehicle, tireIndex, true, 1000.0)
                                            tiresPopped = true
                                        end
                                    end
                                    lastSpikeHit[netId] = GetGameTimer()
                                elseif tiresOverSpike > 0 then
                                    for _, tireIndex in ipairs(tiresToPop) do
                                        if not IsVehicleTyreBurst(vehicle, tireIndex, false) then
                                            SetVehicleTyreBurst(vehicle, tireIndex, true, 1000.0)
                                            tiresPopped = true
                                        end
                                    end
                                    lastSpikeHit[netId] = GetGameTimer()
                                end
                                
                                if tiresPopped then
                                    -- Play sound effect
                                    PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", false)
                                    
                                    break -- Exit loop to prevent multiple hits in same frame
                                end
                            end
                        end
                    end
                end
                
                -- Check spike box spike strips (all three rows)
                for netId, boxData in pairs(deployedSpikeBoxes) do
                    if boxData.activated then
                        -- Check all three spike strips
                        local spikeStrips = {
                            {strip = boxData.spikeStrip1, id = "box1_" .. netId},
                            {strip = boxData.spikeStrip2, id = "box2_" .. netId},
                            {strip = boxData.spikeStrip3, id = "box3_" .. netId}
                        }
                        
                        for _, spikeInfo in ipairs(spikeStrips) do
                            if spikeInfo.strip then
                                local spikeCoords = GetEntityCoords(spikeInfo.strip)
                                local distance = #(vehicleCoords - spikeCoords)
                                
                                if distance < Config.DamageDistance then
                                    if not lastSpikeHit[spikeInfo.id] or GetGameTimer() - lastSpikeHit[spikeInfo.id] > 100 then
                                        if math.random() < Config.TirePopChance then
                                            -- Same tire popping logic
                                            local vehForward = GetEntityForwardVector(vehicle)
                                            local vehRight = vector3(vehForward.y, -vehForward.x, 0.0)
                                            
                                            local tiresToCheck = {
                                                {index = 0, offset = vector3(-0.8, 1.2, 0)},
                                                {index = 1, offset = vector3(0.8, 1.2, 0)},
                                                {index = 4, offset = vector3(-0.8, -1.2, 0)},
                                                {index = 5, offset = vector3(0.8, -1.2, 0)}
                                            }
                                            
                                            local tiresOverSpike = 0
                                            local tiresToPop = {}
                                            
                                            for _, tire in ipairs(tiresToCheck) do
                                                local tirePos = vehicleCoords + 
                                                    (vehForward * tire.offset.y) + 
                                                    (vehRight * tire.offset.x)
                                                
                                                local tireDistance = #(tirePos - spikeCoords)
                                                
                                                if tireDistance < 2.5 then
                                                    tiresOverSpike = tiresOverSpike + 1
                                                    table.insert(tiresToPop, tire.index)
                                                end
                                            end
                                            
                                            local tiresPopped = false
                                            
                                            if tiresOverSpike >= 3 then
                                                for _, tireIndex in ipairs({0, 1, 4, 5}) do
                                                    if not IsVehicleTyreBurst(vehicle, tireIndex, false) then
                                                        SetVehicleTyreBurst(vehicle, tireIndex, true, 1000.0)
                                                        tiresPopped = true
                                                    end
                                                end
                                                lastSpikeHit[spikeInfo.id] = GetGameTimer()
                                            elseif tiresOverSpike > 0 then
                                                for _, tireIndex in ipairs(tiresToPop) do
                                                    if not IsVehicleTyreBurst(vehicle, tireIndex, false) then
                                                        SetVehicleTyreBurst(vehicle, tireIndex, true, 1000.0)
                                                        tiresPopped = true
                                                    end
                                                end
                                                lastSpikeHit[spikeInfo.id] = GetGameTimer()
                                            end
                                            
                                            if tiresPopped then
                                                -- Play sound effect
                                                PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", false)
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        Wait(100)
    end
end)

-- Use spike strip item
RegisterNetEvent('muffin_spikestrip:client:useSpikeStrip', function()
    DeploySpikeStrip()
end)

-- Use spike box item
RegisterNetEvent('muffin_spikestrip:client:useSpikeBox', function()
    DeploySpikeBox()
end)

-- Command to toggle spike boxes
RegisterCommand('togglespikebox', function(source, args, rawCommand)
    if not IsPolice() then
        QBCore.Functions.Notify('You are not authorized to use this command', 'error')
        return
    end
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestDistance = math.huge
    local closestSpikeBox = nil
    local closestNetId = nil
    
    -- Find the closest spike box
    for netId, boxData in pairs(deployedSpikeBoxes) do
        local distance = #(playerCoords - boxData.coords)
        if distance < closestDistance then
            closestDistance = distance
            closestSpikeBox = boxData
            closestNetId = netId
        end
    end
    
    -- Check if there's a spike box within reasonable range (10 units)
    if closestSpikeBox and closestDistance <= 30.0 then
        -- Toggle the closest spike box
        TriggerServerEvent('muffin_spikestrip:server:activateSpikeBox', closestNetId)
        
        local status = closestSpikeBox.activated and "deactivated" or "activated"
        QBCore.Functions.Notify('Spike box ' .. status .. ' (Distance: ' .. math.floor(closestDistance) .. 'm)', 'primary')
    else
        QBCore.Functions.Notify('No spike boxes found nearby', 'error')
    end
end, false)

-- Help command for spike box
RegisterCommand('spikeboxhelp', function(source, args, rawCommand)
    if not IsPolice() then
        QBCore.Functions.Notify('You are not authorized to use this command', 'error')
        return
    end
    
    QBCore.Functions.Notify('Spike Box Commands:', 'primary')
    QBCore.Functions.Notify('/togglespikebox - Toggle closest spike box', 'primary')
    QBCore.Functions.Notify('Use spikebox item to deploy new boxes', 'primary')
    QBCore.Functions.Notify('Use third-eye to toggle/pickup individual boxes', 'primary')
end, false)
