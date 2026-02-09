--!strict

local module: { Init: (self: any) -> (), Start: (self: any) -> () } = {}

--\\ SERVICES \\ -- TR
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")

--\\ DEPENDENCIES \\ -- TR
local Constants: any = require(ReplicatedStorage.Modules.Constants.Droppers)
local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local PlotmeService: any = require(ServerScriptService.Services.PlotmeService)

--\\ TYPES \\ -- TR
type CandyEvolution = {
	BaseScale: number,
	UpgradeScale: number,
	Limit: number,
	Next: string?,
	MaxLevel: number?,
}

type MutationType = {
	Id: string,
	Multiplier: number,
	LevelBonus: number,
}

type CandyAttributeKeys = {
	CandyModel: string,
	CandyLevel: string,
	CandyProgress: string,
	CandyScale: string,
	HasCandy: string,
	DropSequence: string,
	RemoveSequence: string,
	Mutation: string,
	Mutated: string,
	Multiplier: string,
}

type CandyState = {
	Plot: Model,
	SlotId: string,
	TapId: number?,
	Keys: CandyAttributeKeys,
}

type DropperSlotState = {
	SlotId: string,
	Type: string,
	Candy: CandyState?,
	Taps: { [number]: CandyState }?,
}

type PlotState = {
	Plot: Model,
	Slots: { [string]: DropperSlotState },
}

--\\ CONSTANTS \\ -- TR
local SLOT_LONG: string = Constants.Dropper.SlotLong
local SLOT_WIDE: string = Constants.Dropper.SlotWide
local TYPE_NORMAL: string = Constants.Dropper.TypeNormal
local TYPE_AUTO: string = Constants.Dropper.TypeAuto
local AUTO_TAP_COUNT: number = Constants.Dropper.AutoTapCount

local FALLBACK_BASE_SCALE: number = 1.0
local EMPTY_STRING: string = ""
local MAP_FOLDER_NAME: string = "Map"
local PLOTS_FOLDER_NAME: string = "Plots"
local OWNER_ATTRIBUTE_NAME: string = "Owner"

local ATTRIBUTE_PREFIX: string = "Dropper"
local ATTRIBUTE_TAP_PREFIX: string = "Tap"
local ATTRIBUTE_FORMAT_NORMAL: string = "%s_%s_%s"
local ATTRIBUTE_FORMAT_TAP: string = "%s_%s_%s%d_%s"
local ATTRIBUTE_KEY_CANDY_MODEL: string = "CandyModel"
local ATTRIBUTE_KEY_CANDY_LEVEL: string = "CandyLevel"
local ATTRIBUTE_KEY_CANDY_PROGRESS: string = "CandyProgress"
local ATTRIBUTE_KEY_CANDY_SCALE: string = "CandyScale"
local ATTRIBUTE_KEY_HAS_CANDY: string = "HasCandy"
local ATTRIBUTE_KEY_DROP_SEQUENCE: string = "DropSequence"
local ATTRIBUTE_KEY_REMOVE_SEQUENCE: string = "RemoveSequence"
local ATTRIBUTE_KEY_MUTATION: string = "Mutation"
local ATTRIBUTE_KEY_MUTATED: string = "Mutated"
local ATTRIBUTE_KEY_MULTIPLIER: string = "Multiplier"

local ACTION_PLACE_CANDY: string = "PlaceCandy"
local ACTION_DROP: string = "Drop"
local ACTION_REMOVE_CANDY: string = "RemoveCandy"

local TOOL_ATTRIBUTE_CANDY_MODEL: string = "CandyModel"
local ASSETS_ROOT_NAME: string = "Assets"
local CANDIES_FOLDER_NAME: string = "Candies"
local SETTINGS_FOLDER_NAME: string = "Settings"

local DEFAULT_BOOL: boolean = false
local DEFAULT_NUMBER: number = 0
local DEBUG_ENABLED: boolean = false

--\\ STATE \\ -- TR
local _PlayerPlots: { [Player]: Model } = {}
local _PlotStates: { [Model]: PlotState } = {}
local _ManualDropDebounce: { [string]: number } = {}
local _AutoNextDropTime: { [string]: number } = {}
local _AutoLoopActive: { [Model]: boolean } = {}
local _RandomGenerator: Random = Random.new()

--\\ PRIVATE FUNCTIONS \\ -- TR
local function _GetAttributeKey(SlotId: string, TapId: number?, KeyName: string): string
	if TapId then
		return string.format(ATTRIBUTE_FORMAT_TAP, ATTRIBUTE_PREFIX, SlotId, ATTRIBUTE_TAP_PREFIX, TapId, KeyName)
	end
	return string.format(ATTRIBUTE_FORMAT_NORMAL, ATTRIBUTE_PREFIX, SlotId, KeyName)
