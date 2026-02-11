--!strict

local module: { Init: (self: any) -> (), Start: (self: any) -> () } = {}

--\\ SERVICES \\ -- TR
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")
local ContentProvider: ContentProvider = game:GetService("ContentProvider")

--\\ DEPENDENCIES \\ -- TR
local Constants: any = require(ReplicatedStorage.Modules.Constants.Machines)
local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local TweenModule: any = require(ReplicatedStorage.Modules.Core.Tween)
local Short: any = require(ReplicatedStorage.Modules.Core.Short)
local DroppersModule: any = require(script.Droppers)
local SprinklersModule: any = require(script.Sprinklers)
local UpgradesModule: any = require(script.Upgrades)

--\\ TYPES \\ -- TR
type DropEffect = {
	Part: Part,
	Attachment0: Attachment,
	Attachment1: Attachment,
	Trail: Trail,
	Tween: Tween?,
}

type CandyAttributeKeys = {
	CandyModel: string,
	CandyLevel: string,
	CandyProgress: string,
	CandyScale: string,
	DropSequence: string,
	RemoveSequence: string,
	Mutations: string,
}

type CandyStateRefs = {
	Plot: Model,
	GroupId: string,
	SlotId: string,
	Keys: CandyAttributeKeys,
}

type CandyVisual = {
	State: CandyStateRefs,
	Model: Model?,
	CanPosition: BasePart,
	Parent: Instance,
	Highlight: Highlight?,
	MutationHighlight: Highlight?,
	MutationConnection: RBXScriptConnection?,
	ClickDetector: ClickDetector?,
	LevelBar: BillboardGui?,
	LevelLabel: TextLabel?,
	XpLabel: TextLabel?,
	BarFrame: GuiObject?,
	MutationFrame: Frame?,
	MutationTemplate: TextLabel?,
	MutationClones: { TextLabel }?,
	MutationTextConnection: RBXScriptConnection?,
	LevelBarSize: UDim2?,
	LevelBarOffset: Vector3?,
	BaseScale: number,
	IsRemoving: boolean,
	IsBouncing: boolean,
	IsSpawning: boolean,
	OriginalColors: { [BasePart]: Color3 }?,
	PendingScale: number?,
	BounceConnection: RBXScriptConnection?,
	SpawnConnection: RBXScriptConnection?,
	MutationKey: string?,
	SlotId: string,
	TapId: number?,
	AllowInteraction: boolean,
	AllowAttract: boolean,
	PickupCooldownUntil: number?,
}

type TapVisual = {
	TapModel: Model,
	MainPart: BasePart?,
	CanPosition: BasePart?,
	DropEffect: DropEffect?,
	Candy: CandyVisual?,
	TapId: number,
	GroupId: string,
	SlotId: string,
	Hitbox: BasePart?,
	HoverDetector: ClickDetector?,
	PulseTween: Tween?,
	HasCandy: boolean,
	PreviewModel: Model?,
	PreviewName: string?,
}

type DropperVisual = {
	Model: Model,
	Plot: Model,
	GroupId: string,
	SlotId: string,
	Type: string,
	Config: any,
	MainPart: BasePart?,
	ButtonPart: BasePart?,
	CanPosition: BasePart?,
	HoverDetector: ClickDetector?,
	Highlight: Highlight?,
	HoverTween: RBXScriptConnection?,
	BaseScale: number,
	DropEffect: DropEffect?,
	Taps: { [number]: TapVisual }?,
	HasCandy: boolean,
	IsHovering: boolean,
	HoverColor: Color3,
	SlotPart: BasePart?,
	IsLocalOwner: boolean,
	PreviewModel: Model?,
	PreviewName: string?,
}

type PlotVisual = {
	Plot: Model,
	Groups: { [string]: { Folder: Instance, Slots: { [string]: DropperVisual } } },
}

type CandyFloatData = {
	Visual: CandyVisual,
	BaseCFrame: CFrame,
	Phase: number,
}

--\\ CONSTANTS \\ -- TR
local AllMachinesConfig: any = Constants.Machines
local MachinesConfig: { [string]: any } = {}
DroppersModule.Register(MachinesConfig, AllMachinesConfig)
SprinklersModule.Register(MachinesConfig, AllMachinesConfig)
local VisualConfig: any = Constants.Visual
local TimingConfig: any = Constants.Timing
local AssetsConfig: any = Constants.Assets
local CandyConfig: any = Constants.Candy
local MutationConfig: any = Constants.Mutation

local EMPTY_STRING: string = ""
local ASSETS_ROOT_NAME: string = AssetsConfig.RootFolder
local MACHINES_FOLDER_NAME: string = AssetsConfig.MachinesFolder
local CANDIES_FOLDER_NAME: string = AssetsConfig.CandiesFolder
local SLOT_LONG_ID: string = "1"
local SLOT_WIDE_ID: string = "2"
local CAN_POSITION_NAME: string = "CanPosition"
local MAIN_PART_NAME: string = "Main"
local BUTTON_PART_NAME: string = "Button"
local TAP_NAME: string = "Tap"
local HITBOX_PART_NAME: string = "Hitbox"
local OWNER_ATTRIBUTE_NAME: string = "Owner"
local DROPPER_HIGHLIGHT_COLOR: Color3 = Color3.fromRGB(255, 255, 255)
local DROPPER_PLACE_COLOR: Color3 = Color3.fromRGB(70, 255, 120)
local DROPPER_REMOVE_COLOR: Color3 = Color3.fromRGB(255, 70, 70)
local CANDY_HIGHLIGHT_COLOR: Color3 = Color3.fromRGB(255, 0, 0)
local BUTTON_BASE_SIZE: Vector3 = Vector3.new(2.112, 1.056, 2.112)
local BUTTON_HOVER_SCALE: number = 1.08
local BUTTON_HOVER_TIME: number = 0.08
local BUTTON_CLICK_SCALE: number = 0.9
local BUTTON_READY_COLOR: Color3 = Color3.fromRGB(0, 255, 0)
local BUTTON_COOLDOWN_COLOR: Color3 = Color3.fromRGB(255, 70, 70)
local UPGRADE_SUCCESS_COLOR: Color3 = Color3.fromRGB(70, 255, 120)
local UPGRADE_FAIL_COLOR: Color3 = Color3.fromRGB(255, 70, 70)
local UPGRADE_PULSE_SCALE: number = 1.08
local UPGRADE_PULSE_TIME: number = 0.08
local REMOVE_ATTRACT_TIME: number = 0.25
local CANDY_SPAWN_TIME: number = 0.2
local CANDY_SPAWN_STYLE: string = "Back"
local CANDY_SPAWN_DIRECTION: string = "Out"

local ATTRIBUTE_PREFIX: string = "Machine"
local ATTRIBUTE_TAP_PREFIX: string = "Tap"
local ATTRIBUTE_FORMAT_NORMAL: string = "%s_%s_%s_%s"
local ATTRIBUTE_FORMAT_TAP: string = "%s_%s_%s_%s%d_%s"
local ATTRIBUTE_KEY_CANDY_MODEL: string = "CandyModel"
local ATTRIBUTE_KEY_CANDY_LEVEL: string = "CandyLevel"
local ATTRIBUTE_KEY_CANDY_PROGRESS: string = "CandyProgress"
local ATTRIBUTE_KEY_CANDY_SCALE: string = "CandyScale"
local ATTRIBUTE_KEY_DROP_SEQUENCE: string = "DropSequence"
local ATTRIBUTE_KEY_REMOVE_SEQUENCE: string = "RemoveSequence"
local ATTRIBUTE_KEY_MUTATIONS: string = "Mutations"
local ATTRIBUTE_KEY_UPGRADE_LEVEL: string = "UpgradeLevel"
local ATTRIBUTE_KEY_UPGRADE_PREFIX: string = "Upgrade"

local MEMORIE_FOLDER_NAME: string = "Memorie"
local MEMORIE_PLOTS_FOLDER_NAME: string = "Plots"
local MEMORIE_MACHINES_FOLDER_NAME: string = "Machines"
local MEMORIE_SCALE_FACTOR: number = 1000

local DEFAULT_NUMBER: number = 0

local ACTION_PLACE_CANDY: string = "PlaceCandy"
local ACTION_DROP: string = "Drop"
local ACTION_REMOVE_CANDY: string = "RemoveCandy"
local ACTION_UPGRADE_LEVEL: string = "UpgradeLevel"
local ACTION_UPGRADE_LEVEL_MAX: string = "UpgradeLevelMax"
local ACTION_UPGRADE_SPECIAL: string = "UpgradeSpecial"


local DEBUG_ENABLED: boolean = false
local DEBUG_HOVER: boolean = false
local HOLOGRAM_ENABLED: boolean = false

--\\ STATE \\ -- TR
local _PlotVisuals: { [Model]: PlotVisual } = {}
local _ActiveCandies: { [CandyVisual]: CandyFloatData } = {}
local _RandomGenerator: Random = Random.new()
local _SlotWatchers: { [Instance]: RBXScriptConnection } = {}
local _HologramTweens: { [Model]: RBXScriptConnection } = {}
local _PlotOwnerWatchers: { [Model]: RBXScriptConnection } = {}
local _ButtonTweens: { [BasePart]: Tween } = {}
local _ButtonCooldownUntil: { [BasePart]: number } = {}
local _ActiveDropEffects: { [DropEffect]: boolean } = {}
local _ToolAddedConnection: RBXScriptConnection? = nil
local _ToolRemovedConnection: RBXScriptConnection? = nil
local _MemorieMachinesFolders: { [Model]: Folder } = {}

local _MutationVisuals: { [string]: { Order: number, Color: Color3?, IsRainbow: boolean? } } = {}
for Index: number, MutationData: any in MutationConfig.Types do
	_MutationVisuals[MutationData.Id] = {
		Order = Index,
		Color = MutationData.HighlightColor,
		IsRainbow = MutationData.IsRainbow,
	}
end

--\\ PRIVATE FUNCTIONS \\ -- TR
local function _Debug(Message: string, ...: any): ()
	if not DEBUG_ENABLED then
		return
	end

	local Output: string = string.format(Message, ...)
	print("[DropperDebug]", Output)
end


local function _GetMemorieMachinesFolder(Plot: Model): Folder?
	local Cached: Folder? = _MemorieMachinesFolders[Plot]
	if Cached and Cached.Parent then
		return Cached
	end

	local Root: Instance? = ReplicatedStorage:FindFirstChild(MEMORIE_FOLDER_NAME)
	if not Root or not Root:IsA("Folder") then
		return nil
	end

	local PlotsFolder: Instance? = Root:FindFirstChild(MEMORIE_PLOTS_FOLDER_NAME)
	if not PlotsFolder or not PlotsFolder:IsA("Folder") then
		return nil
	end

	local PlotFolder: Instance? = PlotsFolder:FindFirstChild(Plot.Name)
	if not PlotFolder or not PlotFolder:IsA("Folder") then
		return nil
	end

	local MachinesFolder: Instance? = PlotFolder:FindFirstChild(MEMORIE_MACHINES_FOLDER_NAME)
	if not MachinesFolder or not MachinesFolder:IsA("Folder") then
		return nil
	end

	_MemorieMachinesFolders[Plot] = MachinesFolder
	return MachinesFolder
end

local function _WaitForMemorieMachinesFolder(Plot: Model): Folder?
	local Folder: Folder? = _GetMemorieMachinesFolder(Plot)
	if Folder then
		return Folder
	end

	local Root: Instance = ReplicatedStorage:WaitForChild(MEMORIE_FOLDER_NAME)
	if not Root:IsA("Folder") then
		return nil
	end

	local PlotsFolder: Instance = Root:WaitForChild(MEMORIE_PLOTS_FOLDER_NAME)
	if not PlotsFolder:IsA("Folder") then
		return nil
	end

	local PlotFolder: Instance = PlotsFolder:WaitForChild(Plot.Name)
	if not PlotFolder:IsA("Folder") then
		return nil
	end

	local MachinesFolder: Instance = PlotFolder:WaitForChild(MEMORIE_MACHINES_FOLDER_NAME)
	if MachinesFolder:IsA("Folder") then
		_MemorieMachinesFolders[Plot] = MachinesFolder
		return MachinesFolder
	end

	return nil
end

