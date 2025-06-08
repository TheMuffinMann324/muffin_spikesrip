# Muffin Spike Strip System

A comprehensive FiveM QBCore script that allows police officers to deploy and manage spike strips.

## Features

- **Police-only access** - Only authorized police jobs can deploy spike strips
- **Item-based deployment** - Uses a usable item to deploy spike strips
- **Third-eye interaction** - Pick up spike strips using qb-target
- **Tire damage system** - Automatically pops vehicle tires when driving over spike strips
- **Team sharing** - Any police officer can pick up any spike strip
- **Limit system** - Maximum number of spike strips per player
- **Sync system** - All players see the same spike strips
- **Cleanup** - Automatic cleanup when players disconnect

## Installation

1. Add the `spikestrip` item to your `qb-core/shared/items.lua`:

```lua
['spikestrip'] = {
    ['name'] = 'spikestrip',
    ['label'] = 'Spike Strip',
    ['weight'] = 5000,
    ['type'] = 'item',
    ['image'] = 'spikestrip.png',
    ['unique'] = false,
    ['useable'] = true,
    ['shouldClose'] = true,
    ['combinable'] = nil,
    ['description'] = 'A deployable spike strip used by police to stop vehicles'
}
```

2. Add the script to your `server.cfg`:
```
ensure muffin_spikestrip
```

3. Add an image named `spikestrip.png` to your inventory script's images folder.

## Configuration

Edit `config.lua` to customize:
- Police job names
- Spike strip model
- Damage settings
- Placement distance
- Maximum spike strips per player

## Dependencies

- qb-core
- qb-target

## Usage

1. Police officers receive or buy spike strip items
2. Use the item to deploy a spike strip in front of you
3. Spike strips automatically damage vehicle tires when driven over
4. Use third-eye (qb-target) to pick up spike strips
5. Any police officer can pick up any spike strip

## Support

For support or questions, contact the script author.