end

local function _GetStringAttribute(Plot: Model, Key: string, Default: string): string
	local Value: any = Plot:GetAttribute(Key)
	if typeof(Value) == "string" then
		return Value
	end
	return Default
end

local function _GetNumberAttribute(Plot: Model, Key: string, Default: number): number
	local Value: any = Plot:GetAttribute(Key)
	if typeof(Value) == "number" then
		return Value
	end
	return Default
end

local function _GetBoolAttribute(Plot: Model, Key: string, Default: boolean): boolean
	local Value: any = Plot:GetAttribute(Key)
	if typeof(Value) == "boolean" then
		return Value
	end
	return Default
end

local function _ReadActionData(Data: any): (string?, number?)
	if typeof(Data) ~= "table" then
		return nil, nil
	end

	local SlotId: string? = nil
	local TapId: number? = nil

	local RawSlot: any = Data.SlotId
	if typeof(RawSlot) == "string" then
		SlotId = RawSlot
	else
		local ArraySlot: any = Data[1]
		if typeof(ArraySlot) == "string" then
			SlotId = ArraySlot
		end
	end

	local RawTap: any = Data.TapId
	if typeof(RawTap) == "number" then
		TapId = RawTap
	else
		local ArrayTap: any = Data[2]
		if typeof(ArrayTap) == "number" then
			TapId = ArrayTap
		end
	end

	return SlotId, TapId
end

local function _SetAttribute(Plot: Model, Key: string, Value: any): ()
	Plot:SetAttribute(Key, Value)
end

local function _BuildCandyState(Plot: Model, SlotId: string, TapId: number?): CandyState
	local Keys: CandyAttributeKeys = {
		CandyModel = _GetAttributeKey(SlotId, TapId, ATTRIBUTE_KEY_CANDY_MODEL),
		CandyLevel = _GetAttributeKey(SlotId, TapId, ATTRIBUTE_KEY_CANDY_LEVEL),
		CandyProgress = _GetAttributeKey(SlotId, TapId, ATTRIBUTE_KEY_CANDY_PROGRESS),
		CandyScale = _GetAttributeKey(SlotId, TapId, ATTRIBUTE_KEY_CANDY_SCALE),
		HasCandy = _GetAttributeKey(SlotId, TapId, ATTRIBUTE_KEY_HAS_CANDY),
		DropSequence = _GetAttributeKey(SlotId, TapId, ATTRIBUTE_KEY_DROP_SEQUENCE),
		RemoveSequence = _GetAttributeKey(SlotId, TapId, ATTRIBUTE_KEY_REMOVE_SEQUENCE),
		Mutation = _GetAttributeKey(SlotId, TapId, ATTRIBUTE_KEY_MUTATION),
		Mutated = _GetAttributeKey(SlotId, TapId, ATTRIBUTE_KEY_MUTATED),
		Multiplier = _GetAttributeKey(SlotId, TapId, ATTRIBUTE_KEY_MULTIPLIER),
	}

	_SetAttribute(Plot, Keys.CandyModel, EMPTY_STRING)
	_SetAttribute(Plot, Keys.CandyLevel, DEFAULT_NUMBER)
	_SetAttribute(Plot, Keys.CandyProgress, DEFAULT_NUMBER)
	_SetAttribute(Plot, Keys.CandyScale, DEFAULT_NUMBER)
	_SetAttribute(Plot, Keys.HasCandy, DEFAULT_BOOL)
	_SetAttribute(Plot, Keys.DropSequence, DEFAULT_NUMBER)
	_SetAttribute(Plot, Keys.RemoveSequence, DEFAULT_NUMBER)
	_SetAttribute(Plot, Keys.Mutation, EMPTY_STRING)
	_SetAttribute(Plot, Keys.Mutated, DEFAULT_BOOL)
	_SetAttribute(Plot, Keys.Multiplier, DEFAULT_NUMBER)

	return {
		Plot = Plot,
		SlotId = SlotId,
		TapId = TapId,
		Keys = Keys,
	}
end

local function _ResetCandyState(CandyState: CandyState): ()
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyModel, EMPTY_STRING)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyProgress, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyScale, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.HasCandy, DEFAULT_BOOL)
	_SetAttribute(CandyState.Plot, CandyState.Keys.DropSequence, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.RemoveSequence, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.Mutation, EMPTY_STRING)
	_SetAttribute(CandyState.Plot, CandyState.Keys.Mutated, DEFAULT_BOOL)
	_SetAttribute(CandyState.Plot, CandyState.Keys.Multiplier, DEFAULT_NUMBER)
