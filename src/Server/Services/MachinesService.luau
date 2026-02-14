--!strict

local module: { Init: (self: any) -> (), Start: (self: any) -> () } = {}

--\\ SERVICES \\ -- TR
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")
local HttpService: HttpService = game:GetService("HttpService")

--\\ DEPENDENCIES \\ -- TR
local Constants: any = require(ReplicatedStorage.Modules.Constants.Machines)
local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local PlotmeService: any = require(ServerScriptService.Services.PlotmeService)
local PlayerDataManager: any = require(ReplicatedStorage.Packages.PlayerDataManager)

--\\ TYPES \\ -- TR
type CandyAttributeKeys = {
	CandyModel: string,
	CandyLevel: string,
	CandyProgress: string,
	CandyScale: string,
	HasCandy: string,
	DropSequence: string,
	RemoveSequence: string,
	Mutations: string,
	Mutated: string,
	CandyXp: string,
}

type ProcessAttributeKeys = {
	ProcessState: string,
	ProcessStart: string,
	ProcessEnd: string,
}

type CandyState = {
	Plot: Model,
	GroupId: string,
	SlotId: string,
	TapId: number?,
	Keys: CandyAttributeKeys,
}

type SlotUpgradeState = {
	Level: number,
	Specials: { [string]: number },
}

type MachineSlotState = {
	GroupId: string,
	SlotId: string,
	Config: any,
	Candy: CandyState?,
	Taps: { [number]: CandyState }?,
	Upgrades: SlotUpgradeState,
	ProcessState: string,
	ProcessStart: number,
	ProcessEnd: number,
	ProcessToken: number,
}

type MachineGroupState = {
	GroupId: string,
	Config: any,
	Slots: { [string]: MachineSlotState },
}

type PlotState = {
	Plot: Model,
	Groups: { [string]: MachineGroupState },
}

--\\ CONSTANTS \\ -- TR
local TIMING: any = Constants.Timing
local CANDY_CONFIG: any = Constants.Candy
local MUTATION_CONFIG: any = Constants.Mutation
local MACHINES_CONFIG: { [string]: any } = Constants.Machines

local MAP_FOLDER_NAME: string = "Map"
local PLOTS_FOLDER_NAME: string = "Plots"
local OWNER_ATTRIBUTE_NAME: string = "Owner"

local ATTRIBUTE_PREFIX: string = "Machine"
local ATTRIBUTE_TAP_PREFIX: string = "Tap"
local ATTRIBUTE_FORMAT_NORMAL: string = "%s_%s_%s_%s"
local ATTRIBUTE_FORMAT_TAP: string = "%s_%s_%s_%s%d_%s"

local ATTRIBUTE_KEY_CANDY_MODEL: string = "CandyModel"
local ATTRIBUTE_KEY_CANDY_LEVEL: string = "CandyLevel"
local ATTRIBUTE_KEY_CANDY_PROGRESS: string = "CandyProgress"
local ATTRIBUTE_KEY_CANDY_SCALE: string = "CandyScale"
local ATTRIBUTE_KEY_HAS_CANDY: string = "HasCandy"
local ATTRIBUTE_KEY_DROP_SEQUENCE: string = "DropSequence"
local ATTRIBUTE_KEY_REMOVE_SEQUENCE: string = "RemoveSequence"
local ATTRIBUTE_KEY_MUTATIONS: string = "Mutations"
local ATTRIBUTE_KEY_MUTATED: string = "Mutated"
local ATTRIBUTE_KEY_CANDY_XP: string = "CandyXp"
local TOOL_ATTRIBUTE_DOUBLE_DROPPER_USED: string = "DoubleDropperUsed"
local ATTRIBUTE_KEY_PROCESS_STATE: string = "ProcessState"
local ATTRIBUTE_KEY_PROCESS_START: string = "ProcessStart"
local ATTRIBUTE_KEY_PROCESS_END: string = "ProcessEnd"

local ATTRIBUTE_KEY_UPGRADE_LEVEL: string = "UpgradeLevel"
local ATTRIBUTE_KEY_UPGRADE_PREFIX: string = "Upgrade"

local MEMORIE_FOLDER_NAME: string = "Memorie"
local MEMORIE_PLOTS_FOLDER_NAME: string = "Plots"
local MEMORIE_MACHINES_FOLDER_NAME: string = "Machines"
local MEMORIE_SCALE_FACTOR: number = 1000

local ACTION_PLACE_CANDY: string = "PlaceCandy"
local ACTION_DROP: string = "Drop"
local ACTION_REMOVE_CANDY: string = "RemoveCandy"
local ACTION_UPGRADE_LEVEL: string = "UpgradeLevel"
local ACTION_UPGRADE_LEVEL_MAX: string = "UpgradeLevelMax"
local ACTION_UPGRADE_SPECIAL: string = "UpgradeSpecial"
local ACTION_BUY_MACHINE: string = "BuyMachine"
local ACTION_DOUBLE_DROPPER_START: string = "DoubleDropperStart"

local PROCESS_STATE_IDLE: string = "Idle"
local PROCESS_STATE_PROCESSING: string = "Processing"
local PROCESS_STATE_READY: string = "Ready"

local SETTINGS_FOLDER_NAME: string = "Settings"
local TOOL_ATTRIBUTE_CANDY_MODEL: string = "CandyModel"

local DEFAULT_BOOL: boolean = false
local DEFAULT_NUMBER: number = 0
local DEFAULT_STRING: string = ""
local LEGACY_CANDY_MODEL: string = "Candy"

local UPGRADE_MAX_LEVEL: number = 100
local SCALE_EPSILON: number = 1e-3

local DEBUG_ENABLED: boolean = false
local DEBUG_SAVE: boolean = false
local REMOVE_DEBOUNCE_TIME: number = 1.0
local UPGRADE_DEBOUNCE_TIME: number = 0.08

--\\ STATE \\ -- TR
local _PlayerPlots: { [Player]: Model } = {}
local _PlotStates: { [Model]: PlotState } = {}
local _ManualDropDebounce: { [string]: number } = {}
local _RemoveDebounce: { [string]: number } = {}
local _UpgradeDebounce: { [string]: number } = {}
local _AutoNextDropTime: { [string]: number } = {}
local _AutoLoopActive: { [Model]: boolean } = {}
local _RandomGenerator: Random = Random.new()
local _MemoriePlotsFolder: Folder? = nil
local _MemorieMachinesFolders: { [Model]: Folder } = {}

local _MutationById: { [string]: any } = {}
local _MutationOrder: { [string]: number } = {}
for Index: number, Mutation: any in MUTATION_CONFIG.Types do
	_MutationById[Mutation.Id] = Mutation
	_MutationOrder[Mutation.Id] = Index
end

local _GiveCandyTool: (
	Player: Player,
	CandyName: string,
	Level: number,
	Exp: number,
	Mutations: { string },
	Size: number,
	XpValue: number,
	ExtraAttributes: { [string]: any }?
) -> ()

--\\ PRIVATE FUNCTIONS \\ -- TR
local function _Debug(Message: string, ...: any): ()
	if not DEBUG_ENABLED then
		return
	end

	local Output: string = string.format(Message, ...)
	print("[Machines]", Output)
end

local function _DebugSave(Label: string, Data: any): ()
	if not DEBUG_SAVE then
		return
	end

	local Success: boolean, Encoded: string = pcall(function(): string
		return HttpService:JSONEncode(Data)
	end)
	if Success then
		print(string.format("[Machines][%s] %s", Label, Encoded))
	else
		warn(string.format("[Machines][%s] Failed to encode data", Label))
	end
end

local function _GetPlotOwner(Plot: Model): Player?
	local OwnerId: any = Plot:GetAttribute(OWNER_ATTRIBUTE_NAME)
	if typeof(OwnerId) ~= "number" then
		return nil
	end
	return Players:GetPlayerByUserId(OwnerId)
end

local function _IsSlotOwned(PlayerInstance: Player?, GroupId: string, SlotId: string): boolean
	if not PlayerInstance then
		return false
	end
	return PlotmeService:IsMachineOwned(PlayerInstance, GroupId, SlotId)
end

local function _NormalizeCandyModelName(ModelName: string): string
	if ModelName == LEGACY_CANDY_MODEL then
		return CANDY_CONFIG.DefaultModel
	end
	return ModelName
end

local function _ForceProfileSave(Player: Player, Label: string): ()
	if not DEBUG_SAVE then
		return
	end

	local Cache: any = (PlayerDataManager :: any)._cache
	if typeof(Cache) ~= "table" then
		return
	end
	local Entry: any = Cache[Player]
	if not Entry then
		return
	end
	local Profile: any = Entry.Profile
	if not Profile or typeof(Profile.Save) ~= "function" then
		return
	end

	if DEBUG_SAVE then
		print(string.format("[Machines][ForceSave] %s (%s)", Player.Name, Label))
	end
	Profile:Save()
end

local function _EnsureFolder(Parent: Instance, Name: string): Folder
	local Existing: Instance? = Parent:FindFirstChild(Name)
	if Existing and Existing:IsA("Folder") then
		return Existing
	end
	if Existing then
		Existing:Destroy()
	end

	local FolderInstance: Folder = Instance.new("Folder")
	FolderInstance.Name = Name
	FolderInstance.Parent = Parent
	return FolderInstance
end

local function _GetMemoriePlotsFolder(): Folder
	if _MemoriePlotsFolder and _MemoriePlotsFolder.Parent then
		return _MemoriePlotsFolder
	end

	local Root: Folder = _EnsureFolder(ReplicatedStorage, MEMORIE_FOLDER_NAME)
	local PlotsFolder: Folder = _EnsureFolder(Root, MEMORIE_PLOTS_FOLDER_NAME)
	_MemoriePlotsFolder = PlotsFolder
	return PlotsFolder
end

local function _GetMemorieMachinesFolder(Plot: Model): Folder
	local Cached: Folder? = _MemorieMachinesFolders[Plot]
	if Cached and Cached.Parent then
		return Cached
	end

	local PlotsFolder: Folder = _GetMemoriePlotsFolder()
	local PlotFolder: Folder = _EnsureFolder(PlotsFolder, Plot.Name)
	local MachinesFolder: Folder = _EnsureFolder(PlotFolder, MEMORIE_MACHINES_FOLDER_NAME)
	_MemorieMachinesFolders[Plot] = MachinesFolder
	return MachinesFolder
end

