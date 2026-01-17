local TS = game:GetService('TweenService')

local module = {}

function SetupButton(gui: GuiObject)
	if gui:HasTag('Setup') then return end
	gui:AddTag('Setup')
	
	gui:SetAttribute('DefaultPos', gui.Position)
	gui:SetAttribute('AnchorPoint', gui.AnchorPoint)
	gui:SetAttribute('Hovered', false)
	gui:SetAttribute('Pressed', false)
	
	local sz = gui.Size
	local xS, yS = sz.X.Scale, sz.Y.Scale
	local xO, yO = sz.X.Offset, sz.Y.Offset
	
	gui:SetAttribute('DefaultSize', gui.Size)
	gui:SetAttribute('HoverSize', UDim2.new(xS * 1.1, xO * 1.1, yS * 1.1, yO * 1.1))
	gui:SetAttribute('ShrinkSize', UDim2.new(xS * 0.94, xO * 0.94, yS * 0.94, yO * 0.94))
	gui:SetAttribute('PressedSize', UDim2.new(xS * 0.9, xO * 0.9, yS * 0.9, yO * 0.9))
end

function Pressed(button)
	TS:Create(button, TweenInfo.new(0.15), {Size = button:GetAttribute('PressedSize')}):Play()
end

function Released(button)
	local isHovered = button:GetAttribute('Hovered')
	local isShrunk = button:GetAttribute('Shrunk')
	
	local size
	if isHovered then
		if isShrunk then
			size = button:GetAttribute('ShrinkSize')
		else
			size = button:GetAttribute('HoverSize')
		end
	else
		size = button:GetAttribute('DefaultSize')
	end
	
	TS:Create(button, TweenInfo.new(0.15), {Size = size}):Play()
end

function Hovered(button, shrink)
	TS:Create(button, TweenInfo.new(0.1), {
		Size = shrink and button:GetAttribute('ShrinkSize') or button:GetAttribute('HoverSize')
	}):Play()
	button:SetAttribute('Shrunk', true)
end

function UnHovered(button)
	TS:Create(button, TweenInfo.new(0.1), {Size = button:GetAttribute('DefaultSize')}):Play()
	button:SetAttribute('Shrunk', false)
end

-- =======================
-- Public
-- =======================

function module:Press(button: GuiButton, func: () -> ()?, ...)
	SetupButton(button)
	
	button:SetAttribute('Pressed', true)
	if func then
		func(...)
	else
		Pressed(button)
	end
end

function module:Release(button: GuiButton, func: () -> ()?, ...)
	SetupButton(button)
	
	button:SetAttribute('Pressed', false)
	if func then
		func(...)
	else
		Released(button)
	end
end

function module.Pressed(button: GuiButton, func: () -> ()?)
	SetupButton(button)
	
	button.MouseButton1Down:Connect(function(...)
		module:Press(button, func, ...)
	end)
end

function module.Released(button: GuiButton, func: () -> ()?)
	SetupButton(button)

	button.MouseButton1Up:Connect(function(...)
		module:Release(button, func, ...)
	end)
end

function module.MouseEnter(button: GuiObject, func: () -> ()?, shrink: boolean?)
	SetupButton(button)
	
	button.MouseEnter:Connect(function(...)
		button:SetAttribute('Hovered', true)
		if func then
			func(...)
		else
			Hovered(button, shrink)
		end
	end)
end

function module.MouseLeave(button: GuiObject, func: () -> ()?)
	SetupButton(button)
	
	button.MouseLeave:Connect(function(...)
		button:SetAttribute('Hovered', false)
		if func then
			func(...)
		else
			UnHovered(button)
		end
	end)
end

function module.new(button: GuiObject)
	module.Pressed(button)
	module.Released(button)
	module.MouseEnter(button)
	module.MouseLeave(button)
end

return module