local function _IsScaledKey(Key: string): boolean
	return string.sub(Key, -#ATTRIBUTE_KEY_CANDY_SCALE) == ATTRIBUTE_KEY_CANDY_SCALE
end

local function _DecodeNumber(Key: string, Value: number): number
	if _IsScaledKey(Key) then
		return Value / MEMORIE_SCALE_FACTOR
	end
	return Value
end

local function _WaitForValueObject(Plot: Model, Key: string): ValueBase?
	local Folder: Folder? = _WaitForMemorieMachinesFolder(Plot)
	if not Folder then
		return nil
	end

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
	local TargetFolder: Folder = Folder
	if GroupId and SlotId and KeyName then
		ValueName = KeyName
		local GroupFolder: Instance = Folder:WaitForChild(GroupId)
		local SlotFolder: Instance = GroupFolder:WaitForChild(SlotId)
		if TapId then
			local TapsFolder: Instance = SlotFolder:WaitForChild("Taps")
			local TapFolder: Instance = TapsFolder:WaitForChild(tostring(TapId))
			if TapFolder:IsA("Folder") then
				TargetFolder = TapFolder
			end
		else
			if string.sub(KeyName, 1, #ATTRIBUTE_KEY_UPGRADE_PREFIX) == ATTRIBUTE_KEY_UPGRADE_PREFIX then
				local UpgradesFolder: Instance = SlotFolder:WaitForChild("Upgrades")
				if UpgradesFolder:IsA("Folder") then
					TargetFolder = UpgradesFolder
				end
			else
				local SlotDataFolder: Instance = SlotFolder:WaitForChild("Slot")
				if SlotDataFolder:IsA("Folder") then
					TargetFolder = SlotDataFolder
				end
			end
		end
	end

	local ValueInstance: Instance? = TargetFolder:FindFirstChild(ValueName)
	if not ValueInstance then
		ValueInstance = TargetFolder:WaitForChild(ValueName)
	end
	if ValueInstance and ValueInstance:IsA("ValueBase") then
		return ValueInstance
	end

	local Legacy: Instance? = Folder:FindFirstChild(Key)
	if Legacy and Legacy:IsA("ValueBase") then
		return Legacy
	end
	return nil
end

local function _GetValueChangedSignal(Plot: Model, Key: string): RBXScriptSignal?
	local ValueObject: ValueBase? = _WaitForValueObject(Plot, Key)
	if not ValueObject then
		return nil
	end
	return ValueObject.Changed
end

local function _ConnectValueChanged(Plot: Model, Key: string, Callback: () -> ()): ()
	local Signal: RBXScriptSignal? = _GetValueChangedSignal(Plot, Key)
	if Signal then
		Signal:Connect(Callback)
	elseif DEBUG_ENABLED then
		_Debug("Memorie value missing for key %s", Key)
	end
end

local function _PreloadAssets(): ()
	task.spawn(function(): ()
		local Success: boolean, ErrorMessage: string? = pcall(function(): ()
			ContentProvider:PreloadAsync({ "rbxassetid://284205403" })
		end)
		if not Success and DEBUG_ENABLED then
			_Debug("Preload failed: %s", tostring(ErrorMessage))
		end
	end)
end

local function _DescribeInstance(Target: Instance?): string
	if not Target then
		return "nil"
	end
	return string.format("%s [%s]", Target:GetFullName(), Target.ClassName)
end

local function _DescribeChildren(Parent: Instance): string
	local Names: { string } = {}
	for _, Child: Instance in Parent:GetChildren() do
		table.insert(Names, string.format("%s[%s]", Child.Name, Child.ClassName))
	end
	table.sort(Names)
	local Output: string = table.concat(Names, ", ")
	if Output == "" then
		return "<empty>"
	end
	return Output
end

local function _GetPlotRotation(Plot: Model, SlotId: string, DefaultRotation: number): number
	local Index: number? = nil
	local Digits: string? = string.match(Plot.Name, "%d+")
	if Digits then
		local Parsed: number? = tonumber(Digits)
		if Parsed then
			Index = Parsed
		end
	end

	if not Index then
		local Parent: Instance? = Plot.Parent
		if Parent then
			local Children: { Instance } = Parent:GetChildren()
			table.sort(Children, function(Left: Instance, Right: Instance): boolean
				return Left.Name < Right.Name
			end)
			for ChildIndex: number, Child: Instance in ipairs(Children) do
				if Child == Plot then
					Index = ChildIndex
					break
				end
			end
		end
	end

	if not Index then
		return DefaultRotation
	end

	local RotationsByPlot: { [number]: { [string]: number } } = {
		[1] = { [SLOT_LONG_ID] = -180, [SLOT_WIDE_ID] = 180 },
		[2] = { [SLOT_LONG_ID] = -180, [SLOT_WIDE_ID] = 0 },
		[3] = { [SLOT_LONG_ID] = 90, [SLOT_WIDE_ID] = -90 },
		[4] = { [SLOT_LONG_ID] = 90, [SLOT_WIDE_ID] = -90 },
		[5] = { [SLOT_LONG_ID] = 0, [SLOT_WIDE_ID] = -180 },
		[6] = { [SLOT_LONG_ID] = 0, [SLOT_WIDE_ID] = -180 },
		[7] = { [SLOT_LONG_ID] = -90, [SLOT_WIDE_ID] = 90 },
		[8] = { [SLOT_LONG_ID] = -90, [SLOT_WIDE_ID] = 90 },
	}

	local Rotations: { [string]: number }? = RotationsByPlot[Index]
	if Rotations then
		local Value: number? = Rotations[SlotId]
		if typeof(Value) == "number" then
			return Value
		end
	end

	return DefaultRotation
end

local function _IsPlotOwnedByLocalPlayer(Plot: Model): boolean
	local Player: Player? = Players.LocalPlayer
	if not Player then
		return false
	end

	local OwnerId: any = Plot:GetAttribute(OWNER_ATTRIBUTE_NAME)
	return typeof(OwnerId) == "number" and OwnerId == Player.UserId
end

local function _GetLocalCoins(): number?
	local Player: Player? = Players.LocalPlayer
	if not Player then
		return nil
	end

	local AttributeValue: any = Player:GetAttribute("Coins")
	if typeof(AttributeValue) == "number" then
		return AttributeValue
	end

	local Leaderstats: Instance? = Player:FindFirstChild("leaderstats")
	if Leaderstats then
		local CoinsValue: Instance? = Leaderstats:FindFirstChild("Coins")
		if CoinsValue and (CoinsValue:IsA("IntValue") or CoinsValue:IsA("NumberValue")) then
			return CoinsValue.Value
		end
	end

	local CurrencyFolder: Instance? = Player:FindFirstChild("Currency")
	if CurrencyFolder then
		local CoinsValue: Instance? = CurrencyFolder:FindFirstChild("Coins")
		if CoinsValue and (CoinsValue:IsA("IntValue") or CoinsValue:IsA("NumberValue")) then
			return CoinsValue.Value
		end
	end

	return nil
end

local function _BindCoinsWatcher(): ()
	local Player: Player? = Players.LocalPlayer
	if not Player then
		return
	end

	local function Refresh(): ()
		UpgradesModule.RefreshBoards()
	end

	Player:GetAttributeChangedSignal("Coins"):Connect(function(): ()
		Refresh()
	end)

	local function BindValue(ValueObject: Instance): ()
		if not (ValueObject:IsA("IntValue") or ValueObject:IsA("NumberValue")) then
			return
		end
		ValueObject:GetPropertyChangedSignal("Value"):Connect(function(): ()
			Refresh()
		end)
	end

	local function BindLeaderstats(Leaderstats: Instance): ()
		local CoinsValue: Instance? = Leaderstats:FindFirstChild("Coins")
		if CoinsValue then
			BindValue(CoinsValue)
		end
		Leaderstats.ChildAdded:Connect(function(Child: Instance): ()
			if Child.Name == "Coins" then
				BindValue(Child)
			end
		end)
	end

	local ExistingLeaderstats: Instance? = Player:FindFirstChild("leaderstats")
	if ExistingLeaderstats then
		BindLeaderstats(ExistingLeaderstats)
	end

	local function BindCurrency(Folder: Instance): ()
		local CoinsValue: Instance? = Folder:FindFirstChild("Coins")
		if CoinsValue then
			BindValue(CoinsValue)
		end
		Folder.ChildAdded:Connect(function(Child: Instance): ()
			if Child.Name == "Coins" then
				BindValue(Child)
			end
		end)
	end

	local ExistingCurrency: Instance? = Player:FindFirstChild("Currency")
	if ExistingCurrency then
		BindCurrency(ExistingCurrency)
	end

	Player.ChildAdded:Connect(function(Child: Instance): ()
		if Child.Name == "leaderstats" then
			BindLeaderstats(Child)
		elseif Child.Name == "Currency" then
			BindCurrency(Child)
		end
	end)
end

local function _GetCandyMaxLevelForBillboard(ModelName: string): number
	if ModelName ~= EMPTY_STRING then
		local Evolution: any = CandyConfig.Evolutions[ModelName]
		if Evolution and typeof(Evolution.MaxLevel) == "number" and Evolution.MaxLevel > 0 then
			return Evolution.MaxLevel
		end
	end
	return 5
end

local function _GetEvolutionLimitForBillboard(ModelName: string, Level: number): number
	if ModelName == EMPTY_STRING then
		return 1
	end

	local Evolution: any = CandyConfig.Evolutions[ModelName]
	if not Evolution or typeof(Evolution.Limit) ~= "number" or Evolution.Limit <= 0 then
		return 1
	end

	local BaseLimit: number = Evolution.Limit
	local Growth: number = if typeof(Evolution.LimitGrowth) == "number" then Evolution.LimitGrowth else 0
	if Growth <= 0 or Level <= 1 then
		return BaseLimit
	end

	local Multiplier: number = math.pow(1 + Growth, math.max(0, Level - 1))
	return math.floor(BaseLimit * Multiplier + 0.5)
end

local function _HasPlotOwner(Plot: Model): boolean
	local OwnerId: any = Plot:GetAttribute(OWNER_ATTRIBUTE_NAME)
	return typeof(OwnerId) == "number" and OwnerId > 0
end

local function _WatchPlotOwner(Plot: Model): ()
	if _PlotOwnerWatchers[Plot] then
		return
	end

	_PlotOwnerWatchers[Plot] = Plot:GetAttributeChangedSignal(OWNER_ATTRIBUTE_NAME):Connect(function(): ()
		if _HasPlotOwner(Plot) then
			local Connection: RBXScriptConnection? = _PlotOwnerWatchers[Plot]
			if Connection then
				Connection:Disconnect()
			end
			_PlotOwnerWatchers[Plot] = nil
			_SetupPlotVisual(Plot)
		end
	end)
end

local function _FindDescendant(Parent: Instance, Name: string): Instance?
	return Parent:FindFirstChild(Name, true)
end

local function _FindFirstBasePart(Parent: Instance): BasePart?
	for _, Child: Instance in Parent:GetDescendants() do
		if Child:IsA("BasePart") then
			return Child
		end
	end
	return nil
end

local function _NormalizeName(Name: string): string
	return string.lower((Name:gsub("[%s_%-]", "")))
end

local function _FindHitbox(Parent: Instance): BasePart?
	local Direct: Instance? = _FindDescendant(Parent, HITBOX_PART_NAME)
	if Direct and Direct:IsA("BasePart") then
		return Direct
	end

	local Target: string = _NormalizeName(HITBOX_PART_NAME)
	for _, Descendant: Instance in Parent:GetDescendants() do
		if Descendant:IsA("BasePart") then
			if _NormalizeName(Descendant.Name) == Target then
				return Descendant
			end
		end
	end

	return nil
end

local function _SetQueryMask(Parent: Instance, Allowed: { [Instance]: boolean }): ()
	for _, Descendant: Instance in Parent:GetDescendants() do
		if Descendant:IsA("BasePart") then
			if not Allowed[Descendant] then
				Descendant.CanQuery = false
			end
		end
	end
end

local function _FindSlotContainer(DroppersFolder: Instance, SlotId: string, SlotPartName: string): Instance?
	local Direct: Instance? = DroppersFolder:FindFirstChild(SlotId)
	if Direct then
		return Direct
	end

	local PartDirect: Instance? = DroppersFolder:FindFirstChild(SlotPartName)
	if PartDirect then
		return PartDirect
	end

	local PartDeep: Instance? = DroppersFolder:FindFirstChild(SlotPartName, true)
	if PartDeep then
		return PartDeep
	end

	return nil
end

local function _ResolveSlotPart(SlotContainer: Instance, SlotPartName: string): BasePart?
	if SlotContainer:IsA("BasePart") then
		if SlotContainer.Name == SlotPartName then
			return SlotContainer
		end

		local Child: Instance? = SlotContainer:FindFirstChild(SlotPartName, true)
		if Child and Child:IsA("BasePart") then
			return Child
		end

		return SlotContainer
	end

	local Found: Instance? = SlotContainer:FindFirstChild(SlotPartName, true)
	if Found then
		if Found:IsA("BasePart") then
			return Found
		end

		local NestedPart: BasePart? = _FindFirstBasePart(Found)
		if NestedPart then
			return NestedPart
		end
	end

	local TargetName: string = string.lower((SlotPartName:gsub("[%s_%-]", "")))
	for _, Descendant: Instance in SlotContainer:GetDescendants() do
		if Descendant:IsA("BasePart") then
			local Normalized: string = string.lower((Descendant.Name:gsub("[%s_%-]", "")))
			if Normalized == TargetName then
				return Descendant
			end
		end
	end

	local FallbackPart: BasePart? = _FindFirstBasePart(SlotContainer)
	if FallbackPart then
		_Debug("Slot part fallback used: %s", _DescribeInstance(FallbackPart))
		return FallbackPart
	end

	return nil
end

local function _ResolveSlotParent(SlotContainer: Instance, Fallback: Instance): Instance
	if SlotContainer:IsA("BasePart") then
		return SlotContainer.Parent or Fallback
	end
	return SlotContainer
end

local function _WatchSlotPart(
	SlotContainer: Instance,
	SlotPartName: string,
	OnReady: () -> ()
): ()
	if _SlotWatchers[SlotContainer] then
		return
	end

	_Debug("Waiting for slot part %s in %s", SlotPartName, _DescribeInstance(SlotContainer))

	_SlotWatchers[SlotContainer] = SlotContainer.DescendantAdded:Connect(function(): ()
		if _ResolveSlotPart(SlotContainer, SlotPartName) then
			local Connection: RBXScriptConnection? = _SlotWatchers[SlotContainer]
			if Connection then
				Connection:Disconnect()
			end
			_SlotWatchers[SlotContainer] = nil
			OnReady()
		end
	end)
end

local function _GetDebrisFolder(): Instance
	local Map: Instance? = workspace:FindFirstChild("Map")
	if Map and (Map:IsA("Folder") or Map:IsA("Model")) then
		local DebrisFolder: Instance? = Map:FindFirstChild("Debris")
		if DebrisFolder then
			return DebrisFolder
		end
	end
	return workspace
end

local function _GetAttributeKey(GroupId: string, SlotId: string, TapId: number?, KeyName: string): string
	if TapId then
		return string.format(ATTRIBUTE_FORMAT_TAP, ATTRIBUTE_PREFIX, GroupId, SlotId, ATTRIBUTE_TAP_PREFIX, TapId, KeyName)
	end
	return string.format(ATTRIBUTE_FORMAT_NORMAL, ATTRIBUTE_PREFIX, GroupId, SlotId, KeyName)
end

local function _BuildCandyAttributeKeys(GroupId: string, SlotId: string, TapId: number?): CandyAttributeKeys
	return {
		CandyModel = _GetAttributeKey(GroupId, SlotId, TapId, ATTRIBUTE_KEY_CANDY_MODEL),
		CandyLevel = _GetAttributeKey(GroupId, SlotId, TapId, ATTRIBUTE_KEY_CANDY_LEVEL),
		CandyProgress = _GetAttributeKey(GroupId, SlotId, TapId, ATTRIBUTE_KEY_CANDY_PROGRESS),
		CandyScale = _GetAttributeKey(GroupId, SlotId, TapId, ATTRIBUTE_KEY_CANDY_SCALE),
		DropSequence = _GetAttributeKey(GroupId, SlotId, TapId, ATTRIBUTE_KEY_DROP_SEQUENCE),
		RemoveSequence = _GetAttributeKey(GroupId, SlotId, TapId, ATTRIBUTE_KEY_REMOVE_SEQUENCE),
		Mutations = _GetAttributeKey(GroupId, SlotId, TapId, ATTRIBUTE_KEY_MUTATIONS),
	}
end

local function _GetStringAttribute(Plot: Model, Key: string, Default: string): string
	local ValueObject: ValueBase? = _WaitForValueObject(Plot, Key)
	if ValueObject and ValueObject:IsA("StringValue") then
		return ValueObject.Value
	end
	return Default
end

local function _GetNumberAttribute(Plot: Model, Key: string, Default: number): number
	local ValueObject: ValueBase? = _WaitForValueObject(Plot, Key)
	if ValueObject and ValueObject:IsA("IntValue") then
		return _DecodeNumber(Key, ValueObject.Value)
	end
	return Default
end

local function _DecodeMutations(Value: string): { string }
	if Value == EMPTY_STRING then
		return {}
	end

	local Results: { string } = {}
	local Separator: string = MutationConfig.Separator
	local Pattern: string = "[^" .. Separator .. "]+"
	for Token: string in string.gmatch(Value, Pattern) do
		if Token ~= EMPTY_STRING then
			table.insert(Results, Token)
		end
	end
	return Results
end

local function _GetUpgradeKey(GroupId: string, SlotId: string, UpgradeId: string?): string
	if not UpgradeId or UpgradeId == "Level" then
		return string.format(ATTRIBUTE_FORMAT_NORMAL, ATTRIBUTE_PREFIX, GroupId, SlotId, ATTRIBUTE_KEY_UPGRADE_LEVEL)
	end
	return string.format(ATTRIBUTE_FORMAT_NORMAL, ATTRIBUTE_PREFIX, GroupId, SlotId, ATTRIBUTE_KEY_UPGRADE_PREFIX .. UpgradeId)
end

local function _GetEquippedTool(): Tool?
	local Player: Player? = Players.LocalPlayer
	if not Player then
		return nil
	end

	local Character: Model? = Player.Character
	if not Character then
		return nil
	end

	return Character:FindFirstChildOfClass("Tool")
end

local function _GetCandyAssetsFolder(): Instance?
	local AssetsRoot: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_ROOT_NAME)
	if not AssetsRoot then
		return nil
	end
	return AssetsRoot:FindFirstChild(CANDIES_FOLDER_NAME)
end

local function _HasCandyAsset(Name: string): boolean
	local AssetsFolder: Instance? = _GetCandyAssetsFolder()
	if not AssetsFolder then
		return false
	end

	local Asset: Instance? = AssetsFolder:FindFirstChild(Name)
	return Asset ~= nil and Asset:IsA("Model")
end

local function _GetCandyNameFromTool(ToolInstance: Tool): string?
	local AttributeModel: any = ToolInstance:GetAttribute("CandyModel")
	if typeof(AttributeModel) == "string" and AttributeModel ~= EMPTY_STRING then
		if _HasCandyAsset(AttributeModel) then
			return AttributeModel
		end
	end

	if _HasCandyAsset(ToolInstance.Name) then
		return ToolInstance.Name
	end

	return nil
end

local function _CloneCandyAsset(CandyModelName: string): Model?
	local AssetsRoot: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_ROOT_NAME)
	if not AssetsRoot then
		return nil
	end

	local AssetsFolder: Instance? = AssetsRoot:FindFirstChild(CANDIES_FOLDER_NAME)
	if not AssetsFolder then
		return nil
	end

	local CandyAsset: Instance? = AssetsFolder:FindFirstChild(CandyModelName)
	if not CandyAsset then
		return nil
	end

	local CandyClone: Model? = nil
	if CandyAsset:IsA("Model") then
		CandyClone = CandyAsset:Clone()
	elseif CandyAsset:IsA("BasePart") then
		local ModelWrapper: Model = Instance.new("Model")
		ModelWrapper.Name = CandyAsset.Name
		local PartClone: BasePart = CandyAsset:Clone()
		PartClone.Parent = ModelWrapper
		ModelWrapper.PrimaryPart = PartClone
		CandyClone = ModelWrapper
	elseif CandyAsset:IsA("Folder") then
		local ChildModel: Model? = CandyAsset:FindFirstChildOfClass("Model")
		local ChildPart: BasePart? = CandyAsset:FindFirstChildWhichIsA("BasePart")
		if ChildModel then
			CandyClone = ChildModel:Clone()
		elseif ChildPart then
			local ModelWrapper: Model = Instance.new("Model")
			ModelWrapper.Name = CandyAsset.Name
			local PartClone: BasePart = ChildPart:Clone()
			PartClone.Parent = ModelWrapper
			ModelWrapper.PrimaryPart = PartClone
			CandyClone = ModelWrapper
		end
	end

	if not CandyClone then
		return nil
	end

	local PrimaryPart: BasePart? = CandyClone.PrimaryPart
	if not PrimaryPart then
		PrimaryPart = _FindFirstBasePart(CandyClone)
		if PrimaryPart then
			CandyClone.PrimaryPart = PrimaryPart
		end
	end

	if not PrimaryPart then
		CandyClone:Destroy()
		return nil
	end

	for _, Child: Instance in CandyClone:GetDescendants() do
		if Child:IsA("BasePart") then
			Child.Anchored = true
			Child.CanCollide = false
			Child.CanQuery = false
			Child.CanTouch = false
			local TargetTransparency: number = if Child == PrimaryPart then 1 else 0.5
			Child.Transparency = TargetTransparency
			Child.LocalTransparencyModifier = TargetTransparency
		end
	end

	return CandyClone
