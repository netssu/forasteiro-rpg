-- // Dependencies
local PinataEnums = require(script.Parent.PinataEnums)

-- // Type
export type DropRange = {
	Min: number,
	Max: number,
}

export type PinataConfig = {
	Name: string,
	Description: string,

	Health: number,
	Defense: number?,

	Drops: {
		Coins: DropRange,
		Gems: DropRange?,
	},

	ModelName: string,
	Scale: number,
	RopeLength: number,
}

local module: { [number]: PinataConfig } = {
	[PinataEnums['POCKET PINATA']] = {
		Name = 'Pocket Pinata',
		Description = 'A small but sweet companion!',

		Health = 100,
		Defense = 0,

		-- rewards
		Drops = {
			Coins = { Min = 5, Max = 15 },
			Gems = { Min = 0, Max = 1 },
		},

		-- visual
		ModelName = 'PocketPinataModel',
		Scale = 1.0,

		RopeLength = 18.5,
	},
}

return module
