--!strict

local module = {}

function module.Register(Target: { [string]: any }, MachinesConfig: any): ()
	local Group = MachinesConfig.Droppers
	if Group then
		Target.Droppers = Group
	end
end

local _ActiveHoverDropper: any = nil
local _ActiveHoverTap: any = nil
local _Api: any = nil

function module.SetActiveHoverDropper(Api: any, DropperData: any): ()
	local ActiveApi: any = Api or _Api
	if not ActiveApi then
		return
	end
	if _ActiveHoverDropper and _ActiveHoverDropper ~= DropperData then
		ActiveApi.SetDropperHover(_ActiveHoverDropper, false)
		ActiveApi.ClearDropperPreview(_ActiveHoverDropper)
	end
	if _ActiveHoverTap then
		ActiveApi.ClearTapPreview(_ActiveHoverTap)
		_ActiveHoverTap = nil
	end
	_ActiveHoverDropper = DropperData
end

function module.SetActiveHoverTap(Api: any, TapData: any, DropperData: any): ()
	local ActiveApi: any = Api or _Api
	if not ActiveApi then
		return
	end
	if _ActiveHoverTap and _ActiveHoverTap ~= TapData then
		ActiveApi.ClearTapPreview(_ActiveHoverTap)
	end
	_ActiveHoverTap = TapData
	module.SetActiveHoverDropper(ActiveApi, DropperData)
end

function module.ClearActiveHoverDropper(_: any, DropperData: any): ()
	if _ActiveHoverDropper == DropperData then
		_ActiveHoverDropper = nil
	end
end

function module.ClearActiveHoverTap(_: any, TapData: any): ()
	if _ActiveHoverTap == TapData then
		_ActiveHoverTap = nil
	end
end

function module.RefreshHoverPreview(Api: any): ()
	local ActiveApi: any = Api or _Api
	if not ActiveApi then
		return
	end
	if not ActiveApi.HologramEnabled then
		ActiveApi.ClearOtherPreviews(nil)
		return
	end

	local KeepModel: Model? = nil
	if _ActiveHoverTap then
		KeepModel = _ActiveHoverTap.PreviewModel
	elseif _ActiveHoverDropper then
		KeepModel = _ActiveHoverDropper.PreviewModel
	end
	ActiveApi.ClearOtherPreviews(KeepModel)

	local ToolInstance: Tool? = ActiveApi.GetEquippedTool()
	if _ActiveHoverTap then
		if _ActiveHoverTap.HasCandy then
			ActiveApi.ClearTapPreview(_ActiveHoverTap)
			return
		end
		if ToolInstance then
			local CandyName: string? = ActiveApi.GetCandyNameFromTool(ToolInstance)
			if CandyName and _ActiveHoverTap.CanPosition then
				ActiveApi.ShowTapPreview(
					_ActiveHoverTap,
					CandyName,
					_ActiveHoverTap.CanPosition.CFrame,
					_ActiveHoverTap.TapModel.Parent or _ActiveHoverTap.TapModel
				)
				return
			end
		end
		ActiveApi.ClearTapPreview(_ActiveHoverTap)
		return
	end

	if _ActiveHoverDropper then
		if _ActiveHoverDropper.HasCandy then
			ActiveApi.ClearDropperPreview(_ActiveHoverDropper)
			return
		end
		if ToolInstance then
			local CandyName: string? = ActiveApi.GetCandyNameFromTool(ToolInstance)
			if CandyName then
				local PreviewCFrame: CFrame = if _ActiveHoverDropper.CanPosition
					then _ActiveHoverDropper.CanPosition.CFrame
					else _ActiveHoverDropper.Model:GetPivot()
				ActiveApi.ShowDropperPreview(_ActiveHoverDropper, CandyName, PreviewCFrame)
				return
			end
		end
		ActiveApi.ClearDropperPreview(_ActiveHoverDropper)
	end
end

local function _SetDropperHasCandy(Api: any, DropperData: any, HasCandy: boolean): ()
	DropperData.HasCandy = HasCandy
	DropperData.HoverColor = if HasCandy then Api.DropperRemoveColor else Api.DropperHighlightColor

	if DropperData.Highlight then
		DropperData.Highlight.FillColor = DropperData.HoverColor
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