local function _IsScaledKey(Key: string): boolean
	return string.sub(Key, -#ATTRIBUTE_KEY_CANDY_SCALE) == ATTRIBUTE_KEY_CANDY_SCALE
end

local function _EncodeNumber(Key: string, Value: number): number
	if _IsScaledKey(Key) then
		return math.floor((Value * MEMORIE_SCALE_FACTOR) + 0.5)
	end
	return math.floor(Value + 0.5)
end

local function _DecodeNumber(Key: string, Value: number): number
	if _IsScaledKey(Key) then
		return Value / MEMORIE_SCALE_FACTOR
	end
	return Value
end

local function _GetValueObject(Plot: Model, Key: string): ValueBase?
	local Folder: Folder = _GetMemorieMachinesFolder(Plot)
	local GroupId: string? = nil
	local SlotId: string? = nil
	local TapId: number? = nil
	local KeyName: string? = nil
	local TapIdValue: string? = nil

	GroupId, SlotId, TapIdValue, KeyName = string.match(
		Key,
		"^" .. ATTRIBUTE_PREFIX .. "_([^_]+)_([^_]+)_" .. ATTRIBUTE_TAP_PREFIX .. "(%d+)_(.+)$"
	)
	if GroupId and SlotId and TapIdValue and KeyName then
		TapId = tonumber(TapIdValue)
	else
		GroupId, SlotId, KeyName = string.match(Key, "^" .. ATTRIBUTE_PREFIX .. "_([^_]+)_([^_]+)_(.+)$")
	end

	local ValueName: string = Key
	if GroupId and SlotId and KeyName then
		ValueName = KeyName
		local GroupFolder: Instance? = Folder:FindFirstChild(GroupId)
		if GroupFolder and GroupFolder:IsA("Folder") then
			local SlotFolder: Instance? = GroupFolder:FindFirstChild(SlotId)
			if SlotFolder and SlotFolder:IsA("Folder") then
				if TapId then
					local TapsFolder: Instance? = SlotFolder:FindFirstChild("Taps")
					if TapsFolder and TapsFolder:IsA("Folder") then
						local TapFolder: Instance? = TapsFolder:FindFirstChild(tostring(TapId))
						if TapFolder and TapFolder:IsA("Folder") then
							Folder = TapFolder
						end
					end
				else
					if string.sub(KeyName, 1, #ATTRIBUTE_KEY_UPGRADE_PREFIX) == ATTRIBUTE_KEY_UPGRADE_PREFIX then
						local UpgradesFolder: Instance? = SlotFolder:FindFirstChild("Upgrades")
						if UpgradesFolder and UpgradesFolder:IsA("Folder") then
							Folder = UpgradesFolder
						end
					else
						local SlotDataFolder: Instance? = SlotFolder:FindFirstChild("Slot")
						if SlotDataFolder and SlotDataFolder:IsA("Folder") then
							Folder = SlotDataFolder
						end
					end
				end
			end
		end
	end

	local Existing: Instance? = Folder:FindFirstChild(ValueName)
	if Existing and Existing:IsA("ValueBase") then
		return Existing
	end

	if GroupId and SlotId and KeyName then
		local Legacy: Instance? = _GetMemorieMachinesFolder(Plot):FindFirstChild(Key)
		if Legacy and Legacy:IsA("ValueBase") then
			Legacy.Parent = Folder
			Legacy.Name = ValueName
			return Legacy
		end
		if Legacy then
			Legacy:Destroy()
		end
	end
	return nil
end

local function _GetOrCreateValue(Plot: Model, Key: string, ClassName: string): ValueBase
	local MachinesFolder: Folder = _GetMemorieMachinesFolder(Plot)
	local GroupId: string? = nil
	local SlotId: string? = nil
	local TapId: number? = nil
	local KeyName: string? = nil
	local TapIdValue: string? = nil

	GroupId, SlotId, TapIdValue, KeyName = string.match(
		Key,
		"^" .. ATTRIBUTE_PREFIX .. "_([^_]+)_([^_]+)_" .. ATTRIBUTE_TAP_PREFIX .. "(%d+)_(.+)$"
	)
	if GroupId and SlotId and TapIdValue and KeyName then
		TapId = tonumber(TapIdValue)
	else
		GroupId, SlotId, KeyName = string.match(Key, "^" .. ATTRIBUTE_PREFIX .. "_([^_]+)_([^_]+)_(.+)$")
	end

	local Folder: Folder = MachinesFolder
	local ValueName: string = Key
	if GroupId and SlotId and KeyName then
		ValueName = KeyName
		local GroupFolder: Folder = _EnsureFolder(MachinesFolder, GroupId)
		local SlotFolder: Folder = _EnsureFolder(GroupFolder, SlotId)
		if TapId then
			local TapsFolder: Folder = _EnsureFolder(SlotFolder, "Taps")
			Folder = _EnsureFolder(TapsFolder, tostring(TapId))
		else
			if string.sub(KeyName, 1, #ATTRIBUTE_KEY_UPGRADE_PREFIX) == ATTRIBUTE_KEY_UPGRADE_PREFIX then
				Folder = _EnsureFolder(SlotFolder, "Upgrades")
			else
				Folder = _EnsureFolder(SlotFolder, "Slot")
			end
		end

		local Legacy: Instance? = MachinesFolder:FindFirstChild(Key)
		if Legacy and Legacy.ClassName == ClassName then
			Legacy.Parent = Folder
			Legacy.Name = ValueName
			return Legacy :: ValueBase
		end
		if Legacy then
			Legacy:Destroy()
		end
	end

	local Existing: Instance? = Folder:FindFirstChild(ValueName)
	if Existing and Existing.ClassName == ClassName then
		return Existing :: ValueBase
	end
	if Existing then
		Existing:Destroy()
	end

	local ValueInstance: Instance = Instance.new(ClassName)
	ValueInstance.Name = ValueName
	ValueInstance.Parent = Folder
	return ValueInstance :: ValueBase
end

local function _GetAttributeKey(GroupId: string, SlotId: string, TapId: number?, KeyName: string): string
	if TapId then
		return string.format(ATTRIBUTE_FORMAT_TAP, ATTRIBUTE_PREFIX, GroupId, SlotId, ATTRIBUTE_TAP_PREFIX, TapId, KeyName)
	end
	return string.format(ATTRIBUTE_FORMAT_NORMAL, ATTRIBUTE_PREFIX, GroupId, SlotId, KeyName)
end

local function _GetUpgradeKey(GroupId: string, SlotId: string, UpgradeId: string?): string
	if not UpgradeId or UpgradeId == "Level" then
		return string.format(ATTRIBUTE_FORMAT_NORMAL, ATTRIBUTE_PREFIX, GroupId, SlotId, ATTRIBUTE_KEY_UPGRADE_LEVEL)
	end
	return string.format(ATTRIBUTE_FORMAT_NORMAL, ATTRIBUTE_PREFIX, GroupId, SlotId, ATTRIBUTE_KEY_UPGRADE_PREFIX .. UpgradeId)
end

local function _GetStringAttribute(Plot: Model, Key: string, Default: string): string
	local ValueObject: ValueBase? = _GetValueObject(Plot, Key)
	if ValueObject and ValueObject:IsA("StringValue") then
		return ValueObject.Value
	end
	return Default
end

local function _GetNumberAttribute(Plot: Model, Key: string, Default: number): number
	local ValueObject: ValueBase? = _GetValueObject(Plot, Key)
	if ValueObject then
		if ValueObject:IsA("IntValue") then
			return _DecodeNumber(Key, ValueObject.Value)
		end
		if ValueObject:IsA("NumberValue") then
			local Value: number = ValueObject.Value
			if _IsScaledKey(Key) and Value > 10 then
				return Value / MEMORIE_SCALE_FACTOR
			end
			return Value
		end
	end
	return Default
end

local function _GetBoolAttribute(Plot: Model, Key: string, Default: boolean): boolean
	local ValueObject: ValueBase? = _GetValueObject(Plot, Key)
	if ValueObject and ValueObject:IsA("IntValue") then
		return ValueObject.Value ~= 0
	end
	return Default
end

local function _SetAttribute(Plot: Model, Key: string, Value: any): ()
	local ValueType: string? = nil
	local Encoded: any = Value

	if typeof(Value) == "string" then
		ValueType = "StringValue"
	elseif typeof(Value) == "number" then
		ValueType = "IntValue"
		Encoded = _EncodeNumber(Key, Value)
	elseif typeof(Value) == "boolean" then
		ValueType = "IntValue"
		Encoded = if Value then 1 else 0
	end

	if not ValueType then
		return
	end

	local ValueObject: ValueBase = _GetOrCreateValue(Plot, Key, ValueType)
	if ValueType == "StringValue" then
		(ValueObject :: StringValue).Value = Encoded
	else
		(ValueObject :: IntValue).Value = Encoded
	end
end

local function _EncodeMutations(Mutations: { string }): string
	if #Mutations == 0 then
		return DEFAULT_STRING
	end
	return table.concat(Mutations, MUTATION_CONFIG.Separator)
end

local function _DecodeMutations(Value: string): { string }
	if Value == DEFAULT_STRING then
		return {}
	end

	local Results: { string } = {}
	local Separator: string = MUTATION_CONFIG.Separator
	local Pattern: string = "[^" .. Separator .. "]+"
	for Token: string in string.gmatch(Value, Pattern) do
		if Token ~= DEFAULT_STRING then
			table.insert(Results, Token)
		end
	end
	return Results
end
local function _NormalizeMutations(Value: any): { string }
	if typeof(Value) == "table" then
		local Results: { string } = {}
		for _, Item: any in Value do
			if typeof(Item) == "string" then
				table.insert(Results, Item)
			end
		end
		return Results
	end
	if typeof(Value) == "string" then
		return _DecodeMutations(Value)
	end
	return {}
end

local function _SortMutations(Mutations: { string }): ()
	table.sort(Mutations, function(Left: string, Right: string): boolean
		return (_MutationOrder[Left] or 999) < (_MutationOrder[Right] or 999)
	end)
end

local function _BuildCandyState(Plot: Model, GroupId: string, SlotId: string, TapId: number?): CandyState
	local Keys: CandyAttributeKeys = {
		CandyModel = _GetAttributeKey(GroupId, SlotId, TapId, ATTRIBUTE_KEY_CANDY_MODEL),
		CandyLevel = _GetAttributeKey(GroupId, SlotId, TapId, ATTRIBUTE_KEY_CANDY_LEVEL),
		CandyProgress = _GetAttributeKey(GroupId, SlotId, TapId, ATTRIBUTE_KEY_CANDY_PROGRESS),
		CandyScale = _GetAttributeKey(GroupId, SlotId, TapId, ATTRIBUTE_KEY_CANDY_SCALE),
		HasCandy = _GetAttributeKey(GroupId, SlotId, TapId, ATTRIBUTE_KEY_HAS_CANDY),
		DropSequence = _GetAttributeKey(GroupId, SlotId, TapId, ATTRIBUTE_KEY_DROP_SEQUENCE),
		RemoveSequence = _GetAttributeKey(GroupId, SlotId, TapId, ATTRIBUTE_KEY_REMOVE_SEQUENCE),
		Mutations = _GetAttributeKey(GroupId, SlotId, TapId, ATTRIBUTE_KEY_MUTATIONS),
		Mutated = _GetAttributeKey(GroupId, SlotId, TapId, ATTRIBUTE_KEY_MUTATED),
		CandyXp = _GetAttributeKey(GroupId, SlotId, TapId, ATTRIBUTE_KEY_CANDY_XP),
	}

	_SetAttribute(Plot, Keys.CandyModel, DEFAULT_STRING)
	_SetAttribute(Plot, Keys.CandyLevel, DEFAULT_NUMBER)
	_SetAttribute(Plot, Keys.CandyProgress, DEFAULT_NUMBER)
	_SetAttribute(Plot, Keys.CandyScale, DEFAULT_NUMBER)
	_SetAttribute(Plot, Keys.HasCandy, DEFAULT_BOOL)
	_SetAttribute(Plot, Keys.DropSequence, DEFAULT_NUMBER)
	_SetAttribute(Plot, Keys.RemoveSequence, DEFAULT_NUMBER)
	_SetAttribute(Plot, Keys.Mutations, DEFAULT_STRING)
	_SetAttribute(Plot, Keys.Mutated, DEFAULT_BOOL)
	_SetAttribute(Plot, Keys.CandyXp, DEFAULT_NUMBER)

	return {
		Plot = Plot,
		GroupId = GroupId,
		SlotId = SlotId,
		TapId = TapId,
		Keys = Keys,
	}
end

local function _BuildProcessAttributeKeys(GroupId: string, SlotId: string): ProcessAttributeKeys
	return {
		ProcessState = _GetAttributeKey(GroupId, SlotId, nil, ATTRIBUTE_KEY_PROCESS_STATE),
		ProcessStart = _GetAttributeKey(GroupId, SlotId, nil, ATTRIBUTE_KEY_PROCESS_START),
		ProcessEnd = _GetAttributeKey(GroupId, SlotId, nil, ATTRIBUTE_KEY_PROCESS_END),
	}
end

local function _ResetCandyState(CandyState: CandyState): ()
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyModel, DEFAULT_STRING)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyProgress, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyScale, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.HasCandy, DEFAULT_BOOL)
	_SetAttribute(CandyState.Plot, CandyState.Keys.DropSequence, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.RemoveSequence, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.Mutations, DEFAULT_STRING)
	_SetAttribute(CandyState.Plot, CandyState.Keys.Mutated, DEFAULT_BOOL)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyXp, DEFAULT_NUMBER)
end

local function _GetCandyEvolution(ModelName: string): any
	local Normalized: string = _NormalizeCandyModelName(ModelName)
	return CANDY_CONFIG.Evolutions[Normalized]
end

local function _ClampCandyScale(ModelName: string, Scale: number): number
	local Evolution: any = _GetCandyEvolution(ModelName)
	if Evolution and typeof(Evolution.MaxScale) == "number" and Evolution.MaxScale > 0 then
		if Scale > Evolution.MaxScale then
			return Evolution.MaxScale
		end
	end
	return Scale
end

local function _GetCandyMaxLevel(ModelName: string): number?
	local Evolution: any = _GetCandyEvolution(ModelName)
	if not Evolution then
		return nil
	end
	local MaxLevel: any = Evolution.MaxLevel
	if typeof(MaxLevel) == "number" and MaxLevel > 0 then
		return MaxLevel
	end
	return nil
end

local function _ComputeCandyScale(ModelName: string, Progress: number, FallbackScale: number?): number
	local Evolution: any = _GetCandyEvolution(ModelName)
	if Evolution then
		local Scale: number = Evolution.BaseScale + (Progress * Evolution.UpgradeScale)
		return _ClampCandyScale(ModelName, Scale)
	end
	return _ClampCandyScale(ModelName, FallbackScale or 1.0)
end

local function _ComputeCandyScaleForLevel(
	ModelName: string,
	Level: number,
	Progress: number,
	FallbackScale: number?
): number
	local Evolution: any = _GetCandyEvolution(ModelName)
	if Evolution then
		local MaxLevel: number? = _GetCandyMaxLevel(ModelName)
		if MaxLevel and Level >= MaxLevel then
			return _ClampCandyScale(ModelName, Evolution.MaxScale or _ComputeCandyScale(ModelName, Progress, FallbackScale))
		end
	end
	return _ComputeCandyScale(ModelName, Progress, FallbackScale)
end

local function _ResolveCandyScale(ModelName: string, Level: number, Progress: number, StoredScale: number?): number
	local Evolution: any = _GetCandyEvolution(ModelName)
	local BaseScale: number = if Evolution then Evolution.BaseScale else 1.0
	local ComputedScale: number = _ComputeCandyScaleForLevel(ModelName, Level, Progress, BaseScale)
	if typeof(StoredScale) == "number" and StoredScale > 0 then
		local ClampedScale: number = _ClampCandyScale(ModelName, StoredScale)
		if math.abs(ClampedScale - ComputedScale) <= SCALE_EPSILON then
			return ClampedScale
		end
	end
	return ComputedScale
end