end

local function _GetCandyEvolution(ModelName: string): CandyEvolution?
	local Evolutions: { [string]: CandyEvolution } = Constants.Candy.Evolutions
	return Evolutions[ModelName]
end

local function _GetCandyMaxLevel(ModelName: string): number?
	local Evolution: CandyEvolution? = _GetCandyEvolution(ModelName)
	if not Evolution then
		return nil
	end

	local MaxLevel: any = Evolution.MaxLevel
	if typeof(MaxLevel) == "number" and MaxLevel > 0 then
		return MaxLevel
	end
	return nil
end

local function _FindMutationConfig(MutationId: string): MutationType?
	local Types: { MutationType } = Constants.Mutation.Types
	for _, MutationConfig: MutationType in Types do
		if MutationConfig.Id == MutationId then
			return MutationConfig
		end
	end
	return nil
end

local function _PickMutationConfig(): MutationType?
	local Types: { MutationType } = Constants.Mutation.Types
	local Count: number = #Types
	if Count <= 0 then
		return nil
	end

	local Index: number = _RandomGenerator:NextInteger(1, Count)
	return Types[Index]
end

local function _UpdateMultiplier(CandyState: CandyState): ()
	local BaseMultiplier: number = Constants.Multiplier.Base
	local PerLevel: number = Constants.Multiplier.PerLevel
	local Level: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, DEFAULT_NUMBER)
	local CurrentMultiplier: number = BaseMultiplier + (Level * PerLevel)

	local Mutated: boolean = _GetBoolAttribute(CandyState.Plot, CandyState.Keys.Mutated, DEFAULT_BOOL)
	if Mutated then
		local MutationName: string = _GetStringAttribute(CandyState.Plot, CandyState.Keys.Mutation, EMPTY_STRING)
		local MutationConfig: MutationType? = _FindMutationConfig(MutationName)
		local MutationMultiplier: number = if MutationConfig then MutationConfig.Multiplier else 1.0
		local LevelBonus: number = if MutationConfig then MutationConfig.LevelBonus else Constants.Multiplier.MutationLevelBonus
		CurrentMultiplier = (CurrentMultiplier * MutationMultiplier) + (Level * LevelBonus)
	end

	_SetAttribute(CandyState.Plot, CandyState.Keys.Multiplier, CurrentMultiplier)
end

local function _HasCandy(CandyState: CandyState): boolean
	return _GetBoolAttribute(CandyState.Plot, CandyState.Keys.HasCandy, DEFAULT_BOOL)
end

local function _ApplyMutation(CandyState: CandyState): ()
	if not _HasCandy(CandyState) then
		return
	end

	local Mutated: boolean = _GetBoolAttribute(CandyState.Plot, CandyState.Keys.Mutated, DEFAULT_BOOL)
	local Chance: number = Constants.Mutation.Chance
	local LoseChance: number = Constants.Mutation.LoseChance

	if not Mutated then
		if _RandomGenerator:NextNumber() <= Chance then
			local MutationConfig: MutationType? = _PickMutationConfig()
			if MutationConfig then
				_SetAttribute(CandyState.Plot, CandyState.Keys.Mutation, MutationConfig.Id)
				_SetAttribute(CandyState.Plot, CandyState.Keys.Mutated, true)
			end
		end
		return
	end

	if _RandomGenerator:NextNumber() <= LoseChance then
		_SetAttribute(CandyState.Plot, CandyState.Keys.Mutation, EMPTY_STRING)
		_SetAttribute(CandyState.Plot, CandyState.Keys.Mutated, false)
	end
end

local function _SetCandy(CandyState: CandyState, CandyModel: string): ()
	local Evolution: CandyEvolution? = _GetCandyEvolution(CandyModel)
	local BaseScale: number = if Evolution then Evolution.BaseScale else FALLBACK_BASE_SCALE
	local MaxLevel: number? = _GetCandyMaxLevel(CandyModel)
	local StartLevel: number = 1
	if MaxLevel and MaxLevel < StartLevel then
		StartLevel = MaxLevel
	end

	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyModel, CandyModel)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, StartLevel)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyProgress, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyScale, BaseScale)
	_SetAttribute(CandyState.Plot, CandyState.Keys.HasCandy, true)
	_SetAttribute(CandyState.Plot, CandyState.Keys.Mutation, EMPTY_STRING)
	_SetAttribute(CandyState.Plot, CandyState.Keys.Mutated, DEFAULT_BOOL)
	_SetAttribute(CandyState.Plot, CandyState.Keys.Multiplier, DEFAULT_NUMBER)

	_UpdateMultiplier(CandyState)