local function _SetupNormalDropper(Api: any, DropperData: any, SlotFolder: Instance): ()
	local CanPosition: BasePart? = Api.FindDescendant(DropperData.Model, Api.CanPositionName) :: BasePart?
	if not CanPosition then
		Api.Debug("CanPosition missing in Dropper %s", DropperData.Model.Name)
		return
	end
	DropperData.CanPosition = CanPosition

	if not DropperData.DropEffect and DropperData.Config.UseDropEffect then
		DropperData.DropEffect = Api.CreateDropEffect()
	end

	local Keys: any = Api.BuildCandyAttributeKeys(DropperData.GroupId, DropperData.SlotId, nil)
	local Plot: Model = DropperData.Plot

	local function RefreshCandyState(): ()
		local ModelName: string = Api.GetStringAttribute(Plot, Keys.CandyModel, Api.EmptyString)
		_SetDropperHasCandy(Api, DropperData, ModelName ~= Api.EmptyString)
	end

	local ModelSignal: RBXScriptSignal? = Api.GetValueChangedSignal(Plot, Keys.CandyModel)
	if ModelSignal then
		ModelSignal:Connect(function(): ()
			RefreshCandyState()
		end)
	end
	RefreshCandyState()

	Api.BindCandyState(
		DropperData.Plot,
		DropperData.GroupId,
		DropperData.SlotId,
		Keys,
		CanPosition,
		SlotFolder,
		nil,
		DropperData.DropEffect,
		DropperData.MainPart,
		Api.Timing.ManualDropTime,
		DropperData.IsLocalOwner
	)
end

local function _SetupAutoDropper(Api: any, DropperData: any, SlotFolder: Instance): ()
	local TapModels: { Model } = _CollectTapModels(DropperData.Model, Api.TapName, DropperData.Config.TapCount)
	local Available: number = 0
	for Index: number = 1, DropperData.Config.TapCount do
		if TapModels[Index] then
			Available += 1
		end
	end
	if Available <= 0 then
		Api.Debug("No Tap models found in Dropper2 %s", DropperData.Model.Name)
		return
	end

	Api.Debug("Auto Dropper taps: %d in %s", Available, DropperData.Model.Name)

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
				if Api.HologramEnabled and DropperData.Config.AllowPreview and DropperData.Config.AllowManualPlacement then
					if not TapData.HasCandy then
						local ToolInstance: Tool? = Api.GetEquippedTool()
						if ToolInstance then
							local CandyName: string? = Api.GetCandyNameFromTool(ToolInstance)
							if CandyName and TapData.CanPosition then
								Api.ShowTapPreview(TapData, CandyName, TapData.CanPosition.CFrame, DropperData.Model.Parent or DropperData.Model)
							end
						end
					end
				end
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

				if not DropperData.Config.AllowManualPlacement then
					Api.FlashDropper(DropperData, Api.DropperRemoveColor)
					Api.PlayDropperClickScale(DropperData, DropperData.BaseScale * Api.ClickShrinkScale)
					return
				end

				local ToolInstance: Tool? = Api.GetEquippedTool()
				if not ToolInstance then
					Api.FlashDropper(DropperData, Api.DropperRemoveColor)
					Api.PlayDropperClickScale(DropperData, DropperData.BaseScale * Api.ClickShrinkScale)
					return
				end

				local CandyName: string? = Api.GetCandyNameFromTool(ToolInstance)
				if not CandyName then
					Api.FlashDropper(DropperData, Api.DropperRemoveColor)
					Api.PlayDropperClickScale(DropperData, DropperData.BaseScale * Api.ClickShrinkScale)
					return
				end

				Api.FlashDropper(DropperData, Api.DropperPlaceColor)
				Api.PlayDropperClickScale(DropperData, Api.GetReturnScale(DropperData) + Api.ClickBounceScale)
				Api.Packets.Machines:Fire(Api.ActionPlace, {
					GroupId = DropperData.GroupId,
					SlotId = DropperData.SlotId,
					TapId = TapData.TapId,
				})
			end)
		end
	end

	DropperData.Taps = TapDataMap
end

