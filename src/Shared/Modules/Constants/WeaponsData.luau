local module = {}

-- // Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- // Types
export type WeaponConfig = {
	Name: string,
	Description: string,

	Damage: number,
	Cooldown: number,
	Range: number,

	Rarity: 'Common' | 'Uncommon' | 'Rare' | 'Epic' | 'Legendary',
	ModelName: string,

	Price: number?,
}

local Weapons: { [string]: WeaponConfig } = {
	["RustyKnife"] = {
		Name = "Rusty Knife",
		ModelName = "RustyKnife",
		Rarity = "Common",
		Damage = 5,
		Cooldown = 0.8,
		Price = 0,
		Description = "Better than using your hands."
	},
	["Club"] = {
		Name = "Wooden Club",
		ModelName = "Club",
		Rarity = "Common",
		Damage = 12,
		Cooldown = 0.9,
		Price = 150,
		Description = "A solid piece of wood."
	},
	["BigClub"] = {
		Name = "Big Club",
		ModelName = "BigClub",
		Rarity = "Uncommon",
		Damage = 25,
		Cooldown = 1.2,
		Price = 450,
		Description = "Heavy and reliable."
	},
	["Axe"] = {
		Name = "Iron Axe",
		ModelName = "Axe",
		Rarity = "Uncommon",
		Damage = 40,
		Cooldown = 0.7,
		Price = 1200,
		Description = "Cuts through candy like butter."
	},
	["Hammer"] = {
		Name = "Steel Hammer",
		ModelName = "Hammer",
		Rarity = "Rare",
		Damage = 75,
		Cooldown = 1.0,
		Price = 3500,
		Description = "Smash everything in sight."
	},
	["Scythe"] = {
		Name = "Scythe",
		ModelName = "Scythe",
		Rarity = "Epic",
		Damage = 150,
		Cooldown = 0.5,
		Price = 8000,
		Description = "The reaper of pinatas."
	},
	["DevilScythe"] = {
		Name = "Devil Scythe",
		ModelName = "DevilScythe",
		Rarity = "Legendary",
		Damage = 350,
		Cooldown = 0.4,
		Price = 25000,
		Description = "Straight from the underworld."
	},
	["Excalibur"] = {
		Name = "Excalibur",
		ModelName = "Excalibur",
		Rarity = "Mythical",
		Damage = 800,
		Cooldown = 0.3,
		Price = 100000,
		Description = "The sword of the king."
	},
	["Mjolnir"] = {
		Name = "Mjolnir",
		ModelName = "Mjolnir",
		Rarity = "Godly",
		Damage = 2500,
		Cooldown = 0.2,
		Price = 1000000,
		Description = "The power of thunder."
	}
}

return Weapons