end

local function _CancelHologramTween(TargetModel: Model): ()
	local Connection: RBXScriptConnection? = _HologramTweens[TargetModel]
	if Connection then
		Connection:Disconnect()
		_HologramTweens[TargetModel] = nil
	end
end

local function _PlayHologramSpawn(TargetModel: Model): ()
	if not TargetModel.Parent then
		return
	end

	_CancelHologramTween(TargetModel)
	local TargetScale: number = TargetModel:GetScale()
	TargetModel:ScaleTo(0.01)

	_HologramTweens[TargetModel] = TweenModule:TweenScale(
		TargetModel,
		0.15,
		"Sine",
		"Out",
		TargetScale,
		function(): ()
			_HologramTweens[TargetModel] = nil
		end
	)
end

local function _PlayHologramDespawn(TargetModel: Model, OnComplete: (() -> ())?): ()
	if not TargetModel.Parent then
		if OnComplete then
			OnComplete()
		end
		return
	end

	_CancelHologramTween(TargetModel)
	_HologramTweens[TargetModel] = TweenModule:TweenScale(
		TargetModel,
		0.15,
		"Sine",
		"In",
		0,
		function(): ()
			_HologramTweens[TargetModel] = nil
			if OnComplete then
				OnComplete()
			end
		end
	)
end

local function _ApplyHologramTint(TargetModel: Model, TintColor: Color3): ()
	local PrimaryPart: BasePart? = TargetModel.PrimaryPart
	if not PrimaryPart then
		PrimaryPart = _FindFirstBasePart(TargetModel)
	end

	for _, Child: Instance in TargetModel:GetDescendants() do
		if Child:IsA("BasePart") then
			local TargetTransparency: number = if Child == PrimaryPart then 1 else 0.5
			Child.Transparency = TargetTransparency
			Child.LocalTransparencyModifier = TargetTransparency
			Child.Color = TintColor
		end
	end
end

local function _AttachRemovalTrail(TargetModel: Model): (() -> ())?
	local PrimaryPart: BasePart? = TargetModel.PrimaryPart
	if not PrimaryPart then
		PrimaryPart = _FindFirstBasePart(TargetModel)
	end
	if not PrimaryPart then
		return nil
	end

	local Attachment0: Attachment = Instance.new("Attachment")
	Attachment0.Position = Vector3.new(0, 0, VisualConfig.DropPartSize.Z * 0.5)
	Attachment0.Parent = PrimaryPart

	local Attachment1: Attachment = Instance.new("Attachment")
	Attachment1.Position = Vector3.new(0, 0, -VisualConfig.DropPartSize.Z * 0.5)
	Attachment1.Parent = PrimaryPart

	local Trail: Trail = Instance.new("Trail")
	Trail.Attachment0 = Attachment0
	Trail.Attachment1 = Attachment1
	Trail.Lifetime = VisualConfig.DropTrailLifetime
	Trail.MinLength = 0
	Trail.WidthScale = NumberSequence.new(VisualConfig.DropTrailWidth * 0.4)
	Trail.Color = ColorSequence.new(VisualConfig.DropTrailColor)
	Trail.Texture = "rbxassetid://284205403"
	Trail.FaceCamera = true
	Trail.Enabled = true
	Trail.Parent = PrimaryPart

	return function(): ()
		if Trail.Parent then
			Trail:Destroy()
		end
		if Attachment0.Parent then
			Attachment0:Destroy()
		end
		if Attachment1.Parent then
			Attachment1:Destroy()
		end
	end
end

local function _ClearDropperPreview(DropperData: DropperVisual): ()
	local PreviewModel: Model? = DropperData.PreviewModel
	if not PreviewModel then
		return
	end

	DropperData.PreviewModel = nil
	DropperData.PreviewName = nil
	_PlayHologramDespawn(PreviewModel, function(): ()
		PreviewModel:Destroy()
	end)
end

local _ClearOtherPreviews: (KeepModel: Model?) -> ()

local function _ShowDropperPreview(DropperData: DropperVisual, CandyName: string, TargetCFrame: CFrame): ()
	if DropperData.PreviewModel and DropperData.PreviewName == CandyName then
		DropperData.PreviewModel:PivotTo(TargetCFrame)
		return
	end

	_ClearOtherPreviews(DropperData.PreviewModel)
	_ClearDropperPreview(DropperData)
	local Clone: Model? = _CloneCandyAsset(CandyName)
	if not Clone then
		return
	end

	Clone.Parent = DropperData.Model.Parent or DropperData.Model
	Clone:PivotTo(TargetCFrame)
	DropperData.PreviewModel = Clone
	DropperData.PreviewName = CandyName
	_PlayHologramSpawn(Clone)
end

local function _ClearTapPreview(TapData: TapVisual): ()
	local PreviewModel: Model? = TapData.PreviewModel
	if not PreviewModel then
		return
	end

	TapData.PreviewModel = nil
	TapData.PreviewName = nil
	_PlayHologramDespawn(PreviewModel, function(): ()
		PreviewModel:Destroy()
	end)
end

