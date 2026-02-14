--!strict

local module = {}

local PROCESS_STATE_IDLE = "Idle"
local PROCESS_STATE_PROCESSING = "Processing"
local PROCESS_STATE_READY = "Ready"
local DEBUG_STARTMODEL = true

local function _DebugStart(Api: any, Message: string, ...: any): ()
	if not DEBUG_STARTMODEL then
		return
	end
	if Api and Api.Debug then
		Api.Debug("[StartModel] " .. Message, ...)
	end
	print(string.format("[StartModel] " .. Message, ...))
end

local function _FormatSeconds(Seconds: number): string
	local Total: number = math.max(0, math.floor(Seconds + 0.5))
	local Minutes: number = math.floor(Total / 60)
	local Remaining: number = Total % 60
	return string.format("%dm %ds", Minutes, Remaining)
end

local function _GetProcessSeconds(Api: any, Plot: Model, GroupId: string, SlotId: string, SlotConfig: any): number
	local LevelConfig: any = SlotConfig.Upgrades and SlotConfig.Upgrades.Level
	if not LevelConfig or LevelConfig.Mode ~= "Time" then
		return 0
	end

	local LevelKey: string = Api.GetUpgradeKey(GroupId, SlotId, "Level")
	local Level: number = Api.GetNumberAttribute(Plot, LevelKey, Api.DefaultNumber)
	local BaseSeconds: number = if typeof(LevelConfig.BaseTimeSeconds) == "number" then LevelConfig.BaseTimeSeconds else 0
	local Reduction: number = if typeof(LevelConfig.TimeReduction) == "number" then LevelConfig.TimeReduction else 0
	local MinSeconds: number = if typeof(LevelConfig.MinTimeSeconds) == "number" then LevelConfig.MinTimeSeconds else 0
	local Seconds: number = BaseSeconds - (math.max(0, Level - 1) * Reduction)
	if Seconds < MinSeconds then
		Seconds = MinSeconds
	end
	if Seconds < 0 then
		Seconds = 0
	end
	return Seconds
end

local function _GetProcessState(Api: any, Plot: Model, GroupId: string, SlotId: string): string
	local Key: string = Api.GetAttributeKey(GroupId, SlotId, nil, "ProcessState")
	return Api.GetStringAttribute(Plot, Key, PROCESS_STATE_IDLE)
end

local function _GetProcessEnd(Api: any, Plot: Model, GroupId: string, SlotId: string): number
	local Key: string = Api.GetAttributeKey(GroupId, SlotId, nil, "ProcessEnd")
	return Api.GetNumberAttribute(Plot, Key, Api.DefaultNumber)
end

local function _FindStartUi(Root: Instance): (TextButton?, TextButton?, TextLabel?, TextLabel?)
	local StartModel: Instance? = Root:FindFirstChild("StartModel", true)
	if not StartModel then
		return nil, nil, nil, nil
	end

	local Purifier: Instance? = StartModel:FindFirstChild("Purifier", true)
	if not Purifier then
		return nil, nil, nil, nil
	end

	local StartButton: TextButton? = nil
	local ClaimButton: TextButton? = nil
	local TimeLabel: TextLabel? = nil
	local ReadyLabel: TextLabel? = nil

	local StartCandidate: Instance? = Purifier:FindFirstChild("Start", true)
	if StartCandidate and StartCandidate:IsA("TextButton") then
		StartButton = StartCandidate
	end

	local ClaimCandidate: Instance? = Purifier:FindFirstChild("Claim", true)
	if ClaimCandidate and ClaimCandidate:IsA("TextButton") then
		ClaimButton = ClaimCandidate
	end

	local TimeCandidate: Instance? = Purifier:FindFirstChild("Time", true)
	if TimeCandidate and TimeCandidate:IsA("TextLabel") then
		TimeLabel = TimeCandidate
	end

	local ReadyCandidate: Instance? = Purifier:FindFirstChild("Ready", true)
	if ReadyCandidate and ReadyCandidate:IsA("TextLabel") then
		ReadyLabel = ReadyCandidate
	end

	return StartButton, ClaimButton, TimeLabel, ReadyLabel