local function _ComputeCandyXpValue(ModelName: string, Level: number, Progress: number, Mutations: { string }): number
	local BasePerLevel: number = CANDY_CONFIG.XpPerLevel
	local PerProgress: number = CANDY_CONFIG.XpPerProgress
	if PerProgress <= 0 then
		local Evolution: any = _GetCandyEvolution(ModelName)
		if Evolution and Evolution.Limit and Evolution.Limit > 0 then
			PerProgress = BasePerLevel / Evolution.Limit
		else
			PerProgress = 1
		end
	end

	local BaseValue: number = (Level * BasePerLevel) + (Progress * PerProgress)
	local Multiplier: number = 1
	for _, MutationId: string in Mutations do
		local MutationConfig: any = _MutationById[MutationId]
		if MutationConfig and typeof(MutationConfig.Multiplier) == "number" then
			Multiplier *= MutationConfig.Multiplier
		end
	end

	return math.floor(BaseValue * Multiplier + 0.5)
end

local function _UpdateCandyXpAttribute(CandyState: CandyState): ()
	local RawModelName: string = _GetStringAttribute(CandyState.Plot, CandyState.Keys.CandyModel, DEFAULT_STRING)
	local ModelName: string = _NormalizeCandyModelName(RawModelName)
	if ModelName == DEFAULT_STRING then
		_SetAttribute(CandyState.Plot, CandyState.Keys.CandyXp, DEFAULT_NUMBER)
		return
	end
	if ModelName ~= RawModelName then
		_SetAttribute(CandyState.Plot, CandyState.Keys.CandyModel, ModelName)
	end

	local Level: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, DEFAULT_NUMBER)
	local Progress: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyProgress, DEFAULT_NUMBER)
	local MutationsValue: string = _GetStringAttribute(CandyState.Plot, CandyState.Keys.Mutations, DEFAULT_STRING)
	local Mutations: { string } = _DecodeMutations(MutationsValue)
	local XpValue: number = _ComputeCandyXpValue(ModelName, Level, Progress, Mutations)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyXp, XpValue)
end

local function _HasCandy(CandyState: CandyState): boolean
	return _GetBoolAttribute(CandyState.Plot, CandyState.Keys.HasCandy, DEFAULT_BOOL)
end

local function _SetCandyStateValues(
	CandyState: CandyState,
	CandyModel: string,
	Level: number,
	Progress: number,
	Mutations: { string },
	Scale: number
): ()
	local NormalizedModel: string = _NormalizeCandyModelName(CandyModel)
	local MutationValue: string = _EncodeMutations(Mutations)
	local MutatedValue: boolean = #Mutations > 0

	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyModel, NormalizedModel)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, Level)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyProgress, Progress)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyScale, Scale)
	_SetAttribute(CandyState.Plot, CandyState.Keys.HasCandy, true)
	_SetAttribute(CandyState.Plot, CandyState.Keys.Mutations, MutationValue)
	_SetAttribute(CandyState.Plot, CandyState.Keys.Mutated, MutatedValue)

	_UpdateCandyXpAttribute(CandyState)
end

local function _SetCandy(CandyState: CandyState, CandyModel: string): ()
	CandyModel = _NormalizeCandyModelName(CandyModel)
	local Evolution: any = _GetCandyEvolution(CandyModel)
	local BaseScale: number = if Evolution then Evolution.BaseScale else 1.0
	local MaxLevel: number? = _GetCandyMaxLevel(CandyModel)
	local StartLevel: number = 1
	if MaxLevel and MaxLevel < StartLevel then
		StartLevel = MaxLevel
	end

	_SetCandyStateValues(CandyState, CandyModel, StartLevel, 0, {}, BaseScale)
end

local function _SetCandyWithState(
	CandyState: CandyState,
	CandyModel: string,
	Level: number?,
	Exp: number?,
	Mutations: { string }?,
	Scale: number?
): ()
	CandyModel = _NormalizeCandyModelName(CandyModel)
	local MaxLevel: number? = _GetCandyMaxLevel(CandyModel)

	local Progress: number = if typeof(Exp) == "number" and Exp >= 0 then Exp else 0
	local ResolvedLevel: number = if typeof(Level) == "number" and Level >= 0 then Level else 1
	if MaxLevel and ResolvedLevel > MaxLevel then
		ResolvedLevel = MaxLevel
	end
	local ResolvedScale: number = _ResolveCandyScale(CandyModel, ResolvedLevel, Progress, Scale)
	ResolvedScale = _ClampCandyScale(CandyModel, ResolvedScale)

	local MutationList: { string } = {}
	if Mutations then
		MutationList = Mutations
	end

	_SetCandyStateValues(CandyState, CandyModel, ResolvedLevel, Progress, MutationList, ResolvedScale)
end
local function _GetLevelBonus(SlotState: MachineSlotState): number
	local LevelConfig: any = SlotState.Config.Upgrades.Level
	local Level: number = SlotState.Upgrades.Level
	if Level <= 0 then
		return 0
	end
	if typeof(LevelConfig.Growth) == "number" then
		return math.max(0, Level - 1) * LevelConfig.Growth
	end

	local Tier: any = LevelConfig.Levels[Level]
	if Tier and typeof(Tier.XpBonus) == "number" then
		return Tier.XpBonus
	end

	local Last: any = LevelConfig.Levels[#LevelConfig.Levels]
	if Last and typeof(Last.XpBonus) == "number" then
		return Last.XpBonus
	end

	return 0
end

local function _RoundValue(Value: number): number
	return math.floor(Value + 0.5)
end

local function _GetLevelCostNext(SlotState: MachineSlotState): number?
	local LevelConfig: any = SlotState.Config.Upgrades.Level
	local Level: number = SlotState.Upgrades.Level
	if Level >= UPGRADE_MAX_LEVEL then
		return nil
	end

	local NextLevel: number = Level + 1
	local NextTier: any = LevelConfig.Levels[NextLevel]
	if not NextTier then
		NextTier = LevelConfig.Levels[#LevelConfig.Levels]
	end
	if NextTier and typeof(NextTier.Cost) == "number" then
		return NextTier.Cost
	end
	return nil
end

local function _GetSpecialMultiplier(SlotState: MachineSlotState, UpgradeId: string): number
	local Specials: any = SlotState.Config.Upgrades.Specials
	if not Specials then
		return 1
	end
	local UpgradeConfig: any = Specials[UpgradeId]
	if not UpgradeConfig then
		return 1
	end

	local Level: number = SlotState.Upgrades.Specials[UpgradeId] or 0
	if Level <= 0 then
		return 1
	end
	local Tier: any = UpgradeConfig.Levels[Level]
	if Tier and typeof(Tier.Multiplier) == "number" then
		return Tier.Multiplier
	end
	local Last: any = UpgradeConfig.Levels[#UpgradeConfig.Levels]
	if Last and typeof(Last.Multiplier) == "number" then
		return Last.Multiplier
	end
	return 1
end

local function _GetDropXp(SlotState: MachineSlotState): number
	local LevelConfig: any = SlotState.Config.Upgrades.Level
	local BaseDrop: number = LevelConfig.BaseDropXp
	local Bonus: number = _GetLevelBonus(SlotState)
	local XpMultiplier: number = _GetSpecialMultiplier(SlotState, "Xp")
	return _RoundValue((BaseDrop + Bonus) * XpMultiplier)
end

local function _GetProcessDurationSeconds(SlotState: MachineSlotState, LevelOverride: number?): number
	local LevelConfig: any = SlotState.Config.Upgrades.Level
	if not LevelConfig or LevelConfig.Mode ~= "Time" then
		return 0
	end
	local BaseSeconds: number = if typeof(LevelConfig.BaseTimeSeconds) == "number" then LevelConfig.BaseTimeSeconds else 0
	local Reduction: number = if typeof(LevelConfig.TimeReduction) == "number" then LevelConfig.TimeReduction else 0
	local MinSeconds: number = if typeof(LevelConfig.MinTimeSeconds) == "number" then LevelConfig.MinTimeSeconds else 0
	local Level: number = LevelOverride or SlotState.Upgrades.Level or 1
	local Seconds: number = BaseSeconds - (math.max(0, Level - 1) * Reduction)
	if Seconds < MinSeconds then
		Seconds = MinSeconds
	end
	if Seconds < 0 then
		Seconds = 0
	end
	return Seconds
end

local function _IsTimeProcessSlot(SlotState: MachineSlotState): boolean
	local LevelConfig: any = SlotState.Config.Upgrades.Level
	return LevelConfig ~= nil and LevelConfig.Mode == "Time"
end

local function _GetSpeedMultiplier(SlotState: MachineSlotState): number
	return _GetSpecialMultiplier(SlotState, "Speed")
end

local function _GetMutationChanceMultiplier(SlotState: MachineSlotState): number
	return _GetSpecialMultiplier(SlotState, "Mutation")
end

local function _ApplyMutation(CandyState: CandyState, ChanceMultiplier: number): ()
	if not _HasCandy(CandyState) then
		return
	end

	local MutationValue: string = _GetStringAttribute(CandyState.Plot, CandyState.Keys.Mutations, DEFAULT_STRING)
	local MutationList: { string } = _DecodeMutations(MutationValue)

	if #MutationList >= MUTATION_CONFIG.MaxCount then
		return
	end

	local Chance: number = MUTATION_CONFIG.Chance * ChanceMultiplier
	if Chance <= 0 then
		return
	end

	if _RandomGenerator:NextNumber() > Chance then
		return
	end

	local Available: { string } = {}
	local Existing: { [string]: boolean } = {}
	for _, MutationId: string in MutationList do
		Existing[MutationId] = true
	end

	for _, MutationData: any in MUTATION_CONFIG.Types do
		if not Existing[MutationData.Id] then
			table.insert(Available, MutationData.Id)
		end
	end

	if #Available == 0 then
		return
	end

	local PickIndex: number = _RandomGenerator:NextInteger(1, #Available)
	local Picked: string = Available[PickIndex]
	table.insert(MutationList, Picked)
	_SortMutations(MutationList)

	_SetAttribute(CandyState.Plot, CandyState.Keys.Mutations, _EncodeMutations(MutationList))
	_SetAttribute(CandyState.Plot, CandyState.Keys.Mutated, true)
	_UpdateCandyXpAttribute(CandyState)
end

local function _GetEvolutionLimit(Evolution: any, Level: number): number
	local BaseLimit: number = if Evolution and typeof(Evolution.Limit) == "number" then Evolution.Limit else 0
	if BaseLimit <= 0 then
		return 0
	end
	local Growth: number = if Evolution and typeof(Evolution.LimitGrowth) == "number" then Evolution.LimitGrowth else 0
	if Growth <= 0 then
		return BaseLimit
	end
	if Level <= 1 then
		return BaseLimit
	end
	local Multiplier: number = math.pow(1 + Growth, math.max(0, Level - 1))
	return math.floor(BaseLimit * Multiplier + 0.5)
end

local function _ApplyProgress(CandyState: CandyState, SlotState: MachineSlotState, AddProgress: number, IsAuto: boolean): ()
	if not _HasCandy(CandyState) then
		return
	end

	if AddProgress <= 0 then
		return
	end

	local CurrentModel: string = _GetStringAttribute(CandyState.Plot, CandyState.Keys.CandyModel, DEFAULT_STRING)
	if CurrentModel == DEFAULT_STRING then
		return
	end

	local Evolution: any = _GetCandyEvolution(CurrentModel)
	if not Evolution then
		return
	end

	local CurrentLevel: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, DEFAULT_NUMBER)
	local MaxLevel: number? = _GetCandyMaxLevel(CurrentModel)
	if MaxLevel and CurrentLevel >= MaxLevel then
		return
	end

	local CurrentProgress: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyProgress, DEFAULT_NUMBER)
	local NewProgress: number = CurrentProgress + AddProgress
	local NewLevel: number = CurrentLevel
	local NewModel: string = CurrentModel
	local NewEvolution: any = Evolution

	while NewEvolution and _GetEvolutionLimit(NewEvolution, NewLevel) > 0 do
		local Required: number = _GetEvolutionLimit(NewEvolution, NewLevel)
		if NewProgress < Required then
			break
		end
		NewProgress -= Required
		NewLevel += 1
		if MaxLevel and NewLevel >= MaxLevel then
			NewLevel = MaxLevel
			NewProgress = 0
			break
		end

		if NewEvolution.Next and NewEvolution.Next ~= DEFAULT_STRING then
			NewModel = NewEvolution.Next
			NewEvolution = _GetCandyEvolution(NewModel) or NewEvolution
		end
	end

	local NewScale: number = _ComputeCandyScaleForLevel(
		NewModel,
		NewLevel,
		NewProgress,
		if NewEvolution then NewEvolution.BaseScale else 1.0
	)

	if NewModel ~= CurrentModel then
		_SetAttribute(CandyState.Plot, CandyState.Keys.CandyModel, NewModel)
	end

	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, NewLevel)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyProgress, NewProgress)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyScale, NewScale)

	if IsAuto then
		local ChanceMultiplier: number = _GetMutationChanceMultiplier(SlotState)
		_ApplyMutation(CandyState, ChanceMultiplier)
	end

	_UpdateCandyXpAttribute(CandyState)
end

