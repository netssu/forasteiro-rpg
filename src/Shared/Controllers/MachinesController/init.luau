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
local DoubleDroppersModule: any = require(script.DoubleDroppers)
local UpgradesModule: any = require(script.Upgrades)

--\\ TYPES \\ -- TR
type DropEffect = {
	Part: Part,
	EffectAttachment: Attachment?,
	PrimeAttachment: Attachment?,
	Tween: Tween?,
}

type CandyAttributeKeys = {
	CandyModel: string,
	CandyLevel: string,
	CandyProgress: string,
	CandyScale: string,
	HasCandy: string,
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

type TextLike = TextLabel | TextButton | TextBox

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
	LevelLabel: TextLike?,
	XpLabel: TextLike?,
	BarFrame: GuiObject?,
	MutationFrame: Frame?,
	MutationTemplate: TextLabel?,
	MutationClones: { TextLabel }?,
	MutationTextConnection: RBXScriptConnection?,
	LevelBarSize: UDim2?,
	LevelBarOffset: Vector3?,
	LevelBarBaseScale: number?,
	BaseScale: number,
	IsRemoving: boolean,
	IsBouncing: boolean,
	IsSpawning: boolean,
	OriginalColors: { [BasePart]: Color3 }?,
	PendingScale: number?,
	BounceConnection: RBXScriptConnection?,
	SpawnConnection: RBXScriptConnection?,
	MutationKey: string?,
	BillboardUpdatePending: boolean?,
	SkipSpawnTween: boolean?,
	PendingBillboard: boolean?,
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
DoubleDroppersModule.Register(MachinesConfig, AllMachinesConfig)
local VisualConfig: any = Constants.Visual
local TimingConfig: any = Constants.Timing
local AssetsConfig: any = Constants.Assets
local CandyConfig: any = Constants.Candy
local MutationConfig: any = Constants.Mutation

local EMPTY_STRING: string = ""
local ASSETS_ROOT_NAME: string = AssetsConfig.RootFolder
local MACHINES_FOLDER_NAME: string = AssetsConfig.MachinesFolder
local CANDIES_FOLDER_NAME: string = AssetsConfig.CandiesFolder
local CAN_POSITION_NAME: string = "CanPosition"
local MAIN_PART_NAME: string = "Main"
local BUTTON_PART_NAME: string = "Button"
local TAP_NAME: string = "Tap"
local HITBOX_PART_NAME: string = "Hitbox"
local OWNER_ATTRIBUTE_NAME: string = "Owner"
local CLIENT_HIDDEN_ATTRIBUTE: string = "ClientHidden"
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

local Attr = {
	Prefix = "Machine",
	TapPrefix = "Tap",
	FormatNormal = "%s_%s_%s_%s",
	FormatTap = "%s_%s_%s_%s%d_%s",
	CandyModel = "CandyModel",
	CandyLevel = "CandyLevel",
	CandyProgress = "CandyProgress",
	CandyScale = "CandyScale",
	HasCandy = "HasCandy",
	DropSequence = "DropSequence",
	RemoveSequence = "RemoveSequence",
	Mutations = "Mutations",
	UpgradeLevel = "UpgradeLevel",
	UpgradePrefix = "Upgrade",
}

local MemorieNames = {
	Root = "Memorie",
	Plots = "Plots",
	Machines = "Machines",
}
local MEMORIE_SCALE_FACTOR: number = 1000
local DROP_EFFECT_CLEANUP_DELAY: number = 1.0

local DEFAULT_NUMBER: number = 0
local DEFAULT_BOOL: boolean = false
local LEGACY_CANDY_MODEL: string = "Candy"

local Actions = {
	PlaceCandy = "PlaceCandy",
	Drop = "Drop",
	RemoveCandy = "RemoveCandy",
	UpgradeLevel = "UpgradeLevel",
	UpgradeLevelMax = "UpgradeLevelMax",
	UpgradeSpecial = "UpgradeSpecial",
	BuyMachine = "BuyMachine",
	DoubleDropperStart = "DoubleDropperStart",
}

local LEVELBAR_MAX_DISTANCE: number = 100
local CANDY_GROUND_EPSILON: number = 0.01


local DebugFlags = {
	Enabled = false,
	Hover = false,
	Hologram = false,
}

--\\ STATE \\ -- TR
local _PlotVisuals: { [Model]: PlotVisual } = {}
local _ActiveCandies: { [CandyVisual]: CandyFloatData } = {}
local _RandomGenerator: Random = Random.new()
local _SlotWatchers: { [Instance]: RBXScriptConnection } = {}
local _HologramTweens: { [Model]: RBXScriptConnection } = {}
local _PlotOwnerWatchers: { [Model]: RBXScriptConnection } = {}
local _PlotGroupWatchers: { [Model]: { [string]: RBXScriptConnection } } = {}
local _ButtonTweens: { [BasePart]: Tween } = {}
local _ButtonCooldownUntil: { [BasePart]: number } = {}
local _ActiveDropEffects: { [DropEffect]: boolean } = {}
local _PurchasedSlotWatchers: { [string]: RBXScriptConnection } = {}
local _TryBindBuyButton: ((Instance) -> ())? = nil
local _BindBuyButtonsInPlot: ((Model) -> ())? = nil
local _RefreshAllBuyModels: (() -> ())? = nil
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
	if not DebugFlags.Enabled then
		return
	end

	local Output: string = string.format(Message, ...)
	print("[DropperDebug]", Output)
end

local function _NormalizeCandyModelName(ModelName: string): string
	if ModelName == LEGACY_CANDY_MODEL then
		return CandyConfig.DefaultModel
	end
	return ModelName
end

local function _EnsureCandyAboveGround(CandyData: CandyVisual): ()
	if not CandyData.Model then
		return
	end

	local BaseY: number = CandyData.CanPosition.Position.Y
	local RayOrigin: Vector3 = CandyData.CanPosition.Position + Vector3.new(0, 10, 0)
	local RayDirection: Vector3 = Vector3.new(0, -200, 0)
	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = { CandyData.Model }
	local Result: RaycastResult? = workspace:Raycast(RayOrigin, RayDirection, RaycastParams)
	local GroundY: number? = if Result then Result.Position.Y else nil
	local BoundsCFrame: CFrame, BoundsSize: Vector3 = CandyData.Model:GetBoundingBox()
	local MinY: number = BoundsCFrame.Position.Y - (BoundsSize.Y * 0.5)
	local TargetMinY: number = BaseY
	if GroundY and GroundY > TargetMinY then
		TargetMinY = GroundY
	end
	if MinY < TargetMinY then
		local Offset: number = (TargetMinY - MinY) + CANDY_GROUND_EPSILON
		local Pivot: CFrame = CandyData.Model:GetPivot()
		CandyData.Model:PivotTo(Pivot + Vector3.new(0, Offset, 0))
	end
end

local function _ClearCandyLevelBar(CandyData: CandyVisual): ()
	if CandyData.MutationTextConnection then
		CandyData.MutationTextConnection:Disconnect()
	end
	CandyData.MutationTextConnection = nil

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
	CandyData.LevelBarBaseScale = nil
	CandyData.BillboardUpdatePending = nil
	CandyData.PendingBillboard = nil
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

local function _AsTextLike(Value: Instance?): TextLike?
	if Value and (Value:IsA("TextLabel") or Value:IsA("TextButton") or Value:IsA("TextBox")) then
		return Value :: TextLike
	end
	return nil
end

local function _ScheduleCandyBillboardUpdate(CandyData: CandyVisual): ()
	if CandyData.BillboardUpdatePending then
		return
	end
	CandyData.BillboardUpdatePending = true
	task.defer(function(): ()
		CandyData.BillboardUpdatePending = nil
		if CandyData.IsRemoving then
			return
		end
		module._UpdateCandyBillboard(CandyData)
	end)
end


local function _GetMemorieMachinesFolder(Plot: Model): Folder?
	local Cached: Folder? = _MemorieMachinesFolders[Plot]
	if Cached and Cached.Parent then
		return Cached
	end

	local Root: Instance? = ReplicatedStorage:FindFirstChild(MemorieNames.Root)
	if not Root or not Root:IsA("Folder") then
		return nil
	end

	local PlotsFolder: Instance? = Root:FindFirstChild(MemorieNames.Plots)
	if not PlotsFolder or not PlotsFolder:IsA("Folder") then
		return nil
	end

	local PlotFolder: Instance? = PlotsFolder:FindFirstChild(Plot.Name)
	if not PlotFolder or not PlotFolder:IsA("Folder") then
		return nil
	end

	local MachinesFolder: Instance? = PlotFolder:FindFirstChild(MemorieNames.Machines)
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

	local Root: Instance = ReplicatedStorage:WaitForChild(MemorieNames.Root)
	if not Root:IsA("Folder") then
		return nil
	end

	local PlotsFolder: Instance = Root:WaitForChild(MemorieNames.Plots)
	if not PlotsFolder:IsA("Folder") then
		return nil
	end

	local PlotFolder: Instance = PlotsFolder:WaitForChild(Plot.Name)
	if not PlotFolder:IsA("Folder") then
		return nil
	end

	local MachinesFolder: Instance = PlotFolder:WaitForChild(MemorieNames.Machines)
	if MachinesFolder:IsA("Folder") then
		_MemorieMachinesFolders[Plot] = MachinesFolder
		return MachinesFolder
	end

	return nil
end

local function _IsScaledKey(Key: string): boolean
	return string.sub(Key, -#Attr.CandyScale) == Attr.CandyScale
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
		"^" .. Attr.Prefix .. "_([^_]+)_([^_]+)_" .. Attr.TapPrefix .. "(%d+)_(.+)$"
	)
	if GroupId and SlotId and TapIdValue and KeyName then
		TapId = tonumber(TapIdValue)
	else
		GroupId, SlotId, KeyName = string.match(Key, "^" .. Attr.Prefix .. "_([^_]+)_([^_]+)_(.+)$")
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
			if string.sub(KeyName, 1, #Attr.UpgradePrefix) == Attr.UpgradePrefix then
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
	elseif DebugFlags.Enabled then
		_Debug("Memorie value missing for key %s", Key)
	end
end

local function _PreloadAssets(): ()
	task.spawn(function(): ()
		local Success: boolean, ErrorMessage: string? = pcall(function(): ()
			ContentProvider:PreloadAsync({ "rbxassetid://284205403" })
		end)
		if not Success and DebugFlags.Enabled then
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

local function _GetPlotIndex(Plot: Model): number?
	local AttributeIndex: any = Plot:GetAttribute("PlotIndex")
	if typeof(AttributeIndex) == "number" and AttributeIndex >= 1 then
		return math.floor(AttributeIndex + 0.5)
	end

	local Digits: string? = string.match(Plot.Name, "%d+")
	if Digits then
		local Parsed: number? = tonumber(Digits)
		if Parsed and Parsed >= 1 then
			return math.floor(Parsed + 0.5)
		end
	end

	return nil
end

local function _GetSlotRotation(Plot: Model, SlotConfig: any): number
	local Rotation: number = if typeof(SlotConfig) == "table" and typeof(SlotConfig.RotationDefault) == "number"
		then SlotConfig.RotationDefault
		else 0
	local UseByPlot: any = if typeof(SlotConfig) == "table" then SlotConfig.UseRotationByPlot else nil
	local ByPlot: any = if typeof(SlotConfig) == "table" then SlotConfig.RotationByPlot else nil
	if UseByPlot == true and typeof(ByPlot) == "table" then
		local Index: number? = _GetPlotIndex(Plot)
		if Index then
			local Value: any = ByPlot[Index]
			if typeof(Value) == "number" then
				Rotation = Value
			end
		end
	end
	local Offset: number = if typeof(SlotConfig) == "table" and typeof(SlotConfig.ModelRotationOffset) == "number"
		then SlotConfig.ModelRotationOffset
		else 0
	return Rotation + Offset
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
		if _RefreshAllBuyModels then
			_RefreshAllBuyModels()
		end
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
	local Normalized: string = _NormalizeCandyModelName(ModelName)
	if Normalized ~= EMPTY_STRING then
		local Evolution: any = CandyConfig.Evolutions[Normalized]
		if Evolution and typeof(Evolution.MaxLevel) == "number" and Evolution.MaxLevel > 0 then
			return Evolution.MaxLevel
		end
	end
	return 5
end

local function _GetEvolutionLimitForBillboard(ModelName: string, Level: number): number
	local Normalized: string = _NormalizeCandyModelName(ModelName)
	if Normalized == EMPTY_STRING then
		return 1
	end

	local Evolution: any = CandyConfig.Evolutions[Normalized]
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

local function _SlotContainerMatchesSlot(GroupFolder: Instance, Container: Instance, SlotId: string): boolean
	local NormalizedSlot: string = _NormalizeName(SlotId)
	if NormalizedSlot == "" then
		return false
	end
	local NormalizedKey: string = _NormalizeName("slot" .. SlotId)

	local Current: Instance? = Container
	while Current and Current ~= GroupFolder do
		local Normalized: string = _NormalizeName(Current.Name)
		if Normalized == NormalizedSlot or Normalized == NormalizedKey then
			return true
		end
		if string.find(Normalized, NormalizedSlot, 1, true) then
			return true
		end
		Current = Current.Parent
	end
	return false
end

local function _IsSlotPartShared(GroupConfig: any, SlotPartName: string): boolean
	local Count: number = 0
	for _, SlotConfig: any in GroupConfig.Slots do
		if SlotConfig.SlotPartName == SlotPartName then
			Count += 1
			if Count > 1 then
				return true
			end
		end
	end
	return false
end

local function _FindSlotContainer(
	GroupFolder: Instance,
	SlotId: string,
	SlotPartName: string,
	RequireSlotMatch: boolean?
): Instance?
	local Direct: Instance? = GroupFolder:FindFirstChild(SlotId)
	if Direct then
		if not RequireSlotMatch or _SlotContainerMatchesSlot(GroupFolder, Direct, SlotId) then
			return Direct
		end
	end

	local NormalizedSlot: string = _NormalizeName(SlotId)
	local NormalizedKey: string = _NormalizeName("slot" .. SlotId)
	local BestCandidate: Instance? = nil
	for _, Descendant: Instance in GroupFolder:GetDescendants() do
		if Descendant:IsA("Model") or Descendant:IsA("Folder") or Descendant:IsA("BasePart") then
			local Normalized: string = _NormalizeName(Descendant.Name)
			local Matches = Normalized ~= "" and (Normalized == NormalizedSlot or Normalized == NormalizedKey)
			if not Matches and NormalizedSlot ~= "" then
				if string.find(Normalized, NormalizedSlot, 1, true) and string.find(Normalized, "slot", 1, true) then
					Matches = true
				end
			end
			if Matches then
				if SlotPartName ~= "" and Descendant:FindFirstChild(SlotPartName, true) then
					if not RequireSlotMatch or _SlotContainerMatchesSlot(GroupFolder, Descendant, SlotId) then
						return Descendant
					end
				end
				if not BestCandidate and (not RequireSlotMatch or _SlotContainerMatchesSlot(GroupFolder, Descendant, SlotId)) then
					BestCandidate = Descendant
				end
			end
		end
	end
	if BestCandidate then
		return BestCandidate
	end

	if RequireSlotMatch then
		for _, Descendant: Instance in GroupFolder:GetDescendants() do
			if Descendant:IsA("BasePart") and _NormalizeName(Descendant.Name) == _NormalizeName(SlotPartName) then
				local ParentContainer: Instance = Descendant.Parent or GroupFolder
				if _SlotContainerMatchesSlot(GroupFolder, ParentContainer, SlotId) then
					return ParentContainer
				end
			end
		end
		return nil
	end

	local PartDirect: Instance? = GroupFolder:FindFirstChild(SlotPartName)
	if PartDirect then
		return PartDirect
	end

	local PartDeep: Instance? = GroupFolder:FindFirstChild(SlotPartName, true)
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
	local BestMatch: BasePart? = nil
	local BestScore: number = math.huge
	for _, Descendant: Instance in SlotContainer:GetDescendants() do
		if Descendant:IsA("BasePart") then
			local Normalized: string = string.lower((Descendant.Name:gsub("[%s_%-]", "")))
			if Normalized == TargetName then
				return Descendant
			end
			if TargetName ~= "" and string.find(Normalized, TargetName, 1, true) then
				local Score: number = #Normalized
				if Score < BestScore then
					BestScore = Score
					BestMatch = Descendant
				end
			end
		end
	end
	if BestMatch then
		return BestMatch
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

local function _ShouldUsePartForPlacement(Part: BasePart): boolean
	local Normalized: string = _NormalizeName(Part.Name)
	if string.find(Normalized, "hitbox", 1, true) then
		return false
	end
	if Part.Transparency >= 1 and not Part.CanCollide and not Part.CanQuery and not Part.CanTouch then
		return false
	end
	return true
end

local function _GetModelMinDot(Model: Model, SlotUp: Vector3, UsePrimaryPart: boolean?): number?
	local function GetPartMinDot(Part: BasePart): number
		local Half: Vector3 = Part.Size * 0.5
		local Right: Vector3 = Part.CFrame.RightVector
		local Up: Vector3 = Part.CFrame.UpVector
		local Look: Vector3 = Part.CFrame.LookVector
		local Extent: number = math.abs(SlotUp:Dot(Right)) * Half.X
			+ math.abs(SlotUp:Dot(Up)) * Half.Y
			+ math.abs(SlotUp:Dot(Look)) * Half.Z
		return Part.Position:Dot(SlotUp) - Extent
	end

	if UsePrimaryPart and Model.PrimaryPart then
		return GetPartMinDot(Model.PrimaryPart)
	end
	local Best: number? = nil
	for _, Descendant: Instance in Model:GetDescendants() do
		if Descendant:IsA("BasePart") and _ShouldUsePartForPlacement(Descendant) then
			local MinDot: number = GetPartMinDot(Descendant)
			if not Best or MinDot < Best then
				Best = MinDot
			end
		end
	end
	return Best
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
		return string.format(Attr.FormatTap, Attr.Prefix, GroupId, SlotId, Attr.TapPrefix, TapId, KeyName)
	end
	return string.format(Attr.FormatNormal, Attr.Prefix, GroupId, SlotId, KeyName)
end

local function _BuildCandyAttributeKeys(GroupId: string, SlotId: string, TapId: number?): CandyAttributeKeys
	return {
		CandyModel = _GetAttributeKey(GroupId, SlotId, TapId, Attr.CandyModel),
		CandyLevel = _GetAttributeKey(GroupId, SlotId, TapId, Attr.CandyLevel),
		CandyProgress = _GetAttributeKey(GroupId, SlotId, TapId, Attr.CandyProgress),
		CandyScale = _GetAttributeKey(GroupId, SlotId, TapId, Attr.CandyScale),
		HasCandy = _GetAttributeKey(GroupId, SlotId, TapId, Attr.HasCandy),
		DropSequence = _GetAttributeKey(GroupId, SlotId, TapId, Attr.DropSequence),
		RemoveSequence = _GetAttributeKey(GroupId, SlotId, TapId, Attr.RemoveSequence),
		Mutations = _GetAttributeKey(GroupId, SlotId, TapId, Attr.Mutations),
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

local function _GetBoolAttribute(Plot: Model, Key: string, Default: boolean): boolean
	local ValueObject: ValueBase? = _WaitForValueObject(Plot, Key)
	if ValueObject and ValueObject:IsA("IntValue") then
		return ValueObject.Value ~= 0
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
		return string.format(Attr.FormatNormal, Attr.Prefix, GroupId, SlotId, Attr.UpgradeLevel)
	end
	return string.format(Attr.FormatNormal, Attr.Prefix, GroupId, SlotId, Attr.UpgradePrefix .. UpgradeId)
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
		local Normalized: string = _NormalizeCandyModelName(AttributeModel)
		if _HasCandyAsset(Normalized) then
			return Normalized
		end
	end

	local ToolName: string = _NormalizeCandyModelName(ToolInstance.Name)
	if _HasCandyAsset(ToolName) then
		return ToolName
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

	if DebugFlags.Hover then
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

local function _CloneDropEffectAttachment(): Attachment?
	local AssetsRoot: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_ROOT_NAME)
	if not AssetsRoot then
		return nil
	end
	local ModelsFolder: Instance? = AssetsRoot:FindFirstChild(AssetsConfig.ModelsFolder)
	if not ModelsFolder then
		return nil
	end
	local DropEffectModel: Instance? = ModelsFolder:FindFirstChild("DropEffect")
	if not DropEffectModel then
		return nil
	end

	local Direct: Instance? = DropEffectModel:FindFirstChild("Attachment")
	if Direct and Direct:IsA("Attachment") then
		return Direct:Clone()
	end

	local Candidate: Instance? = DropEffectModel:FindFirstChildWhichIsA("Attachment", true)
	if Candidate and Candidate:IsA("Attachment") then
		return Candidate:Clone()
	end

	return nil
end

local function _GetLocalPlot(): Model?
	local Player: Player? = Players.LocalPlayer
	if not Player then
		return nil
	end
	local Map: Instance? = workspace:FindFirstChild("Map")
	if not Map then
		return nil
	end
	local Plots: Instance? = Map:FindFirstChild("Plots")
	if not Plots then
		return nil
	end
	for _, Plot: Instance in Plots:GetChildren() do
		if Plot:IsA("Model") then
			local OwnerId: any = Plot:GetAttribute(OWNER_ATTRIBUTE_NAME)
			if typeof(OwnerId) == "number" and OwnerId == Player.UserId then
				return Plot
			end
		end
	end
	return nil
end

do
	local _BuyButtonConnections: { [GuiButton]: RBXScriptConnection } = {}
	local _BuyButtonCooldowns: { [GuiButton]: number } = {}
	local _PlotBuyWatchers: { [Model]: RBXScriptConnection } = {}
	local _TrackedBuyModels: { [Model]: boolean } = {}
	local _BuyModelParents: { [Model]: Instance } = {}
	local _BuyModelDestroyConnections: { [Model]: RBXScriptConnection } = {}
	local _BuyButtonInputConnections: { [GuiButton]: RBXScriptConnection } = {}
	local _BuyButtonScaleTweens: { [GuiButton]: Tween } = {}
	local _BuyButtonBaseScales: { [GuiButton]: number } = {}
	local BUY_BUTTON_PRESS_SCALE: number = 0.94
	local BUY_BUTTON_POP_SCALE: number = 1.03
	local BUY_BUTTON_PRESS_IN_TIME: number = 0.05
	local BUY_BUTTON_POP_TIME: number = 0.085
	local BUY_BUTTON_SETTLE_TIME: number = 0.095

	local function _GetOrCreateButtonScale(Button: GuiButton): UIScale
		local Existing: UIScale? = Button:FindFirstChildOfClass("UIScale")
		if Existing then
			return Existing
		end
		local Scale: UIScale = Instance.new("UIScale")
		Scale.Scale = 1
		Scale.Parent = Button
		return Scale
	end

	local function _PlayBuyButtonPress(Button: GuiButton): ()
		local Scale: UIScale = _GetOrCreateButtonScale(Button)
		local BaseScale: number = _BuyButtonBaseScales[Button] or Scale.Scale
		_BuyButtonBaseScales[Button] = BaseScale

		local ActiveTween: Tween? = _BuyButtonScaleTweens[Button]
		if ActiveTween then
			ActiveTween:Cancel()
			_BuyButtonScaleTweens[Button] = nil
		end

		Scale.Scale = BaseScale
		local ShrinkTween: Tween = TweenService:Create(
			Scale,
			TweenInfo.new(BUY_BUTTON_PRESS_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = BaseScale * BUY_BUTTON_PRESS_SCALE }
		)
		_BuyButtonScaleTweens[Button] = ShrinkTween

		ShrinkTween.Completed:Once(function(PlaybackState: Enum.PlaybackState): ()
			if _BuyButtonScaleTweens[Button] ~= ShrinkTween then
				return
			end
			if PlaybackState ~= Enum.PlaybackState.Completed then
				return
			end
			local PopTween: Tween = TweenService:Create(
				Scale,
				TweenInfo.new(BUY_BUTTON_POP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = BaseScale * BUY_BUTTON_POP_SCALE }
			)
			_BuyButtonScaleTweens[Button] = PopTween
			PopTween.Completed:Once(function(PopState: Enum.PlaybackState): ()
				if _BuyButtonScaleTweens[Button] ~= PopTween then
					return
				end
				if PopState ~= Enum.PlaybackState.Completed then
					return
				end
				local SettleTween: Tween = TweenService:Create(
					Scale,
					TweenInfo.new(BUY_BUTTON_SETTLE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
					{ Scale = BaseScale }
				)
				_BuyButtonScaleTweens[Button] = SettleTween
				SettleTween.Completed:Once(function(): ()
					if _BuyButtonScaleTweens[Button] == SettleTween then
						_BuyButtonScaleTweens[Button] = nil
					end
				end)
				SettleTween:Play()
			end)
			PopTween:Play()
		end)

		ShrinkTween:Play()
	end

	local function _FindBuyModelFromInstance(Target: Instance): Model?
		local Current: Instance? = Target
		while Current do
			if Current:IsA("Model") then
				local GroupId: any = Current:GetAttribute("MachineGroup")
				local SlotId: any = Current:GetAttribute("MachineSlot")
				if typeof(GroupId) == "string" and typeof(SlotId) == "string" then
					return Current
				end
			end
			Current = Current.Parent
		end
		return nil
	end

	local function _FindBuildingSignBuyRoot(Model: Model): Instance?
		local Sign: Instance? = Model:FindFirstChild("BuildingSign", true)
		if Sign then
			return Sign:FindFirstChild("Buy", true)
		end
		return nil
	end

	local function _SetBuyableGradient(Target: Instance?, CanBuy: boolean): ()
		if not Target then
			return
		end
		local Buyable: Instance? = Target:FindFirstChild("Buyable", true)
		if Buyable and Buyable:IsA("UIGradient") then
			Buyable.Enabled = CanBuy
		end
		local NotBuyable: Instance? = Target:FindFirstChild("NotBuyable", true)
		if NotBuyable and NotBuyable:IsA("UIGradient") then
			NotBuyable.Enabled = not CanBuy
		end
	end

	local function _TrackBuyModel(Model: Model): ()
		if _TrackedBuyModels[Model] then
			return
		end
		_TrackedBuyModels[Model] = true
		if Model.Parent then
			_BuyModelParents[Model] = Model.Parent
		end
		_BuyModelDestroyConnections[Model] = Model.Destroying:Connect(function(): ()
			_TrackedBuyModels[Model] = nil
			_BuyModelParents[Model] = nil
			local Connection: RBXScriptConnection? = _BuyModelDestroyConnections[Model]
			if Connection then
				Connection:Disconnect()
			end
			_BuyModelDestroyConnections[Model] = nil
		end)
	end

	local function _SetBuyModelVisible(Model: Model, Visible: boolean): ()
		_TrackBuyModel(Model)
		if Visible then
			local Parent: Instance? = _BuyModelParents[Model]
			if not Model.Parent and Parent and Parent.Parent then
				Model.Parent = Parent
			end
		else
			if Model.Parent then
				_BuyModelParents[Model] = Model.Parent
				Model.Parent = nil
			end
		end
	end

	local function _UpdateBuyModelVisual(Model: Model): ()
		_TrackBuyModel(Model)

		local Cost: any = Model:GetAttribute("PurchaseCost")
		local MinCoins: any = Model:GetAttribute("MinCoinsToShow")
		local Coins: number? = _GetLocalCoins()

		local CanBuy: boolean = false
		if typeof(Cost) == "number" then
			if Cost <= 0 then
				CanBuy = true
			elseif Coins ~= nil then
				CanBuy = Coins >= Cost
			end
		end

		_SetBuyableGradient(_FindBuildingSignBuyRoot(Model), CanBuy)

		local Visible: boolean = true
		if typeof(MinCoins) == "number" then
			if Coins == nil then
				Visible = MinCoins <= 0
			else
				Visible = Coins >= MinCoins
			end
		end
		_SetBuyModelVisible(Model, Visible)
	end

	local function _RefreshBuyModelsInPlot(Plot: Model): ()
		for _, Descendant: Instance in Plot:GetDescendants() do
			if Descendant:IsA("Model") then
				local GroupId: any = Descendant:GetAttribute("MachineGroup")
				local SlotId: any = Descendant:GetAttribute("MachineSlot")
				if typeof(GroupId) == "string" and typeof(SlotId) == "string" then
					_UpdateBuyModelVisual(Descendant)
				end
			end
		end
	end

	local function _RefreshAll(): ()
		for Model: Model, _ in _TrackedBuyModels do
			_UpdateBuyModelVisual(Model)
		end
	end

	local function _TryBind(Target: Instance): ()
		if not Target:IsA("GuiButton") then
			return
		end
		if _BuyButtonConnections[Target] then
			return
		end

		local BuyModel: Model? = _FindBuyModelFromInstance(Target)
		local GroupId: any = Target:GetAttribute("MachineGroup")
		local SlotId: any = Target:GetAttribute("MachineSlot")
		if (typeof(GroupId) ~= "string" or typeof(SlotId) ~= "string") and BuyModel then
			local ModelGroupId: any = BuyModel:GetAttribute("MachineGroup")
			local ModelSlotId: any = BuyModel:GetAttribute("MachineSlot")
			if typeof(ModelGroupId) == "string" and typeof(ModelSlotId) == "string" then
				Target:SetAttribute("MachineGroup", ModelGroupId)
				Target:SetAttribute("MachineSlot", ModelSlotId)
				GroupId = ModelGroupId
				SlotId = ModelSlotId

				local ModelCost: any = BuyModel:GetAttribute("PurchaseCost")
				local ModelRequiredRebirth: any = BuyModel:GetAttribute("RequiredRebirth")
				local ModelPlotOwner: any = BuyModel:GetAttribute("PlotOwner")
				local ModelDisplayName: any = BuyModel:GetAttribute("DisplayName")
				local ModelMinCoinsToShow: any = BuyModel:GetAttribute("MinCoinsToShow")

				if typeof(ModelCost) == "number" then
					Target:SetAttribute("PurchaseCost", ModelCost)
				end
				if typeof(ModelRequiredRebirth) == "number" then
					Target:SetAttribute("RequiredRebirth", ModelRequiredRebirth)
				end
				if typeof(ModelPlotOwner) == "number" then
					Target:SetAttribute("PlotOwner", ModelPlotOwner)
				end
				if typeof(ModelDisplayName) == "string" then
					Target:SetAttribute("DisplayName", ModelDisplayName)
				end
				if typeof(ModelMinCoinsToShow) == "number" then
					Target:SetAttribute("MinCoinsToShow", ModelMinCoinsToShow)
				end
			end
		end
		if typeof(GroupId) ~= "string" or typeof(SlotId) ~= "string" then
			return
		end

		if BuyModel then
			_UpdateBuyModelVisual(BuyModel)
		end

		_BuyButtonInputConnections[Target] = Target.InputBegan:Connect(function(Input: InputObject): ()
			local InputType: Enum.UserInputType = Input.UserInputType
			if InputType == Enum.UserInputType.MouseButton1 or InputType == Enum.UserInputType.Touch then
				_PlayBuyButtonPress(Target)
			end
		end)

		_BuyButtonConnections[Target] = Target.Activated:Connect(function(): ()
			local CooldownUntil: number? = _BuyButtonCooldowns[Target]
			if CooldownUntil and os.clock() < CooldownUntil then
				return
			end
			_BuyButtonCooldowns[Target] = os.clock() + 0.5

			local CurrentGroupId: any = Target:GetAttribute("MachineGroup")
			local CurrentSlotId: any = Target:GetAttribute("MachineSlot")
			if (typeof(CurrentGroupId) ~= "string" or typeof(CurrentSlotId) ~= "string") and BuyModel then
				local ModelGroupId: any = BuyModel:GetAttribute("MachineGroup")
				local ModelSlotId: any = BuyModel:GetAttribute("MachineSlot")
				if typeof(ModelGroupId) == "string" and typeof(ModelSlotId) == "string" then
					CurrentGroupId = ModelGroupId
					CurrentSlotId = ModelSlotId
				end
			end
			if typeof(CurrentGroupId) ~= "string" or typeof(CurrentSlotId) ~= "string" then
				return
			end

			local OwnerId: any = Target:GetAttribute("PlotOwner")
			if typeof(OwnerId) ~= "number" and BuyModel then
				local ModelOwnerId: any = BuyModel:GetAttribute("PlotOwner")
				if typeof(ModelOwnerId) == "number" then
					OwnerId = ModelOwnerId
				end
			end
			local Player: Player? = Players.LocalPlayer
			if Player and typeof(OwnerId) == "number" and OwnerId ~= Player.UserId then
				return
			end

			Packets.Machines:Fire(Actions.BuyMachine, {
				GroupId = CurrentGroupId,
				SlotId = CurrentSlotId,
			})
		end)

		Target.Destroying:Connect(function(): ()
			local Connection: RBXScriptConnection? = _BuyButtonConnections[Target]
			if Connection then
				Connection:Disconnect()
			end
			local InputConnection: RBXScriptConnection? = _BuyButtonInputConnections[Target]
			if InputConnection then
				InputConnection:Disconnect()
			end
			_BuyButtonConnections[Target] = nil
			_BuyButtonInputConnections[Target] = nil
			_BuyButtonCooldowns[Target] = nil
			_BuyButtonScaleTweens[Target] = nil
			_BuyButtonBaseScales[Target] = nil
		end)
	end

	local function _Bind(Plot: Model): ()
		for _, Descendant: Instance in Plot:GetDescendants() do
			_TryBind(Descendant)
		end

		_RefreshBuyModelsInPlot(Plot)

		if _PlotBuyWatchers[Plot] then
			return
		end
		_PlotBuyWatchers[Plot] = Plot.DescendantAdded:Connect(function(Child: Instance): ()
			_TryBind(Child)
		end)
	end

	_TryBindBuyButton = _TryBind
	_BindBuyButtonsInPlot = _Bind
	_RefreshAllBuyModels = _RefreshAll
end

local function _SetDropEffectEnabled(EffectAttachment: Attachment?, Enabled: boolean): ()
	if not EffectAttachment then
		return
	end
	for _, Descendant: Instance in EffectAttachment:GetDescendants() do
		if Descendant:IsA("ParticleEmitter") or Descendant:IsA("Beam") or Descendant:IsA("Trail") then
			Descendant.Enabled = Enabled
		end
	end
end

local function _ScheduleDropEffectCleanup(DropEffectData: DropEffect): ()
	local Part: Part = DropEffectData.Part
	task.delay(DROP_EFFECT_CLEANUP_DELAY, function(): ()
		if _ActiveDropEffects[DropEffectData] then
			return
		end
		if DropEffectData.Part ~= Part then
			return
		end
		if Part.Parent then
			Part:Destroy()
		end
	end)
end

local function _EnsurePrimeDropEffectAttachment(DropEffectData: DropEffect, MainPart: BasePart?): ()
	if not MainPart then
		return
	end

	if DropEffectData.PrimeAttachment and DropEffectData.PrimeAttachment.Parent == MainPart then
		return
	end

	local Existing: Instance? = MainPart:FindFirstChild("DropEffectAttachment")
	if Existing and Existing:IsA("Attachment") then
		DropEffectData.PrimeAttachment = Existing
		_SetDropEffectEnabled(Existing, false)
		return
	end

	if DropEffectData.PrimeAttachment and DropEffectData.PrimeAttachment.Parent then
		DropEffectData.PrimeAttachment:Destroy()
	end

	local EffectAttachment: Attachment? = _CloneDropEffectAttachment()
	if EffectAttachment then
		EffectAttachment.Name = "DropEffectAttachment"
		EffectAttachment.Parent = MainPart
		_SetDropEffectEnabled(EffectAttachment, false)
	end
	DropEffectData.PrimeAttachment = EffectAttachment
end

local function _CloneDropEffectAttachmentFromPrime(PrimeAttachment: Attachment?): Attachment?
	if PrimeAttachment and PrimeAttachment.Parent then
		return PrimeAttachment:Clone()
	end
	return _CloneDropEffectAttachment()
end

local function _RefreshDropEffectAttachment(DropEffectData: DropEffect): ()
	if DropEffectData.EffectAttachment and DropEffectData.EffectAttachment.Parent then
		DropEffectData.EffectAttachment:Destroy()
		DropEffectData.EffectAttachment = nil
	end

	local EffectAttachment: Attachment? = _CloneDropEffectAttachmentFromPrime(DropEffectData.PrimeAttachment)
	if EffectAttachment then
		EffectAttachment.Parent = DropEffectData.Part
		_SetDropEffectEnabled(EffectAttachment, false)
	end
	DropEffectData.EffectAttachment = EffectAttachment
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

	local EffectAttachment: Attachment? = _CloneDropEffectAttachment()
	if EffectAttachment then
		EffectAttachment.Parent = DropPart
		_SetDropEffectEnabled(EffectAttachment, false)
	end

	local DropEffectData: DropEffect = {
		Part = DropPart,
		EffectAttachment = EffectAttachment,
		PrimeAttachment = nil,
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
	DropEffectData.EffectAttachment = NewEffect.EffectAttachment
	DropEffectData.Tween = nil
	return DropEffectData
end

local function _PlayDropEffect(DropEffectData: DropEffect, StartCFrame: CFrame, EndCFrame: CFrame, Duration: number, OnComplete: (() -> ())?): ()
	if _ActiveDropEffects[DropEffectData] then
		if DropEffectData.Tween then
			DropEffectData.Tween:Cancel()
			DropEffectData.Tween = nil
		end
		_SetDropEffectEnabled(DropEffectData.EffectAttachment, false)
		_ActiveDropEffects[DropEffectData] = nil
	end

	_RefreshDropEffectAttachment(DropEffectData)
	DropEffectData.Part.CFrame = StartCFrame
	_SetDropEffectEnabled(DropEffectData.EffectAttachment, true)

	if DropEffectData.Tween then
		DropEffectData.Tween:Cancel()
		DropEffectData.Tween = nil
		_SetDropEffectEnabled(DropEffectData.EffectAttachment, false)
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
			_SetDropEffectEnabled(DropEffectData.EffectAttachment, false)
			DropEffectData.Tween = nil
			_ActiveDropEffects[DropEffectData] = nil
			_ScheduleDropEffectCleanup(DropEffectData)
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

	if DebugFlags.Hover then
		_Debug("TweenScale %s -> %.3f", DropperData.Model.Name, TargetScale)
	end
	_StartDropperScaleTween(DropperData, VisualConfig.HoverTweenTime, VisualConfig.HoverTweenStyle, VisualConfig.HoverTweenDirection, TargetScale, function(): ()
		DropperData.HoverTween = nil
	end)
end

local function _SetDropperHover(DropperData: DropperVisual, IsHover: boolean): ()
	DropperData.IsHovering = IsHover
	if not DropperData.Highlight then
		if DebugFlags.Hover then
			_Debug("Hover ignored (no highlight) for %s", DropperData.Model.Name)
		end
		return
	end

	if IsHover then
		if DebugFlags.Hover then
			_Debug("Hover enter for %s", DropperData.Model.Name)
		end
		DropperData.Highlight.OutlineColor = DROPPER_HIGHLIGHT_COLOR
		DropperData.Highlight.OutlineTransparency = 0
		DropperData.Highlight.FillTransparency = 1
		DropperData.Highlight.Enabled = true
		return
	end

	if DebugFlags.Hover then
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
local function _GetLevelBarScaleFactor(CandyData: CandyVisual): number
	local BaseScale: number = CandyData.LevelBarBaseScale or CandyData.BaseScale or 1
	if BaseScale <= 0 then
		BaseScale = 1
	end
	local CurrentScale: number = CandyData.BaseScale
	if CurrentScale <= 0 then
		CurrentScale = BaseScale
	end
	return CurrentScale / BaseScale
end

local function _ScaleUdim2(Size: UDim2, Scale: number): UDim2
	return UDim2.new(Size.X.Scale, Size.X.Offset * Scale, Size.Y.Scale, Size.Y.Offset * Scale)
end

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
		_EnsureCandyAboveGround(CandyData)
	end

	_SyncLevelBarLayout(CandyData)
end

local function _FinishSpawn(CandyData: CandyVisual): ()
	CandyData.IsSpawning = false
	CandyData.SpawnConnection = nil

	_SyncLevelBarLayout(CandyData)
	_EnsureCandyAboveGround(CandyData)

	if CandyData.PendingBillboard then
		CandyData.PendingBillboard = nil
		module._EnsureCandyBillboard(CandyData)
	end

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

	if CandyData.SkipSpawnTween then
		CandyData.SkipSpawnTween = nil
		CandyData.Model:ScaleTo(math.max(TargetScale, 0.01))
		CandyData.Model:PivotTo(CandyData.CanPosition.CFrame)
		_FinishSpawn(CandyData)
		return
	end

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
	_EnsureCandyAboveGround(CandyData)

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

	local TargetScale: number = CandyData.BaseScale * (1 + VisualConfig.CandyBounceScale)
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
	CandyData.LevelBarBaseScale = nil
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

	_ClearCandyLevelBar(CandyData)

	local Player: Player? = Players.LocalPlayer
	local RootPart: BasePart? = nil
	if Player and Player.Character then
		RootPart = Player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	end

	if RootPart then
		_ClearCandyLevelBar(CandyData)
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
		Packets.Machines:Fire(Actions.RemoveCandy, {
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
	CandyData.LevelBar.MaxDistance = LEVELBAR_MAX_DISTANCE
	local ScaleFactor: number = _GetLevelBarScaleFactor(CandyData)
	if CandyData.LevelBarSize then
		CandyData.LevelBar.Size = _ScaleUdim2(CandyData.LevelBarSize, ScaleFactor)
	end
	if CandyData.LevelBarOffset then
		CandyData.LevelBar.StudsOffset = CandyData.LevelBarOffset * ScaleFactor
	end
end

function module._UpdateCandyBillboard(CandyData: CandyVisual): ()
	if CandyData.IsRemoving then
		return
	end
	if not CandyData.LevelLabel and not CandyData.XpLabel and not CandyData.BarFrame then
		return
	end
	_SyncLevelBarLayout(CandyData)
	local Level: number = _GetNumberAttribute(CandyData.State.Plot, CandyData.State.Keys.CandyLevel, DEFAULT_NUMBER)
	local Exp: number = _GetNumberAttribute(CandyData.State.Plot, CandyData.State.Keys.CandyProgress, DEFAULT_NUMBER)
	local ModelName: string = _GetStringAttribute(CandyData.State.Plot, CandyData.State.Keys.CandyModel, EMPTY_STRING)

	if CandyData.LevelLabel then
		CandyData.LevelLabel.Text = string.format("Level %s", Short:Abbreviate(Level, 1000, 2))
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
			local CurrentXpText: string = Short:Abbreviate(Exp, 1000, 2)
			local MaxXpText: string = Short:Abbreviate(MaxExp, 1000, 2)
			local ExpText: string = string.format(
				"%s <font size=\"10\" color=\"rgb(50,150,255)\">XP</font> / %s <font size=\"10\" color=\"rgb(50,150,255)\">XP</font>",
				CurrentXpText,
				MaxXpText
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
	if CandyData.IsRemoving then
		return
	end
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

	local Billboard: BillboardGui? = _CloneLevelBarBillboard(Template)
	if not Billboard then
		return
	end

	Billboard.MaxDistance = LEVELBAR_MAX_DISTANCE

	local BaseSize: UDim2 = Billboard.Size
	local BaseOffset: Vector3 = Billboard.StudsOffset

	Billboard.Parent = PrimaryPart

	local LevelLabel: TextLike? = nil
	local LevelCandidate: Instance? = Billboard:FindFirstChild("Level", true)
	LevelLabel = _AsTextLike(LevelCandidate)

	local XpLabel: TextLike? = nil
	local BarFrame: GuiObject? = nil
	local BarContainer: GuiObject? = nil
	local function _SetXpLabel(Candidate: Instance?): ()
		if not XpLabel then
			XpLabel = _AsTextLike(Candidate)
		end
	end

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
		_SetXpLabel(XpCandidate)
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
		_SetXpLabel(XpCandidate)
	end

	if not XpLabel then
		local XpCandidate: Instance? = Billboard:FindFirstChild("XP", true)
		_SetXpLabel(XpCandidate)
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
	CandyData.LevelBarBaseScale = CandyData.BaseScale

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

	if DebugFlags.Enabled then
		_Debug(
			"Candy spawned %s at %s (parent=%s)",
			CandyModelName,
			tostring(CandyClone:GetPivot().Position),
			_DescribeInstance(CandyData.Parent)
		)
	end

	local ScaleValue: number = _GetNumberAttribute(CandyData.State.Plot, CandyData.State.Keys.CandyScale, DEFAULT_NUMBER)
	local TargetScale: number = if ScaleValue > 0 then ScaleValue else 1
	CandyData.PendingBillboard = true
	_PlayCandySpawn(CandyData, TargetScale)
	_SetupCandyHover(CandyData)

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

	local NormalizedName: string = _NormalizeCandyModelName(CandyModelName)
	local CandyAsset: Instance? = AssetsFolder:FindFirstChild(NormalizedName)
	if not CandyAsset then
		_Debug("Candy asset missing: %s", NormalizedName)
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
	module.CandyTools.FinalizeSpawn(CandyData, CandyClone, NormalizedName)
end

local function _HandleCandyModelChanged(CandyData: CandyVisual): ()
	if CandyData.LevelBar or CandyData.MutationTextConnection then
		_ClearCandyLevelBar(CandyData)
	end

	local ModelName: string = _GetStringAttribute(CandyData.State.Plot, CandyData.State.Keys.CandyModel, EMPTY_STRING)
	if ModelName == EMPTY_STRING then
		if CandyData.Model then
			_AnimateCandyRemove(CandyData)
		end
		return
	end

	if CandyData.Model then
		CandyData.SkipSpawnTween = true
	end
	if CandyData.IsRemoving then
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
	if CandyData.IsRemoving then
		return
	end
	if CandyData.Model then
		local RawModelName: string =
			_GetStringAttribute(CandyData.State.Plot, CandyData.State.Keys.CandyModel, EMPTY_STRING)
		local TargetName: string = _NormalizeCandyModelName(RawModelName)
		local CurrentName: string = _NormalizeCandyModelName(CandyData.Model.Name)
		if TargetName ~= EMPTY_STRING and CurrentName ~= TargetName then
			return
		end
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
	if CandyData.LevelBar or CandyData.MutationTextConnection then
		_ClearCandyLevelBar(CandyData)
	end

	local HasCandy: boolean = _GetBoolAttribute(CandyData.State.Plot, CandyData.State.Keys.HasCandy, DEFAULT_BOOL)
	if HasCandy then
		CandyData.SkipSpawnTween = true
		_CleanupCandyVisual(CandyData)
		task.delay(0.1, function(): ()
			_EnsureCandyVisualFromState(CandyData)
		end)
		return
	end

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
	if MainPart then
		_EnsurePrimeDropEffectAttachment(DropEffectData, MainPart)
	end

	local TargetPosition: Vector3 = CandyData.CanPosition.Position
	local StartAttachmentCFrame: CFrame
	local AttachmentLocal: CFrame? = nil

	if DropEffectData.PrimeAttachment and DropEffectData.PrimeAttachment.Parent then
		StartAttachmentCFrame = DropEffectData.PrimeAttachment.WorldCFrame
		AttachmentLocal = DropEffectData.PrimeAttachment.CFrame
	elseif MainPart then
		StartAttachmentCFrame = MainPart.CFrame
	else
		StartAttachmentCFrame = CFrame.new(TargetPosition + Vector3.new(0, math.max(VisualConfig.DropPartSize.Y, 4), 0))
	end

	local StartPos: Vector3 = StartAttachmentCFrame.Position
	local EndPosition: Vector3 = Vector3.new(StartPos.X, TargetPosition.Y, StartPos.Z)

	local StartRotation: CFrame = StartAttachmentCFrame - StartPos
	local EndAttachmentCFrame: CFrame = CFrame.new(EndPosition) * StartRotation

	local StartCFrame: CFrame
	local EndCFrame: CFrame
	if AttachmentLocal then
		local InverseLocal: CFrame = AttachmentLocal:Inverse()
		StartCFrame = StartAttachmentCFrame * InverseLocal
		EndCFrame = EndAttachmentCFrame * InverseLocal
	else
		StartCFrame = StartAttachmentCFrame
		EndCFrame = EndAttachmentCFrame
	end

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
		LevelBarBaseScale = nil,
		BaseScale = 1,
		IsRemoving = false,
		IsBouncing = false,
		IsSpawning = false,
		OriginalColors = nil,
		PendingScale = nil,
		BounceConnection = nil,
		SpawnConnection = nil,
		MutationKey = nil,
		SkipSpawnTween = nil,
		SlotId = SlotId,
		TapId = TapId,
		AllowInteraction = AllowInteraction,
		AllowAttract = false,
		PickupCooldownUntil = nil,
	}

	if DropEffectData then
		_EnsurePrimeDropEffectAttachment(DropEffectData, MainPart)
	end

	_ConnectValueChanged(Plot, Keys.CandyModel, function(): ()
		_HandleCandyModelChanged(CandyData)
	end)

	_ConnectValueChanged(Plot, Keys.CandyScale, function(): ()
		_HandleCandyScaleChanged(CandyData)
	end)
	_ConnectValueChanged(Plot, Keys.CandyLevel, function(): ()
		_ScheduleCandyBillboardUpdate(CandyData)
	end)
	_ConnectValueChanged(Plot, Keys.CandyProgress, function(): ()
		_ScheduleCandyBillboardUpdate(CandyData)
	end)
	_ConnectValueChanged(Plot, Keys.Mutations, function(): ()
		_ScheduleCandyBillboardUpdate(CandyData)
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
	_ScheduleCandyBillboardUpdate(CandyData)
	module._UpdateCandyMutationHighlight(CandyData)
end

local function _CloneDropperModel(
	SlotContainer: Instance,
	ParentContainer: Instance,
	GroupConfig: any,
	AssetName: string,
	SlotPartName: string,
	RotationDegrees: number,
	UsePrimaryPartForPlacement: boolean?
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

	do
		local Pivot: CFrame = Clone:GetPivot()
		local SlotRotation: CFrame = SlotPart.CFrame - SlotPart.Position
		local TargetRotation: CFrame = SlotRotation
		if RotationDegrees ~= 0 then
			local Rotation: CFrame = CFrame.fromAxisAngle(SlotUp, math.rad(RotationDegrees))
			TargetRotation = Rotation * TargetRotation
		end
		Clone:PivotTo(CFrame.new(Pivot.Position) * TargetRotation)
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

	local MinDot: number? = _GetModelMinDot(Clone, SlotUp, UsePrimaryPartForPlacement)
	if not MinDot then
		MinDot = Center:Dot(SlotUp) - ExtentAlongUp
	end
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

	Clone, SlotPart = _CloneDropperModel(
		SlotContainer,
		ParentContainer,
		GroupConfig,
		SlotConfig.AssetName,
		SlotConfig.SlotPartName,
		RotationDegrees,
		SlotConfig.UsePrimaryPartForPlacement == true
	)
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
	DoubleDropper = DoubleDroppersModule,
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
	GetUpgradeKey = _GetUpgradeKey,
	GetAttributeKey = _GetAttributeKey,
	BindCandyState = _BindCandyState,
	GetStringAttribute = _GetStringAttribute,
	GetNumberAttribute = _GetNumberAttribute,
	ConnectValueChanged = _ConnectValueChanged,
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
	Actions = Actions,
	ActionPlace = Actions.PlaceCandy,
	ActionRemove = Actions.RemoveCandy,
	ActionDrop = Actions.Drop,
	EmptyString = EMPTY_STRING,
	DefaultNumber = DEFAULT_NUMBER,
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
	HologramEnabled = DebugFlags.Hologram,
	DebugHover = DebugFlags.Hover,
	CursorIcon = "rbxassetid://96499340217478",
}

local _SetupPlotVisual: (Plot: Model) -> ()

local function _SetupGroupVisual(
	Plot: Model,
	GroupId: string,
	GroupConfig: any,
	GroupFolder: Instance,
	IsLocalOwner: boolean,
	PlotData: PlotVisual
): ()
	if PlotData.Groups[GroupId] then
		return
	end

	local GroupVisual = {
		Folder = GroupFolder,
		Slots = {},
	}

	for SlotId: string, SlotConfig: any in GroupConfig.Slots do
		local RequireSlotMatch: boolean = _IsSlotPartShared(GroupConfig, SlotConfig.SlotPartName)
		local SlotFolder: Instance? =
			_FindSlotContainer(GroupFolder, SlotId, SlotConfig.SlotPartName, RequireSlotMatch)
		if not SlotFolder then
			continue
		end

		local ParentContainer: Instance = _ResolveSlotParent(SlotFolder, GroupFolder)
		local Rotation: number = _GetSlotRotation(Plot, SlotConfig)
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
				local RetrySlotFolder: Instance? =
					_FindSlotContainer(GroupFolder, SlotId, SlotConfig.SlotPartName, RequireSlotMatch)
				if not RetrySlotFolder then
					return
				end
				local RetryVisual: DropperVisual? = _SetupDropperVisual(
					Plot,
					GroupId,
					GroupConfig,
					RetrySlotFolder,
					_ResolveSlotParent(RetrySlotFolder, GroupFolder),
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

local function _SetupPurchasedSlot(Plot: Model, GroupId: string, SlotId: string): ()
	local PlotData: PlotVisual? = _PlotVisuals[Plot]
	if not PlotData then
		_SetupPlotVisual(Plot)
		return
	end

	local GroupConfig: any = MachinesConfig[GroupId]
	if not GroupConfig then
		return
	end

	local GroupFolder: Instance? = Plot:FindFirstChild(GroupConfig.PlotFolder)
	if not GroupFolder then
		return
	end

	local GroupVisual: any = PlotData.Groups[GroupId]
	if not GroupVisual then
		_SetupGroupVisual(Plot, GroupId, GroupConfig, GroupFolder, _IsPlotOwnedByLocalPlayer(Plot), PlotData)
		return
	end

	if GroupVisual.Slots and GroupVisual.Slots[SlotId] then
		return
	end

	local SlotConfig: any = GroupConfig.Slots[SlotId]
	if not SlotConfig then
		return
	end

	local RequireSlotMatch: boolean = _IsSlotPartShared(GroupConfig, SlotConfig.SlotPartName)
	local SlotFolder: Instance? =
		_FindSlotContainer(GroupFolder, SlotId, SlotConfig.SlotPartName, RequireSlotMatch)
	if not SlotFolder then
		local WatchKey: string = string.format("%s|%s|%s", Plot.Name, GroupId, SlotId)
		if _PurchasedSlotWatchers[WatchKey] then
			return
		end
		_PurchasedSlotWatchers[WatchKey] = GroupFolder.DescendantAdded:Connect(function(): ()
			local Found: Instance? =
				_FindSlotContainer(GroupFolder, SlotId, SlotConfig.SlotPartName, RequireSlotMatch)
			if Found then
				local Connection: RBXScriptConnection? = _PurchasedSlotWatchers[WatchKey]
				if Connection then
					Connection:Disconnect()
				end
				_PurchasedSlotWatchers[WatchKey] = nil
				_SetupPurchasedSlot(Plot, GroupId, SlotId)
			end
		end)
		return
	end

	local ParentContainer: Instance = _ResolveSlotParent(SlotFolder, GroupFolder)
	local Rotation: number = _GetSlotRotation(Plot, SlotConfig)

	local SlotVisual: DropperVisual? = _SetupDropperVisual(
		Plot,
		GroupId,
		GroupConfig,
		SlotFolder,
		ParentContainer,
		SlotId,
		SlotConfig,
		Rotation,
		_IsPlotOwnedByLocalPlayer(Plot)
	)

	if SlotVisual then
		GroupVisual.Slots[SlotId] = SlotVisual
		local Handler: any = _GroupModules[GroupId]
		if Handler and Handler.SetupSlot then
			Handler.SetupSlot(_MachineApi, SlotVisual, ParentContainer)
		end
	end

	UpgradesModule.SetupBoard(Plot, GroupId, GroupConfig, GroupFolder, _IsPlotOwnedByLocalPlayer(Plot))
end

local function _WatchPlotGroupFolder(
	Plot: Model,
	GroupId: string,
	GroupConfig: any,
	IsLocalOwner: boolean,
	PlotData: PlotVisual
): ()
	if PlotData.Groups[GroupId] then
		return
	end

	local Existing: Instance? = Plot:FindFirstChild(GroupConfig.PlotFolder)
	if Existing and (Existing:IsA("Folder") or Existing:IsA("Model")) then
		_SetupGroupVisual(Plot, GroupId, GroupConfig, Existing, IsLocalOwner, PlotData)
		return
	end

	local PlotWatchers = _PlotGroupWatchers[Plot]
	if not PlotWatchers then
		PlotWatchers = {}
		_PlotGroupWatchers[Plot] = PlotWatchers
	end

	if PlotWatchers[GroupId] then
		return
	end

	PlotWatchers[GroupId] = Plot.ChildAdded:Connect(function(Child: Instance): ()
		if PlotData.Groups[GroupId] then
			local Connection = PlotWatchers[GroupId]
			if Connection then
				Connection:Disconnect()
			end
			PlotWatchers[GroupId] = nil
			return
		end

		if Child.Name ~= GroupConfig.PlotFolder then
			return
		end
		if not (Child:IsA("Folder") or Child:IsA("Model")) then
			return
		end

		local Connection = PlotWatchers[GroupId]
		if Connection then
			Connection:Disconnect()
		end
		PlotWatchers[GroupId] = nil
		_SetupGroupVisual(Plot, GroupId, GroupConfig, Child, IsLocalOwner, PlotData)
	end)
end

_SetupPlotVisual = function(Plot: Model): ()
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
			_WatchPlotGroupFolder(Plot, GroupId, GroupConfig, IsLocalOwner, PlotData)
			continue
		end
		_SetupGroupVisual(Plot, GroupId, GroupConfig, GroupFolder, IsLocalOwner, PlotData)
	end

	if _BindBuyButtonsInPlot then
		_BindBuyButtonsInPlot(Plot)
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
		local Plot: Model? = CandyData.State and CandyData.State.Plot
		if Plot and Plot:GetAttribute(CLIENT_HIDDEN_ATTRIBUTE) == true then
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
		ActionUpgradeLevel = Actions.UpgradeLevel,
		ActionUpgradeLevelMax = Actions.UpgradeLevelMax,
		ActionUpgradeSpecial = Actions.UpgradeSpecial,
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
		if Action == "UpgradeResult" then
			UpgradesModule.HandleUpgradeResult(Data)
			return
		end
		if Action == "MachinePurchased" then
			local GroupId: any = Data and Data.GroupId
			local SlotId: any = Data and Data.SlotId
			if typeof(GroupId) ~= "string" or typeof(SlotId) ~= "string" then
				return
			end
			local Plot: Model? = _GetLocalPlot()
			if Plot then
				_SetupPurchasedSlot(Plot, GroupId, SlotId)
				task.delay(0.25, function(): ()
					if Plot.Parent then
						_SetupPurchasedSlot(Plot, GroupId, SlotId)
					end
				end)
				task.delay(0.75, function(): ()
					if Plot.Parent then
						_SetupPurchasedSlot(Plot, GroupId, SlotId)
					end
				end)
			end
			return
		end
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