end

local function _SetCandyWithState(
	CandyState: CandyState,
	CandyModel: string,
	Level: number?,
	Exp: number?,
	Mutation: string?,
	Mutated: boolean?,
	Scale: number?
): ()
	local Evolution: CandyEvolution? = _GetCandyEvolution(CandyModel)
	local BaseScale: number = if Evolution then Evolution.BaseScale else FALLBACK_BASE_SCALE
	local MaxLevel: number? = _GetCandyMaxLevel(CandyModel)
	local Progress: number = if typeof(Exp) == "number" and Exp >= 0 then Exp else DEFAULT_NUMBER
	local ResolvedScale: number = BaseScale
	if typeof(Scale) == "number" and Scale > 0 then
		ResolvedScale = Scale
	elseif Evolution then
		ResolvedScale = Evolution.BaseScale + (Progress * Evolution.UpgradeScale)
	end

	local ResolvedLevel: number = if typeof(Level) == "number" and Level > 0 then Level else 1
	if MaxLevel and ResolvedLevel > MaxLevel then
		ResolvedLevel = MaxLevel
	end
	local MutationValue: string = if typeof(Mutation) == "string" then Mutation else EMPTY_STRING
	local MutatedValue: boolean = if typeof(Mutated) == "boolean" then Mutated else DEFAULT_BOOL
	if MutationValue == EMPTY_STRING then
		MutatedValue = false
	end

	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyModel, CandyModel)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, ResolvedLevel)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyProgress, Progress)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyScale, ResolvedScale)
	_SetAttribute(CandyState.Plot, CandyState.Keys.HasCandy, true)
	_SetAttribute(CandyState.Plot, CandyState.Keys.Mutation, MutationValue)
	_SetAttribute(CandyState.Plot, CandyState.Keys.Mutated, MutatedValue)
	_SetAttribute(CandyState.Plot, CandyState.Keys.Multiplier, DEFAULT_NUMBER)

	_UpdateMultiplier(CandyState)
end

local function _ApplyUpgrade(CandyState: CandyState, IsAuto: boolean): ()
	if not _HasCandy(CandyState) then
		return
	end

	local CurrentModel: string = _GetStringAttribute(CandyState.Plot, CandyState.Keys.CandyModel, EMPTY_STRING)
	if CurrentModel == EMPTY_STRING then
		return
	end

	local Evolution: CandyEvolution? = _GetCandyEvolution(CurrentModel)
	if not Evolution then
		return
	end

	local CurrentProgress: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyProgress, DEFAULT_NUMBER)
	local CurrentLevel: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, DEFAULT_NUMBER)
	local MaxLevel: number? = _GetCandyMaxLevel(CurrentModel)
	if MaxLevel and CurrentLevel >= MaxLevel then
		return
	end
	local NewProgress: number = CurrentProgress + 1
	local NewModel: string = CurrentModel
	local NewScale: number = Evolution.BaseScale + (NewProgress * Evolution.UpgradeScale)

	if NewProgress >= Evolution.Limit then
		local NextModel: string? = Evolution.Next
		if NextModel and NextModel ~= EMPTY_STRING then
			local NextEvolution: CandyEvolution? = _GetCandyEvolution(NextModel)
			NewModel = NextModel
			NewProgress = 0
			NewScale = if NextEvolution then NextEvolution.BaseScale else Evolution.BaseScale
		else
			NewModel = CurrentModel
			NewProgress = 0
			NewScale = Evolution.BaseScale
		end
	end

	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, CurrentLevel + 1)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyProgress, NewProgress)

	if NewModel ~= CurrentModel then
		_SetAttribute(CandyState.Plot, CandyState.Keys.CandyModel, NewModel)
	end

	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyScale, NewScale)

	if IsAuto then
		_ApplyMutation(CandyState)
	end

	_UpdateMultiplier(CandyState)
end

local function _TriggerDrop(CandyState: CandyState, IsAuto: boolean, DropTime: number): ()
	if not _HasCandy(CandyState) then
		return
	end
	local CurrentModel: string = _GetStringAttribute(CandyState.Plot, CandyState.Keys.CandyModel, EMPTY_STRING)
	if CurrentModel ~= EMPTY_STRING then
		local CurrentLevel: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, DEFAULT_NUMBER)
		local MaxLevel: number? = _GetCandyMaxLevel(CurrentModel)
		if MaxLevel and CurrentLevel >= MaxLevel then
			return
		end
	end

	local CurrentSequence: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.DropSequence, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.DropSequence, CurrentSequence + 1)

	task.delay(DropTime, function(): ()
		if not _HasCandy(CandyState) then
			return
		end
		_ApplyUpgrade(CandyState, IsAuto)
	end)