local function _SetProcessState(Plot: Model, GroupId: string, SlotId: string, SlotState: MachineSlotState, State: string, StartValue: number, EndValue: number): ()
	local ProcessKeys: ProcessAttributeKeys = _BuildProcessAttributeKeys(GroupId, SlotId)
	SlotState.ProcessState = State
	SlotState.ProcessStart = StartValue
	SlotState.ProcessEnd = EndValue
	_SetAttribute(Plot, ProcessKeys.ProcessState, State)
	_SetAttribute(Plot, ProcessKeys.ProcessStart, StartValue)
	_SetAttribute(Plot, ProcessKeys.ProcessEnd, EndValue)
end

local function _CompleteTimeProcess(SlotState: MachineSlotState, CandyState: CandyState): ()
	if not _HasCandy(CandyState) then
		_SetProcessState(CandyState.Plot, SlotState.GroupId, SlotState.SlotId, SlotState, PROCESS_STATE_READY, SlotState.ProcessStart, SlotState.ProcessEnd)
		return
	end

	local CurrentProgress: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyProgress, DEFAULT_NUMBER)
	if CurrentProgress > 0 then
		_ApplyProgress(CandyState, SlotState, CurrentProgress, false)
	end

	_SetProcessState(CandyState.Plot, SlotState.GroupId, SlotState.SlotId, SlotState, PROCESS_STATE_READY, SlotState.ProcessStart, SlotState.ProcessEnd)
end

local function _ApplyOfflineMutations(CandyState: CandyState, Drops: number, SlotState: MachineSlotState): ()
	if Drops <= 0 then
		return
	end

	local MutationValue: string = _GetStringAttribute(CandyState.Plot, CandyState.Keys.Mutations, DEFAULT_STRING)
	local MutationList: { string } = _DecodeMutations(MutationValue)
	if #MutationList >= MUTATION_CONFIG.MaxCount then
		return
	end

	local Chance: number = MUTATION_CONFIG.Chance * _GetMutationChanceMultiplier(SlotState)
	if Chance <= 0 then
		return
	end

	local RemainingDrops: number = Drops
	while RemainingDrops > 0 and #MutationList < MUTATION_CONFIG.MaxCount do
		local Roll: number = _RandomGenerator:NextNumber()
		local Needed: number = math.floor(math.log(1 - Roll) / math.log(1 - Chance)) + 1
		if Needed > RemainingDrops then
			break
		end
		RemainingDrops -= Needed

		local Available: { string } = {}
		local Existing: { [string]: boolean } = {}
		for _, MutationId: string in MutationList do
			Existing[MutationId] = true
		end
		for _, MutationData: any in MUTATION_CONFIG.Types do
			if not Existing[MutationData.Id] then
				table.insert(Available, MutationData.Id)
			end
		end
		if #Available == 0 then
			break
		end
		local PickIndex: number = _RandomGenerator:NextInteger(1, #Available)
		local Picked: string = Available[PickIndex]
		table.insert(MutationList, Picked)
		_SortMutations(MutationList)
	end

	_SetAttribute(CandyState.Plot, CandyState.Keys.Mutations, _EncodeMutations(MutationList))
	_SetAttribute(CandyState.Plot, CandyState.Keys.Mutated, #MutationList > 0)
	_UpdateCandyXpAttribute(CandyState)
end

local function _TriggerDrop(CandyState: CandyState, SlotState: MachineSlotState, IsAuto: boolean, DropTime: number): ()
	if not _HasCandy(CandyState) then
		return
	end

	local CurrentModel: string = _GetStringAttribute(CandyState.Plot, CandyState.Keys.CandyModel, DEFAULT_STRING)
	if CurrentModel == DEFAULT_STRING then
		return
	end

	local MaxLevel: number? = _GetCandyMaxLevel(CurrentModel)
	local CurrentLevel: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, DEFAULT_NUMBER)
	if MaxLevel and CurrentLevel >= MaxLevel then
		return
	end

	local CurrentSequence: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.DropSequence, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.DropSequence, CurrentSequence + 1)

	local DropXp: number = _GetDropXp(SlotState)
	if DropXp <= 0 then
		return
	end

	if IsAuto and DropTime > 0 then
		task.delay(DropTime, function(): ()
			if not _HasCandy(CandyState) then
				return
			end
			_ApplyProgress(CandyState, SlotState, DropXp, IsAuto)
		end)
	else
		_ApplyProgress(CandyState, SlotState, DropXp, IsAuto)
	end
end

local function _RemoveCandy(CandyState: CandyState): ()
	if not _HasCandy(CandyState) then
		return
	end

	local RemoveSequence: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.RemoveSequence, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.HasCandy, false)
	_SetAttribute(CandyState.Plot, CandyState.Keys.RemoveSequence, RemoveSequence + 1)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyModel, DEFAULT_STRING)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyProgress, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.Mutations, DEFAULT_STRING)
	_SetAttribute(CandyState.Plot, CandyState.Keys.Mutated, DEFAULT_BOOL)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyXp, DEFAULT_NUMBER)
	_SetAttribute(CandyState.Plot, CandyState.Keys.CandyScale, DEFAULT_NUMBER)
end

do
	local RunService: RunService = game:GetService("RunService")
	local ASSETS_CONFIG: any = Constants.Assets
	local ASSETS_ROOT_NAME: string = if ASSETS_CONFIG and typeof(ASSETS_CONFIG.RootFolder) == "string"
		then ASSETS_CONFIG.RootFolder
		else "Assets"
	local ASSETS_TOOLS_FOLDER_NAME: string = "Tools"
	local ASSETS_MODELS_FOLDER_NAME: string = if ASSETS_CONFIG and typeof(ASSETS_CONFIG.ModelsFolder) == "string"
		then ASSETS_CONFIG.ModelsFolder
		else "Models"
	local ASSETS_CANDIES_FOLDER_NAME: string = if ASSETS_CONFIG and typeof(ASSETS_CONFIG.CandiesFolder) == "string"
		then ASSETS_CONFIG.CandiesFolder
		else "Candies"
	local LEVEL_BAR_TEMPLATE_NAME: string = if ASSETS_CONFIG and typeof(ASSETS_CONFIG.LevelBarName) == "string"
		then ASSETS_CONFIG.LevelBarName
		else "LevelBar"
	local TOOL_MUTATION_HIGHLIGHT_NAME: string = "ToolMutationHighlight"
	local TOOL_MUTATION_HIGHLIGHT_FILL_TRANSPARENCY: number = 0.5
	local TOOL_MUTATION_HIGHLIGHT_OUTLINE_TRANSPARENCY: number = 1
	local TOOL_MUTATION_RAINBOW_SPEED: number = 0.6

	local _ToolRainbowHighlights: { [Highlight]: boolean } = {}
	local _ToolRainbowConnection: RBXScriptConnection? = nil

	local function _NormalizeNameForLookup(Value: string): string
	local Output: string = string.lower(Value)
	Output = string.gsub(Output, "%s+", "")
	Output = string.gsub(Output, "_", "")
	Output = string.gsub(Output, "-", "")
	return Output
end

local function _AsTextLike(Value: Instance?): Instance?
	if Value and (Value:IsA("TextLabel") or Value:IsA("TextButton") or Value:IsA("TextBox")) then
		return Value
	end
	return nil
end

local function _SetTextLikeText(TextLike: Instance?, Text: string): ()
	local Target: Instance? = _AsTextLike(TextLike)
	if not Target then
		return
	end

	local AnyTarget: any = Target
	AnyTarget.Text = Text
end

local function _FindChildByNormalizedName(Parent: Instance, Name: string): Instance?
	local Direct: Instance? = Parent:FindFirstChild(Name)
	if Direct then
		return Direct
	end

	local TargetNormalized: string = _NormalizeNameForLookup(Name)
	for _, Child: Instance in Parent:GetChildren() do
		if _NormalizeNameForLookup(Child.Name) == TargetNormalized then
			return Child
		end
	end

	return nil
end

local function _FindFirstBasePart(Target: Instance): BasePart?
	if Target:IsA("BasePart") then
		return Target
	end
	for _, Descendant in Target:GetDescendants() do
		if Descendant:IsA("BasePart") then
			return Descendant
		end
	end
	return nil
end

local function _EnsureModelPrimaryPart(ModelInstance: Model): BasePart?
	if ModelInstance.PrimaryPart then
		return ModelInstance.PrimaryPart
	end

	local Handle: Instance? = ModelInstance:FindFirstChild("Handle", true)
	if Handle and Handle:IsA("BasePart") then
		ModelInstance.PrimaryPart = Handle
		return Handle
	end

	local FirstPart: BasePart? = _FindFirstBasePart(ModelInstance)
	if FirstPart then
		ModelInstance.PrimaryPart = FirstPart
	end
	return FirstPart
end

local function _GetAssetsFolder(): Instance?
	local Assets: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_ROOT_NAME)
	return Assets
end

local function _GetAssetsToolsFolder(): Instance?
	local Assets: Instance? = _GetAssetsFolder()
	if not Assets then
		return nil
	end
	return Assets:FindFirstChild(ASSETS_TOOLS_FOLDER_NAME)
end

local function _GetAssetsModelsFolder(): Instance?
	local Assets: Instance? = _GetAssetsFolder()
	if not Assets then
		return nil
	end
	return Assets:FindFirstChild(ASSETS_MODELS_FOLDER_NAME)
end

local function _GetAssetsCandiesFolder(): Instance?
	local Assets: Instance? = _GetAssetsFolder()
	if Assets then
		local DirectCandies: Instance? = _FindChildByNormalizedName(Assets, ASSETS_CANDIES_FOLDER_NAME)
		if DirectCandies then
			return DirectCandies
		end
	end

	local ModelsFolder: Instance? = _GetAssetsModelsFolder()
	if not ModelsFolder then
		return nil
	end
	return _FindChildByNormalizedName(ModelsFolder, ASSETS_CANDIES_FOLDER_NAME)
end

local function _FindCandyToolTemplate(CandyName: string): Instance?
	local ToolsFolder: Instance? = _GetAssetsToolsFolder()
	if not ToolsFolder then
		return nil
	end

	local Direct: Instance? = _FindChildByNormalizedName(ToolsFolder, CandyName)
	if Direct then
		return Direct
	end

	local ToolMap: any = CANDY_CONFIG.ToolMap
	if typeof(ToolMap) == "table" then
		local TargetNormalized: string = _NormalizeNameForLookup(CandyName)
		for _, Child: Instance in ToolsFolder:GetChildren() do
			local MappedCandy: any = ToolMap[Child.Name]
			if typeof(MappedCandy) == "string" and _NormalizeNameForLookup(MappedCandy) == TargetNormalized then
				return Child
			end
		end
	end

	return nil
end

local function _FindCandyModelTemplate(CandyName: string): Instance?
	local CandiesFolder: Instance? = _GetAssetsCandiesFolder()
	if not CandiesFolder then
		return nil
	end

	local Direct: Instance? = _FindChildByNormalizedName(CandiesFolder, CandyName)
	if Direct then
		return Direct
	end

	local TargetNormalized: string = _NormalizeNameForLookup(CandyName)
	for _, Child: Instance in CandiesFolder:GetChildren() do
		if Child:IsA("Folder") then
			local MappedName: any = Child:GetAttribute("Name")
			if typeof(MappedName) == "string" and _NormalizeNameForLookup(MappedName) == TargetNormalized then
				return Child
			end
		end
	end

	return nil
end

local function _CloneCandyModelFromTemplate(Template: Instance, CandyName: string): Model?
	if Template:IsA("Model") then
		local Clone: Model = Template:Clone()
		Clone.Name = CandyName
		return Clone
	end

	if Template:IsA("BasePart") then
		local Wrapper: Model = Instance.new("Model")
		Wrapper.Name = CandyName
		local PartClone: BasePart = Template:Clone()
		PartClone.Parent = Wrapper
		Wrapper.PrimaryPart = PartClone
		return Wrapper
	end

	if Template:IsA("Folder") then
		local ChildModel: Model? = Template:FindFirstChildWhichIsA("Model")
		if ChildModel then
			local Clone: Model = ChildModel:Clone()
			Clone.Name = CandyName
			return Clone
		end
		local ChildPart: BasePart? = Template:FindFirstChildWhichIsA("BasePart")
		if ChildPart then
			local Wrapper: Model = Instance.new("Model")
			Wrapper.Name = CandyName
			local PartClone: BasePart = ChildPart:Clone()
			PartClone.Parent = Wrapper
			Wrapper.PrimaryPart = PartClone
			return Wrapper
		end
	end

	return nil
end

local function _CreateCandyToolFromTemplate(CandyName: string): Tool
	local Template: Instance? = _FindCandyToolTemplate(CandyName)
	local ToolInstance: Tool

	if Template and Template:IsA("Tool") then
		ToolInstance = Template:Clone()
	elseif Template then
		ToolInstance = Instance.new("Tool")
		local Clone: Instance = Template:Clone()
		Clone.Parent = ToolInstance
	else
		ToolInstance = Instance.new("Tool")
	end

	ToolInstance.Name = CandyName

	local Handle: Instance? = ToolInstance:FindFirstChild("Handle", true)
	if not (Handle and Handle:IsA("BasePart")) then
		ToolInstance.RequiresHandle = false
	end

	return ToolInstance
end

