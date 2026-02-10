local module = {}

-- // Type Definitions
export type DropRange = {
	Min: number,
	Max: number,
}

export type PinataConfig = {
	Name: string,
	Description: string,
	
	-- Progression
	RequiredXP: number, 

	-- Stats
	MaxHealth: number, 
	Defense: number?,

	-- Rewards
	Drops: {
		Coins: DropRange,
		Gems: DropRange?,
	},

	-- Visuals
	ModelName: string,
	Scale: number,
	RopeLength: number,
}

-- Configuração por Nível (Index = Level)
local PinataLevels: { [number]: PinataConfig } = {
	[1] = {
		Name = 'Pocket Pinata',
		Description = 'A small but sweet companion!',
		RequiredXP = 100,
		MaxHealth = 100, -- 1.0x
		Drops = { Coins = { Min = 50, Max = 80 } }, -- Baseado no antigo (Lv 1 * 50)
		ModelName = 'Pocket Pinata',
		Scale = 0.8,
		RopeLength = 23,
	},
	[2] = {
		Name = 'Donkey',
		Description = 'A classic party animal.',
		RequiredXP = 350,
		MaxHealth = 150, -- 1.5x
		Drops = { Coins = { Min = 100, Max = 150 } },
		ModelName = 'Donkey',
		Scale = 1.0,
		RopeLength = 23,
	},
	[3] = {
		Name = 'Lhama',
		Description = 'Spits candy, not saliva.',
		RequiredXP = 750,
		MaxHealth = 220, -- 2.2x
		Drops = { Coins = { Min = 150, Max = 200 } },
		ModelName = 'Lhama',
		Scale = 1.1,
		RopeLength = 22,
	},
	[4] = {
		Name = 'Bettle',
		Description = 'Hard shell, sweet center.',
		RequiredXP = 1500,
		MaxHealth = 350, -- 3.5x
		Drops = { Coins = { Min = 200, Max = 300 } },
		ModelName = 'Bettle',
		Scale = 1.0,
		RopeLength = 22,
	},
	[5] = {
		Name = 'Puffer',
		Description = 'Don\'t touch the spikes!',
		RequiredXP = 2800,
		MaxHealth = 500, -- 5.0x
		Drops = { Coins = { Min = 250, Max = 400 } },
		ModelName = 'Puffer',
		Scale = 1.2,
		RopeLength = 25,
	},
	[6] = {
		Name = 'Shark',
		Description = 'King of the candy ocean.',
		RequiredXP = 5000,
		MaxHealth = 750, -- 7.5x
		Drops = { Coins = { Min = 300, Max = 500 } },
		ModelName = 'Shark',
		Scale = 1.4,
		RopeLength = 25,
	},
	[7] = {
		Name = 'Unicorn',
		Description = 'Magical and full of loot.',
		RequiredXP = 8500,
		MaxHealth = 1100, -- 11.0x
		Drops = { Coins = { Min = 400, Max = 600 } },
		ModelName = 'Unicorn',
		Scale = 1.3,
		RopeLength = 28,
	},
	[8] = {
		Name = 'GoldSeeker',
		Description = 'Rich in flavor and coins.',
		RequiredXP = 14000,
		MaxHealth = 1600, -- 16.0x
		Drops = { Coins = { Min = 500, Max = 800 } },
		ModelName = 'GoldSeeker',
		Scale = 1.4,
		RopeLength = 28,
	},
	[9] = {
		Name = 'DragonPinata',
		Description = 'A legendary beast.',
		RequiredXP = 22000,
		MaxHealth = 2500, -- 25.0x
		Drops = { Coins = { Min = 800, Max = 1200 } },
		ModelName = 'DragonPinata',
		Scale = 1.8,
		RopeLength = 35,
	},
	[10] = {
		Name = 'HydraLhama',
		Description = 'Three heads are better than one.',
		RequiredXP = 35000,
		MaxHealth = 4000, -- 40.0x
		Drops = { Coins = { Min = 1500, Max = 2500 } },
		ModelName = 'HydraLhama',
		Scale = 2.2,
		RopeLength = 40,
	},
	[11] = {
		Name = 'BlackHole',
		Description = 'Infinite density of candy.',
		RequiredXP = 55000,
		MaxHealth = 10000, -- 100.0x
		Drops = { Coins = { Min = 5000, Max = 10000 } },
		ModelName = 'BlackHole',
		Scale = 1.0,
		RopeLength = 40,
	},
}

return PinataLevels