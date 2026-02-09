local TweenService = game:GetService('TweenService')

local function CloseFrame(Frame: GuiObject, _props)
	local Tween = TweenService:Create(
		Frame,
		TweenInfo.new(
			0.5,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.In
		),
		{
			Position = UDim2.fromScale(0.5, -0.5),
		}
	)

	Tween:Play()

	task.delay(0.5,function()
		Frame.Visible = false
	end)
end

local function OpenFrame(Frame: GuiObject, _props)
	if Frame.Visible then
		CloseFrame(Frame, _props)
		return
	end

	Frame.Visible = true
	Frame.Position = UDim2.fromScale(0.5, -0.5)

	TweenService:Create(
		Frame,
		TweenInfo.new(
			0.2,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		),
		{ Position = UDim2.fromScale(0.5, 0.5) }
	):Play()
end

return table.freeze({
	['Open'] = OpenFrame,
	['Close'] = CloseFrame,
})