local function _FindCandyModelInTool(ToolInstance: Tool, CandyName: string): Model?
	local Direct: Instance? = ToolInstance:FindFirstChild(CandyName, true)
	if Direct and Direct:IsA("Model") then
		return Direct
	end

	local TargetNormalized: string = _NormalizeNameForLookup(CandyName)
	local FirstModel: Model? = nil
	for _, Descendant in ToolInstance:GetDescendants() do
		if Descendant:IsA("Model") then
			if not FirstModel then
				FirstModel = Descendant
			end
			if _NormalizeNameForLookup(Descendant.Name) == TargetNormalized then
				return Descendant
			end
		end
	end

	return FirstModel
end

local function _EnsureCandyModelInTool(ToolInstance: Tool, CandyName: string): Model?
	local Existing: Model? = _FindCandyModelInTool(ToolInstance, CandyName)
	if Existing and _NormalizeNameForLookup(Existing.Name) == _NormalizeNameForLookup(CandyName) then
		return Existing
	end

	local Template: Instance? = _FindCandyModelTemplate(CandyName)
	if Template then
		local Clone: Model? = _CloneCandyModelFromTemplate(Template, CandyName)
		if Clone then
			Clone.Parent = ToolInstance
			return Clone
		end
	end

	if Existing then
		Existing.Name = CandyName
		return Existing
	end

	return nil
end

local function _CloneLevelBarBillboard(Template: Instance): BillboardGui?
	if Template:IsA("BillboardGui") then
		return Template:Clone()
	end

	local BillboardTemplate: Instance? = Template:FindFirstChildWhichIsA("BillboardGui", true)
	if BillboardTemplate and BillboardTemplate:IsA("BillboardGui") then
		return BillboardTemplate:Clone()
	end

	return nil
end

local function _GetEvolutionLimitForLevelBar(ModelName: string, Level: number): number
	local Evolution: any = _GetCandyEvolution(ModelName)
	if not Evolution or typeof(Evolution.Limit) ~= "number" or Evolution.Limit <= 0 then
		return 1
	end

	local BaseLimit: number = Evolution.Limit
	local Growth: number = if typeof(Evolution.LimitGrowth) == "number" then Evolution.LimitGrowth else 0
	if Growth <= 0 or Level <= 1 then
		return BaseLimit
	end

	local Multiplier: number = math.pow(1 + Growth, math.max(0, Level - 1))
	return math.floor((BaseLimit * Multiplier) + 0.5)
end

local function _FindLevelBarFill(Billboard: BillboardGui): GuiObject?
	local DirectBar: Instance? = Billboard:FindFirstChild("Bar")
	if DirectBar and DirectBar:IsA("GuiObject") then
		local Inner: Instance? = DirectBar:FindFirstChild("Bar")
		if Inner and Inner:IsA("GuiObject") then
			return Inner
		end
		return DirectBar
	end

	for _, Descendant in Billboard:GetDescendants() do
		if Descendant:IsA("GuiObject") and Descendant.Name == "Bar" then
			local Parent: Instance? = Descendant.Parent
			if Parent and Parent:IsA("GuiObject") and Parent.Name == "Bar" then
				return Descendant
			end
		end
	end

	local Candidate: Instance? = Billboard:FindFirstChild("Bar", true)
	if Candidate and Candidate:IsA("GuiObject") then
		local Inner: Instance? = Candidate:FindFirstChild("Bar")
		if Inner and Inner:IsA("GuiObject") then
			return Inner
		end
		return Candidate
	end

	return nil
end

local function _FindLevelBarXpLabel(Billboard: BillboardGui): Instance?
	local Direct: Instance? = Billboard:FindFirstChild("XP", true)
	if Direct then
		local TextLike: Instance? = _AsTextLike(Direct)
		if TextLike then
			return TextLike
		end
	end

	local BarContainer: Instance? = Billboard:FindFirstChild("Bar", true)
	if BarContainer then
		local Candidate: Instance? = BarContainer:FindFirstChild("XP", true)
		local TextLike: Instance? = _AsTextLike(Candidate)
		if TextLike then
			return TextLike
		end
	end

	return nil
end

local function _ApplyMutationsToLevelBar(Billboard: BillboardGui, Mutations: { string }): ()
	local MutationRoot: Instance? = Billboard:FindFirstChild("Mutations", true)
	if not MutationRoot or not MutationRoot:IsA("Frame") then
		return
	end

	local MutationFrame: Frame = MutationRoot
	local Template: Instance? = MutationFrame:FindFirstChild("Content", true)
	local TemplateLabel: TextLabel? = if Template and Template:IsA("TextLabel") then Template else nil
	if not TemplateLabel then
		MutationFrame.Visible = #Mutations > 0
		return
	end

	local ParentForClones: Instance = TemplateLabel.Parent or MutationFrame
	for _, Descendant in ParentForClones:GetChildren() do
		if Descendant:IsA("TextLabel") and Descendant ~= TemplateLabel then
			if Descendant:GetAttribute("ToolMutationClone") == true then
				Descendant:Destroy()
			end
		end
	end

	if #Mutations == 0 then
		MutationFrame.Visible = false
		TemplateLabel.Visible = false
		return
	end

	MutationFrame.Visible = true
	TemplateLabel.Visible = false
	for _, MutationId: string in Mutations do
		local Clone: TextLabel = TemplateLabel:Clone()
		Clone.Visible = true
		Clone.Text = MutationId
		Clone:SetAttribute("ToolMutationClone", true)
		Clone.Parent = ParentForClones
	end
end

local function _SetToolRainbowHighlightTracking(HighlightInstance: Highlight, Enabled: boolean): ()
	if Enabled then
		_ToolRainbowHighlights[HighlightInstance] = true
		if _ToolRainbowConnection then
			return
		end

		_ToolRainbowConnection = RunService.Heartbeat:Connect(function(): ()
			local ActiveCount: number = 0
			local Hue: number = (os.clock() * TOOL_MUTATION_RAINBOW_SPEED) % 1
			local Color: Color3 = Color3.fromHSV(Hue, 1, 1)

			for TrackedHighlight: Highlight, _ in _ToolRainbowHighlights do
				if not TrackedHighlight.Parent then
					_ToolRainbowHighlights[TrackedHighlight] = nil
				else
					TrackedHighlight.FillColor = Color
					TrackedHighlight.OutlineColor = Color
					ActiveCount += 1
				end
			end

			if ActiveCount == 0 and _ToolRainbowConnection then
				_ToolRainbowConnection:Disconnect()
				_ToolRainbowConnection = nil
			end
		end)
		return
	end

	_ToolRainbowHighlights[HighlightInstance] = nil
	if next(_ToolRainbowHighlights) == nil and _ToolRainbowConnection then
		_ToolRainbowConnection:Disconnect()
		_ToolRainbowConnection = nil
	end
end

local function _FindToolMutationHighlight(CandyModel: Model): Highlight?
	local Found: Highlight? = nil
	for _, Child: Instance in CandyModel:GetChildren() do
		if Child:IsA("Highlight") and Child.Name == TOOL_MUTATION_HIGHLIGHT_NAME then
			if Found then
				_SetToolRainbowHighlightTracking(Child, false)
				Child:Destroy()
			else
				Found = Child
			end
		end
	end
	return Found
end

local function _GetOrCreateToolMutationHighlight(CandyModel: Model): Highlight
	local Existing: Highlight? = _FindToolMutationHighlight(CandyModel)
	if Existing then
		return Existing
	end

	local HighlightInstance: Highlight = Instance.new("Highlight")
	HighlightInstance.Name = TOOL_MUTATION_HIGHLIGHT_NAME
	HighlightInstance.Parent = CandyModel
	return HighlightInstance
end

local function _GetBestMutationVisual(Mutations: { string }): (Color3, boolean)
	local BestOrder: number = math.huge
	local BestMutation: any = nil
	for _, MutationId: string in Mutations do
		local Order: number = _MutationOrder[MutationId] or math.huge
		if Order < BestOrder then
			BestOrder = Order
			BestMutation = _MutationById[MutationId]
		end
	end

	if not BestMutation then
		return Color3.fromRGB(255, 255, 255), false
	end

	local Color: Color3 = if typeof(BestMutation.HighlightColor) == "Color3"
		then BestMutation.HighlightColor
		else Color3.fromRGB(255, 255, 255)
	local IsRainbow: boolean = BestMutation.IsRainbow == true
	return Color, IsRainbow
end

local function _DisableToolMutationHighlight(HighlightInstance: Highlight?): ()
	if not HighlightInstance then
		return
	end
	HighlightInstance.Enabled = false
	_SetToolRainbowHighlightTracking(HighlightInstance, false)
end

local function _ApplyMutationsToToolHighlight(CandyModel: Model, Mutations: { string }): ()
	local ExistingHighlight: Highlight? = _FindToolMutationHighlight(CandyModel)
	if #Mutations == 0 then
		_DisableToolMutationHighlight(ExistingHighlight)
		return
	end

	local Color: Color3, IsRainbow: boolean = _GetBestMutationVisual(Mutations)
	local HighlightInstance: Highlight = ExistingHighlight or _GetOrCreateToolMutationHighlight(CandyModel)
	HighlightInstance.Adornee = CandyModel
	HighlightInstance.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	HighlightInstance.FillTransparency = TOOL_MUTATION_HIGHLIGHT_FILL_TRANSPARENCY
	HighlightInstance.OutlineTransparency = TOOL_MUTATION_HIGHLIGHT_OUTLINE_TRANSPARENCY
	HighlightInstance.Enabled = true

	if IsRainbow then
		_SetToolRainbowHighlightTracking(HighlightInstance, true)
		return
	end

	_SetToolRainbowHighlightTracking(HighlightInstance, false)
	HighlightInstance.FillColor = Color
	HighlightInstance.OutlineColor = Color
end

local function _SetupCandyToolVisual(
	ToolInstance: Tool,
	CandyName: string,
	Level: number,
	Exp: number,
	Mutations: { string },
	Size: number
): ()
	local CandyModel: Model? = _EnsureCandyModelInTool(ToolInstance, CandyName)
	if not CandyModel then
		return
	end

	if Size > 0 and typeof(CandyModel.ScaleTo) == "function" then
		pcall(function(): ()
			CandyModel:ScaleTo(Size)
		end)
	end

	_ApplyMutationsToToolHighlight(CandyModel, Mutations)

	local PrimaryPart: BasePart? = _EnsureModelPrimaryPart(CandyModel)
	if not PrimaryPart then
		return
	end

	for _, Child: Instance in PrimaryPart:GetChildren() do
		if Child:IsA("BillboardGui") and _NormalizeNameForLookup(Child.Name) == _NormalizeNameForLookup(LEVEL_BAR_TEMPLATE_NAME) then
			Child:Destroy()
		end
	end

	local ModelsFolder: Instance? = _GetAssetsModelsFolder()
	if not ModelsFolder then
		return
	end
	local Template: Instance? = ModelsFolder:FindFirstChild(LEVEL_BAR_TEMPLATE_NAME)
	if not Template then
		return
	end

	local Billboard: BillboardGui? = _CloneLevelBarBillboard(Template)
	if not Billboard then
		return
	end

	Billboard.Name = LEVEL_BAR_TEMPLATE_NAME
	Billboard.Parent = PrimaryPart

	local RoundedLevel: number = math.max(0, math.floor(Level + 0.5))
	_SetTextLikeText(Billboard:FindFirstChild("Level", true), string.format("Level %d", RoundedLevel))

	local MaxLevel: number? = _GetCandyMaxLevel(CandyName)
	local IsMaxLevel: boolean = MaxLevel ~= nil and Level >= (MaxLevel :: number)
	local MaxExp: number = _GetEvolutionLimitForLevelBar(CandyName, Level)
	local Progress: number = if IsMaxLevel then 1 else (if MaxExp > 0 then math.clamp(Exp / MaxExp, 0, 1) else 0)

	local XpLabel: Instance? = _FindLevelBarXpLabel(Billboard)
	if XpLabel then
		if IsMaxLevel then
			_SetTextLikeText(XpLabel, "MAX")
			pcall(function(): ()
				local AnyXpLabel: any = XpLabel
				AnyXpLabel.RichText = false
			end)
		else
			local CurrentValue: number = math.max(0, math.floor(Exp + 0.5))
			_SetTextLikeText(XpLabel, string.format("%d XP / %d XP", CurrentValue, MaxExp))
		end
	end

	local Fill: GuiObject? = _FindLevelBarFill(Billboard)
	if Fill then
		Fill.Size = UDim2.new(Progress, 0, 1, 0)
	end

	_ApplyMutationsToLevelBar(Billboard, Mutations)
end

