Config = {}

-- Item name for spike strip
Config.SpikeStripItem = 'spikestrip'

-- Item name for spike box (remote activation)
Config.SpikeBoxItem = 'spikebox'

-- Police job names that can use spike strips
Config.PoliceJobs = {
    'police',
    'bcso',
    'sasp',
    'lspd'
}

-- Spike strip model
Config.SpikeStripModel = 'p_ld_stinger_s'

-- Spike box model
Config.SpikeBoxModel = 'prop_rail_sigbox01' -- You can change this to any box prop

-- Distance to damage tires
Config.DamageDistance = 5.0

-- Spike strip placement distance from player
Config.PlacementDistance = 3.0

-- Spike box placement distance from player (closer than regular spike strips)
Config.SpikeBoxPlacementDistance = 1.5

-- Spike box spike deployment distances
Config.SpikeBoxDeployDistance1 = 2.0  -- First row of spikes (closest to box)
Config.SpikeBoxDeployDistance2 = 4.0  -- Second row of spikes (middle)
Config.SpikeBoxDeployDistance3 = 6.0  -- Third row of spikes (furthest from box)

-- Spike box animation timing
Config.SpikeDeployDelay = 1000  -- Delay between each spike deployment (in milliseconds)
Config.SpikeRetractDelay = 500  -- Delay between each spike retraction (in milliseconds)

-- Maximum number of spike strips per player
Config.MaxSpikeStrips = 5

-- Maximum number of spike boxes per player
Config.MaxSpikeBoxes = 3

-- Tire popping chance (0.0 to 1.0)
Config.TirePopChance = 1.0

-- Speed threshold for tire damage (in units per second)
Config.SpeedThreshold = 5.0

-- Animation settings
Config.UseAnimations = true -- Set to false to disable animations
Config.PlaceAnimation = {
    dict = "amb@world_human_gardener_plant@male@base",
    anim = "base",
    duration = 3000 -- 3 seconds
}
Config.PickupAnimation = {
    dict = "pickup_object",
    anim = "putdown_low",
    duration = 2000 -- 2 seconds
}
