--!strict

local module: { Init: (self: any) -> (), Start: (self: any) -> () } = {}

--\\ SERVICES \\ -- TR
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")
local ContentProvider: ContentProvider = game:GetService("ContentProvider")

--\\ DEPENDENCIES \\ -- TR
local Constants: any = require(ReplicatedStorage.Modules.Constants.Droppers)
local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local TweenModule: any = require(ReplicatedStorage.Modules.Core.Tween)

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
}

type CandyStateRefs = {
	Plot: Model,
	Keys: CandyAttributeKeys,
}

type CandyVisual = {
	State: CandyStateRefs,
	Model: Model?,
	CanPosition: BasePart,
	Parent: Instance,
	Highlight: Highlight?,
	ClickDetector: ClickDetector?,
	Billboard: BillboardGui?,
	LevelLabel: TextLabel?,
	BaseScale: number,
	IsRemoving: boolean,
	IsBouncing: boolean,
	IsSpawning: boolean,
	OriginalColors: { [BasePart]: Color3 }?,
	PendingScale: number?,
	BounceConnection: RBXScriptConnection?,
	SpawnConnection: RBXScriptConnection?,
	SlotId: string,
	TapId: number?,
	AllowInteraction: boolean,
	AllowAttract: boolean,
}

type TapVisual = {
	TapModel: Model,
	MainPart: BasePart?,
	CanPosition: BasePart?,
	DropEffect: DropEffect?,
	Candy: CandyVisual?,
	TapId: number,
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
	SlotId: string,
	Type: string,
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
	DroppersFolder: Instance,
	LongSlot: Instance?,
	WideSlot: Instance?,
	DropperLong: DropperVisual?,
	DropperWide: DropperVisual?,
}

type CandyFloatData = {
	Visual: CandyVisual,
	BaseCFrame: CFrame,
	Phase: number,
}

--\\ CONSTANTS \\ -- TR
local DropperConfig: any = Constants.Dropper
local VisualConfig: any = Constants.Visual
local TimingConfig: any = Constants.Timing
local AssetsConfig: any = Constants.Assets
local CandyConfig: any = Constants.Candy
local MAX_ACTIVATION_DISTANCE: number = 1000

local EMPTY_STRING: string = ""
local ASSETS_ROOT_NAME: string = "Assets"
local MAP_FOLDER_NAME: string = "Map"
local PLOTS_FOLDER_NAME: string = "Plots"
local DEBRIS_FOLDER_NAME: string = "Debris"
local LONG_SLOT_PART_NAME: string = "Long Slot"
local WIDE_SLOT_PART_NAME: string = "Wide Slot"
local CAN_POSITION_NAME: string = "CanPosition"
local MAIN_PART_NAME: string = "Main"
local BUTTON_PART_NAME: string = "Button"
local TAP_NAME: string = "Tap"
local SOUND_UP_NAME: string = "Up"
local DROP_EFFECT_PART_NAME: string = "DropEffect"
local HITBOX_PART_NAME: string = "Hitbox"
local OWNER_ATTRIBUTE_NAME: string = "Owner"
local DROPPER_HIGHLIGHT_COLOR: Color3 = Color3.fromRGB(255, 255, 255)
local DROPPER_PLACE_COLOR: Color3 = Color3.fromRGB(70, 255, 120)
local DROPPER_REMOVE_COLOR: Color3 = Color3.fromRGB(255, 70, 70)
local CANDY_HIGHLIGHT_COLOR: Color3 = Color3.fromRGB(255, 0, 0)
local HIGHLIGHT_FILL_TRANSPARENCY: number = 0.7
local HIGHLIGHT_OUTLINE_TRANSPARENCY: number = 1
local CLICK_SHRINK_SCALE: number = 0.92
local CLICK_BOUNCE_SCALE: number = 0.08
local HOLOGRAM_TRANSPARENCY: number = 0.5
local HOLOGRAM_SPAWN_TIME: number = 0.15
local HOLOGRAM_SPAWN_STYLE: string = "Sine"
local HOLOGRAM_SPAWN_DIRECTION: string = "Out"
local DEFAULT_MAX_LEVEL: number = 5
local BUTTON_BASE_SIZE: Vector3 = Vector3.new(2.112, 1.056, 2.112)
local BUTTON_HOVER_SCALE: number = 1.08
local BUTTON_HOVER_TIME: number = 0.08
local BUTTON_CLICK_SCALE: number = 0.9
local BUTTON_READY_COLOR: Color3 = Color3.fromRGB(0, 255, 0)
local BUTTON_COOLDOWN_COLOR: Color3 = Color3.fromRGB(255, 70, 70)
local REMOVE_ATTRACT_TIME: number = 0.25
local BILLBOARD_SIZE: UDim2 = UDim2.fromOffset(160, 40)
local BILLBOARD_OFFSET: Vector3 = Vector3.new(0, 2, 0)
local BILLBOARD_MAX_DISTANCE: number = 25
local BILLBOARD_TEXT_COLOR: Color3 = Color3.fromRGB(255, 255, 255)
local BILLBOARD_TEXT_STROKE: number = 0.4
local CANDY_SPAWN_TIME: number = 0.2
local CANDY_SPAWN_STYLE: string = "Back"
local CANDY_SPAWN_DIRECTION: string = "Out"
local REMOVE_TRAIL_TEXTURE: string = "rbxassetid://284205403"

local ATTRIBUTE_PREFIX: string = "Dropper"
local ATTRIBUTE_TAP_PREFIX: string = "Tap"
local ATTRIBUTE_FORMAT_NORMAL: string = "%s_%s_%s"
local ATTRIBUTE_FORMAT_TAP: string = "%s_%s_%s%d_%s"
local ATTRIBUTE_KEY_CANDY_MODEL: string = "CandyModel"
local ATTRIBUTE_KEY_CANDY_LEVEL: string = "CandyLevel"
local ATTRIBUTE_KEY_CANDY_PROGRESS: string = "CandyProgress"
local ATTRIBUTE_KEY_CANDY_SCALE: string = "CandyScale"
local ATTRIBUTE_KEY_DROP_SEQUENCE: string = "DropSequence"
local ATTRIBUTE_KEY_REMOVE_SEQUENCE: string = "RemoveSequence"

local DEFAULT_NUMBER: number = 0

local ACTION_PLACE_CANDY: string = "PlaceCandy"
local ACTION_DROP: string = "Drop"
local ACTION_REMOVE_CANDY: string = "RemoveCandy"


