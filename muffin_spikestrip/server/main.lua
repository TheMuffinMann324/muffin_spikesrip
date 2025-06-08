local QBCore = exports['qb-core']:GetCoreObject()
local deployedSpikeStrips = {}
local deployedSpikeBoxes = {}

-- Register usable item for spike strip
QBCore.Functions.CreateUseableItem(Config.SpikeStripItem, function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    -- Check if player is police
    local isPolice = false
    for _, job in ipairs(Config.PoliceJobs) do
        if Player.PlayerData.job.name == job then
            isPolice = true
            break
        end
    end
    
    if not isPolice then
        TriggerClientEvent('QBCore:Notify', source, 'You are not authorized to use this item', 'error')
        return
    end
    
    -- Check spike strip limit per player
    local playerSpikeCount = 0
    for _, data in pairs(deployedSpikeStrips) do
        if data.deployer == source then
            playerSpikeCount = playerSpikeCount + 1
        end
    end
    
    if playerSpikeCount >= Config.MaxSpikeStrips then
        TriggerClientEvent('QBCore:Notify', source, 'You have reached the maximum number of deployed spike strips (' .. Config.MaxSpikeStrips .. ')', 'error')
        return
    end
    
    -- Remove item from inventory
    Player.Functions.RemoveItem(Config.SpikeStripItem, 1)
    TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[Config.SpikeStripItem], "remove")
    
    -- Trigger client event to deploy spike strip
    TriggerClientEvent('muffin_spikestrip:client:useSpikeStrip', source)
end)

-- Register usable item for spike box
QBCore.Functions.CreateUseableItem(Config.SpikeBoxItem, function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    -- Check if player is police
    local isPolice = false
    for _, job in ipairs(Config.PoliceJobs) do
        if Player.PlayerData.job.name == job then
            isPolice = true
            break
        end
    end
    
    if not isPolice then
        TriggerClientEvent('QBCore:Notify', source, 'You are not authorized to use this item', 'error')
        return
    end
    
    -- Check spike box limit per player
    local playerBoxCount = 0
    for _, data in pairs(deployedSpikeBoxes) do
        if data.deployer == source then
            playerBoxCount = playerBoxCount + 1
        end
    end
    
    if playerBoxCount >= Config.MaxSpikeBoxes then
        TriggerClientEvent('QBCore:Notify', source, 'You have reached the maximum number of deployed spike boxes (' .. Config.MaxSpikeBoxes .. ')', 'error')
        return
    end
    
    -- Remove item from inventory
    Player.Functions.RemoveItem(Config.SpikeBoxItem, 1)
    TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[Config.SpikeBoxItem], "remove")
    
    -- Trigger client event to deploy spike box
    TriggerClientEvent('muffin_spikestrip:client:useSpikeBox', source)
end)

-- Handle spike strip deployment
RegisterNetEvent('muffin_spikestrip:server:deploySpikeStrip', function(netId, coords)
    local src = source
    deployedSpikeStrips[netId] = {
        deployer = src,
        coords = coords,
        heading = 0.0
    }
    
    -- Sync with all clients
    TriggerClientEvent('muffin_spikestrip:client:syncSpikeStrips', -1, deployedSpikeStrips)
end)

-- Handle spike box deployment
RegisterNetEvent('muffin_spikestrip:server:deploySpikeBox', function(netId, coords, heading)
    local src = source
    deployedSpikeBoxes[netId] = {
        deployer = src,
        coords = coords,
        heading = heading,
        activated = false
    }
    
    -- Sync with all clients
    TriggerClientEvent('muffin_spikestrip:client:syncSpikeBoxes', -1, deployedSpikeBoxes)
end)

-- Handle spike strip pickup
RegisterNetEvent('muffin_spikestrip:server:pickupSpikeStrip', function(netId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    if deployedSpikeStrips[netId] then
        -- Give item back to player
        Player.Functions.AddItem(Config.SpikeStripItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.SpikeStripItem], "add")
        
        -- Remove from deployed list
        deployedSpikeStrips[netId] = nil
        
        -- Sync with all clients
        TriggerClientEvent('muffin_spikestrip:client:removeSpikeStrip', -1, netId)
    end
end)

-- Handle spike box pickup
RegisterNetEvent('muffin_spikestrip:server:pickupSpikeBox', function(netId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    if deployedSpikeBoxes[netId] then
        -- Give item back to player
        Player.Functions.AddItem(Config.SpikeBoxItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.SpikeBoxItem], "add")
        
        -- Remove from deployed list
        deployedSpikeBoxes[netId] = nil
        
        -- Sync with all clients
        TriggerClientEvent('muffin_spikestrip:client:removeSpikeBox', -1, netId)
    end
end)

-- Handle spike box activation
RegisterNetEvent('muffin_spikestrip:server:activateSpikeBox', function(netId)
    if deployedSpikeBoxes[netId] then
        deployedSpikeBoxes[netId].activated = not deployedSpikeBoxes[netId].activated
        
        -- Sync activation state with all clients
        TriggerClientEvent('muffin_spikestrip:client:toggleSpikeBox', -1, netId, deployedSpikeBoxes[netId].activated)
    end
end)

-- Player drop event (cleanup spike strips and boxes)
RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(src)
    local toRemoveStrips = {}
    for netId, data in pairs(deployedSpikeStrips) do
        if data.deployer == src then
            table.insert(toRemoveStrips, netId)
        end
    end
    
    local toRemoveBoxes = {}
    for netId, data in pairs(deployedSpikeBoxes) do
        if data.deployer == src then
            table.insert(toRemoveBoxes, netId)
        end
    end
    
    for _, netId in ipairs(toRemoveStrips) do
        deployedSpikeStrips[netId] = nil
        TriggerClientEvent('muffin_spikestrip:client:removeSpikeStrip', -1, netId)
    end
    
    for _, netId in ipairs(toRemoveBoxes) do
        deployedSpikeBoxes[netId] = nil
        TriggerClientEvent('muffin_spikestrip:client:removeSpikeBox', -1, netId)
    end
end)

-- Sync spike strips and boxes when player joins
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    TriggerClientEvent('muffin_spikestrip:client:syncSpikeStrips', src, deployedSpikeStrips)
    TriggerClientEvent('muffin_spikestrip:client:syncSpikeBoxes', src, deployedSpikeBoxes)
end)

-- Resource stop cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Clean up all spike strips and boxes
        TriggerClientEvent('muffin_spikestrip:client:syncSpikeStrips', -1, {})
        TriggerClientEvent('muffin_spikestrip:client:syncSpikeBoxes', -1, {})
    end
end)