local function _SetupDropperHover(Api: any, DropperData: any): ()
	local HoverPart: BasePart? = Api.FindHitbox(DropperData.Model)

	if not HoverPart then
		Api.Debug("Hitbox missing for %s (children: %s)", DropperData.Model.Name, Api.DescribeChildren(DropperData.Model))
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
	Api.SetQueryMask(DropperData.Model, Allowed)

	Api.EnsureDropperHighlight(DropperData)

	local ExistingDetector: ClickDetector? = HoverPart:FindFirstChildOfClass("ClickDetector")
	local Detector: ClickDetector = ExistingDetector or Instance.new("ClickDetector")
	Detector.MaxActivationDistance = Api.MaxActivationDistance
	Detector.CursorIcon = Api.CursorIcon
	Detector.Parent = HoverPart
	DropperData.HoverDetector = Detector

	Detector.MouseHoverEnter:Connect(function(): ()
		Api.SetActiveHoverDropper(DropperData)
		Api.SetDropperHover(DropperData, true)
		Api.ClearDropperPreview(DropperData)
		if Api.HologramEnabled and DropperData.Config.AllowPreview and DropperData.Config.AllowManualPlacement then
			if not DropperData.HasCandy then
				local ToolInstance: Tool? = Api.GetEquippedTool()
				if ToolInstance then
					local CandyName: string? = Api.GetCandyNameFromTool(ToolInstance)
					if CandyName then
						local PreviewCFrame: CFrame = if DropperData.CanPosition then DropperData.CanPosition.CFrame else DropperData.Model:GetPivot()
						Api.ShowDropperPreview(DropperData, CandyName, PreviewCFrame)
					end
				end
			end
		end
	end)

	Detector.MouseHoverLeave:Connect(function(): ()
		Api.SetDropperHover(DropperData, false)
		Api.ClearDropperPreview(DropperData)
		Api.ClearActiveHoverDropper(DropperData)
	end)

	Detector.MouseClick:Connect(function(): ()
		Api.ClearDropperPreview(DropperData)

		if DropperData.HasCandy then
			Api.FlashDropper(DropperData, Api.DropperRemoveColor)
			Api.PlayDropperClickScale(DropperData, DropperData.BaseScale * Api.ClickShrinkScale)
			Api.Packets.Machines:Fire(Api.ActionRemove, {
				GroupId = DropperData.GroupId,
				SlotId = DropperData.SlotId,
			})
			return
		end

		if not DropperData.Config.AllowManualPlacement then
			Api.FlashDropper(DropperData, Api.DropperRemoveColor)
			Api.PlayDropperClickScale(DropperData, DropperData.BaseScale * Api.ClickShrinkScale)
			return
		end

		local ToolInstance: Tool? = Api.GetEquippedTool()
		if not ToolInstance then
			Api.FlashDropper(DropperData, Api.DropperRemoveColor)
			Api.PlayDropperClickScale(DropperData, DropperData.BaseScale * Api.ClickShrinkScale)
			return
		end

		local CandyName: string? = Api.GetCandyNameFromTool(ToolInstance)
		if not CandyName then
			Api.FlashDropper(DropperData, Api.DropperRemoveColor)
			Api.PlayDropperClickScale(DropperData, DropperData.BaseScale * Api.ClickShrinkScale)
			return
		end

		Api.FlashDropper(DropperData, Api.DropperPlaceColor)
		Api.PlayDropperClickScale(DropperData, Api.GetReturnScale(DropperData) + Api.ClickBounceScale)
		Api.Packets.Machines:Fire(Api.ActionPlace, {
			GroupId = DropperData.GroupId,
			SlotId = DropperData.SlotId,
		})
	end)
end