_ClearOtherPreviews = function(KeepModel: Model?): ()
	for _, PlotData: PlotVisual in _PlotVisuals do
		for _, GroupData in PlotData.Groups do
			for _, SlotVisual: DropperVisual in GroupData.Slots do
				if SlotVisual.PreviewModel and SlotVisual.PreviewModel ~= KeepModel then
					_ClearDropperPreview(SlotVisual)
				end
				if SlotVisual.Taps then
					for _, TapData: TapVisual in SlotVisual.Taps do
						if TapData.PreviewModel and TapData.PreviewModel ~= KeepModel then
							_ClearTapPreview(TapData)
						end
					end
				end
			end
		end
	end
end

local function _ShowTapPreview(TapData: TapVisual, CandyName: string, TargetCFrame: CFrame, Parent: Instance): ()
	if TapData.PreviewModel and TapData.PreviewName == CandyName then
		TapData.PreviewModel:PivotTo(TargetCFrame)
		return
	end

	_ClearOtherPreviews(TapData.PreviewModel)
	_ClearTapPreview(TapData)
	local Clone: Model? = _CloneCandyAsset(CandyName)
	if not Clone then
		return
	end

	Clone.Parent = Parent
	Clone:PivotTo(TargetCFrame)
	TapData.PreviewModel = Clone
	TapData.PreviewName = CandyName
	_PlayHologramSpawn(Clone)
end

local function _GetReturnScale(DropperData: DropperVisual): number
	return DropperData.BaseScale
end

local function _AlignDropperToSlot(DropperData: DropperVisual): ()
	local SlotPart: BasePart? = DropperData.SlotPart
	if not SlotPart then
		return
	end

	local SlotUp: Vector3 = SlotPart.CFrame.UpVector
	local SlotTop: Vector3 = SlotPart.Position + (SlotUp * (SlotPart.Size.Y * 0.5))

	local BboxCFrame: CFrame, BboxSize: Vector3 = DropperData.Model:GetBoundingBox()
	local Center: Vector3 = BboxCFrame.Position
	local ToSlot: Vector3 = SlotPart.Position - Center
	local VerticalComponent: Vector3 = SlotUp * ToSlot:Dot(SlotUp)
	local HorizontalOffset: Vector3 = ToSlot - VerticalComponent

	local HalfSize: Vector3 = BboxSize * 0.5
	local Right: Vector3 = BboxCFrame.RightVector
	local Up: Vector3 = BboxCFrame.UpVector
	local Look: Vector3 = BboxCFrame.LookVector
	local ExtentAlongUp: number = math.abs(SlotUp:Dot(Right)) * HalfSize.X
		+ math.abs(SlotUp:Dot(Up)) * HalfSize.Y
		+ math.abs(SlotUp:Dot(Look)) * HalfSize.Z

	local MinDot: number = Center:Dot(SlotUp) - ExtentAlongUp
	local TargetDot: number = SlotTop:Dot(SlotUp)
	local VerticalOffset: Vector3 = SlotUp * (TargetDot - MinDot)
	local TotalOffset: Vector3 = HorizontalOffset + VerticalOffset

	if TotalOffset.Magnitude > 1e-4 then
		DropperData.Model:PivotTo(DropperData.Model:GetPivot() + TotalOffset)
	end
end

local function _StartDropperScaleTween(
	DropperData: DropperVisual,
	Duration: number,
	Style: string,
	Direction: string,
	TargetScale: number,
	OnComplete: (() -> ())?
): ()
	if DropperData.HoverTween then
		DropperData.HoverTween:Disconnect()
		DropperData.HoverTween = nil
	end

	local StartTime: number = os.clock()
	local StartScale: number = DropperData.Model:GetScale()
	local SafeTargetScale: number = math.max(TargetScale, 0.01)

	DropperData.HoverTween = RunService.RenderStepped:Connect(function(): ()
		local Elapsed: number = os.clock() - StartTime
		local Progress: number = math.min(1, Elapsed / Duration)
		local EasingValue: number = TweenService:GetValue(Progress, Enum.EasingStyle[Style], Enum.EasingDirection[Direction])
		local CurrentScale: number = StartScale + (SafeTargetScale - StartScale) * EasingValue
		if CurrentScale < 0.01 then
			CurrentScale = 0.01
		end

		DropperData.Model:ScaleTo(CurrentScale)
		_AlignDropperToSlot(DropperData)

		if Progress >= 1 then
			if DropperData.HoverTween then
				DropperData.HoverTween:Disconnect()
			end
			DropperData.HoverTween = nil
			if OnComplete then
				OnComplete()
			end
		end
	end)
end

local function _FlashDropper(DropperData: DropperVisual, FlashColor: Color3): ()
	if not DropperData.Highlight then
		return
	end

	if DEBUG_HOVER then
		_Debug(
			"Flash %s color=%s hasCandy=%s",
			DropperData.Model.Name,
			tostring(FlashColor),
			tostring(DropperData.HasCandy)
		)
	end
	local Highlight: Highlight = DropperData.Highlight
	Highlight.OutlineColor = FlashColor
	Highlight.OutlineTransparency = 0
	Highlight.FillTransparency = 1
	Highlight.Enabled = true

	TweenModule:Tween(Highlight, 0.12, "Sine", "Out", { OutlineTransparency = 0.7 }, 0, false, function(): ()
		Highlight.OutlineColor = DROPPER_HIGHLIGHT_COLOR
		Highlight.OutlineTransparency = 0
		Highlight.FillTransparency = 1
		if not DropperData.IsHovering then
			Highlight.Enabled = false
		end
	end)
end

local function _EnsureDropperHighlight(DropperData: DropperVisual): ()
	if DropperData.Highlight then
		return
	end

	local Highlight: Highlight = Instance.new("Highlight")
	Highlight.FillColor = DROPPER_HIGHLIGHT_COLOR
	Highlight.FillTransparency = 1
	Highlight.OutlineColor = DROPPER_HIGHLIGHT_COLOR
	Highlight.OutlineTransparency = 0
	Highlight.Adornee = DropperData.Model
	Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	Highlight.Enabled = false
	Highlight.Parent = DropperData.Model

	DropperData.Highlight = Highlight
	DropperData.HoverColor = DROPPER_HIGHLIGHT_COLOR
end

local function _StartTapPulse(TapData: TapVisual): ()
	if not TapData.Hitbox then
		return
	end

	if TapData.PulseTween then
		TapData.PulseTween:Cancel()
		TapData.PulseTween = nil
	end

	TapData.Hitbox.Color = Color3.fromRGB(255, 255, 255)
	TapData.Hitbox.Transparency = 1
	TapData.Hitbox.LocalTransparencyModifier = 1
end

local function _StopTapPulse(TapData: TapVisual): ()
	if TapData.PulseTween then
		TapData.PulseTween:Cancel()
		TapData.PulseTween = nil
	end

	if TapData.Hitbox then
		TapData.Hitbox.Transparency = 1
		TapData.Hitbox.LocalTransparencyModifier = 1
	end
end

local function _PlayDropperClickScale(DropperData: DropperVisual, TargetScale: number): ()
	local ReturnScale: number = _GetReturnScale(DropperData)
	_StartDropperScaleTween(DropperData, 0.12, "Sine", "Out", TargetScale, function(): ()
		_StartDropperScaleTween(DropperData, 0.14, "Sine", "Out", ReturnScale, function(): ()
			DropperData.HoverTween = nil
		end)
	end)
end

local function _TweenButtonSize(ButtonPart: BasePart, TargetSize: Vector3, Duration: number, OnComplete: (() -> ())?): ()
	local Existing: Tween? = _ButtonTweens[ButtonPart]
	if Existing then
		Existing:Cancel()
		Existing:Destroy()
		_ButtonTweens[ButtonPart] = nil
	end

	local Tween: Tween = TweenService:Create(
		ButtonPart,
		TweenInfo.new(Duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Size = TargetSize }
	)
	_ButtonTweens[ButtonPart] = Tween
	Tween:Play()

	Tween.Completed:Once(function(): ()
		if _ButtonTweens[ButtonPart] == Tween then
			_ButtonTweens[ButtonPart] = nil
		end
		Tween:Destroy()
		if OnComplete then
			OnComplete()
		end
	end)
end

local function _PlayButtonClick(ButtonPart: BasePart): ()
	local ShrunkSize: Vector3 = BUTTON_BASE_SIZE * BUTTON_CLICK_SCALE
	local ReturnSize: Vector3 = if ButtonPart:GetAttribute("IsHovering") then BUTTON_BASE_SIZE * BUTTON_HOVER_SCALE else BUTTON_BASE_SIZE

	_TweenButtonSize(ButtonPart, ShrunkSize, 0.08, function(): ()
		_TweenButtonSize(ButtonPart, ReturnSize, 0.1, nil)
	end)
end

local function _CreateDropEffect(): DropEffect
	local DropPart: Part = Instance.new("Part")
	DropPart.Name = "DropEffect"
	DropPart.Size = VisualConfig.DropPartSize
	DropPart.Anchored = true
	DropPart.CanCollide = false
	DropPart.CanQuery = false
	DropPart.CanTouch = false
	DropPart.Transparency = 1
	DropPart.Parent = _GetDebrisFolder()

	local Attachment0: Attachment = Instance.new("Attachment")
	Attachment0.Position = Vector3.new(0, 0, DropPart.Size.Z * 0.5)
	Attachment0.Parent = DropPart

	local Attachment1: Attachment = Instance.new("Attachment")
	Attachment1.Position = Vector3.new(0, 0, -DropPart.Size.Z * 0.5)
	Attachment1.Parent = DropPart

	local Trail: Trail = Instance.new("Trail")
	Trail.Attachment0 = Attachment0
	Trail.Attachment1 = Attachment1
	Trail.Lifetime = VisualConfig.DropTrailLifetime
	Trail.Color = ColorSequence.new(VisualConfig.DropTrailColor)
	Trail.Texture = EMPTY_STRING
	Trail.FaceCamera = true
	Trail.Enabled = false
	Trail.Parent = DropPart

	local DropEffectData: DropEffect = {
		Part = DropPart,
		Attachment0 = Attachment0,
		Attachment1 = Attachment1,
		Trail = Trail,
		Tween = nil,
	}

	return DropEffectData
end

local function _EnsureDropEffect(DropEffectData: DropEffect?): DropEffect?
	if not DropEffectData then
		return nil
	end
	if DropEffectData.Part.Parent then
		return DropEffectData
	end
	_ActiveDropEffects[DropEffectData] = nil

	local NewEffect: DropEffect = _CreateDropEffect()
	DropEffectData.Part = NewEffect.Part
	DropEffectData.Attachment0 = NewEffect.Attachment0
	DropEffectData.Attachment1 = NewEffect.Attachment1
	DropEffectData.Trail = NewEffect.Trail
	DropEffectData.Tween = nil
	return DropEffectData
end

local function _PlayDropEffect(DropEffectData: DropEffect, StartCFrame: CFrame, EndCFrame: CFrame, Duration: number, OnComplete: (() -> ())?): ()
	if _ActiveDropEffects[DropEffectData] then
		if DropEffectData.Tween then
			DropEffectData.Tween:Cancel()
			DropEffectData.Tween = nil
		end
		DropEffectData.Trail.Enabled = false
		_ActiveDropEffects[DropEffectData] = nil
	end

	DropEffectData.Part.CFrame = StartCFrame
	DropEffectData.Trail.Texture = EMPTY_STRING
	DropEffectData.Trail.Color = ColorSequence.new(VisualConfig.DropTrailColor)
	DropEffectData.Trail.Enabled = true

	if DropEffectData.Tween then
		DropEffectData.Tween:Cancel()
		DropEffectData.Tween = nil
		DropEffectData.Trail.Enabled = false
	end

	_ActiveDropEffects[DropEffectData] = true
	DropEffectData.Tween = TweenModule:Tween(
		DropEffectData.Part,
		Duration,
		"Linear",
		"Out",
		{ CFrame = EndCFrame },
		0,
		false,
		function(): ()
			DropEffectData.Trail.Enabled = false
			DropEffectData.Tween = nil
			_ActiveDropEffects[DropEffectData] = nil
			if DropEffectData.Part.Parent then
				DropEffectData.Part:Destroy()
			end
			if OnComplete then
				OnComplete()
			end
		end
	)
end

local function _TweenDropperScale(DropperData: DropperVisual, TargetScale: number): ()
	if DropperData.HoverTween then
		DropperData.HoverTween:Disconnect()
		DropperData.HoverTween = nil
	end

	if DEBUG_HOVER then
		_Debug("TweenScale %s -> %.3f", DropperData.Model.Name, TargetScale)
	end
	_StartDropperScaleTween(DropperData, VisualConfig.HoverTweenTime, VisualConfig.HoverTweenStyle, VisualConfig.HoverTweenDirection, TargetScale, function(): ()
		DropperData.HoverTween = nil
	end)
end

local function _SetDropperHover(DropperData: DropperVisual, IsHover: boolean): ()
	DropperData.IsHovering = IsHover
	if not DropperData.Highlight then
		if DEBUG_HOVER then
			_Debug("Hover ignored (no highlight) for %s", DropperData.Model.Name)
		end
		return
	end

	if IsHover then
		if DEBUG_HOVER then
			_Debug("Hover enter for %s", DropperData.Model.Name)
		end
		DropperData.Highlight.OutlineColor = DROPPER_HIGHLIGHT_COLOR
		DropperData.Highlight.OutlineTransparency = 0
		DropperData.Highlight.FillTransparency = 1
		DropperData.Highlight.Enabled = true
		return
	end

	if DEBUG_HOVER then
		_Debug("Hover leave for %s", DropperData.Model.Name)
	end
	DropperData.Highlight.Enabled = false
