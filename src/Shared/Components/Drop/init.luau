--!strict

--\\ SERVICES \\ -- TR
local RunService: RunService = game:GetService("RunService")
local Workspace: Workspace = workspace

--\\ TYPES \\ -- TR
type DropTemplate = Model | BasePart
type DropTemplateList = { DropTemplate }
type DropAmountList = { number }
type DropTemplates = DropTemplate | DropTemplateList
type DropAmounts = number | DropAmountList

type DropStateName = "Dropping" | "Floating" | "Magnet"

type DropItemState = {
	ItemId: number,
	Instance: DropTemplate,
	Template: DropTemplate,
	StartCFrame: CFrame,
	GroundCFrame: CFrame,
	Rotation: CFrame,
	SpawnTime: number,
	State: DropStateName,
	FloatPhase: number,
	LandedTime: number,
}

type DropClientState = {
	Duration: number,
	StartTime: number,
	ActiveCount: number,
	Items: { [number]: DropItemState },
	Collected: { [number]: boolean },
	TargetRoot: BasePart?,
}

type DropPool = { [Instance]: { DropTemplate } }

type ModuleType = {
	Spawn: (
		self: ModuleType,
		Origin: BasePart,
		Templates: DropTemplates,
		Duration: number,
		Amounts: DropAmounts,
		TargetCharacter: Model?,
		SpawnRadius: number?
	) -> (),
}

--\\ CONSTANTS \\ -- TR
local STATE_DROPPING: DropStateName = "Dropping"
local STATE_FLOATING: DropStateName = "Floating"
local STATE_MAGNET: DropStateName = "Magnet"

local SPAWN_RADIUS: number = 4
local SPAWN_HEIGHT: number = 2
local DROP_TIME: number = 0.7
local DROP_ARC_HEIGHT: number = 6

local FLOAT_AMPLITUDE: number = 0.5
local FLOAT_SPEED: number = 2

local MAGNET_RANGE: number = 10
local MAGNET_SPEED: number = 22
local COLLECT_DISTANCE: number = 1.2
local MAGNET_DELAY: number = 0.1

local GROUND_RAY_DISTANCE: number = 60
local GROUND_OFFSET: number = 0.5

local MAX_DELTA_TIME: number = 0.1

local TWO_PI: number = math.pi * 2
local ZERO: number = 0
local ONE: number = 1

local TRAIL_NAME: string = "DropTrail"
local TRAIL_ATTACHMENT_0: string = "DropTrailAttachment0"
local TRAIL_ATTACHMENT_1: string = "DropTrailAttachment1"
local TRAIL_TEXTURE: string = "rbxassetid://284205403"
local TRAIL_LIFETIME: number = 0.22
local TRAIL_MIN_LENGTH: number = 0.1
local TRAIL_MAX_LENGTH: number = 0.6
local TRAIL_TRANSPARENCY_START: number = 0
local TRAIL_TRANSPARENCY_END: number = 1
local TRAIL_OFFSET: number = 0.6

--\\ CLIENT STATE \\ -- TR
local ActiveDrops: { [number]: DropClientState } = {}
local ActiveDropCount: number = ZERO
local DropPools: DropPool = {}
local RenderConnection: RBXScriptConnection? = nil
local NextDropId: number = ONE

local RaycastParamsObject: RaycastParams = RaycastParams.new()
RaycastParamsObject.FilterType = Enum.RaycastFilterType.Exclude
RaycastParamsObject.RespectCanCollide = true

local RaycastFilter: { Instance } = table.create(ZERO)
RaycastParamsObject.FilterDescendantsInstances = RaycastFilter

--\\ PRIVATE FUNCTIONS \\ -- TR
local function _FindFirstBasePart(Container: Instance): BasePart?
	local Descendants: { Instance } = Container:GetDescendants()
	for Index: number, Descendant: Instance in Descendants do
		if Descendant:IsA("BasePart") then
			return Descendant
		end
	end
	return nil
end

local function _GetRoot(Template: DropTemplate): BasePart?
	if Template:IsA("BasePart") then
		return Template
	end

	local ModelTemplate: Model = Template
	local PrimaryPart: BasePart? = ModelTemplate.PrimaryPart
	if PrimaryPart then
		return PrimaryPart
	end

	local FirstPart: BasePart? = _FindFirstBasePart(ModelTemplate)
	if not FirstPart then
		return nil
	end

	ModelTemplate.PrimaryPart = FirstPart
	return FirstPart
