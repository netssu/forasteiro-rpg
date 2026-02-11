--!strict

export type CandyEvolution = {
	BaseScale: number,
	UpgradeScale: number,
	Limit: number,
	LimitGrowth: number?,
	Next: string?,
	MaxLevel: number?,
	MaxScale: number?,
}

export type CandyConfig = {
	DefaultModel: string,
	ToolMap: { [string]: string },
	Evolutions: { [string]: CandyEvolution },
	XpPerLevel: number,
	XpPerProgress: number,
}

export type MutationType = {
	Id: string,
	Multiplier: number,
	HighlightColor: Color3?,
	IsRainbow: boolean?,
}

export type MutationConfig = {
	Chance: number,
	MaxCount: number,
	Separator: string,
	Types: { MutationType },
}

export type DropperTimingConfig = {
	ManualDropTime: number,
	ManualDebounce: number,
	AutoDropInterval: number,
	AutoDropTime: number,
	AutoLoopStep: number,
}

export type VisualConfig = {
	FocusDistance: number,
	HoverScale: number,
	HoverTweenTime: number,
	HoverTweenStyle: string,
	HoverTweenDirection: string,
	CandyBounceScale: number,
	CandyBounceTime: number,
	CandyBounceStyle: string,
	CandyBounceDirection: string,
	FloatAmplitude: number,
	FloatSpeed: number,
	AttractDistance: number,
	AttractSpeed: number,
	DropPartSize: Vector3,
	DropTrailLifetime: number,
	DropTrailWidth: number,
	DropTrailColor: Color3,
	DropTrailTexture: string,
}

export type LevelUpgradeTier = {
	Cost: number,
	XpBonus: number,
}

export type SpecialUpgradeTier = {
	Cost: number,
	Multiplier: number,
}

export type SpecialUpgradeConfig = {
	Id: string,
	Label: string,
	Levels: { SpecialUpgradeTier },
}

export type LevelUpgradeConfig = {
	BaseDropXp: number,
	Levels: { LevelUpgradeTier },
	Growth: number?,
}

export type SlotUpgradeConfig = {
	Level: LevelUpgradeConfig,
	Specials: { [string]: SpecialUpgradeConfig }?,
}

export type MachineSlotConfig = {
	Id: string,
	Type: string,
	AssetName: string,
	SlotPartName: string,
	TapCount: number,
	RotationDefault: number,
	AllowManualPlacement: boolean,
	AllowPreview: boolean,
	UseDropEffect: boolean,
	UseMainPart: boolean,
	Upgrades: SlotUpgradeConfig,
}

export type MachineGroupConfig = {
	Id: string,
	PlotFolder: string,
	AssetsFolder: string,
	BoardName: string,
	Slots: { [string]: MachineSlotConfig },
}

export type AssetConfig = {
	RootFolder: string,
	MachinesFolder: string,
	ModelsFolder: string,
	CandiesFolder: string,
	LevelBarName: string,
}

export type Config = {
	Candy: CandyConfig,
	Mutation: MutationConfig,
	Timing: DropperTimingConfig,
	Visual: VisualConfig,
	Assets: AssetConfig,
	Machines: { [string]: MachineGroupConfig },
}

local DEFAULT_CANDY_MODEL: string = "Candy"
local TOOL_TO_CANDY: { [string]: string } = {
	CandyTool = "Candy",
}

local CANDY_EVOLUTIONS: { [string]: CandyEvolution } = {
	Candy = {
		BaseScale = 1.0,
		UpgradeScale = 0.02,
		Limit = 40,
		LimitGrowth = 0.1,
		Next = "Candy",
		MaxLevel = 40,
		MaxScale = 5,
	},
}

local MUTATION_TYPES: { MutationType } = {
	{
		Id = "Arco-íris",
		Multiplier = 3.0,
		HighlightColor = Color3.fromRGB(255, 255, 255),
		IsRainbow = true,
	},
	{
		Id = "Sangue",
		Multiplier = 3.0,
		HighlightColor = Color3.fromRGB(190, 0, 0),
	},
	{
		Id = "Congelado",
		Multiplier = 3.0,
		HighlightColor = Color3.fromRGB(100, 180, 255),
	},
	{
		Id = "Tóxico",
		Multiplier = 3.0,
		HighlightColor = Color3.fromRGB(90, 255, 120),
	},
	{
		Id = "Brilhante",
		Multiplier = 3.0,
		HighlightColor = Color3.fromRGB(255, 235, 120),
	},
}

local DROPPER_LEVEL_UPGRADES: LevelUpgradeConfig = {
	BaseDropXp = 1,
	Growth = 3.5,
	Levels = {
		{ Cost = 0, XpBonus = 0 },
		{ Cost = 0, XpBonus = 1 },
		{ Cost = 0, XpBonus = 2 },
		{ Cost = 0, XpBonus = 3 },
		{ Cost = 0, XpBonus = 4 },
		{ Cost = 0, XpBonus = 5 },
	},
}

