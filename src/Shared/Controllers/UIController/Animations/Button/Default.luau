-- // Services
local TweenService = game:GetService('TweenService')

return table.freeze({
	MouseEnter = function(Button: GuiObject, UIPropers)
		local oldPos = UIPropers
		TweenService:Create(
			Button,
			TweenInfo.new(
				0.8,
				Enum.EasingStyle.Elastic,
				Enum.EasingDirection.Out
			),
			{
				Size = UDim2.fromScale(
					oldPos.Size.X.Scale + 0.5,
					oldPos.Size.Y.Scale + 0.5
				),
			}
		)
	end,

	MouseLeave = function(Button: GuiObject) end,

	Activated = function(Button: GuiObject) end,
})
