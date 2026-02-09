local module = {}

-- // Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- // Dependencies
local WeaponsEnum = require(script.Parent.WeaponsEnum)

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
	[WeaponsEnum.STICK] = {
		Name = 'Wooden Stick',
		Description = 'A simple stick found in the backyard.',

		Damage = 10,
		Cooldown = 0.5,
		Range = 10,

		Rarity = 'Common',
		ModelName = 'WoodenStick',
	},
}

return Weapons