local SPRINKLER_LEVEL_UPGRADES: LevelUpgradeConfig = {
	BaseDropXp = 5,
	Growth = 5.5,
	Levels = {
		{ Cost = 0, XpBonus = 0 },
		{ Cost = 0, XpBonus = 1 },
		{ Cost = 0, XpBonus = 2 },
		{ Cost = 0, XpBonus = 3 },
		{ Cost = 0, XpBonus = 4 },
		{ Cost = 0, XpBonus = 5 },
	},
}

local DROPPER_SPECIALS: { [string]: SpecialUpgradeConfig } = {
	Speed = {
		Id = "Speed",
		Label = "Faster",
		Levels = {
			{ Cost = 0, Multiplier = 1.15 },
			{ Cost = 0, Multiplier = 1.3 },
			{ Cost = 0, Multiplier = 1.5 },
		},
	},
	Mutation = {
		Id = "Mutation",
		Label = "Mutation",
		Levels = {
			{ Cost = 0, Multiplier = 1.25 },
			{ Cost = 0, Multiplier = 1.5 },
			{ Cost = 0, Multiplier = 2.0 },
		},
	},
	Xp = {
		Id = "Xp",
		Label = "XP",
		Levels = {
			{ Cost = 0, Multiplier = 1.2 },
			{ Cost = 0, Multiplier = 1.45 },
			{ Cost = 0, Multiplier = 1.8 },
		},
	},
}

local module: Config = {
	Candy = {
		DefaultModel = DEFAULT_CANDY_MODEL,
		ToolMap = TOOL_TO_CANDY,
		Evolutions = CANDY_EVOLUTIONS,
		XpPerLevel = 100,
		XpPerProgress = 12.5,
	},
	Mutation = {
		Chance = 0.001,
		MaxCount = #MUTATION_TYPES,
		Separator = "|",
		Types = MUTATION_TYPES,
	},
	Timing = {
		ManualDropTime = 0.45,
		ManualDebounce = 0.7,
		AutoDropInterval = 1.15,
		AutoDropTime = 0.7,
		AutoLoopStep = 0.2,
	},
	Visual = {
		FocusDistance = 3000,
		HoverScale = 1.15,
		HoverTweenTime = 0.12,
		HoverTweenStyle = "Sine",
		HoverTweenDirection = "Out",
		CandyBounceScale = 0.08,
		CandyBounceTime = 0.12,
		CandyBounceStyle = "Sine",
		CandyBounceDirection = "Out",
		FloatAmplitude = 0.45,
		FloatSpeed = 2.3,
		AttractDistance = 12.0,
		AttractSpeed = 6.0,
		DropPartSize = Vector3.new(1.379, 0.69, 1.379),
		DropTrailLifetime = 0.18,
		DropTrailWidth = 1.2,
		DropTrailColor = Color3.fromRGB(255, 255, 255),
		DropTrailTexture = "rbxassetid://284205403",
	},
	Assets = {
		RootFolder = "Assets",
		MachinesFolder = "Maquinas",
		ModelsFolder = "Models",
		CandiesFolder = "Candies",
		LevelBarName = "LevelBar",
	},
	Machines = {
		Droppers = {
			Id = "Droppers",
			PlotFolder = "Droppers",
			AssetsFolder = "Droppers",
			BoardName = "Board",
			Slots = {
				["1"] = {
					Id = "1",
					Type = "Manual",
					AssetName = "Dropper",
					SlotPartName = "Long Slot",
					TapCount = 1,
					RotationDefault = 180,
					AllowManualPlacement = false,
					AllowPreview = false,
					UseDropEffect = true,
					UseMainPart = true,
					Upgrades = {
						Level = DROPPER_LEVEL_UPGRADES,
					},
				},
				["2"] = {
					Id = "2",
					Type = "Auto",
					AssetName = "Dropper2",
					SlotPartName = "Wide Slot",
					TapCount = 4,
					RotationDefault = 180,
					AllowManualPlacement = false,
					AllowPreview = false,
					UseDropEffect = true,
					UseMainPart = true,
					Upgrades = {
						Level = DROPPER_LEVEL_UPGRADES,
						Specials = DROPPER_SPECIALS,
					},
				},
			},
		},
		Sprinklers = {
			Id = "Sprinklers",
			PlotFolder = "Sprinklers",
			AssetsFolder = "Sprinklers",
			BoardName = "Board",
			Slots = {
				["1"] = {
					Id = "1",
					Type = "Auto",
					AssetName = "Sprinkler",
					SlotPartName = "Long Slot",
					TapCount = 4,
					RotationDefault = 180,
					AllowManualPlacement = false,
					AllowPreview = false,
					UseDropEffect = false,
					UseMainPart = false,
					Upgrades = {
						Level = SPRINKLER_LEVEL_UPGRADES,
					},
				},
				["2"] = {
					Id = "2",
					Type = "Auto",
					AssetName = "Sprinkler2",
					SlotPartName = "Wide Slot",
					TapCount = 8,
					RotationDefault = 180,
					AllowManualPlacement = false,
					AllowPreview = false,
					UseDropEffect = false,
					UseMainPart = false,
					Upgrades = {
						Level = SPRINKLER_LEVEL_UPGRADES,
						Specials = DROPPER_SPECIALS,
					},
				},
			},
		},
	},
}

return module