end

local function _EnsureTrail(Part: BasePart): ()
	local Attachment0: Attachment? = Part:FindFirstChild(TRAIL_ATTACHMENT_0)
	if not Attachment0 then
		local NewAttachment0: Attachment = Instance.new("Attachment")
		NewAttachment0.Name = TRAIL_ATTACHMENT_0
		NewAttachment0.Parent = Part
		Attachment0 = NewAttachment0
	end

	local Attachment1: Attachment? = Part:FindFirstChild(TRAIL_ATTACHMENT_1)
	if not Attachment1 then
		local NewAttachment1: Attachment = Instance.new("Attachment")
		NewAttachment1.Name = TRAIL_ATTACHMENT_1
		NewAttachment1.Parent = Part
		Attachment1 = NewAttachment1
	end

	local Offset: number = math.max(Part.Size.Z * 0.5, TRAIL_OFFSET)
	Attachment0.Position = Vector3.new(ZERO, ZERO, -Offset)
	Attachment1.Position = Vector3.new(ZERO, ZERO, Offset)

	local Trail: Trail? = Part:FindFirstChild(TRAIL_NAME)
	if Trail then
		Trail.Attachment0 = Attachment0
		Trail.Attachment1 = Attachment1
		return
	end

	local NewTrail: Trail = Instance.new("Trail")
	NewTrail.Name = TRAIL_NAME
	NewTrail.Attachment0 = Attachment0
	NewTrail.Attachment1 = Attachment1
	NewTrail.Lifetime = TRAIL_LIFETIME
	NewTrail.Texture = TRAIL_TEXTURE
	NewTrail.Transparency = NumberSequence.new(TRAIL_TRANSPARENCY_START, TRAIL_TRANSPARENCY_END)
	NewTrail.WidthScale = NumberSequence.new(TRAIL_MAX_LENGTH, TRAIL_MIN_LENGTH)
	NewTrail.Parent = Part
end

local function _PrepareInstance(Template: DropTemplate): ()
	if Template:IsA("BasePart") then
		local Part: BasePart = Template
		Part.Anchored = true
		Part.CanCollide = false
		Part.CanQuery = false
		Part.CanTouch = false
		_EnsureTrail(Part)
		return
	end

	local ModelTemplate: Model = Template
	local Root: BasePart? = _GetRoot(ModelTemplate)
	local Descendants: { Instance } = ModelTemplate:GetDescendants()
	for Index: number, Descendant: Instance in Descendants do
		if Descendant:IsA("BasePart") then
			local Part: BasePart = Descendant
			Part.Anchored = true
			Part.CanCollide = false
			Part.CanQuery = false
			Part.CanTouch = false
		end
	end

	if Root then
		_EnsureTrail(Root)
	end
end

local function _GetCurvePosition(StartPosition: Vector3, EndPosition: Vector3, Height: number, Alpha: number): Vector3
	local InvertedAlpha: number = ONE - Alpha
	local PositionX: number = InvertedAlpha * StartPosition.X + Alpha * EndPosition.X
	local PositionY: number = InvertedAlpha * StartPosition.Y
		+ Alpha * EndPosition.Y
		+ math.sin(Alpha * math.pi) * Height
	local PositionZ: number = InvertedAlpha * StartPosition.Z + Alpha * EndPosition.Z
	return Vector3.new(PositionX, PositionY, PositionZ)
end

local function _GetCircleOffset(Index: number, Amount: number, Radius: number): Vector3
	local SafeAmount: number = math.max(Amount, ONE)
	local Ratio: number = (Index - ONE) / SafeAmount
	local Angle: number = Ratio * TWO_PI
	return Vector3.new(math.cos(Angle) * Radius, ZERO, math.sin(Angle) * Radius)
end

local function _GetGroundCFrame(StartPosition: Vector3): CFrame
	local Direction: Vector3 = Vector3.new(ZERO, -GROUND_RAY_DISTANCE, ZERO)
	local RayResult: RaycastResult? = Workspace:Raycast(StartPosition, Direction, RaycastParamsObject)
	if not RayResult then
		return CFrame.new(StartPosition)
	end

	local GroundPosition: Vector3 = RayResult.Position + Vector3.new(ZERO, GROUND_OFFSET, ZERO)
	return CFrame.new(GroundPosition)
