local TweenService = game:GetService('TweenService')

return table.freeze({
	['Open'] = function(
		ScreenGui: ScreenGui,
		_: {
			[GuiObject]: { Position: { UDim2 }, Size: { UDim2 } },
		}
	)
		if ScreenGui:FindFirstChild('Background') then
			ScreenGui.Enabled = true

			local Background =
				ScreenGui:FindFirstChild('Background') :: ImageLabel
			Background.Position = UDim2.fromScale(0.5, -0.5)
			TweenService:Create(
				Background,
				TweenInfo.new(
					0.2,
					Enum.EasingStyle.Back,
					Enum.EasingDirection.Out
				),
				{ Position = UDim2.fromScale(0.5, 0.5) }
			):Play()
		end
	end,

	['Close'] = function(
		_: ImageButton,
		_: {
			[GuiObject]: { Position: { UDim2 }, Size: { UDim2 } },
		},
		Args: { ScreenGui: ScreenGui }
	)
		local ScreenGui: ScreenGui = Args.ScreenGui
		if ScreenGui:FindFirstChild('Background') then
			local Background =
				ScreenGui:FindFirstChild('Background') :: ImageLabel
			Background.Position = UDim2.fromScale(0.5, 0.5)
			local Tween = TweenService:Create(
				Background,
				TweenInfo.new(
					0.5,
					Enum.EasingStyle.Back,
					Enum.EasingDirection.Out
				),
				{
					Position = UDim2.fromScale(
						Background.Position.X.Scale,
						-0.5
					),
				}
			)
			Tween.Completed:Once(function()
				ScreenGui.Enabled = false
			end)

			Tween:Play()
		end
	end,
})