end

local function _RemoveCandy(CandyState: CandyState): ()
	if not _HasCandy(CandyState) then
		return
	end

	local CandyName: string = _GetStringAttribute(CandyState.Plot, CandyState.Keys.CandyModel, EMPTY_STRING)
	local CandyLevel: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, DEFAULT_NUMBER)
	local RemoveSequence: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.RemoveSequence, DEFAULT_NUMBER)

	_SetAttribute(CandyState.Plot, CandyState.Keys.HasCandy, false)
	_SetAttribute(CandyState.Plot, CandyState.Keys.RemoveSequence, RemoveSequence + 1)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyModel, EMPTY_STRING)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyProgress, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.Mutation, EMPTY_STRING)
	_SetAttribute(CandyState.Plot, CandyState.Keys.Mutated, DEFAULT_BOOL)
	_SetAttribute(CandyState.Plot, CandyState.Keys.Multiplier, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyScale, DEFAULT_NUMBER)

	if DEBUG_ENABLED then
		print(`[Dropper]: Removed candy {CandyName} at level {CandyLevel}`)
	end
end

local function _GiveCandyTool(
	Player: Player,
	CandyName: string,
	Level: number,
	Exp: number,
	Mutation: string,
	Mutated: boolean,
	Size: number
): ()
	if CandyName == EMPTY_STRING then
		return
	end

	local ToolInstance: Tool = Instance.new("Tool")
	ToolInstance.Name = CandyName

	local Config: Configuration = Instance.new("Configuration")
	Config.Name = SETTINGS_FOLDER_NAME
	Config:SetAttribute("Name", CandyName)
	Config:SetAttribute("Type", "Consumable")
	Config:SetAttribute("Level", Level)
	Config:SetAttribute("Exp", Exp)
	Config:SetAttribute("Mutation", Mutation)
	Config:SetAttribute("Mutated", Mutated)
	Config:SetAttribute("Size", Size)
	Config.Parent = ToolInstance

	local Backpack: Instance? = Player:FindFirstChildOfClass("Backpack")
	ToolInstance.Parent = Backpack or Player:FindFirstChild("Backpack") or Player.Character
end

local function _CreateSlotState(Plot: Model, SlotId: string, DropperType: string): DropperSlotState
	local SlotState: DropperSlotState = {
		SlotId = SlotId,
		Type = DropperType,
		Candy = nil,
		Taps = nil,
	}

	if DropperType == TYPE_NORMAL then
		SlotState.Candy = _BuildCandyState(Plot, SlotId, nil)
		return SlotState
	end

	local Taps: { [number]: CandyState } = table.create(AUTO_TAP_COUNT)
	for Index: number = 1, AUTO_TAP_COUNT do
		Taps[Index] = _BuildCandyState(Plot, SlotId, Index)
	end

	SlotState.Taps = Taps
	return SlotState
end

local function _CreatePlotState(Plot: Model): PlotState
	local Slots: { [string]: DropperSlotState } = {}

	local NormalSlot: DropperSlotState = _CreateSlotState(Plot, SLOT_LONG, TYPE_NORMAL)
	local AutoSlot: DropperSlotState = _CreateSlotState(Plot, SLOT_WIDE, TYPE_AUTO)

	Slots[SLOT_LONG] = NormalSlot
	Slots[SLOT_WIDE] = AutoSlot

	local PlotState: PlotState = {
		Plot = Plot,
		Slots = Slots,
	}

	_PlotStates[Plot] = PlotState
	return PlotState
end

local function _GetPlayerPlot(Player: Player): Model?
	return _PlayerPlots[Player]
end

local function _GetPlotState(Player: Player): PlotState?
	local Plot: Model? = _GetPlayerPlot(Player)
	if not Plot then
		return nil
	end
	local OwnerId: any = Plot:GetAttribute(OWNER_ATTRIBUTE_NAME)
	if typeof(OwnerId) ~= "number" or OwnerId ~= Player.UserId then
		return nil
	end
	return _PlotStates[Plot]
end

local function _GetCandyStateFromAction(PlotState: PlotState, SlotId: string, TapId: number?): CandyState?
	local SlotState: DropperSlotState? = PlotState.Slots[SlotId]
	if not SlotState then
		return nil
	end

	if SlotState.Type == TYPE_NORMAL then
		return SlotState.Candy
	end

	if not TapId then
		return nil
	end

	local TapStates: { [number]: CandyState }? = SlotState.Taps
	if not TapStates then
		return nil
	end

	return TapStates[TapId]