end

local function _IsButtonOnCooldown(ButtonPart: BasePart): boolean
	local Until: number? = _ButtonCooldownUntil[ButtonPart]
	return typeof(Until) == "number" and os.clock() < Until
end

local function _SetButtonHighlightState(ButtonHighlight: Highlight?, IsCooldown: boolean): ()
	if not ButtonHighlight then
		return
	end

	ButtonHighlight.FillColor = Color3.fromRGB(255, 255, 255)
	local Adornee: Instance? = ButtonHighlight.Adornee
	if Adornee and Adornee:IsA("BasePart") then
		Adornee.Color = if IsCooldown then BUTTON_COOLDOWN_COLOR else BUTTON_READY_COLOR
	end
end

local _SyncLevelBarLayout: (CandyData: CandyVisual) -> ()

local function _ApplyCandyScale(CandyData: CandyVisual, NewScale: number): ()
	CandyData.BaseScale = NewScale

	if CandyData.IsRemoving then
		return
	end

	if CandyData.IsBouncing or CandyData.IsSpawning then
		CandyData.PendingScale = NewScale
		return
	end

	if CandyData.Model then
		CandyData.Model:ScaleTo(NewScale)
		CandyData.Model:PivotTo(CandyData.CanPosition.CFrame)
	end

	_SyncLevelBarLayout(CandyData)
end

local function _FinishSpawn(CandyData: CandyVisual): ()
	CandyData.IsSpawning = false
	CandyData.SpawnConnection = nil

	_SyncLevelBarLayout(CandyData)

	if CandyData.PendingScale then
		local PendingScale: number = CandyData.PendingScale
		CandyData.PendingScale = nil
		_ApplyCandyScale(CandyData, PendingScale)
	end
end

local function _PlayCandySpawn(CandyData: CandyVisual, TargetScale: number): ()
	if not CandyData.Model then
		return
	end

	if CandyData.SpawnConnection then
		CandyData.SpawnConnection:Disconnect()
		CandyData.SpawnConnection = nil
	end

	CandyData.IsSpawning = true
	CandyData.BaseScale = TargetScale

	CandyData.Model:ScaleTo(0.01)
	CandyData.Model:PivotTo(CandyData.CanPosition.CFrame)

	local SafeScale: number = math.max(TargetScale, 0.01)
	CandyData.SpawnConnection = TweenModule:TweenScale(
		CandyData.Model,
		CANDY_SPAWN_TIME,
		CANDY_SPAWN_STYLE,
		CANDY_SPAWN_DIRECTION,
		SafeScale,
		function(): ()
			_FinishSpawn(CandyData)
		end
	)
end

local function _FinishBounce(CandyData: CandyVisual): ()
	CandyData.IsBouncing = false
	CandyData.BounceConnection = nil

	_SyncLevelBarLayout(CandyData)

	if CandyData.PendingScale then
		local PendingScale: number = CandyData.PendingScale
		CandyData.PendingScale = nil
		_ApplyCandyScale(CandyData, PendingScale)
	end
end

local function _PlayCandyBounce(CandyData: CandyVisual): ()
	if not CandyData.Model then
		return
	end

	if CandyData.IsRemoving then
		return
	end
	if CandyData.IsSpawning then
		return
	end

	if CandyData.BounceConnection then
		CandyData.BounceConnection:Disconnect()
		CandyData.BounceConnection = nil
	end

	CandyData.IsBouncing = true

	local TargetScale: number = CandyData.BaseScale + VisualConfig.CandyBounceScale
	CandyData.BounceConnection = TweenModule:TweenScale(
		CandyData.Model,
		VisualConfig.CandyBounceTime,
		VisualConfig.CandyBounceStyle,
		VisualConfig.CandyBounceDirection,
		TargetScale,
		function(): ()
			CandyData.BounceConnection = TweenModule:TweenScale(
				CandyData.Model,
				VisualConfig.CandyBounceTime,
				VisualConfig.CandyBounceStyle,
				VisualConfig.CandyBounceDirection,
				CandyData.BaseScale,
				function(): ()
					_FinishBounce(CandyData)
				end
			)
		end
	)
end

local function _CleanupCandyVisual(CandyData: CandyVisual): ()
	if CandyData.Model then
		CandyData.Model:Destroy()
		CandyData.Model = nil
	end

	CandyData.Highlight = nil
	CandyData.ClickDetector = nil
	if CandyData.MutationConnection then
		CandyData.MutationConnection:Disconnect()
	end
	CandyData.MutationConnection = nil
	if CandyData.MutationTextConnection then
		CandyData.MutationTextConnection:Disconnect()
	end
	CandyData.MutationTextConnection = nil
	CandyData.MutationHighlight = nil
	if CandyData.LevelBar then
		CandyData.LevelBar:Destroy()
	end
	CandyData.LevelBar = nil
	CandyData.LevelLabel = nil
	CandyData.XpLabel = nil
	CandyData.BarFrame = nil
	if CandyData.MutationTextConnection then
		CandyData.MutationTextConnection:Disconnect()
	end
	CandyData.MutationTextConnection = nil
	CandyData.MutationFrame = nil
	CandyData.MutationTemplate = nil
	CandyData.MutationClones = nil
	CandyData.LevelBarSize = nil
	CandyData.LevelBarOffset = nil
	CandyData.OriginalColors = nil
	if CandyData.SpawnConnection then
		CandyData.SpawnConnection:Disconnect()
	end
	CandyData.SpawnConnection = nil
	CandyData.IsRemoving = false
	CandyData.IsSpawning = false
	CandyData.PendingScale = nil
	_ActiveCandies[CandyData] = nil
end

local function _AnimateCandyRemove(CandyData: CandyVisual): ()
	if CandyData.IsRemoving then
		return
	end

	if not CandyData.Model then
		return
	end

	local RemovingModel: Model = CandyData.Model
	CandyData.IsRemoving = true

	if CandyData.BounceConnection then
		CandyData.BounceConnection:Disconnect()
		CandyData.BounceConnection = nil
	end
	if CandyData.SpawnConnection then
		CandyData.SpawnConnection:Disconnect()
		CandyData.SpawnConnection = nil
	end
	CandyData.IsSpawning = false
	CandyData.PendingScale = nil

	_ApplyHologramTint(CandyData.Model, Color3.fromRGB(255, 0, 0))
	local CleanupTrail: (() -> ())? = _AttachRemovalTrail(CandyData.Model)

	_ActiveCandies[CandyData] = nil
	CandyData.AllowAttract = false

	if CandyData.LevelBar then
		CandyData.LevelBar:Destroy()
	end
	CandyData.LevelBar = nil
	CandyData.LevelLabel = nil
	CandyData.XpLabel = nil
	CandyData.BarFrame = nil
	CandyData.MutationFrame = nil
	CandyData.MutationTemplate = nil
	CandyData.MutationClones = nil
	CandyData.LevelBarSize = nil
	CandyData.LevelBarOffset = nil

	local Player: Player? = Players.LocalPlayer
	local RootPart: BasePart? = nil
	if Player and Player.Character then
		RootPart = Player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	end

	if RootPart then
		local Target: CFrame = RootPart.CFrame
		TweenModule:TweenModel(RemovingModel, REMOVE_ATTRACT_TIME, "Sine", "In", { Value = Target }, 0, false, function(): ()
			TweenModule:TweenScale(
				RemovingModel,
				VisualConfig.CandyBounceTime,
				"Sine",
				"In",
				0,
				function(): ()
					if CleanupTrail then
						CleanupTrail()
					end
					if CandyData.Model ~= RemovingModel then
						if RemovingModel.Parent then
							RemovingModel:Destroy()
						end
						CandyData.IsRemoving = false
						return
					end
					_CleanupCandyVisual(CandyData)
				end
			)
		end)
	else
		TweenModule:TweenScale(
			RemovingModel,
			VisualConfig.CandyBounceTime,
			"Sine",
			"In",
			0,
			function(): ()
				if CleanupTrail then
					CleanupTrail()
				end
				if CandyData.Model ~= RemovingModel then
					if RemovingModel.Parent then
						RemovingModel:Destroy()
					end
					CandyData.IsRemoving = false
					return
				end
				_CleanupCandyVisual(CandyData)
			end
		)
	end
end

local function _SetupCandyHover(CandyData: CandyVisual): ()
	if not CandyData.Model then
		return
	end
	if not CandyData.AllowInteraction then
		return
	end

	local PrimaryPart: BasePart? = CandyData.Model.PrimaryPart
	if not PrimaryPart then
		return
	end

	local Highlight: Highlight = Instance.new("Highlight")
	Highlight.FillColor = CANDY_HIGHLIGHT_COLOR
	Highlight.FillTransparency = 0.7
	Highlight.OutlineTransparency = 1
	Highlight.Enabled = false
	Highlight.Parent = CandyData.Model
	CandyData.Highlight = Highlight

	local Detector: ClickDetector = Instance.new("ClickDetector")
	Detector.MaxActivationDistance = 1000
	Detector.Parent = PrimaryPart
	CandyData.ClickDetector = Detector

	Detector.MouseHoverEnter:Connect(function(): ()
		if not CandyData.Model then
			return
		end

		if CandyData.Highlight then
			CandyData.Highlight.Enabled = true
		end

		if not CandyData.OriginalColors then
			CandyData.OriginalColors = {}
			for _, Child: Instance in CandyData.Model:GetDescendants() do
				if Child:IsA("BasePart") then
					CandyData.OriginalColors[Child] = Child.Color
				end
			end
		end

		for _, Child: Instance in CandyData.Model:GetDescendants() do
			if Child:IsA("BasePart") then
				Child.LocalTransparencyModifier = 0.5
				Child.Color = Color3.fromRGB(255, 0, 0)
			end
		end
	end)

	Detector.MouseHoverLeave:Connect(function(): ()
		if CandyData.Highlight then
			CandyData.Highlight.Enabled = false
		end

		if CandyData.Model then
			for _, Child: Instance in CandyData.Model:GetDescendants() do
				if Child:IsA("BasePart") then
					Child.LocalTransparencyModifier = 0
					if CandyData.OriginalColors and CandyData.OriginalColors[Child] then
						Child.Color = CandyData.OriginalColors[Child]
					end
				end
			end
		end
	end)

	Detector.MouseClick:Connect(function(): ()
		if CandyData.IsRemoving then
			return
		end
		local Now: number = os.clock()
		local Cooldown: number = if CandyData.TapId then 0.9 else 1.0
		if CandyData.PickupCooldownUntil and Now < CandyData.PickupCooldownUntil then
			return
		end
		CandyData.PickupCooldownUntil = Now + Cooldown
		Packets.Machines:Fire(ACTION_REMOVE_CANDY, {
			GroupId = CandyData.State.GroupId,
			SlotId = CandyData.SlotId,
			TapId = CandyData.TapId,
		})
	end)
end

function module._ClearMutationLabels(CandyData: CandyVisual): ()
	if CandyData.MutationTextConnection then
		CandyData.MutationTextConnection:Disconnect()
	end
	CandyData.MutationTextConnection = nil
	if CandyData.MutationClones then
		for _, Label: TextLabel in CandyData.MutationClones do
			Label:Destroy()
		end
	end
	CandyData.MutationClones = nil
end

local function _ApplyMutationTextEffect(CandyData: CandyVisual): ()
	if not CandyData.MutationClones or #CandyData.MutationClones == 0 then
		return
	end

	local HasRainbow: boolean = false
	for _, Label: TextLabel in CandyData.MutationClones do
		local MutationId: string = Label.Text
		local Visual: any = _MutationVisuals[MutationId]
		if Visual and Visual.IsRainbow then
			HasRainbow = true
		else
			local Color: Color3 = if Visual and Visual.Color then Visual.Color else Color3.fromRGB(255, 255, 255)
			Label.TextColor3 = Color
			Label.TextStrokeColor3 = Color
			Label.TextStrokeTransparency = 0.4
		end
	end

	if not HasRainbow then
		return
	end

	CandyData.MutationTextConnection = RunService.RenderStepped:Connect(function(): ()
		if not CandyData.MutationClones then
			return
		end
		local Hue: number = (os.clock() * 0.6) % 1
		local Color: Color3 = Color3.fromHSV(Hue, 1, 1)
		for _, Label: TextLabel in CandyData.MutationClones do
			local MutationId: string = Label.Text
			local Visual: any = _MutationVisuals[MutationId]
			if Visual and Visual.IsRainbow then
				Label.TextColor3 = Color
				Label.TextStrokeColor3 = Color
				Label.TextStrokeTransparency = 0.4
			end
		end
	end)
end

