--!strict

export type CandyEvolution = {
	BaseScale: number,
	UpgradeScale: number,
	Limit: number,
	Next: string?,
	MaxLevel: number?,
}

export type CandyConfig = {
	DefaultModel: string,
	ToolMap: { [string]: string },
	Evolutions: { [string]: CandyEvolution },
}

export type MutationType = {
	Id: string,
	Multiplier: number,
	LevelBonus: number,
}

export type MutationConfig = {
	Chance: number,
	LoseChance: number,
	Types: { MutationType },
}

export type MultiplierConfig = {
	Base: number,
	PerLevel: number,
	MutationLevelBonus: number,
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

export type DropperConfig = {
	AutoTapCount: number,
	StateFolderName: string,
	SlotLong: string,
	SlotWide: string,
	TypeNormal: string,
	TypeAuto: string,
	TapsFolderName: string,
	RotationNormal: number,
	RotationAuto: number,
}

export type AssetConfig = {
	DroppersFolder: string,
	CandiesFolder: string,
	DropperModel: string,
	Dropper2Model: string,
}

export type Config = {
	Candy: CandyConfig,
	Mutation: MutationConfig,
	Multiplier: MultiplierConfig,
	Timing: DropperTimingConfig,
	Visual: VisualConfig,
	Dropper: DropperConfig,
	Assets: AssetConfig,
}

local DEFAULT_CANDY_MODEL: string = "Candy"
local TOOL_TO_CANDY: { [string]: string } = {
	CandyTool = "Candy",
}

local CANDY_EVOLUTIONS: { [string]: CandyEvolution } = {
	Candy = {
		BaseScale = 1.0,
		UpgradeScale = 0.05,
		Limit = 8,
		Next = "Candy",
		MaxLevel = 5,
	}
}

local MUTATION_TYPES: { MutationType } = {
	{
		Id = "Rainbow",
		Multiplier = 3.0,
		LevelBonus = 1.0,
	},
	{
		Id = "Golden",
		Multiplier = 5.0,
		LevelBonus = 2.0,
	},
}

local module: Config = {
	Candy = {
		DefaultModel = DEFAULT_CANDY_MODEL,
		ToolMap = TOOL_TO_CANDY,
		Evolutions = CANDY_EVOLUTIONS,
	},
	Mutation = {
		Chance = 0.12,
		LoseChance = 0.08,
		Types = MUTATION_TYPES,
	},
	Multiplier = {
		Base = 1.0,
		PerLevel = 0.15,
		MutationLevelBonus = 1.0,
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
	Dropper = {
		AutoTapCount = 3,
		StateFolderName = "Droppers",
		SlotLong = "1",
		SlotWide = "2",
		TypeNormal = "Dropper",
		TypeAuto = "Dropper2",
		TapsFolderName = "Taps",
		RotationNormal = 180,
		RotationAuto = 180,
	},
	Assets = {
		DroppersFolder = "Droppers",
		CandiesFolder = "Candies",
		DropperModel = "Dropper",
		Dropper2Model = "Dropper2",
	},
}

return module