_GiveCandyTool = function(
	Player: Player,
	CandyName: string,
	Level: number,
	Exp: number,
	Mutations: { string },
	Size: number,
	XpValue: number,
	ExtraAttributes: { [string]: any }?
): ()
	if CandyName == DEFAULT_STRING then
		return
	end
	CandyName = _NormalizeCandyModelName(CandyName)

	local ToolInstance: Tool = _CreateCandyToolFromTemplate(CandyName)
	ToolInstance:SetAttribute(TOOL_ATTRIBUTE_CANDY_MODEL, CandyName)
	ToolInstance:SetAttribute("Level", Level)
	ToolInstance:SetAttribute("Xp", Exp)
	ToolInstance:SetAttribute("Mutations", _EncodeMutations(Mutations))
	ToolInstance:SetAttribute("Scale", Size)
	ToolInstance:SetAttribute("XpValue", XpValue)
	if ExtraAttributes then
		for Key: string, Value: any in ExtraAttributes do
			ToolInstance:SetAttribute(Key, Value)
		end
	end

	local Config: Configuration = Instance.new("Configuration")
	Config.Name = SETTINGS_FOLDER_NAME
	Config:SetAttribute("Name", CandyName)
	Config:SetAttribute("Type", "Consumable")
	Config:SetAttribute("Level", Level)
	Config:SetAttribute("Exp", Exp)
	Config:SetAttribute("Mutations", _EncodeMutations(Mutations))
	Config:SetAttribute("Size", Size)
	Config:SetAttribute("XpValue", XpValue)
	Config.Parent = ToolInstance

	_SetupCandyToolVisual(ToolInstance, CandyName, Level, Exp, Mutations, Size)

	local Backpack: Instance? = Player:FindFirstChildOfClass("Backpack")
	ToolInstance.Parent = Backpack or Player:FindFirstChild("Backpack") or Player.Character
end

end

local function _CreateSlotState(Plot: Model, GroupId: string, SlotId: string, SlotConfig: any): MachineSlotState
	local ProcessKeys: ProcessAttributeKeys = _BuildProcessAttributeKeys(GroupId, SlotId)
	_SetAttribute(Plot, ProcessKeys.ProcessState, "Idle")
	_SetAttribute(Plot, ProcessKeys.ProcessStart, DEFAULT_NUMBER)
	_SetAttribute(Plot, ProcessKeys.ProcessEnd, DEFAULT_NUMBER)

	local SlotState: MachineSlotState = {
		GroupId = GroupId,
		SlotId = SlotId,
		Config = SlotConfig,
		Candy = nil,
		Taps = nil,
		Upgrades = {
			Level = 1,
			Specials = {},
		},
		ProcessState = "Idle",
		ProcessStart = 0,
		ProcessEnd = 0,
		ProcessToken = 0,
	}

	if SlotConfig.TapCount <= 1 then
		SlotState.Candy = _BuildCandyState(Plot, GroupId, SlotId, nil)
		return SlotState
	end

	local Taps: { [number]: CandyState } = table.create(SlotConfig.TapCount)
	for Index: number = 1, SlotConfig.TapCount do
		Taps[Index] = _BuildCandyState(Plot, GroupId, SlotId, Index)
	end
	SlotState.Taps = Taps

	return SlotState
end

local function _CreateGroupState(Plot: Model, GroupId: string, GroupConfig: any): MachineGroupState
	local Slots: { [string]: MachineSlotState } = {}
	for SlotId: string, SlotConfig: any in GroupConfig.Slots do
		Slots[SlotId] = _CreateSlotState(Plot, GroupId, SlotId, SlotConfig)
	end

	return {
		GroupId = GroupId,
		Config = GroupConfig,
		Slots = Slots,
	}
end

local function _CreatePlotState(Plot: Model): PlotState
	local Groups: { [string]: MachineGroupState } = {}
	for GroupId: string, GroupConfig: any in MACHINES_CONFIG do
		Groups[GroupId] = _CreateGroupState(Plot, GroupId, GroupConfig)
	end

	local PlotState: PlotState = {
		Plot = Plot,
		Groups = Groups,
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

local function _GetSlotState(PlotState: PlotState, GroupId: string, SlotId: string): MachineSlotState?
	local GroupState: MachineGroupState? = PlotState.Groups[GroupId]
	if not GroupState then
		return nil
	end
	return GroupState.Slots[SlotId]
end

local function _GetCandyStateFromAction(SlotState: MachineSlotState, TapId: number?): CandyState?
	if SlotState.Taps then
		if not TapId then
			return nil
		end
		return SlotState.Taps[TapId]
	end
	return SlotState.Candy
end

local function _GetHeldCandyTool(Player: Player): Tool?
	local Character: Model? = Player.Character
	if Character then
		return Character:FindFirstChildOfClass("Tool")
	end
	return nil
end

local function _ReadCandyFromTool(ToolInstance: Tool): (string?, number?, number?, { string }?, number?)
	local CandyModel: string? = nil
	local AttributeModel: any = ToolInstance:GetAttribute(TOOL_ATTRIBUTE_CANDY_MODEL)
	if typeof(AttributeModel) == "string" and AttributeModel ~= DEFAULT_STRING then
		CandyModel = AttributeModel
	else
		local ToolMap: { [string]: string } = CANDY_CONFIG.ToolMap
		CandyModel = ToolMap[ToolInstance.Name]
	end
	if CandyModel then
		CandyModel = _NormalizeCandyModelName(CandyModel)
	end
	if not CandyModel then
		return nil, nil, nil, nil, nil
	end

	local Level: number? = ToolInstance:GetAttribute("Level")
	local Exp: number? = ToolInstance:GetAttribute("Xp")
	local MutationsValue: any = ToolInstance:GetAttribute("Mutations")
	local Mutations: { string }? = nil
	if typeof(MutationsValue) == "string" and MutationsValue ~= DEFAULT_STRING then
		Mutations = _DecodeMutations(MutationsValue)
	end
	local Scale: number? = ToolInstance:GetAttribute("Scale")
	return CandyModel, Level, Exp, Mutations, Scale
end

local function _GetFirstEmptyTap(SlotState: MachineSlotState): CandyState?
	local TapStates: { [number]: CandyState }? = SlotState.Taps
	if not TapStates then
		return nil
	end

	for Index: number = 1, #TapStates do
		local TapState: CandyState? = TapStates[Index]
		if TapState and not _HasCandy(TapState) then
			return TapState
		end
	end

	return nil
end

local function _SetUpgradeAttributes(Plot: Model, GroupId: string, SlotState: MachineSlotState): ()
	local LevelKey: string = _GetUpgradeKey(GroupId, SlotState.SlotId, "Level")
	_SetAttribute(Plot, LevelKey, SlotState.Upgrades.Level)

	local Specials: any = SlotState.Config.Upgrades.Specials
	if Specials then
		for UpgradeId: string, _ in Specials do
			local Key: string = _GetUpgradeKey(GroupId, SlotState.SlotId, UpgradeId)
			local Level: number = SlotState.Upgrades.Specials[UpgradeId] or 0
			_SetAttribute(Plot, Key, Level)
		end
	end
end

local function _ApplySavedUpgrades(Plot: Model, GroupId: string, SlotState: MachineSlotState, Data: any): ()
	local Level: number = 1
	if typeof(Data) == "table" and typeof(Data.Level) == "number" then
		Level = math.max(1, Data.Level)
	end
	if Level > UPGRADE_MAX_LEVEL then
		Level = UPGRADE_MAX_LEVEL
	end
	SlotState.Upgrades.Level = Level

	local Specials: { [string]: number } = {}
	if typeof(Data) == "table" and typeof(Data.Specials) == "table" then
		for UpgradeId: string, Value: any in Data.Specials do
			if typeof(Value) == "number" then
				Specials[UpgradeId] = math.max(0, Value)
			end
		end
	end

	SlotState.Upgrades.Specials = Specials
	_SetUpgradeAttributes(Plot, GroupId, SlotState)
end

local function _ApplySavedCandyData(CandyState: CandyState, Data: any): ()
	if typeof(Data) ~= "table" then
		return
	end
	local ModelName: any = Data.Model
	if typeof(ModelName) ~= "string" or ModelName == DEFAULT_STRING then
		return
	end
	ModelName = _NormalizeCandyModelName(ModelName)
	local Level: number? = if typeof(Data.Level) == "number" then Data.Level else nil
	local Exp: number? = if typeof(Data.Exp) == "number" then Data.Exp else nil
	local Scale: number? = if typeof(Data.Scale) == "number" then Data.Scale else nil
	local Mutations: { string } = _NormalizeMutations(Data.Mutations)
	_SetCandyWithState(CandyState, ModelName, Level, Exp, Mutations, Scale)
end

local function _EnsureDefaultCandy(SlotState: MachineSlotState): ()
	if _IsTimeProcessSlot(SlotState) then
		return
	end
	if SlotState.Taps then
		for Index: number = 1, #SlotState.Taps do
			local TapState: CandyState? = SlotState.Taps[Index]
			if TapState and not _HasCandy(TapState) then
				if SlotState.Config.Type == "Auto" then
					_SetCandyWithState(TapState, CANDY_CONFIG.DefaultModel, 0, 0, {}, nil)
				else
					_SetCandy(TapState, CANDY_CONFIG.DefaultModel)
				end
			end
		end
		return
	end

	if SlotState.Candy and not _HasCandy(SlotState.Candy) then
		_SetCandy(SlotState.Candy, CANDY_CONFIG.DefaultModel)
	end
end

local function _ApplySavedProcess(Plot: Model, GroupId: string, SlotState: MachineSlotState, SlotData: any): ()
	local ProcessKeys: ProcessAttributeKeys = _BuildProcessAttributeKeys(GroupId, SlotState.SlotId)
	local ProcessData: any = if typeof(SlotData) == "table" then SlotData.Process else nil
	local State: string = "Idle"
	local StartValue: number = 0
	local EndValue: number = 0

	if typeof(ProcessData) == "table" then
		if typeof(ProcessData.State) == "string" then
			State = ProcessData.State
		end
		if typeof(ProcessData.Start) == "number" then
			StartValue = ProcessData.Start
		end
		if typeof(ProcessData.End) == "number" then
			EndValue = ProcessData.End
		end
	end

	SlotState.ProcessState = State
	SlotState.ProcessStart = StartValue
	SlotState.ProcessEnd = EndValue

	_SetAttribute(Plot, ProcessKeys.ProcessState, State)
	_SetAttribute(Plot, ProcessKeys.ProcessStart, StartValue)
	_SetAttribute(Plot, ProcessKeys.ProcessEnd, EndValue)
end

local function _ApplySavedData(PlotState: PlotState, SavedMachines: any): ()
	for GroupId: string, GroupState: MachineGroupState in PlotState.Groups do
		local GroupData: any = if typeof(SavedMachines) == "table" then SavedMachines[GroupId] else nil
		local SlotsData: any = if typeof(GroupData) == "table" then GroupData.Slots else nil
		for SlotId: string, SlotState: MachineSlotState in GroupState.Slots do
			local SlotData: any = if typeof(SlotsData) == "table" then SlotsData[SlotId] else nil
			_ApplySavedUpgrades(PlotState.Plot, GroupId, SlotState, SlotData and SlotData.Upgrades)
			_ApplySavedProcess(PlotState.Plot, GroupId, SlotState, SlotData)

			if SlotState.Taps then
				local TapData: any = if typeof(SlotData) == "table" then SlotData.Taps else nil
				for TapId: number, TapState: CandyState in SlotState.Taps do
					local Data: any = if typeof(TapData) == "table" then TapData[TapId] else nil
					_ApplySavedCandyData(TapState, Data)
				end
			else
				local CandyData: any = if typeof(SlotData) == "table" then SlotData.Candy else nil
				if SlotState.Candy then
					_ApplySavedCandyData(SlotState.Candy, CandyData)
				end
			end

			_EnsureDefaultCandy(SlotState)
		end
	end
end

local function _CaptureCandyData(CandyState: CandyState): any
	if not _HasCandy(CandyState) then
		return nil
	end
	local ModelName: string = _GetStringAttribute(CandyState.Plot, CandyState.Keys.CandyModel, DEFAULT_STRING)
	if ModelName == DEFAULT_STRING then
		return nil
	end
	ModelName = _NormalizeCandyModelName(ModelName)
	local Level: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, DEFAULT_NUMBER)
	local Exp: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyProgress, DEFAULT_NUMBER)
	local Scale: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyScale, DEFAULT_NUMBER)
	local ResolvedScale: number = _ResolveCandyScale(ModelName, Level, Exp, Scale)
	if math.abs(ResolvedScale - Scale) > SCALE_EPSILON then
		_SetAttribute(CandyState.Plot, CandyState.Keys.CandyScale, ResolvedScale)
		Scale = ResolvedScale
	end
	local MutationsValue: string = _GetStringAttribute(CandyState.Plot, CandyState.Keys.Mutations, DEFAULT_STRING)
	return {
		Model = ModelName,
		Level = Level,
		Exp = Exp,
		Scale = Scale,
		Mutations = _DecodeMutations(MutationsValue),
	}
end

local function _CaptureMachinesData(PlotState: PlotState): { [string]: any }
	local Result: { [string]: any } = {}
	for GroupId: string, GroupState: MachineGroupState in PlotState.Groups do
		local GroupData: { [string]: any } = { Slots = {} }
		for SlotId: string, SlotState: MachineSlotState in GroupState.Slots do
			local SlotData: { [string]: any } = {}
			SlotData.Upgrades = {
				Level = SlotState.Upgrades.Level,
				Specials = SlotState.Upgrades.Specials,
			}
			SlotData.Process = {
				State = SlotState.ProcessState,
				Start = SlotState.ProcessStart,
				End = SlotState.ProcessEnd,
			}

			if SlotState.Taps then
				local TapData: { [number]: any } = {}
				for TapId: number, TapState: CandyState in SlotState.Taps do
					TapData[TapId] = _CaptureCandyData(TapState)
				end
				SlotData.Taps = TapData
			else
				if SlotState.Candy then
					SlotData.Candy = _CaptureCandyData(SlotState.Candy)
				end
			end

			GroupData.Slots[SlotId] = SlotData
		end
		Result[GroupId] = GroupData
	end
	return Result