function module._UpdateMutationLabels(CandyData: CandyVisual, Mutations: { string }): ()
	module._ClearMutationLabels(CandyData)
	if not CandyData.MutationFrame or not CandyData.MutationTemplate then
		return
	end

	if #Mutations == 0 then
		CandyData.MutationFrame.Visible = false
		return
	end

	CandyData.MutationFrame.Visible = true
	CandyData.MutationTemplate.Visible = false

	local Clones: { TextLabel } = {}
	for _, MutationName: string in Mutations do
		local Clone: TextLabel = CandyData.MutationTemplate:Clone()
		Clone.Text = MutationName
		Clone.Visible = true
		Clone.Parent = CandyData.MutationTemplate.Parent
		table.insert(Clones, Clone)
	end
	CandyData.MutationClones = Clones
	_ApplyMutationTextEffect(CandyData)
end

_SyncLevelBarLayout = function(CandyData: CandyVisual): ()
	if not CandyData.LevelBar then
		return
	end
	if CandyData.LevelBarSize then
		CandyData.LevelBar.Size = CandyData.LevelBarSize
	end
	if CandyData.LevelBarOffset then
		CandyData.LevelBar.StudsOffset = CandyData.LevelBarOffset
	end
end

function module._UpdateCandyBillboard(CandyData: CandyVisual): ()
	if not CandyData.LevelLabel and not CandyData.XpLabel and not CandyData.BarFrame then
		return
	end
	_SyncLevelBarLayout(CandyData)
	local Level: number = _GetNumberAttribute(CandyData.State.Plot, CandyData.State.Keys.CandyLevel, DEFAULT_NUMBER)
	local Exp: number = _GetNumberAttribute(CandyData.State.Plot, CandyData.State.Keys.CandyProgress, DEFAULT_NUMBER)
	local ModelName: string = _GetStringAttribute(CandyData.State.Plot, CandyData.State.Keys.CandyModel, EMPTY_STRING)

	if CandyData.LevelLabel then
		CandyData.LevelLabel.Text = string.format("Level %d", Level)
	end

	local MaxLevel: number? = nil
	if ModelName ~= EMPTY_STRING then
		MaxLevel = _GetCandyMaxLevelForBillboard(ModelName)
	end
	local IsMaxLevel: boolean = MaxLevel ~= nil and Level >= (MaxLevel :: number)

	local MaxExp: number = 1
	if ModelName ~= EMPTY_STRING then
		MaxExp = _GetEvolutionLimitForBillboard(ModelName, Level)
	end

	if CandyData.XpLabel then
		if IsMaxLevel then
			CandyData.XpLabel.Text = "MAX"
			CandyData.XpLabel.RichText = false
		else
			local ExpText: string = string.format(
				"%s <font size=\"10\" color=\"rgb(50,150,255)\">XP</font> / %s <font size=\"10\" color=\"rgb(50,150,255)\">XP</font>",
				Short:Abbreviate(Exp),
				Short:Abbreviate(MaxExp)
			)
			CandyData.XpLabel.Text = ExpText
			CandyData.XpLabel.RichText = true
		end
	end

	local Progress: number = 0
	if IsMaxLevel then
		Progress = 1
	elseif MaxExp > 0 then
		Progress = math.clamp(Exp / MaxExp, 0, 1)
	end

	if CandyData.BarFrame then
		CandyData.BarFrame.Visible = true
		local TargetSize: UDim2 = UDim2.new(Progress, 0, 1, 0)
		TweenService:Create(CandyData.BarFrame, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Size = TargetSize,
		}):Play()
	end

	local MutationValue: string = _GetStringAttribute(CandyData.State.Plot, CandyData.State.Keys.Mutations, EMPTY_STRING)
	local Mutations: { string } = _DecodeMutations(MutationValue)
	module._UpdateMutationLabels(CandyData, Mutations)
end

function module._EnsureCandyBillboard(CandyData: CandyVisual): ()
	if CandyData.LevelBar then
		module._UpdateCandyBillboard(CandyData)
		return
	end

	if not CandyData.Model then
		return
	end

	local PrimaryPart: BasePart? = CandyData.Model.PrimaryPart
	if not PrimaryPart then
		return
	end

	local AssetsRoot: Instance = ReplicatedStorage:WaitForChild(ASSETS_ROOT_NAME)
	local ModelsFolder: Instance = AssetsRoot:WaitForChild(AssetsConfig.ModelsFolder)
	local Template: Instance? = ModelsFolder:FindFirstChild(AssetsConfig.LevelBarName)
	if not Template then
		return
	end

	local Clone: Instance = Template:Clone()
	local Billboard: BillboardGui? = nil
	if Clone:IsA("BillboardGui") then
		Billboard = Clone
	else
		Billboard = Clone:FindFirstChildWhichIsA("BillboardGui", true)
	end
	if not Billboard then
		return
	end

	Billboard.MaxDistance = 30

	local BaseSize: UDim2 = Billboard.Size
	local BaseOffset: Vector3 = Billboard.StudsOffset

	Clone.Parent = PrimaryPart

	local LevelLabel: TextLabel? = nil
	local LevelCandidate: Instance? = Billboard:FindFirstChild("Level", true)
	if LevelCandidate and LevelCandidate:IsA("TextLabel") then
		LevelLabel = LevelCandidate
	end

	local XpLabel: TextLabel? = nil
	local BarFrame: GuiObject? = nil
	local BarContainer: GuiObject? = nil

	local DirectBar: Instance? = Billboard:FindFirstChild("Bar")
	if DirectBar and DirectBar:IsA("GuiObject") then
		BarContainer = DirectBar
		local Inner: Instance? = DirectBar:FindFirstChild("Bar")
		if Inner and Inner:IsA("GuiObject") then
			BarFrame = Inner
		else
			BarFrame = DirectBar
		end
		local XpCandidate: Instance? = DirectBar:FindFirstChild("XP", true)
		if XpCandidate and XpCandidate:IsA("TextLabel") then
			XpLabel = XpCandidate
		end
	end

	if not BarFrame then
		for _, Descendant: Instance in Billboard:GetDescendants() do
			if Descendant:IsA("GuiObject") and Descendant.Name == "Bar" then
				local Parent: Instance? = Descendant.Parent
				if Parent and Parent:IsA("GuiObject") and Parent.Name == "Bar" then
					BarContainer = Parent
					BarFrame = Descendant
					break
				end
			end
		end
	end

	if not BarFrame then
		local BarCandidate: Instance? = Billboard:FindFirstChild("Bar", true)
		if BarCandidate and BarCandidate:IsA("GuiObject") then
			BarContainer = BarCandidate
			local Inner: Instance? = BarCandidate:FindFirstChild("Bar")
			if Inner and Inner:IsA("GuiObject") then
				BarFrame = Inner
			else
				BarFrame = BarCandidate
			end
		end
	end

	if BarContainer then
		local XpCandidate: Instance? = BarContainer:FindFirstChild("XP", true)
		if XpCandidate and XpCandidate:IsA("TextLabel") then
			XpLabel = XpCandidate
		end
	end

	if not XpLabel then
		local XpCandidate: Instance? = Billboard:FindFirstChild("XP", true)
		if XpCandidate and XpCandidate:IsA("TextLabel") then
			XpLabel = XpCandidate
		end
	end

	if BarContainer and BarFrame == BarContainer then
		local Inner: Instance? = BarContainer:FindFirstChild("Bar", true)
		if Inner and Inner:IsA("GuiObject") and Inner ~= BarContainer then
			BarFrame = Inner
		end
	end

	local MutationFrame: Frame? = nil
	local MutationCandidate: Instance? = Billboard:FindFirstChild("Mutations", true)
	if MutationCandidate and MutationCandidate:IsA("Frame") then
		MutationFrame = MutationCandidate
	end
	local MutationTemplate: TextLabel? = nil
	if MutationFrame then
		local Content: Instance? = MutationFrame:FindFirstChild("Content", true)
		if Content and Content:IsA("TextLabel") then
			MutationTemplate = Content
		end
	end

	CandyData.LevelBar = Billboard
	CandyData.LevelLabel = LevelLabel
	CandyData.XpLabel = XpLabel
	CandyData.BarFrame = BarFrame
	CandyData.MutationFrame = MutationFrame
	CandyData.MutationTemplate = MutationTemplate
	CandyData.MutationClones = nil
	if CandyData.MutationTextConnection then
		CandyData.MutationTextConnection:Disconnect()
	end
	CandyData.MutationTextConnection = nil
	CandyData.LevelBarSize = BaseSize
	CandyData.LevelBarOffset = BaseOffset

	_SyncLevelBarLayout(CandyData)
	module._UpdateCandyBillboard(CandyData)
end

local function _StopMutationHighlight(CandyData: CandyVisual): ()
	if CandyData.MutationConnection then
		CandyData.MutationConnection:Disconnect()
	end
	CandyData.MutationConnection = nil
	if CandyData.MutationHighlight then
		CandyData.MutationHighlight.Enabled = false
	end
end

local function _StartRainbowHighlight(CandyData: CandyVisual): ()
	_StopMutationHighlight(CandyData)
	if not CandyData.MutationHighlight then
		return
	end

	CandyData.MutationHighlight.Enabled = true
	CandyData.MutationConnection = RunService.RenderStepped:Connect(function(): ()
		if not CandyData.MutationHighlight then
			return
		end
		local Hue: number = (os.clock() * 0.6) % 1
		local Color: Color3 = Color3.fromHSV(Hue, 1, 1)
		CandyData.MutationHighlight.FillColor = Color
		CandyData.MutationHighlight.OutlineColor = Color
	end)
end

function module._UpdateCandyMutationHighlight(CandyData: CandyVisual): ()
	if not CandyData.Model then
		_StopMutationHighlight(CandyData)
		return
	end

	local MutationValue: string = _GetStringAttribute(CandyData.State.Plot, CandyData.State.Keys.Mutations, EMPTY_STRING)
	local Mutations: { string } = _DecodeMutations(MutationValue)
	if #Mutations == 0 then
		_StopMutationHighlight(CandyData)
		return
	end

	if not CandyData.MutationHighlight then
		local Highlight: Highlight = Instance.new("Highlight")
		Highlight.Adornee = CandyData.Model
		Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		Highlight.FillTransparency = 0.5
		Highlight.OutlineTransparency = 1
		Highlight.Parent = CandyData.Model
		CandyData.MutationHighlight = Highlight
	end

	local BestId: string? = nil
	local BestOrder: number = math.huge
	for _, MutationId: string in Mutations do
		local Visual: any = _MutationVisuals[MutationId]
		if Visual and Visual.Order < BestOrder then
			BestOrder = Visual.Order
			BestId = MutationId
		end
	end

	if not BestId then
		_StopMutationHighlight(CandyData)
		return
	end

	local VisualData: any = _MutationVisuals[BestId]
	if VisualData and VisualData.IsRainbow then
		_StartRainbowHighlight(CandyData)
		return
	end

	_StopMutationHighlight(CandyData)
	if CandyData.MutationHighlight then
		local Color: Color3 = if VisualData and VisualData.Color then VisualData.Color else Color3.fromRGB(255, 255, 255)
		CandyData.MutationHighlight.FillColor = Color
		CandyData.MutationHighlight.OutlineColor = Color
		CandyData.MutationHighlight.Enabled = true
	end
end

module.CandyTools = {}

function module.CandyTools.ClearVisual(CandyData: CandyVisual, KeepModel: boolean?): ()
	if not CandyData.Model then
		return
	end

	if not KeepModel then
		CandyData.Model:Destroy()
	end
	CandyData.Model = nil
	CandyData.Highlight = nil
	if CandyData.MutationConnection then
		CandyData.MutationConnection:Disconnect()
	end
	CandyData.MutationConnection = nil
	CandyData.MutationHighlight = nil
	if CandyData.MutationTextConnection then
		CandyData.MutationTextConnection:Disconnect()
	end
	CandyData.MutationTextConnection = nil
	CandyData.ClickDetector = nil
	if CandyData.LevelBar then
		CandyData.LevelBar:Destroy()
	end
	CandyData.LevelBar = nil
	CandyData.LevelLabel = nil
	CandyData.XpLabel = nil
	CandyData.BarFrame = nil
	CandyData.MutationFrame = nil
	CandyData.MutationTemplate = nil
	CandyData.MutationClones = nil
end

function module.CandyTools.CloneAssetInstance(CandyAsset: Instance): Model?
	if CandyAsset:IsA("Model") then
		return CandyAsset:Clone()
	end

	if CandyAsset:IsA("BasePart") then
		local ModelWrapper: Model = Instance.new("Model")
		ModelWrapper.Name = CandyAsset.Name
		local PartClone: BasePart = CandyAsset:Clone()
		PartClone.Parent = ModelWrapper
		ModelWrapper.PrimaryPart = PartClone
		return ModelWrapper
	end

	if CandyAsset:IsA("Folder") then
		local ChildModel: Model? = CandyAsset:FindFirstChildOfClass("Model")
		if ChildModel then
			return ChildModel:Clone()
		end
		local ChildPart: BasePart? = CandyAsset:FindFirstChildWhichIsA("BasePart")
		if ChildPart then
			local ModelWrapper: Model = Instance.new("Model")
			ModelWrapper.Name = CandyAsset.Name
			local PartClone: BasePart = ChildPart:Clone()
			PartClone.Parent = ModelWrapper
			ModelWrapper.PrimaryPart = PartClone
			return ModelWrapper
		end
	end

	return nil
end