end

local function _GetDropPool(Template: DropTemplate): { DropTemplate }
	local Pool: { DropTemplate }? = DropPools[Template]
	if Pool then
		return Pool
	end

	local NewPool: { DropTemplate } = table.create(ZERO)
	DropPools[Template] = NewPool
	return NewPool
end

local function _AcquireInstance(Template: DropTemplate): DropTemplate
	local Pool: { DropTemplate } = _GetDropPool(Template)
	local PoolSize: number = #Pool
	if PoolSize > ZERO then
		local PooledInstance: DropTemplate = Pool[PoolSize]
		Pool[PoolSize] = nil
		return PooledInstance
	end

	local NewInstance: DropTemplate = Template:Clone()
	_PrepareInstance(NewInstance)
	return NewInstance
end

local function _ReleaseInstance(Template: DropTemplate, Instance: DropTemplate): ()
	Instance.Parent = nil
	local Pool: { DropTemplate } = _GetDropPool(Template)
	local PoolIndex: number = #Pool + ONE
	Pool[PoolIndex] = Instance
end

local function _StopRenderConnection(): ()
	if not RenderConnection then
		return
	end

	RenderConnection:Disconnect()
	RenderConnection = nil
end

local function _CollectItem(DropState: DropClientState, ItemId: number): ()
	if DropState.Collected[ItemId] then
		return
	end

	local ItemState: DropItemState? = DropState.Items[ItemId]
	DropState.Collected[ItemId] = true
	if not ItemState then
		return
	end

	DropState.Items[ItemId] = nil
	DropState.ActiveCount -= ONE
	_ReleaseInstance(ItemState.Template, ItemState.Instance)
end

local function _ClearDrop(DropId: number): ()
	local DropState: DropClientState? = ActiveDrops[DropId]
	if not DropState then
		return
	end

	for ItemId: number, ItemState: DropItemState in DropState.Items do
		DropState.Collected[ItemId] = true
		_ReleaseInstance(ItemState.Template, ItemState.Instance)
	end

	ActiveDrops[DropId] = nil
	ActiveDropCount -= ONE
	if ActiveDropCount > ZERO then
		return
	end

	_StopRenderConnection()
end

local function _UpdateItem(
	DropState: DropClientState,
	ItemState: DropItemState,
	DeltaTime: number,
	CurrentTime: number
): ()
	if ItemState.State == STATE_DROPPING then
		local ElapsedTime: number = CurrentTime - ItemState.SpawnTime
		local Alpha: number = math.clamp(ElapsedTime / DROP_TIME, ZERO, ONE)
		local StartPosition: Vector3 = ItemState.StartCFrame.Position
		local GroundPosition: Vector3 = ItemState.GroundCFrame.Position
		local CurvePosition: Vector3 = _GetCurvePosition(StartPosition, GroundPosition, DROP_ARC_HEIGHT, Alpha)
		local CurveCFrame: CFrame = CFrame.new(CurvePosition) * ItemState.Rotation
		ItemState.Instance:PivotTo(CurveCFrame)
		if Alpha < ONE then
			return
		end

		ItemState.State = STATE_FLOATING
		ItemState.LandedTime = CurrentTime
		return
	end

	if ItemState.State == STATE_FLOATING then
		local FloatOffset: number = math.sin((CurrentTime + ItemState.FloatPhase) * FLOAT_SPEED) * FLOAT_AMPLITUDE
		local FloatPosition: Vector3 = ItemState.GroundCFrame.Position + Vector3.new(ZERO, FloatOffset, ZERO)
		local FloatCFrame: CFrame = CFrame.new(FloatPosition) * ItemState.Rotation
		ItemState.Instance:PivotTo(FloatCFrame)
		local TargetRoot: BasePart? = DropState.TargetRoot
		if not TargetRoot then
			return
		end

		if CurrentTime - ItemState.LandedTime < MAGNET_DELAY then
			return
		end

		local FloatDistance: number = (TargetRoot.Position - FloatPosition).Magnitude
		if FloatDistance > MAGNET_RANGE then
			return
		end

		ItemState.State = STATE_MAGNET
		return
	end

	if ItemState.State ~= STATE_MAGNET then
		return
	end

	local TargetRoot: BasePart? = DropState.TargetRoot
	if not TargetRoot then
		ItemState.State = STATE_FLOATING
		return
	end

	local CurrentPosition: Vector3 = ItemState.Instance:GetPivot().Position
	local Direction: Vector3 = TargetRoot.Position - CurrentPosition
	local MagnetDistance: number = Direction.Magnitude
	if MagnetDistance <= COLLECT_DISTANCE then
		_CollectItem(DropState, ItemState.ItemId)
		return
	end

	local StepDistance: number = MAGNET_SPEED * DeltaTime
	local MoveVector: Vector3 = Direction.Unit * StepDistance
	if StepDistance >= MagnetDistance then
		MoveVector = Direction
	end

	local MagnetCFrame: CFrame = CFrame.new(CurrentPosition + MoveVector) * ItemState.Rotation
	ItemState.Instance:PivotTo(MagnetCFrame)
