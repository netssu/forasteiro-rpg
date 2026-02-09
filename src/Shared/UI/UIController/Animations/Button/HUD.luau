-- // Services
local TweenService = game:GetService('TweenService')

return table.freeze({
	MouseEnter = function(
		Button: GuiObject,
		UIPropers: {
			[GuiObject]: { Size: { X: { Scale: UDim2 }, Y: { Scale: UDim2 } } },
		}
	)
		local oldPos = UIPropers
		Button.Size = UDim2.fromScale(oldPos.Size.X.Scale, oldPos.Size.Y.Scale)
		TweenService:Create(
			Button,
			TweenInfo.new(
				0.8,
				Enum.EasingStyle.Elastic,
				Enum.EasingDirection.Out
			),
			{
				Size = UDim2.fromScale(
					oldPos.Size.X.Scale + 0.05,
					oldPos.Size.Y.Scale + 0.05
				),
			}
		):Play()
	end,

	MouseLeave = function(
		Button: GuiObject,
		UIPropers: {
			[GuiObject]: { Size: { X: { Scale: UDim2 }, Y: { Scale: UDim2 } } },
		}
	)
		local oldPos = UIPropers
		Button.Size = UDim2.fromScale(
			oldPos.Size.X.Scale + 0.05,
			oldPos.Size.Y.Scale + 0.05
		)
		TweenService:Create(
			Button,
			TweenInfo.new(
				0.8,
				Enum.EasingStyle.Elastic,
				Enum.EasingDirection.Out
			),
			{ Size = UDim2.fromScale(oldPos.Size.X.Scale, oldPos.Size.Y.Scale) }
		):Play()
	end,

	MouseDown = function(
		Button: GuiObject,
		UIPropers: {
			[GuiObject]: { Size: { X: { Scale: UDim2 }, Y: { Scale: UDim2 } } },
		}
	)
		local oldPos = UIPropers
		Button.Size = UDim2.fromScale(
			oldPos.Size.X.Scale + 0.05,
			oldPos.Size.Y.Scale + 0.05
		)
		TweenService:Create(
			Button,
			TweenInfo.new(0.08, Enum.EasingStyle.Linear),
			{ Size = UDim2.fromScale(oldPos.Size.X.Scale, oldPos.Size.Y.Scale) }
		):Play()
	end,

	MouseUp = function(
		Button: GuiObject,
		UIPropers: {
			[GuiObject]: { Size: { X: { Scale: UDim2 }, Y: { Scale: UDim2 } } },
		}
	)
		local oldPos = UIPropers
		Button.Size = UDim2.fromScale(oldPos.Size.X.Scale, oldPos.Size.Y.Scale)
		TweenService:Create(
			Button,
			TweenInfo.new(0.08, Enum.EasingStyle.Linear),
			{
				Size = UDim2.fromScale(
					oldPos.Size.X.Scale + 0.05,
					oldPos.Size.Y.Scale + 0.05
				),
			}
		):Play()
	end,
})