function module.CandyTools.EnsurePrimaryPart(CandyClone: Model): BasePart?
	local PrimaryPart: BasePart? = CandyClone.PrimaryPart
	if PrimaryPart then
		return PrimaryPart
	end

	PrimaryPart = _FindFirstBasePart(CandyClone)
	if PrimaryPart then
		CandyClone.PrimaryPart = PrimaryPart
	end
	return PrimaryPart
end

function module.CandyTools.PrepareClone(CandyClone: Model): ()
	for _, Child: Instance in CandyClone:GetDescendants() do
		if Child:IsA("BillboardGui") then
			Child:Destroy()
		end
	end

	for _, Child: Instance in CandyClone:GetDescendants() do
		if Child:IsA("BasePart") then
			Child.Anchored = true
			Child.CanCollide = false
			Child.CanQuery = false
			Child.CanTouch = false
		end
	end
end

function module.CandyTools.FinalizeSpawn(CandyData: CandyVisual, CandyClone: Model, CandyModelName: string): ()
	CandyClone.Parent = CandyData.Parent
	CandyClone:PivotTo(CandyData.CanPosition.CFrame)

	CandyData.Model = CandyClone
	CandyData.IsRemoving = false
	CandyData.IsBouncing = false
	CandyData.IsSpawning = false
	CandyData.PendingScale = nil
	if CandyData.SpawnConnection then
		CandyData.SpawnConnection:Disconnect()
		CandyData.SpawnConnection = nil
	end

	if DEBUG_ENABLED then
		_Debug(
			"Candy spawned %s at %s (parent=%s)",
			CandyModelName,
			tostring(CandyClone:GetPivot().Position),
			_DescribeInstance(CandyData.Parent)
		)
	end

	local ScaleValue: number = _GetNumberAttribute(CandyData.State.Plot, CandyData.State.Keys.CandyScale, DEFAULT_NUMBER)
	local TargetScale: number = if ScaleValue > 0 then ScaleValue else 1
	_PlayCandySpawn(CandyData, TargetScale)
	_SetupCandyHover(CandyData)
	module._EnsureCandyBillboard(CandyData)

	local FloatData: CandyFloatData = {
		Visual = CandyData,
		BaseCFrame = CandyData.CanPosition.CFrame,
		Phase = _RandomGenerator:NextNumber(0, math.pi * 2),
	}

	_ActiveCandies[CandyData] = FloatData
end

function module._SpawnCandyModel(CandyData: CandyVisual, CandyModelName: string): ()
	local AssetsRoot: Instance = ReplicatedStorage:WaitForChild(ASSETS_ROOT_NAME)
	local AssetsFolder: Instance = AssetsRoot:WaitForChild(CANDIES_FOLDER_NAME)

	local CandyAsset: Instance? = AssetsFolder:FindFirstChild(CandyModelName)
	if not CandyAsset then
		_Debug("Candy asset missing: %s", CandyModelName)
		return
	end

	module.CandyTools.ClearVisual(CandyData, CandyData.IsRemoving)

	local CandyClone: Model? = module.CandyTools.CloneAssetInstance(CandyAsset)

	if not CandyClone then
		_Debug("Candy asset not supported: %s (%s)", CandyModelName, CandyAsset.ClassName)
		return
	end

	local PrimaryPart: BasePart? = module.CandyTools.EnsurePrimaryPart(CandyClone)

	if not PrimaryPart then
		CandyClone:Destroy()
		return
	end

	module.CandyTools.PrepareClone(CandyClone)
	module.CandyTools.FinalizeSpawn(CandyData, CandyClone, CandyModelName)
end

local function _HandleCandyModelChanged(CandyData: CandyVisual): ()
	local ModelName: string = _GetStringAttribute(CandyData.State.Plot, CandyData.State.Keys.CandyModel, EMPTY_STRING)
	if ModelName == EMPTY_STRING then
		if CandyData.Model then
			_AnimateCandyRemove(CandyData)
		end
		return
	end

	module._SpawnCandyModel(CandyData, ModelName)
	module._UpdateCandyMutationHighlight(CandyData)
end

local function _HandleCandyScaleChanged(CandyData: CandyVisual): ()
	local NewScale: number = _GetNumberAttribute(CandyData.State.Plot, CandyData.State.Keys.CandyScale, DEFAULT_NUMBER)
	if NewScale <= 0 then
		return
	end
	_ApplyCandyScale(CandyData, NewScale)
end

local function _EnsureCandyVisualFromState(CandyData: CandyVisual): ()
	if CandyData.Model and not CandyData.IsRemoving then
		return
	end

	local HasCandy: boolean = _GetBoolAttribute(CandyData.State.Plot, CandyData.State.Keys.HasCandy, DEFAULT_BOOL)
	if not HasCandy then
		return
	end

	local ModelName: string = _GetStringAttribute(CandyData.State.Plot, CandyData.State.Keys.CandyModel, EMPTY_STRING)
	if ModelName == EMPTY_STRING then
		return
	end

	module._SpawnCandyModel(CandyData, ModelName)
	module._UpdateCandyMutationHighlight(CandyData)
	module._UpdateCandyBillboard(CandyData)
end

local function _HandleCandyRemove(CandyData: CandyVisual): ()
	_AnimateCandyRemove(CandyData)

	task.delay(0.3, function(): ()
		_EnsureCandyVisualFromState(CandyData)
	end)
end

local function _PlaySoundUp(MainPart: BasePart?): ()
	if not MainPart then
		return
	end

	local SoundInstance: Instance? = MainPart:FindFirstChild("Up")
	if not SoundInstance or not SoundInstance:IsA("Sound") then
		return
	end

	SoundInstance:Play()
end

local function _HandleDropSequence(CandyData: CandyVisual, DropEffectData: DropEffect?, MainPart: BasePart?, DropTime: number): ()
	if not CandyData.Model then
		return
	end
	if not DropEffectData then
		return
	end
	DropEffectData = _EnsureDropEffect(DropEffectData)
	if not DropEffectData then
		return
	end

	local StartCFrame: CFrame = if MainPart then MainPart.CFrame else CandyData.CanPosition.CFrame
	local EndCFrame: CFrame = CandyData.CanPosition.CFrame

	_PlayDropEffect(DropEffectData, StartCFrame, EndCFrame, DropTime, function(): ()
		_PlaySoundUp(MainPart)
		_PlayCandyBounce(CandyData)
	end)
end

local function _BindCandyState(
	Plot: Model,
	GroupId: string,
	SlotId: string,
	Keys: CandyAttributeKeys,
	CanPosition: BasePart,
	Parent: Instance,
	TapId: number?,
	DropEffectData: DropEffect?,
	MainPart: BasePart?,
	DropTime: number,
	AllowInteraction: boolean
): ()
	local CandyData: CandyVisual = {
		State = {
			Plot = Plot,
			GroupId = GroupId,
			SlotId = SlotId,
			Keys = Keys,
		},
		Model = nil,
		CanPosition = CanPosition,
		Parent = Parent,
		Highlight = nil,
		MutationHighlight = nil,
		MutationConnection = nil,
		ClickDetector = nil,
		LevelBar = nil,
		LevelLabel = nil,
		XpLabel = nil,
		BarFrame = nil,
		MutationFrame = nil,
		MutationTemplate = nil,
		MutationClones = nil,
		MutationTextConnection = nil,
		LevelBarSize = nil,
		LevelBarOffset = nil,
		BaseScale = 1,
		IsRemoving = false,
		IsBouncing = false,
		IsSpawning = false,
		OriginalColors = nil,
		PendingScale = nil,
		BounceConnection = nil,
		SpawnConnection = nil,
		MutationKey = nil,
		SlotId = SlotId,
		TapId = TapId,
		AllowInteraction = AllowInteraction,
		AllowAttract = false,
		PickupCooldownUntil = nil,
	}

	_ConnectValueChanged(Plot, Keys.CandyModel, function(): ()
		_HandleCandyModelChanged(CandyData)
	end)

	_ConnectValueChanged(Plot, Keys.CandyScale, function(): ()
		_HandleCandyScaleChanged(CandyData)
	end)
	_ConnectValueChanged(Plot, Keys.CandyLevel, function(): ()
		module._UpdateCandyBillboard(CandyData)
	end)
	_ConnectValueChanged(Plot, Keys.CandyProgress, function(): ()
		module._UpdateCandyBillboard(CandyData)
	end)
	_ConnectValueChanged(Plot, Keys.Mutations, function(): ()
		module._UpdateCandyBillboard(CandyData)
		module._UpdateCandyMutationHighlight(CandyData)
	end)

	_ConnectValueChanged(Plot, Keys.DropSequence, function(): ()
		_HandleDropSequence(CandyData, DropEffectData, MainPart, DropTime)
	end)

	_ConnectValueChanged(Plot, Keys.RemoveSequence, function(): ()
		_HandleCandyRemove(CandyData)
	end)

	_HandleCandyModelChanged(CandyData)
	_HandleCandyScaleChanged(CandyData)
	module._UpdateCandyBillboard(CandyData)
	module._UpdateCandyMutationHighlight(CandyData)
end

local function _CloneDropperModel(
	SlotContainer: Instance,
	ParentContainer: Instance,
	GroupConfig: any,
	AssetName: string,
	SlotPartName: string,
	RotationDegrees: number
): (Model?, BasePart?)
	local AssetsRoot: Instance = ReplicatedStorage:WaitForChild(ASSETS_ROOT_NAME)
	local MachinesFolder: Instance = AssetsRoot:WaitForChild(MACHINES_FOLDER_NAME)
	local AssetsFolder: Instance = MachinesFolder:WaitForChild(GroupConfig.AssetsFolder)

	local Asset: Instance? = AssetsFolder:FindFirstChild(AssetName)
	if not Asset or not Asset:IsA("Model") then
		_Debug("Machine asset missing: %s", AssetName)
		return nil, nil
	end

	local SlotPart: BasePart? = _ResolveSlotPart(SlotContainer, SlotPartName)
	if not SlotPart then
		_Debug("Slot part missing: %s in %s", SlotPartName, _DescribeInstance(SlotContainer))
		_Debug("Slot container children: %s", _DescribeChildren(SlotContainer))
		return nil, nil
	end
	if SlotPart.Name ~= SlotPartName then
		_Debug("Slot part name mismatch. Expected %s, got %s", SlotPartName, SlotPart.Name)
	end
	_Debug("Slot part found: %s at %s", _DescribeInstance(SlotPart), tostring(SlotPart.Position))

	local Clone: Model = Asset:Clone()
	Clone.Parent = ParentContainer

	if not Clone.PrimaryPart then
		local PrimaryPart: BasePart? = _FindFirstBasePart(Clone)
		if PrimaryPart then
			Clone.PrimaryPart = PrimaryPart
		end
	end

	local SlotUp: Vector3 = SlotPart.CFrame.UpVector
	local SlotTop: Vector3 = SlotPart.Position + (SlotUp * (SlotPart.Size.Y * 0.5))

	if RotationDegrees ~= 0 then
		local Pivot: CFrame = Clone:GetPivot()
		local Rotation: CFrame = CFrame.fromAxisAngle(SlotUp, math.rad(RotationDegrees))
		local Rotated: CFrame = CFrame.new(Pivot.Position) * Rotation * (Pivot - Pivot.Position)
		Clone:PivotTo(Rotated)
	end

	local BboxCFrame: CFrame, BboxSize: Vector3 = Clone:GetBoundingBox()
	local Center: Vector3 = BboxCFrame.Position
	local ToSlot: Vector3 = SlotPart.Position - Center
	local VerticalComponent: Vector3 = SlotUp * ToSlot:Dot(SlotUp)
	local HorizontalOffset: Vector3 = ToSlot - VerticalComponent

	local HalfSize: Vector3 = BboxSize * 0.5
	local Right: Vector3 = BboxCFrame.RightVector
	local Up: Vector3 = BboxCFrame.UpVector
	local Look: Vector3 = BboxCFrame.LookVector
	local ExtentAlongUp: number = math.abs(SlotUp:Dot(Right)) * HalfSize.X
		+ math.abs(SlotUp:Dot(Up)) * HalfSize.Y
		+ math.abs(SlotUp:Dot(Look)) * HalfSize.Z

	local MinDot: number = Center:Dot(SlotUp) - ExtentAlongUp
	local TargetDot: number = SlotTop:Dot(SlotUp)
	local VerticalOffset: Vector3 = SlotUp * (TargetDot - MinDot)
	local TotalOffset: Vector3 = HorizontalOffset + VerticalOffset

	Clone:PivotTo(Clone:GetPivot() + TotalOffset)

	_Debug(
		"Cloned %s in %s at %s (slot part: %s)",
		AssetName,
		_DescribeInstance(ParentContainer),
		tostring(Clone:GetPivot().Position),
		_DescribeInstance(SlotPart)
	)
	_Debug("Dropper offset applied: %s (horizontal=%s vertical=%s)", tostring(TotalOffset), tostring(HorizontalOffset), tostring(VerticalOffset))

	return Clone, SlotPart
end