local function _SetupDropperButton(Api: any, DropperData: any): ()
	local ButtonPart: BasePart? = DropperData.ButtonPart
	if not ButtonPart then
		return
	end

	local Detector: ClickDetector? = ButtonPart:FindFirstChildOfClass("ClickDetector")
	if not Detector then
		return
	end
	local Keys: any = Api.BuildCandyAttributeKeys(DropperData.GroupId, DropperData.SlotId, nil)
	ButtonPart.Size = Api.ButtonBaseSize
	ButtonPart:SetAttribute("IsHovering", false)
	ButtonPart:SetAttribute("IsCooldown", false)

	local ButtonHighlight: Highlight = Instance.new("Highlight")
	ButtonHighlight.FillColor = Api.ButtonReadyColor
	ButtonHighlight.FillTransparency = 1
	ButtonHighlight.OutlineTransparency = 1
	ButtonHighlight.Adornee = ButtonPart
	ButtonHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	ButtonHighlight.Enabled = false
	ButtonHighlight.Parent = ButtonPart
	Api.SetButtonHighlightState(ButtonHighlight, false)

	Detector.MouseClick:Connect(function(): ()
		if ButtonPart:GetAttribute("IsCooldown") == true then
			return
		end

		local ModelName: string = Api.GetStringAttribute(DropperData.Plot, Keys.CandyModel, Api.EmptyString)
		if ModelName ~= Api.EmptyString then
			local Level: number = Api.GetNumberAttribute(DropperData.Plot, Keys.CandyLevel, 0)
			local MaxLevel: number = Api.GetCandyMaxLevelForBillboard(ModelName)
			if MaxLevel > 0 and Level >= MaxLevel then
				Api.PlayButtonClick(ButtonPart)
				Api.FlashDropper(DropperData, Api.DropperRemoveColor)
				Api.PlayDropperClickScale(DropperData, Api.GetReturnScale(DropperData) + Api.ClickBounceScale)
				return
			end
		end

		Api.PlayButtonClick(ButtonPart)
		ButtonPart:SetAttribute("IsCooldown", true)
		Api.SetButtonHighlightState(ButtonHighlight, true)
		ButtonHighlight.Enabled = true
		Api.TweenModule:Tween(ButtonHighlight, 0.1, "Sine", "Out", { FillTransparency = 0.8 }, 0, false, nil)

		Api.Packets.Machines:Fire(Api.ActionDrop, {
			GroupId = DropperData.GroupId,
			SlotId = DropperData.SlotId,
		})

		task.delay(Api.Timing.ManualDebounce, function(): ()
			if ButtonPart:GetAttribute("IsCooldown") ~= true then
				return
			end
			ButtonPart:SetAttribute("IsCooldown", false)
			Api.SetButtonHighlightState(ButtonHighlight, false)
			if ButtonPart:GetAttribute("IsHovering") then
				ButtonHighlight.Enabled = true
				Api.TweenModule:Tween(ButtonHighlight, 0.1, "Sine", "Out", { FillTransparency = 0.8 }, 0, false, nil)
			else
				Api.TweenModule:Tween(ButtonHighlight, 0.1, "Sine", "Out", { FillTransparency = 1 }, 0, false, function(): ()
					ButtonHighlight.Enabled = false
				end)
			end
		end)
	end)

	Detector.MouseHoverEnter:Connect(function(): ()
		ButtonPart:SetAttribute("IsHovering", true)
		Api.SetButtonHighlightState(ButtonHighlight, ButtonPart:GetAttribute("IsCooldown") == true)
		ButtonHighlight.Enabled = true
		Api.TweenModule:Tween(ButtonHighlight, 0.1, "Sine", "Out", { FillTransparency = 0.8 }, 0, false, nil)
	end)

	Detector.MouseHoverLeave:Connect(function(): ()
		ButtonPart:SetAttribute("IsHovering", false)
		if ButtonPart:GetAttribute("IsCooldown") == true then
			Api.SetButtonHighlightState(ButtonHighlight, true)
			ButtonHighlight.Enabled = true
			Api.TweenModule:Tween(ButtonHighlight, 0.1, "Sine", "Out", { FillTransparency = 0.8 }, 0, false, nil)
			return
		end
		Api.TweenModule:Tween(ButtonHighlight, 0.1, "Sine", "Out", { FillTransparency = 1 }, 0, false, function(): ()
			ButtonHighlight.Enabled = false
		end)
	end)
end

function module.SetupSlot(Api: any, DropperData: any, ParentContainer: Instance): ()
	_Api = Api
	if not DropperData.IsLocalOwner then
		Api.SetQueryMask(DropperData.Model, {})
	end

	if DropperData.Config.Type == "Manual" then
		_SetupNormalDropper(Api, DropperData, ParentContainer)
		if DropperData.IsLocalOwner then
			_SetupDropperHover(Api, DropperData)
			_SetupDropperButton(Api, DropperData)
		end
	else
		_SetupAutoDropper(Api, DropperData, ParentContainer)
	end
end

return module