end

local function _GetFirstEmptyTap(SlotState: DropperSlotState): CandyState?
	local TapStates: { [number]: CandyState }? = SlotState.Taps
	if not TapStates then
		return nil
	end

	for _, TapState: CandyState in TapStates do
		if not _HasCandy(TapState) then
			return TapState
		end
	end

	return nil
end

local function _GetEquippedCandyTool(Player: Player): Tool?
	local Character: Model? = Player.Character
	if not Character then
		return nil
	end

	local EquippedTool: Tool? = Character:FindFirstChildOfClass("Tool")
	if not EquippedTool then
		return nil
	end
	return EquippedTool
end

local function _ReadToolSettings(ToolInstance: Tool): (number?, number?, string?, boolean?, number?)
	local Settings: Instance? = ToolInstance:FindFirstChild(SETTINGS_FOLDER_NAME)
	if not Settings or not Settings:IsA("Configuration") then
		return nil, nil, nil, nil, nil
	end

	local Level: any = Settings:GetAttribute("Level")
	local Exp: any = Settings:GetAttribute("Exp")
	local Mutation: any = Settings:GetAttribute("Mutation")
	local Mutated: any = Settings:GetAttribute("Mutated")
	local Size: any = Settings:GetAttribute("Size")

	return
		if typeof(Level) == "number" then Level else nil,
	if typeof(Exp) == "number" then Exp else nil,
	if typeof(Mutation) == "string" then Mutation else nil,
	if typeof(Mutated) == "boolean" then Mutated else nil,
	if typeof(Size) == "number" then Size else nil
end

local function _GetCandyModelFromTool(ToolInstance: Tool): string?
	if DEBUG_ENABLED then
		print(`[DropperServer] Resolving candy from tool {ToolInstance.Name}`)
	end
	local AttributeModel: any = ToolInstance:GetAttribute(TOOL_ATTRIBUTE_CANDY_MODEL)
	if typeof(AttributeModel) == "string" and AttributeModel ~= EMPTY_STRING then
		if DEBUG_ENABLED then
			print(`[DropperServer] Tool attribute CandyModel={AttributeModel}`)
		end
		return AttributeModel
	end

	local ToolMap: { [string]: string } = Constants.Candy.ToolMap
	local Mapped: string? = ToolMap[ToolInstance.Name]
	if Mapped then
		if DEBUG_ENABLED then
			print(`[DropperServer] ToolMap matched {ToolInstance.Name} -> {Mapped}`)
		end
		return Mapped
	end

	local Evolutions: { [string]: CandyEvolution } = Constants.Candy.Evolutions
	if Evolutions[ToolInstance.Name] then
		if DEBUG_ENABLED then
			print(`[DropperServer] Evolution matched tool name {ToolInstance.Name}`)
		end
		return ToolInstance.Name
	end

	local AssetsRoot: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_ROOT_NAME)
	if AssetsRoot then
		local CandiesFolder: Instance? = AssetsRoot:FindFirstChild(CANDIES_FOLDER_NAME)
		if CandiesFolder then
			local Asset: Instance? = CandiesFolder:FindFirstChild(ToolInstance.Name)
			if Asset and Asset:IsA("Model") then
				if DEBUG_ENABLED then
					print(`[DropperServer] Candies folder matched tool name {ToolInstance.Name}`)
				end
				return ToolInstance.Name
			end
		end
	end

	if DEBUG_ENABLED then
		print("[DropperServer] No candy match for tool")
	end
	return nil
end