local function _SetupDropperVisual(
	Plot: Model,
	GroupId: string,
	GroupConfig: any,
	SlotContainer: Instance,
	ParentContainer: Instance,
	SlotId: string,
	SlotConfig: any,
	RotationDegrees: number,
	IsLocalOwner: boolean
): DropperVisual?
	local Clone: Model?
	local SlotPart: BasePart?
	Clone, SlotPart = _CloneDropperModel(SlotContainer, ParentContainer, GroupConfig, SlotConfig.AssetName, SlotConfig.SlotPartName, RotationDegrees)
	if not Clone then
		return nil
	end

	local MainPart: BasePart? = nil
	if SlotConfig.UseMainPart then
		MainPart = _FindDescendant(Clone, MAIN_PART_NAME) :: BasePart?
	end
	local ButtonPart: BasePart? = _FindDescendant(Clone, BUTTON_PART_NAME) :: BasePart?
	if SlotConfig.UseMainPart and not MainPart then
		_Debug("Main part missing in %s", Clone.Name)
	end

	local BaseScale: number = Clone:GetScale()

	local DropperData: DropperVisual = {
		Model = Clone,
		Plot = Plot,
		GroupId = GroupId,
		SlotId = SlotId,
		Type = SlotConfig.Type,
		Config = SlotConfig,
		MainPart = MainPart,
		ButtonPart = ButtonPart,
		CanPosition = nil,
		HoverDetector = nil,
		Highlight = nil,
		HoverTween = nil,
		BaseScale = BaseScale,
		DropEffect = nil,
		Taps = nil,
		HasCandy = false,
		IsHovering = false,
		HoverColor = DROPPER_HIGHLIGHT_COLOR,
		SlotPart = SlotPart,
		IsLocalOwner = IsLocalOwner,
		PreviewModel = nil,
		PreviewName = nil,
	}

	_EnsureDropperHighlight(DropperData)

	return DropperData
end

local _GroupModules: { [string]: any } = {
	Droppers = DroppersModule,
	Sprinklers = SprinklersModule,
}

local _MachineApi = {
	Debug = _Debug,
	DescribeChildren = _DescribeChildren,
	FindDescendant = _FindDescendant,
	FindHitbox = _FindHitbox,
	SetQueryMask = _SetQueryMask,
	EnsureDropperHighlight = _EnsureDropperHighlight,
	SetActiveHoverTap = function(TapData: any, DropperData: any): ()
		DroppersModule.SetActiveHoverTap(_MachineApi, TapData, DropperData)
	end,
	SetActiveHoverDropper = function(DropperData: any): ()
		DroppersModule.SetActiveHoverDropper(_MachineApi, DropperData)
	end,
	ClearActiveHoverTap = function(TapData: any): ()
		DroppersModule.ClearActiveHoverTap(_MachineApi, TapData)
	end,
	ClearActiveHoverDropper = function(DropperData: any): ()
		DroppersModule.ClearActiveHoverDropper(_MachineApi, DropperData)
	end,
	SetDropperHover = _SetDropperHover,
	ClearDropperPreview = _ClearDropperPreview,
	ShowDropperPreview = _ShowDropperPreview,
	ClearTapPreview = _ClearTapPreview,
	ShowTapPreview = _ShowTapPreview,
	ClearOtherPreviews = _ClearOtherPreviews,
	GetEquippedTool = _GetEquippedTool,
	GetCandyNameFromTool = _GetCandyNameFromTool,
	FlashDropper = _FlashDropper,
	PlayDropperClickScale = _PlayDropperClickScale,
	GetReturnScale = _GetReturnScale,
	BuildCandyAttributeKeys = _BuildCandyAttributeKeys,
	BindCandyState = _BindCandyState,
	GetStringAttribute = _GetStringAttribute,
	GetNumberAttribute = _GetNumberAttribute,
	GetValueChangedSignal = _GetValueChangedSignal,
	CreateDropEffect = _CreateDropEffect,
	IsButtonOnCooldown = _IsButtonOnCooldown,
	SetButtonHighlightState = _SetButtonHighlightState,
	TweenButtonSize = _TweenButtonSize,
	PlayButtonClick = _PlayButtonClick,
	GetCandyMaxLevelForBillboard = _GetCandyMaxLevelForBillboard,
	TweenModule = TweenModule,
	Timing = TimingConfig,
	Packets = Packets,
	ActionPlace = ACTION_PLACE_CANDY,
	ActionRemove = ACTION_REMOVE_CANDY,
	ActionDrop = ACTION_DROP,
	EmptyString = EMPTY_STRING,
	CanPositionName = CAN_POSITION_NAME,
	MainPartName = MAIN_PART_NAME,
	TapName = TAP_NAME,
	HitboxPartName = HITBOX_PART_NAME,
	ButtonPartName = BUTTON_PART_NAME,
	MaxActivationDistance = 1000,
	DropperHighlightColor = DROPPER_HIGHLIGHT_COLOR,
	DropperPlaceColor = DROPPER_PLACE_COLOR,
	DropperRemoveColor = DROPPER_REMOVE_COLOR,
	ClickShrinkScale = 0.92,
	ClickBounceScale = 0.08,
	ButtonBaseSize = BUTTON_BASE_SIZE,
	ButtonHoverScale = BUTTON_HOVER_SCALE,
	ButtonHoverTime = BUTTON_HOVER_TIME,
	ButtonClickScale = BUTTON_CLICK_SCALE,
	ButtonReadyColor = BUTTON_READY_COLOR,
	ButtonCooldownColor = BUTTON_COOLDOWN_COLOR,
	HologramEnabled = HOLOGRAM_ENABLED,
	DebugHover = DEBUG_HOVER,
	CursorIcon = "rbxassetid://96499340217478",
}

local function _SetupPlotVisual(Plot: Model): ()
	if _PlotVisuals[Plot] then
		return
	end
	if not _HasPlotOwner(Plot) then
		_WatchPlotOwner(Plot)
		return
	end

	_WaitForMemorieMachinesFolder(Plot)

	local IsLocalOwner: boolean = _IsPlotOwnedByLocalPlayer(Plot)
	local PlotData: PlotVisual = {
		Plot = Plot,
		Groups = {},
	}

	for GroupId: string, GroupConfig: any in MachinesConfig do
		local GroupFolder: Instance? = Plot:FindFirstChild(GroupConfig.PlotFolder)
		if not GroupFolder then
			_Debug("%s folder missing in plot %s", GroupConfig.PlotFolder, Plot.Name)
			continue
		end

		local GroupVisual = {
			Folder = GroupFolder,
			Slots = {},
		}

		for SlotId: string, SlotConfig: any in GroupConfig.Slots do
			local SlotFolder: Instance? = _FindSlotContainer(GroupFolder, SlotId, SlotConfig.SlotPartName)
			if not SlotFolder then
				continue
			end

			local ParentContainer: Instance = _ResolveSlotParent(SlotFolder, GroupFolder)
			local Rotation: number = _GetPlotRotation(Plot, SlotId, SlotConfig.RotationDefault)
			local SlotVisual: DropperVisual? = _SetupDropperVisual(
				Plot,
				GroupId,
				GroupConfig,
				SlotFolder,
				ParentContainer,
				SlotId,
				SlotConfig,
				Rotation,
				IsLocalOwner
			)

			if SlotVisual then
				GroupVisual.Slots[SlotId] = SlotVisual
				local Handler: any = _GroupModules[GroupId]
				if Handler and Handler.SetupSlot then
					Handler.SetupSlot(_MachineApi, SlotVisual, ParentContainer)
				end
			else
				_WatchSlotPart(SlotFolder, SlotConfig.SlotPartName, function(): ()
					if GroupVisual.Slots[SlotId] then
						return
					end
					local RetryVisual: DropperVisual? = _SetupDropperVisual(
						Plot,
						GroupId,
						GroupConfig,
						SlotFolder,
						ParentContainer,
						SlotId,
						SlotConfig,
						Rotation,
						IsLocalOwner
					)
					if RetryVisual then
						GroupVisual.Slots[SlotId] = RetryVisual
						local RetryHandler: any = _GroupModules[GroupId]
						if RetryHandler and RetryHandler.SetupSlot then
							RetryHandler.SetupSlot(_MachineApi, RetryVisual, ParentContainer)
						end
					end
				end)
			end
		end

		UpgradesModule.SetupBoard(Plot, GroupId, GroupConfig, GroupFolder, IsLocalOwner)
		PlotData.Groups[GroupId] = GroupVisual
	end

	_PlotVisuals[Plot] = PlotData
end

local function _UpdateCandyFloat(DeltaTime: number): ()
	local Camera: Camera? = workspace.CurrentCamera
	if not Camera then
		return
	end

	for CandyData: CandyVisual, FloatData: CandyFloatData in _ActiveCandies do
		if not CandyData.Model then
			_ActiveCandies[CandyData] = nil
			continue
		end
		FloatData.BaseCFrame = CandyData.CanPosition.CFrame

		local Time: number = os.clock()
		local FloatOffset: number = math.sin(Time * VisualConfig.FloatSpeed + FloatData.Phase) * VisualConfig.FloatAmplitude
		local TargetCFrame: CFrame = FloatData.BaseCFrame * CFrame.new(0, FloatOffset, 0)

		if CandyData.AllowAttract then
			local NearestRoot: BasePart? = nil
			local NearestDistance: number = VisualConfig.AttractDistance + 1

			for _, PlayerInstance: Player in Players:GetPlayers() do
				local Character: Model? = PlayerInstance.Character
				if Character then
					local RootPart: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if RootPart then
						local Distance: number = (RootPart.Position - TargetCFrame.Position).Magnitude
						if Distance < NearestDistance then
							NearestDistance = Distance
							NearestRoot = RootPart
						end
					end
				end
			end

			if NearestRoot and NearestDistance <= VisualConfig.AttractDistance then
				local Direction: Vector3 = (NearestRoot.Position - TargetCFrame.Position)
				if Direction.Magnitude > 0 then
					local MoveDistance: number = math.min(VisualConfig.AttractSpeed * DeltaTime, NearestDistance)
					local MoveOffset: Vector3 = Direction.Unit * MoveDistance
					TargetCFrame = TargetCFrame + MoveOffset
				end
			end
		end

		CandyData.Model:PivotTo(TargetCFrame)
	end
end

local function _AttachToolWatchers(Character: Model): ()
	if _ToolAddedConnection then
		_ToolAddedConnection:Disconnect()
		_ToolAddedConnection = nil
	end
	if _ToolRemovedConnection then
		_ToolRemovedConnection:Disconnect()
		_ToolRemovedConnection = nil
	end

	_ToolAddedConnection = Character.ChildAdded:Connect(function(Child: Instance): ()
		if Child:IsA("Tool") then
			DroppersModule.RefreshHoverPreview(_MachineApi)
		end
	end)

	_ToolRemovedConnection = Character.ChildRemoved:Connect(function(Child: Instance): ()
		if Child:IsA("Tool") then
			DroppersModule.RefreshHoverPreview(_MachineApi)
		end
	end)
end

--\\ PUBLIC FUNCTIONS \\ -- TR
function module:Init(): ()
	UpgradesModule.Init({
		Short = Short,
		TweenService = TweenService,
		TweenModule = TweenModule,
		Packets = Packets,
		ActionUpgradeLevel = ACTION_UPGRADE_LEVEL,
		ActionUpgradeLevelMax = ACTION_UPGRADE_LEVEL_MAX,
		ActionUpgradeSpecial = ACTION_UPGRADE_SPECIAL,
		MaxUpgradeLevel = 100,
		GetCoins = _GetLocalCoins,
		GetUpgradeKey = _GetUpgradeKey,
		GetNumberAttribute = _GetNumberAttribute,
		ConnectValueChanged = _ConnectValueChanged,
		DescribeChildren = _DescribeChildren,
		TweenButtonSize = _TweenButtonSize,
		DefaultNumber = DEFAULT_NUMBER,
	})

	_BindCoinsWatcher()

	_PreloadAssets()
	local Player: Player? = Players.LocalPlayer
	if Player then
		if Player.Character then
			_AttachToolWatchers(Player.Character)
		end
		Player.CharacterAdded:Connect(function(Character: Model): ()
			_AttachToolWatchers(Character)
		end)
	end

	Packets.Machines.OnClientEvent:Connect(function(Action: string, Data: any): ()
		if Action ~= "UpgradeResult" then
			return
		end
		UpgradesModule.HandleUpgradeResult(Data)
	end)

	task.spawn(function(): ()
		local MapInstance: Instance = workspace:WaitForChild("Map")
		if not (MapInstance:IsA("Folder") or MapInstance:IsA("Model")) then
			return
		end

		local PlotsInstance: Instance = MapInstance:WaitForChild("Plots")
		if not (PlotsInstance:IsA("Folder") or PlotsInstance:IsA("Model")) then
			return
		end

		for _, Plot: Instance in PlotsInstance:GetChildren() do
			if Plot:IsA("Model") then
				_SetupPlotVisual(Plot)
			end
		end

		PlotsInstance.ChildAdded:Connect(function(Child: Instance): ()
			if Child:IsA("Model") then
				_SetupPlotVisual(Child)
			end
		end)
	end)
end

function module:Start(): ()
	RunService.RenderStepped:Connect(function(DeltaTime: number): ()
		_UpdateCandyFloat(DeltaTime)
	end)
end

return module