end

local function _UpdateDrop(DropState: DropClientState, DeltaTime: number, CurrentTime: number): ()
	for ItemId: number, ItemState: DropItemState in DropState.Items do
		_UpdateItem(DropState, ItemState, DeltaTime, CurrentTime)
	end
end

local function _UpdateAll(DeltaTime: number): ()
	local CurrentTime: number = os.clock()
	local ClearQueue: { [number]: number } = table.create(ZERO)

	for DropId: number, DropState: DropClientState in ActiveDrops do
		local Elapsed: number = CurrentTime - DropState.StartTime
		if Elapsed >= DropState.Duration then
			local Index: number = #ClearQueue + ONE
			ClearQueue[Index] = DropId
			continue
		end

		_UpdateDrop(DropState, DeltaTime, CurrentTime)
		if DropState.ActiveCount <= ZERO then
			local Index: number = #ClearQueue + ONE
			ClearQueue[Index] = DropId
		end
	end

	for Index: number, DropId: number in ClearQueue do
		_ClearDrop(DropId)
	end

	if ActiveDropCount > ZERO then
		return
	end

	_StopRenderConnection()
end

local function _BuildTemplateQueue(Templates: DropTemplates, Amounts: DropAmounts): { DropTemplate }
	if typeof(Templates) ~= "table" then
		local Count: number = ONE
		if typeof(Amounts) == "number" then
			Count = math.max(math.floor(Amounts), ZERO)
		end
		local Queue: { DropTemplate } = table.create(Count)
		local Index: number = ONE
		while Index <= Count do
			Queue[Index] = Templates
			Index += ONE
		end
		return Queue
	end

	local TemplateList: DropTemplateList = Templates
	if typeof(Amounts) ~= "table" then
		local DefaultCount: number = ZERO
		if typeof(Amounts) == "number" then
			DefaultCount = math.max(math.floor(Amounts), ZERO)
		end
		local Total: number = #TemplateList * DefaultCount
		local Queue: { DropTemplate } = table.create(Total)
		local Index: number = ONE
		local TemplateIndex: number = ONE
		while TemplateIndex <= #TemplateList do
			local CountIndex: number = ONE
			while CountIndex <= DefaultCount do
				Queue[Index] = TemplateList[TemplateIndex]
				Index += ONE
				CountIndex += ONE
			end
			TemplateIndex += ONE
		end
		return Queue
	end

	local AmountList: DropAmountList = Amounts
	local Total: number = ZERO
	local CountIndex: number = ONE
	while CountIndex <= #AmountList do
		Total += math.max(math.floor(AmountList[CountIndex]), ZERO)
		CountIndex += ONE
	end

	local Queue: { DropTemplate } = table.create(Total)
	local Index: number = ONE
	local TemplateIndex: number = ONE
	while TemplateIndex <= #TemplateList do
		local Template: DropTemplate = TemplateList[TemplateIndex]
		local TemplateCount: number = ZERO
		if AmountList[TemplateIndex] then
			TemplateCount = math.max(math.floor(AmountList[TemplateIndex]), ZERO)
		end
		local FillIndex: number = ONE
		while FillIndex <= TemplateCount do
			Queue[Index] = Template
			Index += ONE
			FillIndex += ONE
		end
		TemplateIndex += ONE
	end

	return Queue