local function _HandlePlaceCandy(Player: Player, SlotId: string, TapId: number?): ()
	if DEBUG_ENABLED then
		print(`[DropperServer] PlaceCandy request Player={Player.Name} Slot={SlotId} Tap={TapId}`)
	end
	local PlotState: PlotState? = _GetPlotState(Player)
	if not PlotState then
		if DEBUG_ENABLED then
			print("[DropperServer] No PlotState for player")
		end
		return
	end

	local SlotState: DropperSlotState? = PlotState.Slots[SlotId]
	if not SlotState then
		if DEBUG_ENABLED then
			print("[DropperServer] SlotState missing")
		end
		return
	end

	local CandyState: CandyState? = nil

	if SlotState.Type == TYPE_NORMAL then
		CandyState = SlotState.Candy
	elseif TapId then
		CandyState = _GetCandyStateFromAction(PlotState, SlotId, TapId)
	else
		CandyState = _GetFirstEmptyTap(SlotState)
	end

	if not CandyState then
		if DEBUG_ENABLED then
			print("[DropperServer] CandyState missing")
		end
		return
	end

	if _HasCandy(CandyState) then
		if DEBUG_ENABLED then
			print("[DropperServer] Candy already present")
		end
		return
	end

	local ToolInstance: Tool? = _GetEquippedCandyTool(Player)
	if not ToolInstance then
		if DEBUG_ENABLED then
			print("[DropperServer] No candy tool equipped")
		end
		return
	end

	local CandyModel: string? = _GetCandyModelFromTool(ToolInstance)
	if not CandyModel then
		if DEBUG_ENABLED then
			print("[DropperServer] Tool not mapped to candy", ToolInstance.Name)
		end
		return
	end

	if DEBUG_ENABLED then
		print(`[DropperServer] Placing candy {CandyModel}`)
	end
	local Level: number?, Exp: number?, Mutation: string?, Mutated: boolean?, Size: number? = _ReadToolSettings(ToolInstance)
	if Level or Exp or Mutation or Mutated or Size then
		_SetCandyWithState(CandyState, CandyModel, Level, Exp, Mutation, Mutated, Size)
	else
		_SetCandy(CandyState, CandyModel)
	end
	if DEBUG_ENABLED then
		local ModelValue: any = CandyState.Plot:GetAttribute(CandyState.Keys.CandyModel)
		local HasValue: any = CandyState.Plot:GetAttribute(CandyState.Keys.HasCandy)
		print(`[DropperServer] Candy attrs model={ModelValue} has={HasValue}`)
	end

	if ToolInstance.Parent then
		if DEBUG_ENABLED then
			print(`[DropperServer] Removing tool {ToolInstance.Name} from inventory`)
		end
		ToolInstance:Destroy()
	end
end

local function _HandleDrop(Player: Player, SlotId: string): ()
	local PlotState: PlotState? = _GetPlotState(Player)
	if not PlotState then
		return
	end

	local SlotState: DropperSlotState? = PlotState.Slots[SlotId]
	if not SlotState or SlotState.Type ~= TYPE_NORMAL then
		return
	end

	local CandyState: CandyState? = SlotState.Candy
	if not CandyState or not _HasCandy(CandyState) then
		return
	end

	local DebounceKey: string = CandyState.Keys.DropSequence
	local LastTime: number = _ManualDropDebounce[DebounceKey] or 0
	local Now: number = os.clock()
	local DebounceTime: number = Constants.Timing.ManualDebounce
	if Now - LastTime < DebounceTime then
		return
	end

	_ManualDropDebounce[DebounceKey] = Now
	_TriggerDrop(CandyState, false, Constants.Timing.ManualDropTime)
end

local function _HandleRemoveCandy(Player: Player, SlotId: string, TapId: number?): ()
	local PlotState: PlotState? = _GetPlotState(Player)
	if not PlotState then
		return
	end

	local CandyState: CandyState? = _GetCandyStateFromAction(PlotState, SlotId, TapId)
	if not CandyState then
		return
	end
	if not _HasCandy(CandyState) then
		return
	end

	local CandyName: string = _GetStringAttribute(CandyState.Plot, CandyState.Keys.CandyModel, EMPTY_STRING)
	local CandyLevel: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, DEFAULT_NUMBER)
	local CandyExp: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyProgress, DEFAULT_NUMBER)
	local MutationName: string = _GetStringAttribute(CandyState.Plot, CandyState.Keys.Mutation, EMPTY_STRING)
	local Mutated: boolean = _GetBoolAttribute(CandyState.Plot, CandyState.Keys.Mutated, DEFAULT_BOOL)
	local CandyScale: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyScale, DEFAULT_NUMBER)

	_RemoveCandy(CandyState)
	_GiveCandyTool(Player, CandyName, CandyLevel, CandyExp, MutationName, Mutated, CandyScale)
end

local function _StartAutoLoop(PlotState: PlotState): ()
	if _AutoLoopActive[PlotState.Plot] then
		return
	end

	_AutoLoopActive[PlotState.Plot] = true

	task.spawn(function(): ()
		local Plot: Model = PlotState.Plot
		while Plot.Parent do
			local Now: number = os.clock()
			local AutoSlot: DropperSlotState? = PlotState.Slots[SLOT_WIDE]
			if AutoSlot and AutoSlot.Taps then
				for _, TapState: CandyState in AutoSlot.Taps do
					if _HasCandy(TapState) then
						local DebounceKey: string = TapState.Keys.DropSequence
						local NextTime: number = _AutoNextDropTime[DebounceKey] or 0
						if Now >= NextTime then
							_AutoNextDropTime[DebounceKey] = Now + Constants.Timing.AutoDropInterval
							_TriggerDrop(TapState, true, Constants.Timing.AutoDropTime)
						end
					end
				end
			end

			task.wait(Constants.Timing.AutoLoopStep)
		end

		_AutoLoopActive[PlotState.Plot] = nil
	end)
