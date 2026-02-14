-- SERVICES
local TweenService = game:GetService('TweenService')

-- CONSTANTS
local ANIMATION_CONFIG = {
	OpenDuration = 0.5,
	CloseDuration = 0.4,
	FadeInDuration = 0.3,
	ElementDelay = 0.015,
}

-- FUNCTIONS
local function CloseFrame(Frame: GuiObject, _props)
	for _, child in ipairs(Frame:GetDescendants()) do
		if child:IsA('GuiObject') and child ~= Frame then
			if child:IsA('TextLabel') or child:IsA('TextButton') then
				TweenService:Create(
					child,
					TweenInfo.new(ANIMATION_CONFIG.CloseDuration * 0.5),
					{
						TextTransparency = 1,
					}
				):Play()
			end
			if child:IsA('ImageLabel') or child:IsA('ImageButton') then
				TweenService:Create(
					child,
					TweenInfo.new(ANIMATION_CONFIG.CloseDuration * 0.5),
					{
						ImageTransparency = 1,
					}
				):Play()
			end
			if child:FindFirstChild('UIStroke') then
				TweenService:Create(
					child.UIStroke,
					TweenInfo.new(ANIMATION_CONFIG.CloseDuration * 0.5),
					{
						Transparency = 1,
					}
				):Play()
			end
		end
	end
	
	TweenService:Create(
		Frame,
		TweenInfo.new(
			ANIMATION_CONFIG.CloseDuration,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		),
		{
			BackgroundTransparency = 1,
		}
	):Play()
	
	task.delay(ANIMATION_CONFIG.CloseDuration, function()
		Frame.Visible = false
		
		local originalTransparency = Frame:GetAttribute('OriginalTransparency') or 0
		Frame.BackgroundTransparency = originalTransparency
		
		for _, child in ipairs(Frame:GetDescendants()) do
			if child:IsA('GuiObject') then
				if child:IsA('TextLabel') or child:IsA('TextButton') then
					child.TextTransparency = child:GetAttribute('OriginalTextTransparency') or 0
				end
				if child:IsA('ImageLabel') or child:IsA('ImageButton') then
					child.ImageTransparency = child:GetAttribute('OriginalImageTransparency') or 0
				end
				if child:FindFirstChild('UIStroke') then
					child.UIStroke.Transparency = child.UIStroke:GetAttribute('OriginalTransparency') or 0
				end
			end
		end
	end)
end

local function OpenFrame(Frame: GuiObject, _props)
	if Frame.Visible then
		CloseFrame(Frame, _props)
		return
	end
	
	if not Frame:GetAttribute('OriginalTransparency') then
		Frame:SetAttribute('OriginalTransparency', Frame.BackgroundTransparency)
	end
	
	for _, child in ipairs(Frame:GetDescendants()) do
		if child:IsA('GuiObject') then
			if child:IsA('TextLabel') or child:IsA('TextButton') then
				if not child:GetAttribute('OriginalTextTransparency') then
					child:SetAttribute('OriginalTextTransparency', child.TextTransparency)
				end
			end
			if child:IsA('ImageLabel') or child:IsA('ImageButton') then
				if not child:GetAttribute('OriginalImageTransparency') then
					child:SetAttribute('OriginalImageTransparency', child.ImageTransparency)
				end
			end
			if child:FindFirstChild('UIStroke') then
				if not child.UIStroke:GetAttribute('OriginalTransparency') then
					child.UIStroke:SetAttribute('OriginalTransparency', child.UIStroke.Transparency)
				end
			end
		end
	end
	
	Frame.Visible = true
	Frame.BackgroundTransparency = 1
	
	for _, child in ipairs(Frame:GetDescendants()) do
		if child:IsA('GuiObject') and child ~= Frame then
			if child:IsA('TextLabel') or child:IsA('TextButton') then
				child.TextTransparency = 1
			end
			if child:IsA('ImageLabel') or child:IsA('ImageButton') then
				child.ImageTransparency = 1
			end
			if child:FindFirstChild('UIStroke') then
				child.UIStroke.Transparency = 1
			end
		end
	end
	
	local originalTransparency = Frame:GetAttribute('OriginalTransparency') or 0
	TweenService:Create(
		Frame,
		TweenInfo.new(
			ANIMATION_CONFIG.FadeInDuration,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			BackgroundTransparency = originalTransparency,
		}
	):Play()
	
	task.delay(ANIMATION_CONFIG.FadeInDuration * 0.3, function()
		for i, child in ipairs(Frame:GetDescendants()) do
			if child:IsA('GuiObject') and child ~= Frame then
				task.delay(i * ANIMATION_CONFIG.ElementDelay, function()
					if child:IsA('TextLabel') or child:IsA('TextButton') then
						TweenService:Create(
							child,
							TweenInfo.new(0.3, Enum.EasingStyle.Quad),
							{
								TextTransparency = child:GetAttribute('OriginalTextTransparency') or 0,
							}
						):Play()
					end
					
					if child:IsA('ImageLabel') or child:IsA('ImageButton') then
						TweenService:Create(
							child,
							TweenInfo.new(0.3, Enum.EasingStyle.Quad),
							{
								ImageTransparency = child:GetAttribute('OriginalImageTransparency') or 0,
							}
						):Play()
					end
					
					if child:FindFirstChild('UIStroke') then
						TweenService:Create(
							child.UIStroke,
							TweenInfo.new(0.3, Enum.EasingStyle.Quad),
							{
								Transparency = child.UIStroke:GetAttribute('OriginalTransparency') or 0,
							}
						):Play()
					end
				end)
			end
		end
	end)
end

-- INIT
return table.freeze({
	Open = OpenFrame,
	Close = CloseFrame,
})