end

function module.Register(Target: { [string]: any }, MachinesConfig: any): ()
	local Group = MachinesConfig.DoubleDropper
	if Group then
		Target.DoubleDropper = Group
	end
end

function module.SetupSlot(Api: any, DropperData: any, ParentContainer: Instance): ()
	_DebugStart(
		Api,
		"SetupSlot group=%s slot=%s model=%s parent=%s isLocalOwner=%s",
		tostring(DropperData.GroupId),
		tostring(DropperData.SlotId),
		DropperData.Model and DropperData.Model:GetFullName() or "nil",
		ParentContainer and ParentContainer:GetFullName() or "nil",
		tostring(DropperData.IsLocalOwner)
	)
	if not DropperData.IsLocalOwner then
		Api.SetQueryMask(DropperData.Model, {})
	end

	local Plot: Model = DropperData.Plot
	local GroupId: string = DropperData.GroupId
	local SlotId: string = DropperData.SlotId
	local SlotConfig: any = DropperData.Config

	local TapModel: Model? = Api.FindDescendant(DropperData.Model, Api.TapName) :: Model?
	local CanPosition: BasePart? = nil
	if TapModel then
		CanPosition = Api.FindDescendant(TapModel, Api.CanPositionName) :: BasePart?
	end
	if not CanPosition then
		CanPosition = Api.FindDescendant(DropperData.Model, Api.CanPositionName) :: BasePart?
	end
	if not CanPosition then
		CanPosition = Api.FindDescendant(ParentContainer, Api.CanPositionName) :: BasePart?
	end
	if not CanPosition then
		_DebugStart(Api, "CanPosition missing for group=%s slot=%s", GroupId, SlotId)
		return
	end
	DropperData.CanPosition = CanPosition

	local Keys: any = Api.BuildCandyAttributeKeys(GroupId, SlotId, nil)
	Api.BindCandyState(
		Plot,
		GroupId,
		SlotId,
		Keys,
		CanPosition,
		TapModel,
		nil,
		nil,
		DropperData.MainPart,
		Api.Timing.ManualDropTime,
		false
	)

	local function HasCandy(): boolean
		local ModelName: string = Api.GetStringAttribute(Plot, Keys.CandyModel, Api.EmptyString)
		return ModelName ~= Api.EmptyString
	end

	local Hitbox: BasePart? = nil
	if TapModel then
		Hitbox = Api.FindHitbox(TapModel)
	end
	if not Hitbox then
		Hitbox = Api.FindHitbox(DropperData.Model)
	end
	if Hitbox and DropperData.IsLocalOwner then
		Hitbox.CanCollide = false
		Hitbox.CanTouch = false
		Hitbox.CanQuery = false
		Hitbox.Transparency = 1
		Hitbox.LocalTransparencyModifier = 1
		Api.SetQueryMask(TapModel or DropperData.Model, {})
		local Detector: ClickDetector? = Hitbox:FindFirstChildOfClass("ClickDetector")
		if Detector then
			Detector.MaxActivationDistance = 0
			Detector.CursorIcon = Api.CursorIcon
		end
	end

	local StartButton, ClaimButton, TimeLabel, ReadyLabel = _FindStartUi(ParentContainer)
	if not StartButton and not ClaimButton and not TimeLabel and not ReadyLabel then
		StartButton, ClaimButton, TimeLabel, ReadyLabel = _FindStartUi(DropperData.Model)
	end
	if not StartButton and not ClaimButton and not TimeLabel and not ReadyLabel then
		local Parent: Instance? = DropperData.Model.Parent
		if Parent then
			StartButton, ClaimButton, TimeLabel, ReadyLabel = _FindStartUi(Parent)
		end
	end
	if not StartButton and not ClaimButton and not TimeLabel and not ReadyLabel then
		local GroupFolder: Instance? = Plot:FindFirstChild(GroupId)
		if not GroupFolder then
			local Parent: Instance? = ParentContainer.Parent
			if Parent then
				GroupFolder = Parent
			end
		end
		if GroupFolder then
			local Board: Instance? = GroupFolder:FindFirstChild("Board", true)
			if Board then
				StartButton, ClaimButton, TimeLabel, ReadyLabel = _FindStartUi(Board)
				if StartButton or ClaimButton or TimeLabel or ReadyLabel then
					_DebugStart(Api, "StartModel found via board=%s", Board:GetFullName())
				end
			end
			if not StartButton and not ClaimButton and not TimeLabel and not ReadyLabel then
				StartButton, ClaimButton, TimeLabel, ReadyLabel = _FindStartUi(GroupFolder)
				if StartButton or ClaimButton or TimeLabel or ReadyLabel then
					_DebugStart(Api, "StartModel found via group folder=%s", GroupFolder:GetFullName())
				end
			end
		end
	end
	if not StartButton and not ClaimButton and not TimeLabel and not ReadyLabel then
		local Parent: Instance? = DropperData.Model.Parent
		local StartModelProbe: Instance? = ParentContainer:FindFirstChild("StartModel", true)
		if not StartModelProbe then
			StartModelProbe = DropperData.Model:FindFirstChild("StartModel", true)
		end
		if not StartModelProbe and Parent then
			StartModelProbe = Parent:FindFirstChild("StartModel", true)
		end
		local PurifierProbe: Instance? = nil
		if StartModelProbe then
			PurifierProbe = StartModelProbe:FindFirstChild("Purifier", true)
		end
		local ContainerChildren: string = if Api and Api.DescribeChildren then Api.DescribeChildren(ParentContainer) else "<unavailable>"
		local ModelChildren: string = if Api and Api.DescribeChildren then Api.DescribeChildren(DropperData.Model) else "<unavailable>"
		local ParentChildren: string = if Parent and Api and Api.DescribeChildren then Api.DescribeChildren(Parent) else "<unavailable>"
		local StartChildren: string = if StartModelProbe and Api and Api.DescribeChildren then Api.DescribeChildren(StartModelProbe) else "<unavailable>"
		_DebugStart(
			Api,
			"StartModel UI missing. Model=%s Parent=%s StartModel=%s Purifier=%s ParentContainerChildren=%s ModelChildren=%s ParentChildren=%s StartModelChildren=%s",
			DropperData.Model.Name,
			tostring(Parent),
			StartModelProbe and StartModelProbe:GetFullName() or "nil",
			PurifierProbe and PurifierProbe:GetFullName() or "nil",
			ContainerChildren,
			ModelChildren,
			ParentChildren,
			StartChildren
		)
		return
	end

	_DebugStart(
		Api,
		"StartModel UI found. Start=%s Claim=%s Time=%s Ready=%s",
		StartButton and StartButton:GetFullName() or "nil",
		ClaimButton and ClaimButton:GetFullName() or "nil",
		TimeLabel and TimeLabel:GetFullName() or "nil",
		ReadyLabel and ReadyLabel:GetFullName() or "nil"
	)

	local TimerToken: number = 0

	local function UpdateUi(): ()
		local State: string = _GetProcessState(Api, Plot, GroupId, SlotId)
		local Duration: number = _GetProcessSeconds(Api, Plot, GroupId, SlotId, SlotConfig)
		local EndTime: number = _GetProcessEnd(Api, Plot, GroupId, SlotId)
		local Remaining: number = math.max(0, EndTime - os.time())
		_DebugStart(
			Api,
			"UpdateUi state=%s duration=%s end=%s remaining=%s",
			State,
			tostring(Duration),
			tostring(EndTime),
			tostring(Remaining)
		)

		if State == PROCESS_STATE_PROCESSING then
			if TimeLabel then
				TimeLabel.Text = _FormatSeconds(Remaining)
				TimeLabel.Visible = true
			end
			if ReadyLabel then
				ReadyLabel.Visible = false
			end
			if StartButton then
				StartButton.Visible = false
			end
			if ClaimButton then
				ClaimButton.Visible = false
			end
		elseif State == PROCESS_STATE_READY then
			if TimeLabel then
				TimeLabel.Visible = false
			end
			if ReadyLabel then
				ReadyLabel.Visible = true
			end
			if StartButton then
				StartButton.Visible = false
			end
			if ClaimButton then
				ClaimButton.Visible = true
			end
		else
			if TimeLabel then
				TimeLabel.Text = string.format("Takes %s", _FormatSeconds(Duration))
				TimeLabel.Visible = true
			end
			if ReadyLabel then
				ReadyLabel.Visible = false
			end
			if StartButton then
				StartButton.Visible = true
			end
			if ClaimButton then
				ClaimButton.Visible = false
			end
		end
	end

	local function StartTimerLoop(): ()
		TimerToken += 1
		local Token: number = TimerToken
		task.spawn(function(): ()
			while Token == TimerToken do
				UpdateUi()
				local State: string = _GetProcessState(Api, Plot, GroupId, SlotId)
				if State ~= PROCESS_STATE_PROCESSING then
					break
				end
				task.wait(0.2)
			end
		end)
	end

	if StartButton then
		StartButton.MouseEnter:Connect(function(): ()
			Api.SetDropperHover(DropperData, true)
		end)
		StartButton.MouseLeave:Connect(function(): ()
			Api.SetDropperHover(DropperData, false)
		end)
		StartButton.Activated:Connect(function(): ()
			local State: string = _GetProcessState(Api, Plot, GroupId, SlotId)
			_DebugStart(Api, "Start Activated state=%s", State)
			if State ~= PROCESS_STATE_IDLE then
				return
			end
			Api.Packets.Machines:Fire(Api.Actions.DoubleDropperStart, {
				GroupId = GroupId,
				SlotId = SlotId,
			})
		end)
		StartButton.MouseButton1Click:Connect(function(): ()
			local State: string = _GetProcessState(Api, Plot, GroupId, SlotId)
			_DebugStart(Api, "Start Click state=%s", State)
			if State ~= PROCESS_STATE_IDLE then
				return
			end
			Api.Packets.Machines:Fire(Api.Actions.DoubleDropperStart, {
				GroupId = GroupId,
				SlotId = SlotId,
			})
		end)
	end

	if ClaimButton then
		ClaimButton.MouseEnter:Connect(function(): ()
			Api.SetDropperHover(DropperData, true)
		end)
		ClaimButton.MouseLeave:Connect(function(): ()
			Api.SetDropperHover(DropperData, false)
		end)
		ClaimButton.Activated:Connect(function(): ()
			local State: string = _GetProcessState(Api, Plot, GroupId, SlotId)
			_DebugStart(Api, "Claim Activated state=%s", State)
			if State ~= PROCESS_STATE_READY then
				return
			end
			Api.Packets.Machines:Fire(Api.ActionRemove, {
				GroupId = GroupId,
				SlotId = SlotId,
			})
		end)
		ClaimButton.MouseButton1Click:Connect(function(): ()
			local State: string = _GetProcessState(Api, Plot, GroupId, SlotId)
			_DebugStart(Api, "Claim Click state=%s", State)
			if State ~= PROCESS_STATE_READY then
				return
			end
			Api.Packets.Machines:Fire(Api.ActionRemove, {
				GroupId = GroupId,
				SlotId = SlotId,
			})
		end)
	end

	local StateKey: string = Api.GetAttributeKey(GroupId, SlotId, nil, "ProcessState")
	local EndKey: string = Api.GetAttributeKey(GroupId, SlotId, nil, "ProcessEnd")
	local LevelKey: string = Api.GetUpgradeKey(GroupId, SlotId, "Level")

	Api.ConnectValueChanged(Plot, StateKey, function(): ()
		_DebugStart(Api, "State changed")
		UpdateUi()
		StartTimerLoop()
	end)
	Api.ConnectValueChanged(Plot, EndKey, function(): ()
		_DebugStart(Api, "End changed")
		UpdateUi()
	end)
	Api.ConnectValueChanged(Plot, LevelKey, function(): ()
		_DebugStart(Api, "Level changed")
		UpdateUi()
	end)

	UpdateUi()
	StartTimerLoop()
end

return module