end

local function _ResetPlotState(PlotState: PlotState): ()
	local NormalSlot: DropperSlotState? = PlotState.Slots[SLOT_LONG]
	if NormalSlot and NormalSlot.Candy then
		_ResetCandyState(NormalSlot.Candy)
	end

	local AutoSlot: DropperSlotState? = PlotState.Slots[SLOT_WIDE]
	if AutoSlot and AutoSlot.Taps then
		for _, TapState: CandyState in AutoSlot.Taps do
			_ResetCandyState(TapState)
		end
	end
end

local function _SetupPlot(Plot: Model): ()
	local PlotState: PlotState = _PlotStates[Plot] or _CreatePlotState(Plot)
	_ResetPlotState(PlotState)
	_StartAutoLoop(PlotState)
end

--\\ PUBLIC FUNCTIONS \\ -- TR
function module:Init(): ()
	PlotmeService.Signals.AssignPlot:Connect(function(MetaPlayer: { Instance: Player, Cache: { Plot: Model } }): ()
		local PlayerInstance: Player = MetaPlayer.Instance
		local Plot: Model = MetaPlayer.Cache.Plot
		_PlayerPlots[PlayerInstance] = Plot
		_SetupPlot(Plot)
	end)

	PlotmeService.Signals.RemovePlot:Connect(function(MetaPlayer: { Instance: Player, Cache: { Plot: Model } }): ()
		local PlayerInstance: Player = MetaPlayer.Instance
		_PlayerPlots[PlayerInstance] = nil
	end)

	Players.PlayerRemoving:Connect(function(PlayerInstance: Player): ()
		_PlayerPlots[PlayerInstance] = nil
	end)

	Packets.Dropper.OnServerEvent:Connect(function(PlayerInstance: Player, Action: string, Data: { [string]: any }): ()
		if DEBUG_ENABLED then
			print(`[DropperServer] Packet received Action={Action} DataType={typeof(Data)}`)
		end
		local SlotId: string?, TapId: number? = _ReadActionData(Data)
		if DEBUG_ENABLED then
			local RawSlot: any = if typeof(Data) == "table" then Data.SlotId else nil
			local RawTap: any = if typeof(Data) == "table" then Data.TapId else nil
			local ArraySlot: any = if typeof(Data) == "table" then Data[1] else nil
			local ArrayTap: any = if typeof(Data) == "table" then Data[2] else nil
			print(
				`[DropperServer] Parsed SlotId={tostring(SlotId)} TapId={tostring(TapId)} RawSlot={tostring(RawSlot)} RawTap={tostring(RawTap)} Arr1={tostring(ArraySlot)} Arr2={tostring(ArrayTap)}`
			)
		end
		if Action == ACTION_PLACE_CANDY then
			if SlotId then
				_HandlePlaceCandy(PlayerInstance, SlotId, TapId)
			end
			return
		end

		if Action == ACTION_DROP then
			if SlotId then
				_HandleDrop(PlayerInstance, SlotId)
			end
			return
		end

		if Action == ACTION_REMOVE_CANDY then
			if SlotId then
				_HandleRemoveCandy(PlayerInstance, SlotId, TapId)
			end
			return
		end
	end)

	local Map: Instance? = workspace:FindFirstChild(MAP_FOLDER_NAME)
	if Map and (Map:IsA("Folder") or Map:IsA("Model")) then
		local PlotsFolder: Instance? = Map:FindFirstChild(PLOTS_FOLDER_NAME)
		if PlotsFolder and (PlotsFolder:IsA("Folder") or PlotsFolder:IsA("Model")) then
			for _, Plot: Instance in PlotsFolder:GetChildren() do
				if Plot:IsA("Model") then
					local OwnerId: any = Plot:GetAttribute(OWNER_ATTRIBUTE_NAME)
					if typeof(OwnerId) == "number" then
						local PlayerInstance: Player? = Players:GetPlayerByUserId(OwnerId)
						if PlayerInstance then
							_PlayerPlots[PlayerInstance] = Plot
							_SetupPlot(Plot)
						end
					end
				end
			end
		end
	end
end

function module:Start(): () end

return module
