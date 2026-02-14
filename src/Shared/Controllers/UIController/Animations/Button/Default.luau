-- SERVICES
local TweenService = game:GetService('TweenService')

-- CONSTANTS
local DEFAULT_CONFIG = {
	HoverScale = 1.15,
	ClickScale = 0.85,
	HoverDuration = 0.5,
	ClickDuration = 0.1,
	HoverRotation = 5,
}

-- FUNCTIONS
local function getButtonConfig(Button: GuiObject)
	return {
		HoverScale = Button:GetAttribute('HoverScale') or DEFAULT_CONFIG.HoverScale,
		ClickScale = Button:GetAttribute('ClickScale') or DEFAULT_CONFIG.ClickScale,
		HoverDuration = Button:GetAttribute('HoverDuration') or DEFAULT_CONFIG.HoverDuration,
		ClickDuration = Button:GetAttribute('ClickDuration') or DEFAULT_CONFIG.ClickDuration,
		HoverRotation = Button:GetAttribute('HoverRotation') or DEFAULT_CONFIG.HoverRotation,
	}
end

-- INIT
return table.freeze({
	MouseEnter = function(Button: GuiObject, UIPropers)
		local config = getButtonConfig(Button)
		local oldSize = UIPropers.Size
		
		local hoverTween = TweenService:Create(
			Button,
			TweenInfo.new(
				config.HoverDuration,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),
			{
				Size = UDim2.fromScale(
					oldSize.X.Scale * config.HoverScale,
					oldSize.Y.Scale * config.HoverScale
				),
				Rotation = config.HoverRotation,
			}
		)
		
		hoverTween:Play()
		
		if Button:FindFirstChild('UIStroke') then
			TweenService:Create(
				Button.UIStroke,
				TweenInfo.new(config.HoverDuration, Enum.EasingStyle.Quad),
				{
					Thickness = 4,
					Transparency = 0,
				}
			):Play()
		end
		
		if Button:IsA('TextButton') then
			TweenService:Create(
				Button,
				TweenInfo.new(config.HoverDuration, Enum.EasingStyle.Quad),
				{
					BackgroundTransparency = math.max(0, Button.BackgroundTransparency - 0.1),
				}
			):Play()
		end
	end,
	
	MouseLeave = function(Button: GuiObject, UIPropers)
		local config = getButtonConfig(Button)
		local oldSize = UIPropers.Size
		local originalTransparency = Button:GetAttribute('OriginalTransparency') or Button.BackgroundTransparency
		
		local leaveTween = TweenService:Create(
			Button,
			TweenInfo.new(
				config.HoverDuration,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.In
			),
			{
				Size = oldSize,
				Rotation = 0,
			}
		)
		
		leaveTween:Play()
		
		if Button:FindFirstChild('UIStroke') then
			TweenService:Create(
				Button.UIStroke,
				TweenInfo.new(config.HoverDuration, Enum.EasingStyle.Quad),
				{
					Thickness = 2,
					Transparency = 0.5,
				}
			):Play()
		end
		
		if Button:IsA('TextButton') then
			TweenService:Create(
				Button,
				TweenInfo.new(config.HoverDuration, Enum.EasingStyle.Quad),
				{
					BackgroundTransparency = originalTransparency,
				}
			):Play()
		end
	end,
	
	MouseDown = function(Button: GuiObject, UIPropers)
		local config = getButtonConfig(Button)
		local oldSize = UIPropers.Size
		
		local clickDownTween = TweenService:Create(
			Button,
			TweenInfo.new(
				config.ClickDuration,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			{
				Size = UDim2.fromScale(
					oldSize.X.Scale * config.ClickScale,
					oldSize.Y.Scale * config.ClickScale
				),
				Rotation = -config.HoverRotation,
			}
		)
		
		clickDownTween:Play()
		
		if Button:FindFirstChild('UIStroke') then
			TweenService:Create(
				Button.UIStroke,
				TweenInfo.new(config.ClickDuration),
				{
					Thickness = 6,
				}
			):Play()
		end
	end,
	
	MouseUp = function(Button: GuiObject, UIPropers)
		local config = getButtonConfig(Button)
		local oldSize = UIPropers.Size
		
		local bounceSequence = TweenService:Create(
			Button,
			TweenInfo.new(
				config.ClickDuration,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),
			{
				Size = UDim2.fromScale(
					oldSize.X.Scale * config.HoverScale,
					oldSize.Y.Scale * config.HoverScale
				),
				Rotation = config.HoverRotation,
			}
		)
		
		bounceSequence:Play()
		
		task.delay(config.ClickDuration, function()
			local stabilizeTween = TweenService:Create(
				Button,
				TweenInfo.new(0.15, Enum.EasingStyle.Elastic),
				{
					Rotation = config.HoverRotation,
				}
			)
			stabilizeTween:Play()
		end)
		
		if Button:FindFirstChild('UIStroke') then
			TweenService:Create(
				Button.UIStroke,
				TweenInfo.new(config.ClickDuration),
				{
					Thickness = 4,
				}
			):Play()
		end
	end,
})