end

local function _ApplyOfflineProgress(PlotState: PlotState, OfflineSeconds: number, PlayerInstance: Player?): ()
	if OfflineSeconds <= 0 then
		return
	end

	local NowTime: number = os.time()

	for _, GroupState: MachineGroupState in PlotState.Groups do
		for _, SlotState: MachineSlotState in GroupState.Slots do
			if _IsTimeProcessSlot(SlotState) then
				if _IsSlotOwned(PlayerInstance, GroupState.GroupId, SlotState.SlotId)
					and SlotState.ProcessState == PROCESS_STATE_PROCESSING
					and SlotState.ProcessEnd > 0
					and NowTime >= SlotState.ProcessEnd
				then
					local CandyState: CandyState? = _GetCandyStateFromAction(SlotState, nil)
					if CandyState then
						_CompleteTimeProcess(SlotState, CandyState)
					end
				end
			end

			if SlotState.Config.Type == "Auto" then
				if not _IsSlotOwned(PlayerInstance, GroupState.GroupId, SlotState.SlotId) then
					continue
				end
				local Interval: number = TIMING.AutoDropInterval / _GetSpeedMultiplier(SlotState)
				if Interval <= 0 then
					Interval = TIMING.AutoDropInterval
				end
				local Drops: number = math.floor(OfflineSeconds / Interval)
				if Drops <= 0 then
					continue
				end
				local DropXp: number = _GetDropXp(SlotState)
				if DropXp <= 0 then
					continue
				end

				if SlotState.Taps then
					for _, TapState: CandyState in SlotState.Taps do
						if _HasCandy(TapState) then
							_ApplyProgress(TapState, SlotState, DropXp * Drops, false)
							_ApplyOfflineMutations(TapState, Drops, SlotState)
						end
					end
				elseif SlotState.Candy then
					if _HasCandy(SlotState.Candy) then
						_ApplyProgress(SlotState.Candy, SlotState, DropXp * Drops, false)
						_ApplyOfflineMutations(SlotState.Candy, Drops, SlotState)
					end
				end
			end
		end
	end
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
			local NowTime: number = os.time()
			local Owner: Player? = _GetPlotOwner(Plot)
			if Owner then
				for _, GroupState: MachineGroupState in PlotState.Groups do
					for _, SlotState: MachineSlotState in GroupState.Slots do
						if _IsTimeProcessSlot(SlotState) then
							if _IsSlotOwned(Owner, GroupState.GroupId, SlotState.SlotId)
								and SlotState.ProcessState == PROCESS_STATE_PROCESSING
								and SlotState.ProcessEnd > 0
								and NowTime >= SlotState.ProcessEnd
							then
								local CandyState: CandyState? = _GetCandyStateFromAction(SlotState, nil)
								if CandyState then
									_CompleteTimeProcess(SlotState, CandyState)
								end
							end
						end
						if SlotState.Config.Type == "Auto" then
							if not _IsSlotOwned(Owner, GroupState.GroupId, SlotState.SlotId) then
								continue
							end
							local Interval: number = TIMING.AutoDropInterval / _GetSpeedMultiplier(SlotState)
							if Interval <= 0 then
								Interval = TIMING.AutoDropInterval
							end
							local DropTime: number = TIMING.AutoDropTime
							if SlotState.Taps then
								for Index: number = 1, #SlotState.Taps do
									local TapState: CandyState? = SlotState.Taps[Index]
									if not TapState then
										continue
									end
									if not _HasCandy(TapState) then
										_SetCandyWithState(TapState, CANDY_CONFIG.DefaultModel, 0, 0, {}, nil)
										continue
									end
									local DebounceKey: string = TapState.Keys.DropSequence
									local NextTime: number = _AutoNextDropTime[DebounceKey] or 0
									if Now >= NextTime then
										_AutoNextDropTime[DebounceKey] = Now + Interval
										_TriggerDrop(TapState, SlotState, true, DropTime)
									end
								end
							elseif SlotState.Candy then
								if not _HasCandy(SlotState.Candy) then
									_SetCandyWithState(SlotState.Candy, CANDY_CONFIG.DefaultModel, 0, 0, {}, nil)
								else
									local DebounceKey: string = SlotState.Candy.Keys.DropSequence
									local NextTime: number = _AutoNextDropTime[DebounceKey] or 0
									if Now >= NextTime then
										_AutoNextDropTime[DebounceKey] = Now + Interval
										_TriggerDrop(SlotState.Candy, SlotState, true, DropTime)
									end
								end
							end
						end
					end
				end
			end

			task.wait(TIMING.AutoLoopStep)
		end

		_AutoLoopActive[PlotState.Plot] = nil
	end)
end
local function _ReadActionData(Data: any): (string?, string?, number?, string?)
	if typeof(Data) ~= "table" then
		return nil, nil, nil, nil
	end

	local GroupId: string? = nil
	local SlotId: string? = nil
	local TapId: number? = nil
	local UpgradeId: string? = nil

	if typeof(Data.GroupId) == "string" then
		GroupId = Data.GroupId
	elseif typeof(Data[1]) == "string" then
		GroupId = Data[1]
	end

	if typeof(Data.SlotId) == "string" then
		SlotId = Data.SlotId
	elseif typeof(Data[2]) == "string" then
		SlotId = Data[2]
	end

	if typeof(Data.TapId) == "number" then
		TapId = Data.TapId
	elseif typeof(Data[3]) == "number" then
		TapId = Data[3]
	end

	if typeof(Data.UpgradeId) == "string" then
		UpgradeId = Data.UpgradeId
	elseif typeof(Data[4]) == "string" then
		UpgradeId = Data[4]
	end

	return GroupId, SlotId, TapId, UpgradeId
end

local function _HandlePlaceCandy(Player: Player, GroupId: string, SlotId: string, TapId: number?): ()
	local PlotState: PlotState? = _GetPlotState(Player)
	if not PlotState then
		return
	end

	local SlotState: MachineSlotState? = _GetSlotState(PlotState, GroupId, SlotId)
	if not SlotState then
		return
	end
	if _IsTimeProcessSlot(SlotState) then
		return
	end

	if not SlotState.Config.AllowManualPlacement then
		return
	end

	local CandyState: CandyState? = nil
	if SlotState.Taps then
		if TapId then
			CandyState = SlotState.Taps[TapId]
		else
			CandyState = _GetFirstEmptyTap(SlotState)
		end
	else
		CandyState = SlotState.Candy
	end

	if not CandyState or _HasCandy(CandyState) then
		return
	end

	local ToolInstance: Tool? = nil
	local Character: Model? = Player.Character
	if Character then
		ToolInstance = Character:FindFirstChildOfClass("Tool")
	end
	if not ToolInstance then
		return
	end

	local CandyModel: string? = nil
	local AttributeModel: any = ToolInstance:GetAttribute(TOOL_ATTRIBUTE_CANDY_MODEL)
	if typeof(AttributeModel) == "string" and AttributeModel ~= DEFAULT_STRING then
		CandyModel = AttributeModel
	else
		local ToolMap: { [string]: string } = CANDY_CONFIG.ToolMap
		CandyModel = ToolMap[ToolInstance.Name]
	end
	if CandyModel then
		CandyModel = _NormalizeCandyModelName(CandyModel)
	end
	if not CandyModel then
		return
	end

	_SetCandy(CandyState, CandyModel)

	if ToolInstance.Parent then
		ToolInstance:Destroy()
	end
end

local function _HandleDrop(Player: Player, GroupId: string, SlotId: string): ()
	local PlotState: PlotState? = _GetPlotState(Player)
	if not PlotState then
		return
	end

	local SlotState: MachineSlotState? = _GetSlotState(PlotState, GroupId, SlotId)
	if not SlotState or SlotState.Config.Type ~= "Manual" then
		return
	end
	if _IsTimeProcessSlot(SlotState) then
		return
	end

	local CandyState: CandyState? = SlotState.Candy
	if not CandyState then
		return
	end

	if not _HasCandy(CandyState) then
		_SetCandy(CandyState, CANDY_CONFIG.DefaultModel)
		return
	end

	local DebounceKey: string = CandyState.Keys.DropSequence
	local LastTime: number = _ManualDropDebounce[DebounceKey] or 0
	local Now: number = os.clock()
	if Now - LastTime < TIMING.ManualDebounce then
		return
	end
	_ManualDropDebounce[DebounceKey] = Now

	_TriggerDrop(CandyState, SlotState, false, TIMING.ManualDropTime)
end

local function _RefreshTimeProcessAfterUpgrade(PlotState: PlotState, SlotState: MachineSlotState): ()
	if not _IsTimeProcessSlot(SlotState) then
		return
	end
	if SlotState.ProcessState ~= PROCESS_STATE_PROCESSING then
		return
	end
	if SlotState.ProcessStart <= 0 then
		return
	end

	local NewDuration: number = _GetProcessDurationSeconds(SlotState, SlotState.Upgrades.Level)
	local NewEnd: number = SlotState.ProcessStart + NewDuration
	_SetProcessState(PlotState.Plot, SlotState.GroupId, SlotState.SlotId, SlotState, PROCESS_STATE_PROCESSING, SlotState.ProcessStart, NewEnd)

	local NowTime: number = os.time()
	if NowTime >= NewEnd then
		local CandyState: CandyState? = _GetCandyStateFromAction(SlotState, nil)
		if CandyState then
			_CompleteTimeProcess(SlotState, CandyState)
		end
	end
end

local function _HandleDoubleDropperStart(Player: Player, GroupId: string, SlotId: string): ()
	local PlotState: PlotState? = _GetPlotState(Player)
	if not PlotState then
		return
	end

	local SlotState: MachineSlotState? = _GetSlotState(PlotState, GroupId, SlotId)
	if not SlotState then
		return
	end
	if not _IsTimeProcessSlot(SlotState) then
		return
	end
	if SlotState.ProcessState == PROCESS_STATE_PROCESSING then
		return
	end
	if SlotState.ProcessState == PROCESS_STATE_READY then
		return
	end

	local CandyState: CandyState? = _GetCandyStateFromAction(SlotState, nil)
	if not CandyState then
		return
	end

	if not _HasCandy(CandyState) then
		local ToolInstance: Tool? = _GetHeldCandyTool(Player)
		if not ToolInstance then
			return
		end
		if ToolInstance:GetAttribute(TOOL_ATTRIBUTE_DOUBLE_DROPPER_USED) == true then
			return
		end
		local CandyModel, Level, Exp, Mutations, Scale = _ReadCandyFromTool(ToolInstance)
		if not CandyModel then
			return
		end
		_SetCandyWithState(CandyState, CandyModel, Level, Exp, Mutations, Scale)
		if ToolInstance.Parent then
			ToolInstance:Destroy()
		end
	end

	local Duration: number = _GetProcessDurationSeconds(SlotState, SlotState.Upgrades.Level)
	local StartTime: number = os.time()
	local EndTime: number = StartTime + Duration

	if Duration <= 0 then
		SlotState.ProcessStart = StartTime
		SlotState.ProcessEnd = EndTime
		_CompleteTimeProcess(SlotState, CandyState)
		return
	end

	SlotState.ProcessToken += 1
	_SetProcessState(PlotState.Plot, GroupId, SlotId, SlotState, PROCESS_STATE_PROCESSING, StartTime, EndTime)
end

local function _HandleRemoveCandy(Player: Player, GroupId: string, SlotId: string, TapId: number?): ()
	local PlotState: PlotState? = _GetPlotState(Player)
	if not PlotState then
		return
	end

	local SlotState: MachineSlotState? = _GetSlotState(PlotState, GroupId, SlotId)
	if not SlotState then
		return
	end

	local CandyState: CandyState? = _GetCandyStateFromAction(SlotState, TapId)
	if not CandyState or not _HasCandy(CandyState) then
		return
	end
	if _IsTimeProcessSlot(SlotState) then
		if SlotState.ProcessState ~= PROCESS_STATE_READY then
			return
		end
	end

	local DebounceKey: string = CandyState.Keys.RemoveSequence
	local Now: number = os.clock()
	local LastTime: number = _RemoveDebounce[DebounceKey] or 0
	if Now - LastTime < REMOVE_DEBOUNCE_TIME then
		return
	end
	_RemoveDebounce[DebounceKey] = Now

	local CandyName: string = _GetStringAttribute(CandyState.Plot, CandyState.Keys.CandyModel, DEFAULT_STRING)
	local CandyLevel: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyLevel, DEFAULT_NUMBER)
	local CandyExp: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyProgress, DEFAULT_NUMBER)
	local MutationValue: string = _GetStringAttribute(CandyState.Plot, CandyState.Keys.Mutations, DEFAULT_STRING)
	local Mutations: { string } = _DecodeMutations(MutationValue)
	local CandyScale: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyScale, DEFAULT_NUMBER)
	local CandyXp: number = _GetNumberAttribute(CandyState.Plot, CandyState.Keys.CandyXp, DEFAULT_NUMBER)

	_RemoveCandy(CandyState)
	local ExtraAttributes: { [string]: any }? = nil
	if _IsTimeProcessSlot(SlotState) then
		ExtraAttributes = { [TOOL_ATTRIBUTE_DOUBLE_DROPPER_USED] = true }
	end
	_GiveCandyTool(Player, CandyName, CandyLevel, CandyExp, Mutations, CandyScale, CandyXp, ExtraAttributes)

	if _IsTimeProcessSlot(SlotState) then
		_SetProcessState(PlotState.Plot, GroupId, SlotId, SlotState, PROCESS_STATE_IDLE, 0, 0)
	end

	if SlotState.Config.Type == "Auto" then
		task.delay(0.05, function(): ()
			if not _HasCandy(CandyState) then
				_SetCandyWithState(CandyState, CANDY_CONFIG.DefaultModel, 0, 0, {}, nil)
			end
		end)
		task.delay(0.6, function(): ()
			if not _HasCandy(CandyState) then
				_SetCandyWithState(CandyState, CANDY_CONFIG.DefaultModel, 0, 0, {}, nil)
			end
		end)
	end