local DEBUG_ENABLED: boolean = false
local DEBUG_HOVER: boolean = false

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
local _ActiveHoverDropper: DropperVisual? = nil
local _ActiveHoverTap: TapVisual? = nil
local _ToolAddedConnection: RBXScriptConnection? = nil
local _ToolRemovedConnection: RBXScriptConnection? = nil

--\\ PRIVATE FUNCTIONS \\ -- TR
local function _Debug(Message: string, ...: any): ()
	if not DEBUG_ENABLED then
		return
	end

	local Output: string = string.format(Message, ...)
	print("[DropperDebug]", Output)
end

local function _PreloadAssets(): ()
	task.spawn(function(): ()
		local Success: boolean, ErrorMessage: string? = pcall(function(): ()
			ContentProvider:PreloadAsync({ REMOVE_TRAIL_TEXTURE })
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
	return table.concat(Names, ", ")
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
		[1] = { [DropperConfig.SlotLong] = -180, [DropperConfig.SlotWide] = 180 },
		[2] = { [DropperConfig.SlotLong] = -180, [DropperConfig.SlotWide] = 0 },
		[3] = { [DropperConfig.SlotLong] = 90, [DropperConfig.SlotWide] = -90 },
		[4] = { [DropperConfig.SlotLong] = 90, [DropperConfig.SlotWide] = -90 },
		[5] = { [DropperConfig.SlotLong] = 0, [DropperConfig.SlotWide] = -180 },
		[6] = { [DropperConfig.SlotLong] = 0, [DropperConfig.SlotWide] = -180 },
		[7] = { [DropperConfig.SlotLong] = -90, [DropperConfig.SlotWide] = 90 },
		[8] = { [DropperConfig.SlotLong] = -90, [DropperConfig.SlotWide] = 90 },
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

local function _GetCandyMaxLevelForBillboard(ModelName: string): number
	if ModelName ~= EMPTY_STRING then
		local Evolution: any = CandyConfig.Evolutions[ModelName]
		if Evolution and typeof(Evolution.MaxLevel) == "number" and Evolution.MaxLevel > 0 then
			return Evolution.MaxLevel
		end
	end
	return DEFAULT_MAX_LEVEL
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
	local Map: Instance? = workspace:FindFirstChild(MAP_FOLDER_NAME)
	if Map and (Map:IsA("Folder") or Map:IsA("Model")) then
		local DebrisFolder: Instance? = Map:FindFirstChild(DEBRIS_FOLDER_NAME)
		if DebrisFolder then
			return DebrisFolder
		end
	end
	return workspace
end

local function _GetAttributeKey(SlotId: string, TapId: number?, KeyName: string): string
	if TapId then
		return string.format(ATTRIBUTE_FORMAT_TAP, ATTRIBUTE_PREFIX, SlotId, ATTRIBUTE_TAP_PREFIX, TapId, KeyName)
	end
	return string.format(ATTRIBUTE_FORMAT_NORMAL, ATTRIBUTE_PREFIX, SlotId, KeyName)
end

local function _BuildCandyAttributeKeys(SlotId: string, TapId: number?): CandyAttributeKeys
	return {
		CandyModel = _GetAttributeKey(SlotId, TapId, ATTRIBUTE_KEY_CANDY_MODEL),
		CandyLevel = _GetAttributeKey(SlotId, TapId, ATTRIBUTE_KEY_CANDY_LEVEL),
		CandyProgress = _GetAttributeKey(SlotId, TapId, ATTRIBUTE_KEY_CANDY_PROGRESS),
		CandyScale = _GetAttributeKey(SlotId, TapId, ATTRIBUTE_KEY_CANDY_SCALE),
		DropSequence = _GetAttributeKey(SlotId, TapId, ATTRIBUTE_KEY_DROP_SEQUENCE),
		RemoveSequence = _GetAttributeKey(SlotId, TapId, ATTRIBUTE_KEY_REMOVE_SEQUENCE),
	}
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
	return AssetsRoot:FindFirstChild(AssetsConfig.CandiesFolder)
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

	local AssetsFolder: Instance? = AssetsRoot:FindFirstChild(AssetsConfig.CandiesFolder)
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
			local TargetTransparency: number = if Child == PrimaryPart then 1 else HOLOGRAM_TRANSPARENCY
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
		HOLOGRAM_SPAWN_TIME,
		HOLOGRAM_SPAWN_STYLE,
		HOLOGRAM_SPAWN_DIRECTION,
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
		HOLOGRAM_SPAWN_TIME,
		HOLOGRAM_SPAWN_STYLE,
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
			local TargetTransparency: number = if Child == PrimaryPart then 1 else HOLOGRAM_TRANSPARENCY
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
	Trail.Texture = REMOVE_TRAIL_TEXTURE
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
		if PlotData.DropperLong and PlotData.DropperLong.PreviewModel and PlotData.DropperLong.PreviewModel ~= KeepModel then
			_ClearDropperPreview(PlotData.DropperLong)
		end
		if PlotData.DropperWide then
			if PlotData.DropperWide.PreviewModel and PlotData.DropperWide.PreviewModel ~= KeepModel then
				_ClearDropperPreview(PlotData.DropperWide)
			end
			if PlotData.DropperWide.Taps then
				for _, TapData: TapVisual in PlotData.DropperWide.Taps do
					if TapData.PreviewModel and TapData.PreviewModel ~= KeepModel then
						_ClearTapPreview(TapData)
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
	if DropperData.IsHovering then
		return VisualConfig.HoverScale
	end
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
	Highlight.FillColor = FlashColor
	Highlight.FillTransparency = 0.2
	Highlight.Enabled = true

	TweenModule:Tween(Highlight, 0.12, "Sine", "Out", { FillTransparency = HIGHLIGHT_FILL_TRANSPARENCY }, 0, false, function(): ()
		Highlight.FillColor = DropperData.HoverColor
		Highlight.FillTransparency = HIGHLIGHT_FILL_TRANSPARENCY
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
	Highlight.FillTransparency = HIGHLIGHT_FILL_TRANSPARENCY
	Highlight.OutlineTransparency = HIGHLIGHT_OUTLINE_TRANSPARENCY
	Highlight.Adornee = DropperData.Model
	Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	Highlight.Enabled = false
	Highlight.Parent = DropperData.Model

	DropperData.Highlight = Highlight
	DropperData.HoverColor = DropperData.HoverColor or DROPPER_HIGHLIGHT_COLOR
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

local function _SetDropperHasCandy(DropperData: DropperVisual, HasCandy: boolean): ()
	DropperData.HasCandy = HasCandy
	DropperData.HoverColor = if HasCandy then DROPPER_REMOVE_COLOR else DROPPER_HIGHLIGHT_COLOR

	if DropperData.Highlight then
		DropperData.Highlight.FillColor = DropperData.HoverColor
	end
end

local function _CreateDropEffect(): DropEffect
	local DropPart: Part = Instance.new("Part")
	DropPart.Name = DROP_EFFECT_PART_NAME
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
		DropperData.Highlight.FillColor = DropperData.HoverColor
		DropperData.Highlight.Enabled = true
		_TweenDropperScale(DropperData, VisualConfig.HoverScale)
		return
	end

	if DEBUG_HOVER then
		_Debug("Hover leave for %s", DropperData.Model.Name)
	end
	DropperData.Highlight.Enabled = false
	_TweenDropperScale(DropperData, DropperData.BaseScale)
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

local function _SetActiveHoverDropper(DropperData: DropperVisual): ()
	if _ActiveHoverDropper and _ActiveHoverDropper ~= DropperData then
		_SetDropperHover(_ActiveHoverDropper, false)
		_ClearDropperPreview(_ActiveHoverDropper)
	end
	if _ActiveHoverTap then
		_ClearTapPreview(_ActiveHoverTap)
		_ActiveHoverTap = nil
	end
	_ActiveHoverDropper = DropperData
end

local function _SetActiveHoverTap(TapData: TapVisual, DropperData: DropperVisual): ()
	if _ActiveHoverTap and _ActiveHoverTap ~= TapData then
		_ClearTapPreview(_ActiveHoverTap)
	end
	_ActiveHoverTap = TapData
	_SetActiveHoverDropper(DropperData)
end

local function _ClearActiveHoverDropper(DropperData: DropperVisual): ()
	if _ActiveHoverDropper == DropperData then
		_ActiveHoverDropper = nil
	end
end

local function _ClearActiveHoverTap(TapData: TapVisual): ()
	if _ActiveHoverTap == TapData then
		_ActiveHoverTap = nil
	end
end

local function _RefreshHoverPreview(): ()
	local KeepModel: Model? = nil
	if _ActiveHoverTap then
		KeepModel = _ActiveHoverTap.PreviewModel
	elseif _ActiveHoverDropper then
		KeepModel = _ActiveHoverDropper.PreviewModel
	end
	_ClearOtherPreviews(KeepModel)

	local ToolInstance: Tool? = _GetEquippedTool()
	if _ActiveHoverTap then
		if _ActiveHoverTap.HasCandy then
			_ClearTapPreview(_ActiveHoverTap)
			return
		end
		if ToolInstance then
			local CandyName: string? = _GetCandyNameFromTool(ToolInstance)
			if CandyName and _ActiveHoverTap.CanPosition then
				_ShowTapPreview(_ActiveHoverTap, CandyName, _ActiveHoverTap.CanPosition.CFrame, _ActiveHoverTap.TapModel.Parent or _ActiveHoverTap.TapModel)
				return
			end
		end
		_ClearTapPreview(_ActiveHoverTap)
		return
	end

	if _ActiveHoverDropper then
		if _ActiveHoverDropper.HasCandy then
			_ClearDropperPreview(_ActiveHoverDropper)
			return
		end
		if ToolInstance then
			local CandyName: string? = _GetCandyNameFromTool(ToolInstance)
			if CandyName then
				local PreviewCFrame: CFrame = if _ActiveHoverDropper.CanPosition then _ActiveHoverDropper.CanPosition.CFrame else _ActiveHoverDropper.Model:GetPivot()
				_ShowDropperPreview(_ActiveHoverDropper, CandyName, PreviewCFrame)
				return
			end
		end
		_ClearDropperPreview(_ActiveHoverDropper)
	end
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
	end

	if CandyData.Billboard then
		CandyData.Billboard.StudsOffset = BILLBOARD_OFFSET
		CandyData.Billboard.MaxDistance = BILLBOARD_MAX_DISTANCE
	end
end

local function _FinishSpawn(CandyData: CandyVisual): ()
	CandyData.IsSpawning = false
	CandyData.SpawnConnection = nil

	if CandyData.Billboard then
		CandyData.Billboard.StudsOffset = BILLBOARD_OFFSET
		CandyData.Billboard.MaxDistance = BILLBOARD_MAX_DISTANCE
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
	if CandyData.Billboard then
		CandyData.Billboard:Destroy()
	end
	CandyData.Billboard = nil
	CandyData.LevelLabel = nil
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

	if CandyData.Billboard then
		CandyData.Billboard:Destroy()
	end
	CandyData.Billboard = nil
	CandyData.LevelLabel = nil

	local Player: Player? = Players.LocalPlayer
	local RootPart: BasePart? = nil
	if Player and Player.Character then
		RootPart = Player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	end

	if RootPart then
		local Target: CFrame = RootPart.CFrame
		TweenModule:TweenModel(CandyData.Model, REMOVE_ATTRACT_TIME, "Sine", "In", { Value = Target }, 0, false, function(): ()
			TweenModule:TweenScale(
				CandyData.Model,
				VisualConfig.CandyBounceTime,
				"Sine",
				"In",
				0,
				function(): ()
					if CleanupTrail then
						CleanupTrail()
					end
					_CleanupCandyVisual(CandyData)
				end
			)
		end)
	else
		TweenModule:TweenScale(
			CandyData.Model,
			VisualConfig.CandyBounceTime,
			"Sine",
			"In",
			0,
			function(): ()
				if CleanupTrail then
					CleanupTrail()
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
	Highlight.FillTransparency = HIGHLIGHT_FILL_TRANSPARENCY
	Highlight.OutlineTransparency = HIGHLIGHT_OUTLINE_TRANSPARENCY
	Highlight.Enabled = false
	Highlight.Parent = CandyData.Model
	CandyData.Highlight = Highlight

	local Detector: ClickDetector = Instance.new("ClickDetector")
	Detector.MaxActivationDistance = MAX_ACTIVATION_DISTANCE
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
		Packets.Dropper:Fire(ACTION_REMOVE_CANDY, { CandyData.SlotId, CandyData.TapId })
	end)
end

local function _UpdateCandyBillboard(CandyData: CandyVisual): ()
	if not CandyData.LevelLabel then
		return
	end
	if CandyData.Billboard then
		CandyData.Billboard.Size = BILLBOARD_SIZE
		CandyData.Billboard.StudsOffset = BILLBOARD_OFFSET
		CandyData.Billboard.MaxDistance = BILLBOARD_MAX_DISTANCE
	end

	local Level: number = _GetNumberAttribute(CandyData.State.Plot, CandyData.State.Keys.CandyLevel, DEFAULT_NUMBER)
	local Exp: number = _GetNumberAttribute(CandyData.State.Plot, CandyData.State.Keys.CandyProgress, DEFAULT_NUMBER)
	local ModelName: string = _GetStringAttribute(CandyData.State.Plot, CandyData.State.Keys.CandyModel, EMPTY_STRING)
	local MaxLevel: number = _GetCandyMaxLevelForBillboard(ModelName)
	if MaxLevel > 0 and Level >= MaxLevel then
		CandyData.LevelLabel.Text = string.format("[Lv.%d] Max", Level)
		return
	end
	local MaxExp: number = 0
	if ModelName ~= EMPTY_STRING then
		local Evolution: any = CandyConfig.Evolutions[ModelName]
		if Evolution and typeof(Evolution.Limit) == "number" and Evolution.Limit > 0 then
			MaxExp = Evolution.Limit
		end
	end
	CandyData.LevelLabel.Text = string.format("[Lv.%d] Exp: %d/%d", Level, Exp, MaxExp)
end

local function _EnsureCandyBillboard(CandyData: CandyVisual): ()
	if CandyData.LevelLabel then
		local Billboard: BillboardGui? = CandyData.Billboard
		if not Billboard then
			local Parent: Instance? = CandyData.LevelLabel.Parent
			if Parent and Parent:IsA("BillboardGui") then
				Billboard = Parent
				CandyData.Billboard = Billboard
			end
		end
		if Billboard then
			Billboard.Size = BILLBOARD_SIZE
			Billboard.StudsOffset = BILLBOARD_OFFSET
			Billboard.MaxDistance = BILLBOARD_MAX_DISTANCE
		end
		_UpdateCandyBillboard(CandyData)
		return
	end

	if not CandyData.Model then
		return
	end

	local PrimaryPart: BasePart? = CandyData.Model.PrimaryPart
	if not PrimaryPart then
		return
	end

	local Billboard: BillboardGui = Instance.new("BillboardGui")
	Billboard.Name = "CandyBillboard"
	Billboard.Size = BILLBOARD_SIZE
	Billboard.StudsOffset = BILLBOARD_OFFSET
	Billboard.AlwaysOnTop = true
	Billboard.LightInfluence = 0
	Billboard.MaxDistance = BILLBOARD_MAX_DISTANCE
	Billboard.Parent = PrimaryPart

	local Label: TextLabel = Instance.new("TextLabel")
	Label.Name = "CandyLabel"
	Label.Size = UDim2.fromScale(1, 1)
	Label.BackgroundTransparency = 1
	Label.TextScaled = true
	Label.Font = Enum.Font.GothamBold
	Label.TextColor3 = BILLBOARD_TEXT_COLOR
	Label.TextStrokeTransparency = BILLBOARD_TEXT_STROKE
	Label.Parent = Billboard

	CandyData.Billboard = Billboard
	CandyData.LevelLabel = Label
	_UpdateCandyBillboard(CandyData)
end

local function _SpawnCandyModel(CandyData: CandyVisual, CandyModelName: string): ()
	local AssetsRoot: Instance = ReplicatedStorage:WaitForChild(ASSETS_ROOT_NAME)
	local AssetsFolder: Instance = AssetsRoot:WaitForChild(AssetsConfig.CandiesFolder)

	local CandyAsset: Instance? = AssetsFolder:FindFirstChild(CandyModelName)
	if not CandyAsset then
		_Debug("Candy asset missing: %s", CandyModelName)
		return
	end

	if CandyData.Model then
		CandyData.Model:Destroy()
		CandyData.Model = nil
		CandyData.Highlight = nil
		CandyData.ClickDetector = nil
		if CandyData.Billboard then
			CandyData.Billboard:Destroy()
		end
		CandyData.Billboard = nil
		CandyData.LevelLabel = nil
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
		_Debug("Candy asset not supported: %s (%s)", CandyModelName, CandyAsset.ClassName)
		return
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
		return
	end

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
	_EnsureCandyBillboard(CandyData)

	local FloatData: CandyFloatData = {
		Visual = CandyData,
		BaseCFrame = CandyData.CanPosition.CFrame,
		Phase = _RandomGenerator:NextNumber(0, math.pi * 2),
	}

	_ActiveCandies[CandyData] = FloatData
end

local function _HandleCandyModelChanged(CandyData: CandyVisual): ()
	local ModelName: string = _GetStringAttribute(CandyData.State.Plot, CandyData.State.Keys.CandyModel, EMPTY_STRING)
	if ModelName == EMPTY_STRING then
		if CandyData.Model then
			_AnimateCandyRemove(CandyData)
		end
		return
	end

	_SpawnCandyModel(CandyData, ModelName)
end

local function _HandleCandyScaleChanged(CandyData: CandyVisual): ()
	local NewScale: number = _GetNumberAttribute(CandyData.State.Plot, CandyData.State.Keys.CandyScale, DEFAULT_NUMBER)
	if NewScale <= 0 then
		return
	end
	_ApplyCandyScale(CandyData, NewScale)
end

local function _HandleCandyRemove(CandyData: CandyVisual): ()
	_AnimateCandyRemove(CandyData)
end

local function _PlaySoundUp(MainPart: BasePart?): ()
	if not MainPart then
		return
	end

	local SoundInstance: Instance? = MainPart:FindFirstChild(SOUND_UP_NAME)
	if not SoundInstance or not SoundInstance:IsA("Sound") then
		return
	end

	SoundInstance:Play()
end

local function _HandleDropSequence(CandyData: CandyVisual, DropEffectData: DropEffect?, MainPart: BasePart?, DropTime: number): ()
	if not CandyData.Model then
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
	Keys: CandyAttributeKeys,
	CanPosition: BasePart,
	Parent: Instance,
	SlotId: string,
	TapId: number?,
	DropEffectData: DropEffect?,
	MainPart: BasePart?,
	DropTime: number,
	AllowInteraction: boolean
): ()
	local CandyData: CandyVisual = {
		State = {
			Plot = Plot,
			Keys = Keys,
		},
		Model = nil,
		CanPosition = CanPosition,
		Parent = Parent,
		Highlight = nil,
		ClickDetector = nil,
		Billboard = nil,
		LevelLabel = nil,
		BaseScale = 1,
		IsRemoving = false,
		IsBouncing = false,
		IsSpawning = false,
		OriginalColors = nil,
		PendingScale = nil,
		BounceConnection = nil,
		SpawnConnection = nil,
		SlotId = SlotId,
		TapId = TapId,
		AllowInteraction = AllowInteraction,
		AllowAttract = false,
	}

	Plot:GetAttributeChangedSignal(Keys.CandyModel):Connect(function(): ()
		_HandleCandyModelChanged(CandyData)
	end)

	Plot:GetAttributeChangedSignal(Keys.CandyScale):Connect(function(): ()
		_HandleCandyScaleChanged(CandyData)
	end)
	Plot:GetAttributeChangedSignal(Keys.CandyLevel):Connect(function(): ()
		_UpdateCandyBillboard(CandyData)
	end)
	Plot:GetAttributeChangedSignal(Keys.CandyProgress):Connect(function(): ()
		_UpdateCandyBillboard(CandyData)
	end)

	Plot:GetAttributeChangedSignal(Keys.DropSequence):Connect(function(): ()
		_HandleDropSequence(CandyData, DropEffectData, MainPart, DropTime)
	end)

	Plot:GetAttributeChangedSignal(Keys.RemoveSequence):Connect(function(): ()
		_HandleCandyRemove(CandyData)
	end)

	_HandleCandyModelChanged(CandyData)
	_HandleCandyScaleChanged(CandyData)
	_UpdateCandyBillboard(CandyData)
end

local function _SetupNormalDropper(DropperData: DropperVisual, SlotFolder: Instance): ()
	local CanPosition: BasePart? = _FindDescendant(DropperData.Model, CAN_POSITION_NAME) :: BasePart?
	if not CanPosition then
		_Debug("CanPosition missing in Dropper %s", DropperData.Model.Name)
		return
	end
	DropperData.CanPosition = CanPosition

	if not DropperData.DropEffect then
		DropperData.DropEffect = _CreateDropEffect()
	end

	local Keys: CandyAttributeKeys = _BuildCandyAttributeKeys(DropperData.SlotId, nil)
	local Plot: Model = DropperData.Plot

	local function RefreshCandyState(): ()
		local ModelName: string = _GetStringAttribute(Plot, Keys.CandyModel, EMPTY_STRING)
		_SetDropperHasCandy(DropperData, ModelName ~= EMPTY_STRING)
	end

	Plot:GetAttributeChangedSignal(Keys.CandyModel):Connect(function(): ()
		RefreshCandyState()
	end)
	RefreshCandyState()

	_BindCandyState(
		DropperData.Plot,
		Keys,
		CanPosition,
		SlotFolder,
		DropperData.SlotId,
		nil,
		DropperData.DropEffect,
		DropperData.MainPart,
		TimingConfig.ManualDropTime,
		DropperData.IsLocalOwner
	)
end

local function _SortTapsByPosition(Taps: { Model }): { Model }
	table.sort(Taps, function(Left: Model, Right: Model): boolean
		local LeftPos: Vector3 = Left:GetPivot().Position
		local RightPos: Vector3 = Right:GetPivot().Position
		return LeftPos.X < RightPos.X
	end)
	return Taps
end

local function _CollectTapModels(DropperModel: Model): { Model }
	local TapModels: { Model } = table.create(DropperConfig.AutoTapCount)
	for _, Child: Instance in DropperModel:GetChildren() do
		if Child:IsA("Model") and Child.Name == TAP_NAME then
			table.insert(TapModels, Child)
		end
	end
	return _SortTapsByPosition(TapModels)
end

local function _SetupAutoDropper(DropperData: DropperVisual, SlotFolder: Instance): ()
	local TapModels: { Model } = _CollectTapModels(DropperData.Model)
	if #TapModels <= 0 then
		_Debug("No Tap models found in Dropper2 %s", DropperData.Model.Name)
		return
	end

	_Debug("Auto Dropper taps: %d in %s", #TapModels, DropperData.Model.Name)

	local TapDataMap: { [number]: TapVisual } = {}
	for Index: number = 1, math.min(#TapModels, DropperConfig.AutoTapCount) do
		local TapModel: Model = TapModels[Index]

		local MainPart: BasePart? = _FindDescendant(TapModel, MAIN_PART_NAME) :: BasePart?
		local CanPosition: BasePart? = _FindDescendant(TapModel, CAN_POSITION_NAME) :: BasePart?
		if not CanPosition then
			_Debug("CanPosition missing in Tap %s", TapModel.Name)
			continue
		end

		local DropEffectData: DropEffect = _CreateDropEffect()
		local TapData: TapVisual = {
			TapModel = TapModel,
			MainPart = MainPart,
			CanPosition = CanPosition,
			DropEffect = DropEffectData,
			Candy = nil,
			TapId = Index,
			Hitbox = nil,
			HoverDetector = nil,
			PulseTween = nil,
			HasCandy = false,
			PreviewModel = nil,
			PreviewName = nil,
		}

		TapDataMap[Index] = TapData
		local Keys: CandyAttributeKeys = _BuildCandyAttributeKeys(DropperData.SlotId, Index)
		_BindCandyState(
			DropperData.Plot,
			Keys,
			CanPosition,
			SlotFolder,
			DropperData.SlotId,
			Index,
			DropEffectData,
			MainPart,
			TimingConfig.AutoDropTime,
			DropperData.IsLocalOwner
		)

		local function RefreshCandyState(): ()
			local ModelName: string = _GetStringAttribute(DropperData.Plot, Keys.CandyModel, EMPTY_STRING)
			TapData.HasCandy = ModelName ~= EMPTY_STRING
		end

		DropperData.Plot:GetAttributeChangedSignal(Keys.CandyModel):Connect(function(): ()
			RefreshCandyState()
		end)
		RefreshCandyState()

		-- Tap hover/click using Hitbox inside each Tap.
		local TapHitbox: BasePart? = _FindHitbox(TapModel)
		if not TapHitbox then
			_Debug("Hitbox missing in Tap %s (children: %s)", TapModel.Name, _DescribeChildren(TapModel))
		else
			if not DropperData.IsLocalOwner then
				_SetQueryMask(TapModel, {})
				continue
			end
			TapHitbox.CanCollide = false
			TapHitbox.CanTouch = false
			TapHitbox.CanQuery = true
			TapHitbox.Color = Color3.fromRGB(255, 255, 255)
			TapHitbox.Transparency = 1
			TapHitbox.LocalTransparencyModifier = 1
			TapData.Hitbox = TapHitbox
			_SetQueryMask(TapModel, { [TapHitbox] = true })

			local TapDetector: ClickDetector = TapHitbox:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
			TapDetector.MaxActivationDistance = MAX_ACTIVATION_DISTANCE
			TapDetector.CursorIcon = "rbxassetid://96499340217478"
			TapDetector.Parent = TapHitbox
			TapData.HoverDetector = TapDetector

			TapDetector.MouseHoverEnter:Connect(function(): ()
				_SetActiveHoverTap(TapData, DropperData)
				_SetDropperHover(DropperData, true)
				_ClearTapPreview(TapData)
				if not TapData.HasCandy then
					local ToolInstance: Tool? = _GetEquippedTool()
					if ToolInstance then
						local CandyName: string? = _GetCandyNameFromTool(ToolInstance)
						if CandyName and TapData.CanPosition then
							_ShowTapPreview(TapData, CandyName, TapData.CanPosition.CFrame, DropperData.Model.Parent or DropperData.Model)
						end
					end
				end
			end)

			TapDetector.MouseHoverLeave:Connect(function(): ()
				_SetDropperHover(DropperData, false)
				_ClearTapPreview(TapData)
				_ClearActiveHoverTap(TapData)
				_ClearActiveHoverDropper(DropperData)
			end)

			TapDetector.MouseClick:Connect(function(): ()
				_ClearTapPreview(TapData)
				if TapData.HasCandy then
					_FlashDropper(DropperData, DROPPER_REMOVE_COLOR)
					_PlayDropperClickScale(DropperData, DropperData.BaseScale * CLICK_SHRINK_SCALE)
					Packets.Dropper:Fire(ACTION_REMOVE_CANDY, { DropperData.SlotId, TapData.TapId })
					return
				end

				local ToolInstance: Tool? = _GetEquippedTool()
				if not ToolInstance then
					_FlashDropper(DropperData, DROPPER_REMOVE_COLOR)
					_PlayDropperClickScale(DropperData, DropperData.BaseScale * CLICK_SHRINK_SCALE)
					return
				end

				local CandyName: string? = _GetCandyNameFromTool(ToolInstance)
				if not CandyName then
					_FlashDropper(DropperData, DROPPER_REMOVE_COLOR)
					_PlayDropperClickScale(DropperData, DropperData.BaseScale * CLICK_SHRINK_SCALE)
					return
				end

				_FlashDropper(DropperData, DROPPER_PLACE_COLOR)
				_PlayDropperClickScale(DropperData, _GetReturnScale(DropperData) + CLICK_BOUNCE_SCALE)
				Packets.Dropper:Fire(ACTION_PLACE_CANDY, { DropperData.SlotId, TapData.TapId })
			end)
		end
	end

	DropperData.Taps = TapDataMap
end

local function _SetupDropperHover(DropperData: DropperVisual): ()
	local HoverPart: BasePart? = _FindHitbox(DropperData.Model)

	if not HoverPart then
		_Debug("Hitbox missing for %s (children: %s)", DropperData.Model.Name, _DescribeChildren(DropperData.Model))
		return
	end
	HoverPart.CanCollide = false
	HoverPart.CanTouch = false
	HoverPart.CanQuery = true
	HoverPart.Transparency = 1
	HoverPart.LocalTransparencyModifier = 1
	local Allowed: { [Instance]: boolean } = { [HoverPart] = true }
	if DropperData.ButtonPart then
		Allowed[DropperData.ButtonPart] = true
	end
	_SetQueryMask(DropperData.Model, Allowed)

	_EnsureDropperHighlight(DropperData)

	local ExistingDetector: ClickDetector? = HoverPart:FindFirstChildOfClass("ClickDetector")
	local Detector: ClickDetector = ExistingDetector or Instance.new("ClickDetector")
	Detector.MaxActivationDistance = MAX_ACTIVATION_DISTANCE
	Detector.CursorIcon = "rbxassetid://96499340217478"
	Detector.Parent = HoverPart
	DropperData.HoverDetector = Detector
	if DEBUG_HOVER then
		_Debug(
			"Hover detector ready for %s (part=%s, maxDist=%.1f)",
			DropperData.Model.Name,
			_DescribeInstance(HoverPart),
			MAX_ACTIVATION_DISTANCE
		)
	end

	Detector.MouseHoverEnter:Connect(function(): ()
		if DEBUG_HOVER then
			_Debug("MouseHoverEnter on %s", DropperData.Model.Name)
		end
		_SetActiveHoverDropper(DropperData)
		_SetDropperHover(DropperData, true)
		_ClearDropperPreview(DropperData)
		if not DropperData.HasCandy then
			local ToolInstance: Tool? = _GetEquippedTool()
			if ToolInstance then
				local CandyName: string? = _GetCandyNameFromTool(ToolInstance)
				if CandyName then
					local PreviewCFrame: CFrame = if DropperData.CanPosition then DropperData.CanPosition.CFrame else DropperData.Model:GetPivot()
					_ShowDropperPreview(DropperData, CandyName, PreviewCFrame)
				end
			end
		end
	end)

	Detector.MouseHoverLeave:Connect(function(): ()
		if DEBUG_HOVER then
			_Debug("MouseHoverLeave on %s", DropperData.Model.Name)
		end
		_SetDropperHover(DropperData, false)
		_ClearDropperPreview(DropperData)
		_ClearActiveHoverDropper(DropperData)
	end)

	Detector.MouseClick:Connect(function(): ()
		_ClearDropperPreview(DropperData)
		if DEBUG_HOVER then
			_Debug("MouseClick on %s (slot %s)", DropperData.Model.Name, DropperData.SlotId)
		end

		if DropperData.HasCandy then
			if DEBUG_HOVER then
				_Debug("Click -> remove candy")
			end
			_FlashDropper(DropperData, DROPPER_REMOVE_COLOR)
			_PlayDropperClickScale(DropperData, DropperData.BaseScale * CLICK_SHRINK_SCALE)
			Packets.Dropper:Fire(ACTION_REMOVE_CANDY, { DropperData.SlotId })
			return
		end

		local ToolInstance: Tool? = _GetEquippedTool()
		if not ToolInstance then
			if DEBUG_HOVER then
				_Debug("Click -> no tool equipped")
			end
			_FlashDropper(DropperData, DROPPER_REMOVE_COLOR)
			_PlayDropperClickScale(DropperData, DropperData.BaseScale * CLICK_SHRINK_SCALE)
			return
		end

		local CandyName: string? = _GetCandyNameFromTool(ToolInstance)
		if not CandyName then
			if DEBUG_HOVER then
				_Debug("Click -> tool not matched to candy (%s)", ToolInstance.Name)
			end
			_FlashDropper(DropperData, DROPPER_REMOVE_COLOR)
			_PlayDropperClickScale(DropperData, DropperData.BaseScale * CLICK_SHRINK_SCALE)
			return
		end

		if DEBUG_HOVER then
			_Debug("Click -> place candy %s", CandyName)
		end
		_FlashDropper(DropperData, DROPPER_PLACE_COLOR)
		_PlayDropperClickScale(DropperData, _GetReturnScale(DropperData) + CLICK_BOUNCE_SCALE)
		Packets.Dropper:Fire(ACTION_PLACE_CANDY, { DropperData.SlotId })
	end)
end

local function _SetupDropperButton(DropperData: DropperVisual): ()
	local ButtonPart: BasePart? = DropperData.ButtonPart
	if not ButtonPart then
		return
	end

	local Detector: ClickDetector? = ButtonPart:FindFirstChildOfClass("ClickDetector")
	if not Detector then
		return
	end
	local Keys: CandyAttributeKeys = _BuildCandyAttributeKeys(DropperData.SlotId, nil)
	ButtonPart.Size = BUTTON_BASE_SIZE
	ButtonPart:SetAttribute("IsHovering", false)
	ButtonPart:SetAttribute("IsCooldown", false)

	local ButtonHighlight: Highlight = Instance.new("Highlight")
	ButtonHighlight.FillColor = BUTTON_READY_COLOR
	ButtonHighlight.FillTransparency = 1
	ButtonHighlight.OutlineTransparency = 1
	ButtonHighlight.Adornee = ButtonPart
	ButtonHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	ButtonHighlight.Enabled = false
	ButtonHighlight.Parent = ButtonPart
	_SetButtonHighlightState(ButtonHighlight, false)

	Detector.MouseClick:Connect(function(): ()
		if _IsButtonOnCooldown(ButtonPart) then
			return
		end

		local ModelName: string = _GetStringAttribute(DropperData.Plot, Keys.CandyModel, EMPTY_STRING)
		if ModelName == EMPTY_STRING then
			_PlayButtonClick(ButtonPart)
			_FlashDropper(DropperData, DROPPER_REMOVE_COLOR)
			_PlayDropperClickScale(DropperData, _GetReturnScale(DropperData) + CLICK_BOUNCE_SCALE)
			return
		end

		local Level: number = _GetNumberAttribute(DropperData.Plot, Keys.CandyLevel, DEFAULT_NUMBER)
		local MaxLevel: number = _GetCandyMaxLevelForBillboard(ModelName)
		if MaxLevel > 0 and Level >= MaxLevel then
			_PlayButtonClick(ButtonPart)
			_FlashDropper(DropperData, DROPPER_REMOVE_COLOR)
			_PlayDropperClickScale(DropperData, _GetReturnScale(DropperData) + CLICK_BOUNCE_SCALE)
			return
		end

		_PlayButtonClick(ButtonPart)
		local CooldownEnd: number = os.clock() + TimingConfig.ManualDebounce
		_ButtonCooldownUntil[ButtonPart] = CooldownEnd
		ButtonPart:SetAttribute("IsCooldown", true)
		_SetButtonHighlightState(ButtonHighlight, true)
		ButtonHighlight.Enabled = true
		TweenModule:Tween(ButtonHighlight, 0.1, "Sine", "Out", { FillTransparency = 0.8 }, 0, false, nil)

		Packets.Dropper:Fire(ACTION_DROP, { DropperData.SlotId })

		task.delay(TimingConfig.ManualDebounce, function(): ()
			if _ButtonCooldownUntil[ButtonPart] ~= CooldownEnd then
				return
			end
			_ButtonCooldownUntil[ButtonPart] = nil
			ButtonPart:SetAttribute("IsCooldown", false)
			_SetButtonHighlightState(ButtonHighlight, false)
			if ButtonPart:GetAttribute("IsHovering") then
				ButtonHighlight.Enabled = true
				TweenModule:Tween(ButtonHighlight, 0.1, "Sine", "Out", { FillTransparency = 0.8 }, 0, false, nil)
			else
				TweenModule:Tween(ButtonHighlight, 0.1, "Sine", "Out", { FillTransparency = 1 }, 0, false, function(): ()
					ButtonHighlight.Enabled = false
				end)
			end
		end)
	end)

	Detector.MouseHoverEnter:Connect(function(): ()
		ButtonPart:SetAttribute("IsHovering", true)
		_TweenButtonSize(ButtonPart, BUTTON_BASE_SIZE * BUTTON_HOVER_SCALE, BUTTON_HOVER_TIME, nil)
		_SetButtonHighlightState(ButtonHighlight, _IsButtonOnCooldown(ButtonPart))
		ButtonHighlight.Enabled = true
		TweenModule:Tween(ButtonHighlight, 0.1, "Sine", "Out", { FillTransparency = 0.8 }, 0, false, nil)
	end)

	Detector.MouseHoverLeave:Connect(function(): ()
		ButtonPart:SetAttribute("IsHovering", false)
		_TweenButtonSize(ButtonPart, BUTTON_BASE_SIZE, BUTTON_HOVER_TIME, nil)
		if _IsButtonOnCooldown(ButtonPart) then
			_SetButtonHighlightState(ButtonHighlight, true)
			ButtonHighlight.Enabled = true
			TweenModule:Tween(ButtonHighlight, 0.1, "Sine", "Out", { FillTransparency = 0.8 }, 0, false, nil)
			return
		end
		TweenModule:Tween(ButtonHighlight, 0.1, "Sine", "Out", { FillTransparency = 1 }, 0, false, function(): ()
			ButtonHighlight.Enabled = false
		end)
	end)
end

local function _CloneDropperModel(
	SlotContainer: Instance,
	ParentContainer: Instance,
	AssetName: string,
	SlotPartName: string,
	RotationDegrees: number
): (Model?, BasePart?)
	local AssetsRoot: Instance = ReplicatedStorage:WaitForChild(ASSETS_ROOT_NAME)
	local AssetsFolder: Instance = AssetsRoot:WaitForChild(AssetsConfig.DroppersFolder)

	local Asset: Instance? = AssetsFolder:FindFirstChild(AssetName)
	if not Asset or not Asset:IsA("Model") then
		_Debug("Dropper asset missing: %s", AssetName)
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
	SlotContainer: Instance,
	ParentContainer: Instance,
	SlotId: string,
	AssetName: string,
	SlotPartName: string,
	RotationDegrees: number,
	DropperType: string,
	IsLocalOwner: boolean
): DropperVisual?
	local Clone: Model?
	local SlotPart: BasePart?
	Clone, SlotPart = _CloneDropperModel(SlotContainer, ParentContainer, AssetName, SlotPartName, RotationDegrees)
	if not Clone then
		return nil
	end

	local MainPart: BasePart? = _FindDescendant(Clone, MAIN_PART_NAME) :: BasePart?
	local ButtonPart: BasePart? = _FindDescendant(Clone, BUTTON_PART_NAME) :: BasePart?
	if not MainPart then
		_Debug("Main part missing in %s", Clone.Name)
	end

	local BaseScale: number = Clone:GetScale()

	local DropperData: DropperVisual = {
		Model = Clone,
		Plot = Plot,
		SlotId = SlotId,
		Type = DropperType,
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

	if DropperData.IsLocalOwner then
		if DropperType == DropperConfig.TypeNormal then
			_SetupDropperHover(DropperData)
			_SetupDropperButton(DropperData)
		end
	else
		_SetQueryMask(DropperData.Model, {})
	end

	return DropperData
end

local function _SetupPlotVisual(Plot: Model): ()
	if _PlotVisuals[Plot] then
		return
	end
	if not _HasPlotOwner(Plot) then
		_WatchPlotOwner(Plot)
		return
	end
	local IsLocalOwner: boolean = _IsPlotOwnedByLocalPlayer(Plot)
	local NormalRotation: number = _GetPlotRotation(Plot, DropperConfig.SlotLong, DropperConfig.RotationNormal)
	local AutoRotation: number = _GetPlotRotation(Plot, DropperConfig.SlotWide, DropperConfig.RotationAuto)

	local DroppersFolder: Instance? = Plot:FindFirstChild(AssetsConfig.DroppersFolder)
	if not DroppersFolder then
		_Debug("Droppers folder missing in plot %s", Plot.Name)
		return
	end

	local LongSlotFolder: Instance? = _FindSlotContainer(DroppersFolder, DropperConfig.SlotLong, LONG_SLOT_PART_NAME)
	local WideSlotFolder: Instance? = _FindSlotContainer(DroppersFolder, DropperConfig.SlotWide, WIDE_SLOT_PART_NAME)

	_Debug(
		"Plot %s, Slots: Long=%s Wide=%s",
		Plot.Name,
		_DescribeInstance(LongSlotFolder),
		_DescribeInstance(WideSlotFolder)
	)

	local PlotData: PlotVisual = {
		Plot = Plot,
		DroppersFolder = DroppersFolder,
		LongSlot = LongSlotFolder,
		WideSlot = WideSlotFolder,
		DropperLong = nil,
		DropperWide = nil,
	}

	if LongSlotFolder then
		local LongParent: Instance = _ResolveSlotParent(LongSlotFolder, DroppersFolder)
		_Debug("Long slot parent: %s", _DescribeInstance(LongParent))
		PlotData.DropperLong = _SetupDropperVisual(
			Plot,
			LongSlotFolder,
			LongParent,
			DropperConfig.SlotLong,
			AssetsConfig.DropperModel,
			LONG_SLOT_PART_NAME,
			NormalRotation,
			DropperConfig.TypeNormal,
			IsLocalOwner
		)

		if not PlotData.DropperLong then
			_WatchSlotPart(LongSlotFolder, LONG_SLOT_PART_NAME, function(): ()
				if PlotData.DropperLong then
					return
				end
				PlotData.DropperLong = _SetupDropperVisual(
					Plot,
					LongSlotFolder,
					LongParent,
					DropperConfig.SlotLong,
					AssetsConfig.DropperModel,
					LONG_SLOT_PART_NAME,
					NormalRotation,
					DropperConfig.TypeNormal,
					IsLocalOwner
				)
				if PlotData.DropperLong then
					_SetupNormalDropper(PlotData.DropperLong, LongParent)
				end
			end)
		end
	end

	if WideSlotFolder then
		local WideParent: Instance = _ResolveSlotParent(WideSlotFolder, DroppersFolder)
		_Debug("Wide slot parent: %s", _DescribeInstance(WideParent))
		PlotData.DropperWide = _SetupDropperVisual(
			Plot,
			WideSlotFolder,
			WideParent,
			DropperConfig.SlotWide,
			AssetsConfig.Dropper2Model,
			WIDE_SLOT_PART_NAME,
			AutoRotation,
			DropperConfig.TypeAuto,
			IsLocalOwner
		)

		if not PlotData.DropperWide then
			_WatchSlotPart(WideSlotFolder, WIDE_SLOT_PART_NAME, function(): ()
				if PlotData.DropperWide then
					return
				end
				PlotData.DropperWide = _SetupDropperVisual(
					Plot,
					WideSlotFolder,
					WideParent,
					DropperConfig.SlotWide,
					AssetsConfig.Dropper2Model,
					WIDE_SLOT_PART_NAME,
					AutoRotation,
					DropperConfig.TypeAuto,
					IsLocalOwner
				)
				if PlotData.DropperWide then
					_SetupAutoDropper(PlotData.DropperWide, WideParent)
				end
			end)
		end
	end

	if PlotData.DropperWide and WideSlotFolder then
		local WideParent: Instance = _ResolveSlotParent(WideSlotFolder, DroppersFolder)
		_SetupAutoDropper(PlotData.DropperWide, WideParent)
	end

	if PlotData.DropperLong and LongSlotFolder then
		local LongParent: Instance = _ResolveSlotParent(LongSlotFolder, DroppersFolder)
		_SetupNormalDropper(PlotData.DropperLong, LongParent)
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
			_RefreshHoverPreview()
		end
	end)

	_ToolRemovedConnection = Character.ChildRemoved:Connect(function(Child: Instance): ()
		if Child:IsA("Tool") then
			_RefreshHoverPreview()
		end
	end)
end

--\\ PUBLIC FUNCTIONS \\ -- TR
function module:Init(): ()
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

	task.spawn(function(): ()
		local MapInstance: Instance = workspace:WaitForChild(MAP_FOLDER_NAME)
		if not (MapInstance:IsA("Folder") or MapInstance:IsA("Model")) then
			return
		end

		local PlotsInstance: Instance = MapInstance:WaitForChild(PLOTS_FOLDER_NAME)
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


