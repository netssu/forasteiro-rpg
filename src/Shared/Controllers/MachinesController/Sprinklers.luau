--!strict

local module = {}

function module.Register(Target: { [string]: any }, MachinesConfig: any): ()
	local Group = MachinesConfig.Sprinklers
	if Group then
		Target.Sprinklers = Group
	end
end

local function _SortTapsByPosition(Taps: { Model }, Origin: CFrame): { Model }
	table.sort(Taps, function(Left: Model, Right: Model): boolean
		local LeftLocal: Vector3 = Origin:PointToObjectSpace(Left:GetPivot().Position)
		local RightLocal: Vector3 = Origin:PointToObjectSpace(Right:GetPivot().Position)
		return LeftLocal.X < RightLocal.X
	end)
	return Taps
end

local function _CollectTapModels(DropperModel: Model, TapName: string, TapCount: number): { Model }
	local TapModels: { Model } = table.create(TapCount)
	local Fallback: { Model } = {}
	for _, Child: Instance in DropperModel:GetChildren() do
		if Child:IsA("Model") and Child.Name == TapName then
			local TapId: any = Child:GetAttribute("TapId")
			if typeof(TapId) == "number" and TapId >= 1 and TapId <= TapCount and TapModels[TapId] == nil then
				TapModels[TapId] = Child
			else
				table.insert(Fallback, Child)
			end
		end
	end

	if #Fallback > 0 then
		_SortTapsByPosition(Fallback, DropperModel:GetPivot())
		local FillIndex: number = 1
		for Index: number = 1, TapCount do
			if not TapModels[Index] and Fallback[FillIndex] then
				TapModels[Index] = Fallback[FillIndex]
				FillIndex += 1
			end
		end
	end

	return TapModels
end

local function _SetupAutoSprinkler(Api: any, DropperData: any, SlotFolder: Instance): ()
	local TapModels: { Model } = _CollectTapModels(DropperData.Model, Api.TapName, DropperData.Config.TapCount)
	local Available: number = 0
	for Index: number = 1, DropperData.Config.TapCount do
		if TapModels[Index] then
			Available += 1
		end
	end
	if Available <= 0 then
		Api.Debug("No Tap models found in Sprinkler %s", DropperData.Model.Name)
		return
	end

	Api.Debug("Auto Sprinkler taps: %d in %s", Available, DropperData.Model.Name)

	local TapDataMap: { [number]: any } = {}
	for Index: number = 1, DropperData.Config.TapCount do
		local TapModel: Model = TapModels[Index]
		if not TapModel then
			continue
		end

		local MainPart: BasePart? = Api.FindDescendant(TapModel, Api.MainPartName) :: BasePart?
		local CanPosition: BasePart? = Api.FindDescendant(TapModel, Api.CanPositionName) :: BasePart?
		if not CanPosition then
			Api.Debug("CanPosition missing in Tap %s", TapModel.Name)
			continue
		end

		local DropEffectData: any = nil
		if DropperData.Config.UseDropEffect then
			DropEffectData = Api.CreateDropEffect()
		end
		local TapIdValue: number = Index
		local TapData: any = {
			TapModel = TapModel,
			MainPart = MainPart,
			CanPosition = CanPosition,
			DropEffect = DropEffectData,
			Candy = nil,
			TapId = TapIdValue,
			GroupId = DropperData.GroupId,
			SlotId = DropperData.SlotId,
			Hitbox = nil,
			HoverDetector = nil,
			PulseTween = nil,
			HasCandy = false,
			PreviewModel = nil,
			PreviewName = nil,
		}

		TapDataMap[TapIdValue] = TapData
		local Keys: any = Api.BuildCandyAttributeKeys(DropperData.GroupId, DropperData.SlotId, TapIdValue)
		Api.BindCandyState(
			DropperData.Plot,
			DropperData.GroupId,
			DropperData.SlotId,
			Keys,
			CanPosition,
			SlotFolder,
			TapIdValue,
			DropEffectData,
			MainPart,
			Api.Timing.AutoDropTime,
			DropperData.IsLocalOwner
		)

		local function RefreshCandyState(): ()
			local ModelName: string = Api.GetStringAttribute(DropperData.Plot, Keys.CandyModel, Api.EmptyString)
			TapData.HasCandy = ModelName ~= Api.EmptyString
		end

		local TapSignal: RBXScriptSignal? = Api.GetValueChangedSignal(DropperData.Plot, Keys.CandyModel)
		if TapSignal then
			TapSignal:Connect(function(): ()
				RefreshCandyState()
			end)
		end
		RefreshCandyState()

		local TapHitbox: BasePart? = Api.FindHitbox(TapModel)
		if not TapHitbox then
			Api.Debug("Hitbox missing in Tap %s (children: %s)", TapModel.Name, Api.DescribeChildren(TapModel))
		else
			if not DropperData.IsLocalOwner then
				Api.SetQueryMask(TapModel, {})
				continue
			end
			TapHitbox.CanCollide = false
			TapHitbox.CanTouch = false
			TapHitbox.CanQuery = true
			TapHitbox.Color = Color3.fromRGB(255, 255, 255)
			TapHitbox.Transparency = 1
			TapHitbox.LocalTransparencyModifier = 1
			TapData.Hitbox = TapHitbox
			Api.SetQueryMask(TapModel, { [TapHitbox] = true })

			local TapDetector: ClickDetector = TapHitbox:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
			TapDetector.MaxActivationDistance = Api.MaxActivationDistance
			TapDetector.CursorIcon = Api.CursorIcon
			TapDetector.Parent = TapHitbox
			TapData.HoverDetector = TapDetector

			TapDetector.MouseHoverEnter:Connect(function(): ()
				Api.SetActiveHoverTap(TapData, DropperData)
				Api.SetDropperHover(DropperData, true)
				Api.ClearTapPreview(TapData)
			end)

			TapDetector.MouseHoverLeave:Connect(function(): ()
				Api.SetDropperHover(DropperData, false)
				Api.ClearTapPreview(TapData)
				Api.ClearActiveHoverTap(TapData)
				Api.ClearActiveHoverDropper(DropperData)
			end)

			TapDetector.MouseClick:Connect(function(): ()
				Api.ClearTapPreview(TapData)
				if TapData.HasCandy then
					Api.FlashDropper(DropperData, Api.DropperRemoveColor)
					Api.PlayDropperClickScale(DropperData, DropperData.BaseScale * Api.ClickShrinkScale)
					Api.Packets.Machines:Fire(Api.ActionRemove, {
						GroupId = DropperData.GroupId,
						SlotId = DropperData.SlotId,
						TapId = TapData.TapId,
					})
					return
				end
			end)
		end
	end

	DropperData.Taps = TapDataMap
end

function module.SetupSlot(Api: any, DropperData: any, ParentContainer: Instance): ()
	if not DropperData.IsLocalOwner then
		Api.SetQueryMask(DropperData.Model, {})
	end

	_SetupAutoSprinkler(Api, DropperData, ParentContainer)
end

return module