end

local function _TrySpendCoins(Player: Player, Cost: number): boolean
	if Cost <= 0 then
		return true
	end
	local Current: any = PlayerDataManager:Get(Player, { "Currency", "Coins" })
	if typeof(Current) ~= "number" then
		return false
	end
	if Current < Cost then
		return false
	end
	PlayerDataManager:Set(Player, { "Currency", "Coins" }, Current - Cost)
	return true
end

local function _CanProcessUpgrade(Player: Player, GroupId: string, SlotId: string, UpgradeId: string?): boolean
	local Now: number = os.clock()
	local Key: string = string.format("%d:%s:%s:%s", Player.UserId, GroupId, SlotId, UpgradeId or "Level")
	local LastTime: number = _UpgradeDebounce[Key] or 0
	if Now - LastTime < UPGRADE_DEBOUNCE_TIME then
		return false
	end
	_UpgradeDebounce[Key] = Now
	return true
end

local function _HandleUpgradeLevel(Player: Player, GroupId: string, SlotId: string): boolean?
	local PlotState: PlotState? = _GetPlotState(Player)
	if not PlotState then
		return false
	end

	local SlotState: MachineSlotState? = _GetSlotState(PlotState, GroupId, SlotId)
	if not SlotState then
		return false
	end

	if not _CanProcessUpgrade(Player, GroupId, SlotId, "Level") then
		return nil
	end

	if SlotState.Upgrades.Level >= UPGRADE_MAX_LEVEL then
		return false
	end

	local Cost: number? = _GetLevelCostNext(SlotState)
	if not Cost then
		return false
	end

	if not _TrySpendCoins(Player, Cost) then
		return false
	end

	SlotState.Upgrades.Level += 1
	_SetUpgradeAttributes(PlotState.Plot, GroupId, SlotState)
	_RefreshTimeProcessAfterUpgrade(PlotState, SlotState)
	return true
end

local function _HandleUpgradeSpecial(Player: Player, GroupId: string, SlotId: string, UpgradeId: string): boolean?
	local PlotState: PlotState? = _GetPlotState(Player)
	if not PlotState then
		return false
	end

	local SlotState: MachineSlotState? = _GetSlotState(PlotState, GroupId, SlotId)
	if not SlotState then
		return false
	end

	if not _CanProcessUpgrade(Player, GroupId, SlotId, UpgradeId) then
		return nil
	end

	local Specials: any = SlotState.Config.Upgrades.Specials
	if not Specials then
		return false
	end
	local UpgradeConfig: any = Specials[UpgradeId]
	if not UpgradeConfig then
		return false
	end

	local CurrentLevel: number = SlotState.Upgrades.Specials[UpgradeId] or 0
	local NextTier: any = UpgradeConfig.Levels[CurrentLevel + 1]
	if not NextTier or typeof(NextTier.Cost) ~= "number" then
		return false
	end

	if not _TrySpendCoins(Player, NextTier.Cost) then
		return false
	end

	SlotState.Upgrades.Specials[UpgradeId] = CurrentLevel + 1
	_SetUpgradeAttributes(PlotState.Plot, GroupId, SlotState)
	return true
end

local function _HandleUpgradeLevelMax(Player: Player, GroupId: string, SlotId: string): boolean?
	local PlotState: PlotState? = _GetPlotState(Player)
	if not PlotState then
		return false
	end

	local SlotState: MachineSlotState? = _GetSlotState(PlotState, GroupId, SlotId)
	if not SlotState then
		return false
	end

	if not _CanProcessUpgrade(Player, GroupId, SlotId, "LevelMax") then
		return nil
	end

	if SlotState.Upgrades.Level >= UPGRADE_MAX_LEVEL then
		return false
	end

	local Upgraded: boolean = false
	local Iterations: number = 0

	while SlotState.Upgrades.Level < UPGRADE_MAX_LEVEL do
		Iterations += 1
		if Iterations > 200 then
			break
		end

		local Cost: number? = _GetLevelCostNext(SlotState)
		if not Cost then
			break
		end

		if not _TrySpendCoins(Player, Cost) then
			break
		end

		SlotState.Upgrades.Level += 1
		Upgraded = true
	end

	if Upgraded then
		_SetUpgradeAttributes(PlotState.Plot, GroupId, SlotState)
		_RefreshTimeProcessAfterUpgrade(PlotState, SlotState)
	end

	if not Upgraded then
		return false
	end
	return true
end

local function _SavePlayerMachines(Player: Player, PlotState: PlotState): ()
	for _, GroupState: MachineGroupState in PlotState.Groups do
		for _, SlotState: MachineSlotState in GroupState.Slots do
			_EnsureDefaultCandy(SlotState)
		end
	end
	local MachinesData: { [string]: any } = _CaptureMachinesData(PlotState)
	_DebugSave("Save:" .. PlotState.Plot.Name, MachinesData)
	PlayerDataManager:Set(Player, { "Plot", "Machines" }, MachinesData)
end

local function _SetupPlot(Player: Player, Plot: Model): ()
	local PlotState: PlotState = _PlotStates[Plot] or _CreatePlotState(Plot)
	local SavedMachines: any = PlayerDataManager:Get(Player, { "Plot", "Machines" })
	_DebugSave("Load:" .. Plot.Name, SavedMachines)
	_ApplySavedData(PlotState, SavedMachines)
	_DebugSave("AfterLoad:" .. Plot.Name, _CaptureMachinesData(PlotState))

	local LastLogin: any = PlayerDataManager:Get(Player, { "Metadata", "LastLogin" })
	local OfflineSeconds: number = 0
	if typeof(LastLogin) == "number" and LastLogin > 0 then
		OfflineSeconds = math.max(0, os.time() - LastLogin)
	end
	_ApplyOfflineProgress(PlotState, OfflineSeconds, Player)

	PlayerDataManager:Set(Player, { "Metadata", "LastLogin" }, os.time())
	_SavePlayerMachines(Player, PlotState)

	_StartAutoLoop(PlotState)
end

local function _ClearPlotState(PlotState: PlotState): ()
	for _, GroupState: MachineGroupState in PlotState.Groups do
		for _, SlotState: MachineSlotState in GroupState.Slots do
			SlotState.Upgrades.Level = 1
			SlotState.Upgrades.Specials = {}
			_SetUpgradeAttributes(PlotState.Plot, GroupState.GroupId, SlotState)
			_SetProcessState(PlotState.Plot, GroupState.GroupId, SlotState.SlotId, SlotState, PROCESS_STATE_IDLE, 0, 0)

			if SlotState.Taps then
				for _, TapState: CandyState in SlotState.Taps do
					_ResetCandyState(TapState)
				end
			elseif SlotState.Candy then
				_ResetCandyState(SlotState.Candy)
			end
		end
	end
end

local function ClearDroppers(PlotState: PlotState): ()
	_ClearPlotState(PlotState)
end

--\\ PUBLIC FUNCTIONS \\ -- TR
function module:Init(): ()
	PlotmeService.Signals.AssignPlot:Connect(function(MetaPlayer: { Instance: Player, Cache: { Plot: Model } }): ()
		local PlayerInstance: Player = MetaPlayer.Instance
		local Plot: Model = MetaPlayer.Cache.Plot
		_PlayerPlots[PlayerInstance] = Plot
		_SetupPlot(PlayerInstance, Plot)
	end)

	PlotmeService.Signals.RemovePlot:Connect(function(MetaPlayer: { Instance: Player, Cache: { Plot: Model } }): ()
		local PlayerInstance: Player = MetaPlayer.Instance
		local Plot: Model = MetaPlayer.Cache.Plot
		local PlotState: PlotState? = _PlotStates[Plot]
		if PlotState then
			_DebugSave("RemovePlot:" .. Plot.Name, _CaptureMachinesData(PlotState))
			_SavePlayerMachines(PlayerInstance, PlotState)
			_ForceProfileSave(PlayerInstance, "RemovePlot")
		end
		_PlayerPlots[PlayerInstance] = nil
	end)

	PlayerDataManager:OnPlayerLeaving(function(PlayerInstance: Player): ()
		local Plot: Model? = _GetPlayerPlot(PlayerInstance)
		if Plot then
			local PlotState: PlotState? = _PlotStates[Plot]
			if PlotState then
				_DebugSave("PlayerRemoving:" .. Plot.Name, _CaptureMachinesData(PlotState))
				_SavePlayerMachines(PlayerInstance, PlotState)
			end
		end
		PlayerDataManager:Set(PlayerInstance, { "Metadata", "LastLogin" }, os.time())
		_ForceProfileSave(PlayerInstance, "PlayerRemoving")
		_PlayerPlots[PlayerInstance] = nil
	end)

	Packets.Machines.OnServerEvent:Connect(function(PlayerInstance: Player, Action: string, Data: { [string]: any }): ()
		local GroupId: string?, SlotId: string?, TapId: number?, UpgradeId: string? = _ReadActionData(Data)
		if Action == ACTION_PLACE_CANDY then
			if GroupId and SlotId then
				if not PlotmeService:IsMachineOwned(PlayerInstance, GroupId, SlotId) then
					return
				end
				_HandlePlaceCandy(PlayerInstance, GroupId, SlotId, TapId)
			end
			return
		end

		if Action == ACTION_DROP then
			if GroupId and SlotId then
				if not PlotmeService:IsMachineOwned(PlayerInstance, GroupId, SlotId) then
					return
				end
				_HandleDrop(PlayerInstance, GroupId, SlotId)
			end
			return
		end

		if Action == ACTION_REMOVE_CANDY then
			if GroupId and SlotId then
				if not PlotmeService:IsMachineOwned(PlayerInstance, GroupId, SlotId) then
					return
				end
				_HandleRemoveCandy(PlayerInstance, GroupId, SlotId, TapId)
			end
			return
		end

		if Action == ACTION_DOUBLE_DROPPER_START then
			if GroupId and SlotId then
				if not PlotmeService:IsMachineOwned(PlayerInstance, GroupId, SlotId) then
					return
				end
				_HandleDoubleDropperStart(PlayerInstance, GroupId, SlotId)
			end
			return
		end

		if Action == ACTION_BUY_MACHINE then
			if GroupId and SlotId then
				local Plot: Model? = _GetPlayerPlot(PlayerInstance)
				print(string.format("[BuyDebug] machines packet buy: player=%s group=%s slot=%s plot=%s", PlayerInstance.Name, GroupId, SlotId, Plot and Plot.Name or "nil"))
				if Plot then
					PlotmeService:HandleMachinePurchase(PlayerInstance, Plot, GroupId, SlotId)
				end
			end
			return
		end

		if Action == ACTION_UPGRADE_LEVEL then
			if GroupId and SlotId then
				if not PlotmeService:IsMachineOwned(PlayerInstance, GroupId, SlotId) then
					return
				end
				local Success: boolean? = _HandleUpgradeLevel(PlayerInstance, GroupId, SlotId)
				if Success ~= nil then
					Packets.Machines:FireClient(PlayerInstance, "UpgradeResult", {
						GroupId = GroupId,
						SlotId = SlotId,
						UpgradeId = "Level",
						Success = Success,
					})
				end
			end
			return
		end

		if Action == ACTION_UPGRADE_LEVEL_MAX then
			if GroupId and SlotId then
				if not PlotmeService:IsMachineOwned(PlayerInstance, GroupId, SlotId) then
					return
				end
				local Success: boolean? = _HandleUpgradeLevelMax(PlayerInstance, GroupId, SlotId)
				if Success ~= nil then
					Packets.Machines:FireClient(PlayerInstance, "UpgradeResult", {
						GroupId = GroupId,
						SlotId = SlotId,
						UpgradeId = "LevelMax",
						Success = Success,
					})
				end
			end
			return
		end

		if Action == ACTION_UPGRADE_SPECIAL then
			if GroupId and SlotId and UpgradeId then
				if not PlotmeService:IsMachineOwned(PlayerInstance, GroupId, SlotId) then
					return
				end
				local Success: boolean? = _HandleUpgradeSpecial(PlayerInstance, GroupId, SlotId, UpgradeId)
				if Success ~= nil then
					Packets.Machines:FireClient(PlayerInstance, "UpgradeResult", {
						GroupId = GroupId,
						SlotId = SlotId,
						UpgradeId = UpgradeId,
						Success = Success,
					})
				end
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
							_SetupPlot(PlayerInstance, Plot)
						end
					end
				end
			end
		end
	end
end

function module:Start(): () end

return module