end

local function _EnsureRenderConnection(): ()
	if RenderConnection then
		return
	end

	RenderConnection = RunService.RenderStepped:Connect(function(DeltaTime: number)
		local ClampedDelta: number = math.clamp(DeltaTime, ZERO, MAX_DELTA_TIME)
		_UpdateAll(ClampedDelta)
	end)
end

local function _BuildDropState(
	Origin: BasePart,
	Templates: DropTemplates,
	Duration: number,
	Amounts: DropAmounts,
	TargetCharacter: Model?,
	SpawnRadius: number
): DropClientState
	local TemplateQueue: { DropTemplate } = _BuildTemplateQueue(Templates, Amounts)
	local Amount: number = #TemplateQueue
	local Items: { [number]: DropItemState } = table.create(Amount)
	local Collected: { [number]: boolean } = table.create(Amount, false)
	local StartTime: number = os.clock()
	local OriginCFrame: CFrame = Origin:GetPivot()
	local TargetRoot: BasePart? = nil

	if TargetCharacter then
		local PrimaryPart: BasePart? = TargetCharacter.PrimaryPart
		if PrimaryPart then
			TargetRoot = PrimaryPart
		else
			local HumanoidRootPart: Instance? = TargetCharacter:FindFirstChild("HumanoidRootPart")
			if HumanoidRootPart and HumanoidRootPart:IsA("BasePart") then
				TargetRoot = HumanoidRootPart
			end
		end
	end

	local Index: number = ONE
	while Index <= Amount do
		local Offset: Vector3 = _GetCircleOffset(Index, Amount, SpawnRadius)
		local SpawnOffset: Vector3 = Vector3.new(Offset.X, SPAWN_HEIGHT, Offset.Z)
		local SpawnCFrame: CFrame = OriginCFrame * CFrame.new(SpawnOffset)
		local GroundCFrame: CFrame = _GetGroundCFrame(SpawnCFrame.Position)
		local Template: DropTemplate = TemplateQueue[Index]
		local Instance: DropTemplate = _AcquireInstance(Template)
		Instance.Parent = workspace:WaitForChild("Map"):FindFirstChild("Debris")
		Instance:PivotTo(SpawnCFrame)

		local FloatPhase: number = (Index / math.max(Amount, ONE)) * TWO_PI
		local ItemState: DropItemState = {
			ItemId = Index,
			Instance = Instance,
			Template = Template,
			StartCFrame = SpawnCFrame,
			GroundCFrame = GroundCFrame,
			Rotation = SpawnCFrame.Rotation,
			SpawnTime = StartTime,
			State = STATE_DROPPING,
			FloatPhase = FloatPhase,
			LandedTime = StartTime,
		}

		Items[Index] = ItemState
		Index += ONE
	end

	local DropState: DropClientState = {
		Duration = Duration,
		StartTime = StartTime,
		ActiveCount = Amount,
		Items = Items,
		Collected = Collected,
		TargetRoot = TargetRoot,
	}

	return DropState
end

--\\ MODULE \\ -- TR
local Module: ModuleType = {}

function Module:Spawn(
	Origin: BasePart,
	Templates: DropTemplates,
	Duration: number,
	Amounts: DropAmounts,
	TargetCharacter: Model?,
	SpawnRadius: number?
): ()
	if not Origin then
		return
	end

	if not Templates then
		return
	end

	if Duration <= ZERO then
		return
	end

	local RadiusValue: number = SPAWN_RADIUS
	if SpawnRadius then
		RadiusValue = math.max(SpawnRadius, ZERO)
	end

	local TemplateQueue: { DropTemplate } = _BuildTemplateQueue(Templates, Amounts)
	if #TemplateQueue <= ZERO then
		return
	end

	local DropState: DropClientState = _BuildDropState(Origin, Templates, Duration, Amounts, TargetCharacter, RadiusValue)
	local DropId: number = NextDropId
	NextDropId += ONE

	ActiveDrops[DropId] = DropState
	ActiveDropCount += ONE
	_EnsureRenderConnection()
end

return Module
