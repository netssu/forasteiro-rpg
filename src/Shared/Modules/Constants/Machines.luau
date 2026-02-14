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
	Mode: string?,
	BaseTimeSeconds: number?,
	TimeReduction: number?,
	MinTimeSeconds: number?,
}

export type MachinePurchaseConfig = {
	Cost: number,
	RequiredRebirth: number,
	DefaultOwned: boolean,
	DisplayName: string?,
	MinCoinsToShow: number?,
}

export type GroupPlacementConfig = {
	PlotOffset: Vector3,
	YawOffset: number,
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
	UseRotationByPlot: boolean?,
	RotationByPlot: { [number]: number }?,
	ModelRotationOffset: number?,
	UsePrimaryPartForPlacement: boolean?,
	BuyRotationOffset: number?,
	AllowManualPlacement: boolean,
	AllowPreview: boolean,
	UseDropEffect: boolean,
	UseMainPart: boolean,
	Purchase: MachinePurchaseConfig?,
	Upgrades: SlotUpgradeConfig,
}

export type MachineGroupConfig = {
	Id: string,
	PlotFolder: string,
	AssetsFolder: string,
	BoardName: string,
	Placement: GroupPlacementConfig?,
	BuyRotationOffset: number?,
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

local DEFAULT_CANDY_MODEL: string = "Candy 1"
local TOOL_TO_CANDY: { [string]: string } = {
	CandyTool = "Candy 1",
	Candy = "Candy 1",
}

local CANDY_MAX_SCALE_BY_LEVEL: { [number]: number } = {
	[1] = 0.2,
	[2] = 0.3,
	[3] = 0.25,
	[4] = 2.0,
	[5] = 0.25,
	[6] = 0.3,
	[7] = 0.12,
	[8] = 0.7,
	[9] = 0.2,
	[10] = 0.15,
	[11] = 0.12,
	[12] = 0.2,
	[13] = 0.04,
	[14] = 0.35,
	[15] = 0.04,
	[16] = 0.025,
	[17] = 0.12,
	[18] = 0.11,
	[19] = 0.17,
	[20] = 4.0,
}

local CANDY_MAX_LEVEL: number = 20
local CANDY_START_SCALE_RATIO: number = 0.25
local CANDY_MIN_START_SCALE: number = 0.01
local CANDY_LIMIT: number = 200
local CANDY_LIMIT_GROWTH: number = 0.5

local CANDY_EVOLUTIONS: { [string]: CandyEvolution } = {}
for Level: number = 1, CANDY_MAX_LEVEL do
	local Name: string = string.format("Candy %d", Level)
	local NextName: string = if Level < CANDY_MAX_LEVEL then string.format("Candy %d", Level + 1) else ""
	local MaxScale: number = CANDY_MAX_SCALE_BY_LEVEL[Level] or 1.0
	local BaseScale: number = math.max(CANDY_MIN_START_SCALE, MaxScale * CANDY_START_SCALE_RATIO)
	if BaseScale > MaxScale then
		BaseScale = MaxScale
	end
	local UpgradeScale: number = 0
	if MaxScale > BaseScale and CANDY_LIMIT > 0 then
		UpgradeScale = (MaxScale - BaseScale) / CANDY_LIMIT
	end

	CANDY_EVOLUTIONS[Name] = {
		BaseScale = BaseScale,
		UpgradeScale = UpgradeScale,
		Limit = CANDY_LIMIT,
		LimitGrowth = CANDY_LIMIT_GROWTH,
		Next = NextName,
		MaxLevel = CANDY_MAX_LEVEL,
		MaxScale = MaxScale,
	}
end

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

local function MakeLevelUpgrade(BaseDropXp: number, Growth: number): LevelUpgradeConfig
	return {
		BaseDropXp = BaseDropXp,
		Growth = Growth,
		Levels = {
			{ Cost = 0, XpBonus = 0 },
			{ Cost = 0, XpBonus = 1 },
			{ Cost = 0, XpBonus = 2 },
			{ Cost = 0, XpBonus = 3 },
			{ Cost = 0, XpBonus = 4 },
			{ Cost = 0, XpBonus = 5 },
		},
	}
end

local DROPPER1_LEVEL_UPGRADES: LevelUpgradeConfig = MakeLevelUpgrade(1, 3.5)
local DROPPER2_LEVEL_UPGRADES: LevelUpgradeConfig = MakeLevelUpgrade(2, 2)
local DROPPER3_LEVEL_UPGRADES: LevelUpgradeConfig = MakeLevelUpgrade(5, 4)

local SPRINKLER1_LEVEL_UPGRADES: LevelUpgradeConfig = MakeLevelUpgrade(4, 2)
local SPRINKLER2_LEVEL_UPGRADES: LevelUpgradeConfig = MakeLevelUpgrade(3, 2)
local SPRINKLER3_LEVEL_UPGRADES: LevelUpgradeConfig = MakeLevelUpgrade(9, 6)
local SPRINKLER4_LEVEL_UPGRADES: LevelUpgradeConfig = MakeLevelUpgrade(4, 2)
local SPRINKLER5_LEVEL_UPGRADES: LevelUpgradeConfig = MakeLevelUpgrade(5, 3)
local SPRINKLER6_LEVEL_UPGRADES: LevelUpgradeConfig = MakeLevelUpgrade(11, 7)
local SPRINKLER7_LEVEL_UPGRADES: LevelUpgradeConfig = MakeLevelUpgrade(12, 8)

local DOUBLE_DROPPER_LEVEL_UPGRADES: LevelUpgradeConfig = {
	BaseDropXp = 0,
	Growth = 0,
	Levels = {
		{ Cost = 0, XpBonus = 0 },
		{ Cost = 0, XpBonus = 0 },
		{ Cost = 0, XpBonus = 0 },
		{ Cost = 0, XpBonus = 0 },
	},
	Mode = "Time",
	BaseTimeSeconds = 60,
	TimeReduction = 15,
	MinTimeSeconds = 0,
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

local BUY_CONFIG: { [string]: { [string]: { Name: string, MinCoinsToShow: number, RequiredRebirth: number } } } = {
	Droppers = {
		["1"] = { Name = "Dropper 1", MinCoinsToShow = 0, RequiredRebirth = 0 },
		["2"] = { Name = "Dropper 2", MinCoinsToShow = 0, RequiredRebirth = 0 },
		["3"] = { Name = "Dropper 3", MinCoinsToShow = 0, RequiredRebirth = 3 },
	},
	Sprinklers = {
		["1"] = { Name = "Sprinkler 1", MinCoinsToShow = 0, RequiredRebirth = 0 },
		["2"] = { Name = "Sprinkler 2", MinCoinsToShow = 0, RequiredRebirth = 0 },
		["3"] = { Name = "Sprinkler 3", MinCoinsToShow = 0, RequiredRebirth = 2 },
		["4"] = { Name = "Sprinkler 4", MinCoinsToShow = 0, RequiredRebirth = 3 },
		["5"] = { Name = "Sprinkler 5", MinCoinsToShow = 0, RequiredRebirth = 3 },
		["6"] = { Name = "Sprinkler 6", MinCoinsToShow = 0, RequiredRebirth = 4 },
		["7"] = { Name = "Sprinkler 7", MinCoinsToShow = 0, RequiredRebirth = 4 },
	},
	DoubleDropper = {
		["1"] = { Name = "DoubleDropper", MinCoinsToShow = 0, RequiredRebirth = 2 },
	},
}

local function MakePurchase(
	groupId: string,
	slotId: string,
	defaultOwned: boolean,
	requiredRebirthOverride: number?,
	costOverride: number?,
	minCoinsOverride: number?
): MachinePurchaseConfig
	local group = BUY_CONFIG[groupId]
	local info = if group then group[slotId] else nil
	local displayName = if info and info.Name ~= "" then info.Name else string.format("%s %s", groupId, slotId)
	local minCoins = if typeof(minCoinsOverride) == "number"
		then minCoinsOverride
		else if info and typeof(info.MinCoinsToShow) == "number" then info.MinCoinsToShow else 0
	local cost = if typeof(costOverride) == "number" then costOverride else 0
	local requiredRebirth = if typeof(requiredRebirthOverride) == "number"
		then requiredRebirthOverride
		else if info and typeof(info.RequiredRebirth) == "number" then info.RequiredRebirth else 0
	return {
		Cost = cost,
		RequiredRebirth = requiredRebirth,
		DefaultOwned = defaultOwned,
		DisplayName = displayName,
		MinCoinsToShow = minCoins,
	}
end

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
			Placement = {
				PlotOffset = Vector3.new(26.853, -0.474, -42.123),
				YawOffset = 0,
			},
			Slots = {
				["1"] = {
					Id = "1",
					Type = "Manual",
					AssetName = "Dropper",
					SlotPartName = "Long Slot",
					TapCount = 1,
					RotationDefault = 180,
					UseRotationByPlot = true,
					RotationByPlot = {
						[1] = -180,
						[2] = -180,
						[3] = 90,
						[4] = 90,
						[5] = 0,
						[6] = 0,
						[7] = -90,
						[8] = -90,
					},
					AllowManualPlacement = false,
					AllowPreview = false,
					UseDropEffect = true,
					UseMainPart = true,
					Purchase = MakePurchase("Droppers", "1", true),
					Upgrades = {
						Level = DROPPER1_LEVEL_UPGRADES,
					},
				},
				["2"] = {
					Id = "2",
					Type = "Auto",
					AssetName = "Dropper2",
					SlotPartName = "Wide Slot",
					TapCount = 4,
					RotationDefault = 0,
					ModelRotationOffset = 180,
					UseRotationByPlot = true,
					RotationByPlot = {
						[1] = -180,
						[2] = -180,
						[3] = -90,
						[4] = -90,
						[5] = -180,
						[6] = -180,
						[7] = -90,
						[8] = -90,
					},
					AllowManualPlacement = false,
					AllowPreview = false,
					UseDropEffect = true,
					UseMainPart = true,
					Purchase = MakePurchase("Droppers", "2", false),
					Upgrades = {
						Level = DROPPER2_LEVEL_UPGRADES,
						Specials = DROPPER_SPECIALS,
					},
				},
				["3"] = {
					Id = "3",
					Type = "Auto",
					AssetName = "Dropper3",
					SlotPartName = "Wide Slot",
					TapCount = 2,
					RotationDefault = 0,
					AllowManualPlacement = false,
					AllowPreview = false,
					UseDropEffect = true,
					UseMainPart = true,
					Purchase = MakePurchase("Droppers", "3", false),
					Upgrades = {
						Level = DROPPER3_LEVEL_UPGRADES,
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
			Placement = {
				PlotOffset = Vector3.new(-26.147, -0.474, -38.853),
				YawOffset = 0,
			},
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
					Purchase = MakePurchase("Sprinklers", "1", false),
					Upgrades = {
						Level = SPRINKLER1_LEVEL_UPGRADES,
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
					Purchase = MakePurchase("Sprinklers", "2", false),
					Upgrades = {
						Level = SPRINKLER2_LEVEL_UPGRADES,
						Specials = DROPPER_SPECIALS,
					},
				},
				["3"] = {
					Id = "3",
					Type = "Auto",
					AssetName = "Sprinkler3",
					SlotPartName = "Wide Slot",
					TapCount = 3,
					RotationDefault = 0,
					UsePrimaryPartForPlacement = true,
					BuyRotationOffset = 0,
					AllowManualPlacement = false,
					AllowPreview = false,
					UseDropEffect = false,
					UseMainPart = false,
					Purchase = MakePurchase("Sprinklers", "3", false),
					Upgrades = {
						Level = SPRINKLER3_LEVEL_UPGRADES,
						Specials = DROPPER_SPECIALS,
					},
				},
				["4"] = {
					Id = "4",
					Type = "Auto",
					AssetName = "Sprinkler4",
					SlotPartName = "Wide Slot",
					TapCount = 9,
					RotationDefault = 0,
					UsePrimaryPartForPlacement = true,
					BuyRotationOffset = 0,
					AllowManualPlacement = false,
					AllowPreview = false,
					UseDropEffect = false,
					UseMainPart = false,
					Purchase = MakePurchase("Sprinklers", "4", false),
					Upgrades = {
						Level = SPRINKLER4_LEVEL_UPGRADES,
						Specials = DROPPER_SPECIALS,
					},
				},
				["5"] = {
					Id = "5",
					Type = "Auto",
					AssetName = "Sprinkler5",
					SlotPartName = "Wide Slot",
					TapCount = 8,
					RotationDefault = 0,
					UsePrimaryPartForPlacement = true,
					BuyRotationOffset = 0,
					AllowManualPlacement = false,
					AllowPreview = false,
					UseDropEffect = false,
					UseMainPart = false,
					Purchase = MakePurchase("Sprinklers", "5", false),
					Upgrades = {
						Level = SPRINKLER5_LEVEL_UPGRADES,
						Specials = DROPPER_SPECIALS,
					},
				},
				["6"] = {
					Id = "6",
					Type = "Auto",
					AssetName = "Sprinkler6",
					SlotPartName = "Wide Slot",
					TapCount = 4,
					RotationDefault = 0,
					UsePrimaryPartForPlacement = true,
					BuyRotationOffset = 0,
					AllowManualPlacement = false,
					AllowPreview = false,
					UseDropEffect = false,
					UseMainPart = false,
					Purchase = MakePurchase("Sprinklers", "6", false),
					Upgrades = {
						Level = SPRINKLER6_LEVEL_UPGRADES,
						Specials = DROPPER_SPECIALS,
					},
				},
				["7"] = {
					Id = "7",
					Type = "Auto",
					AssetName = "Sprinkler7",
					SlotPartName = "Wide Slot",
					TapCount = 4,
					RotationDefault = 0,
					UsePrimaryPartForPlacement = true,
					BuyRotationOffset = 0,
					AllowManualPlacement = false,
					AllowPreview = false,
					UseDropEffect = false,
					UseMainPart = false,
					Purchase = MakePurchase("Sprinklers", "7", false),
					Upgrades = {
						Level = SPRINKLER7_LEVEL_UPGRADES,
						Specials = DROPPER_SPECIALS,
					},
				},
			},
		},
		DoubleDropper = {
			Id = "DoubleDropper",
			PlotFolder = "DoubleDropper",
			AssetsFolder = "DoubleDropper",
			BoardName = "Board",
			Placement = {
				PlotOffset = Vector3.new(-26.537, -0.459, -104.164),
				YawOffset = 0,
			},
			Slots = {
				["1"] = {
					Id = "1",
					Type = "Manual",
					AssetName = "DoubleDropper",
					SlotPartName = "Long Slot",
					TapCount = 1,
					RotationDefault = 0,
					BuyRotationOffset = 0,
					AllowManualPlacement = true,
					AllowPreview = true,
					UseDropEffect = false,
					UseMainPart = true,
					Purchase = MakePurchase("DoubleDropper", "1", false),
					Upgrades = {
						Level = DOUBLE_DROPPER_LEVEL_UPGRADES,
					},
				},
			},
		},
	},
}

return module
