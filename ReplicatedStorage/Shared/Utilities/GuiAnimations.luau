--// Services //--
local TweenService = game:GetService("TweenService")

--// Module //--
local GuiAnimations = {}

--// Variables //--
local defaultInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local activeTweens = {}
local animationLocks = {}

--// Helper //--
local function tween(obj, props, info)
	if not obj then return end
	local t = TweenService:Create(obj, info or defaultInfo, props)
	t:Play()
	return t
end

local function canAnimate(obj, animType)
	local key = tostring(obj) .. animType
	return not animationLocks[key]
end

local function lockAnimation(obj, animType, duration)
	local key = tostring(obj) .. animType
	animationLocks[key] = true
	task.delay(duration, function()
		animationLocks[key] = nil
	end)
end

--// Main //--
function GuiAnimations.ButtonHover(button, hoverScale, clickScale)
	hoverScale = hoverScale or 0.95
	clickScale = clickScale or 0.9

	local size = button.Size
	local xsize = size.X.Scale
	local ysize = size.Y.Scale

	local conns = {}

	conns[1] = button.MouseEnter:Connect(function()
		tween(button, {Size = UDim2.fromScale(xsize * hoverScale, ysize * hoverScale)}, TweenInfo.new(0.15))
	end)

	conns[2] = button.MouseLeave:Connect(function()
		tween(button, {Size = UDim2.fromScale(xsize, ysize)}, TweenInfo.new(0.15))
	end)

	conns[3] = button.Activated:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.075, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true), {
			Size = UDim2.fromScale(xsize * clickScale, ysize * clickScale)
		}):Play()
	end)

	button.AncestryChanged:Connect(function()
		if button.Parent == nil or not button:IsDescendantOf(game) then
			for _, conn in conns do
				conn:Disconnect()
			end
		end
	end)
end

function GuiAnimations.SlideIn(frame, duration)
	duration = duration or 0.35

	if not canAnimate(frame, "Slide") then return end
	lockAnimation(frame, "Slide", duration)

	local origPos = frame.Position
	frame.Position = UDim2.fromScale(0.5, 1.25)

	return tween(frame, {Position = origPos}, TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
end

function GuiAnimations.SlideOut(frame, duration)
	duration = duration or 0.35

	if not canAnimate(frame, "Slide") then return end
	lockAnimation(frame, "Slide", duration)

	local origPos = frame.Position
	local t = tween(frame, {Position = UDim2.fromScale(0.5, 1.25)}, TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.In))

	task.spawn(function()
		t.Completed:Wait()
		frame.Position = origPos
	end)

	return t
end

function GuiAnimations.Pulse(uiObj, scale, duration)
	scale = scale or 1.05
	duration = duration or 0.2

	if not canAnimate(uiObj, "Pulse") then return end
	lockAnimation(uiObj, "Pulse", duration)

	local origSize = uiObj.Size
	local bigger = UDim2.new(origSize.X.Scale * scale, 0, origSize.Y.Scale * scale, 0)

	return tween(uiObj, {Size = bigger}, TweenInfo.new(duration/2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true))
end

function GuiAnimations.Flash(uiObj, color, duration, alpha, snap, colorType)
	alpha = alpha or 1
	duration = duration or 0.1
	color = color or Color3.new(1, 1, 1)

	if not canAnimate(uiObj, "Flash") then return end
	lockAnimation(uiObj, "Flash", duration)

	if not colorType then
		if uiObj:IsA("TextLabel") or uiObj:IsA("TextButton") then
			colorType = "TextColor3"
		elseif uiObj:IsA("ImageLabel") or uiObj:IsA("ImageButton") then
			colorType = "ImageColor3"
		elseif uiObj:IsA("Frame") then
			colorType = "BackgroundColor3"
		else
			warn("GuiAnimations.Flash: Unsupported UI type:", uiObj.ClassName)
			return
		end
	end

	local origColor = uiObj:GetAttribute("OriginalColor") or uiObj[colorType]
	local finalColor = origColor:Lerp(color, alpha)

	if snap then
		uiObj[colorType] = finalColor
		local t = tween(uiObj, {[colorType] = origColor}, TweenInfo.new(duration/2, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut))
		task.spawn(function()
			t.Completed:Wait()
			uiObj[colorType] = origColor
		end)
		return t
	else
		local t = tween(uiObj, {[colorType] = finalColor}, TweenInfo.new(duration/2, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut, 0, true))
		return t
	end
end

function GuiAnimations.Fade(uiObj, isIn, duration)
	duration = duration or 0.3

	if not canAnimate(uiObj, "Fade") then return end
	lockAnimation(uiObj, "Fade", duration)

	local from, to = (isIn and 1 or 0), (isIn and 0 or 1)

	uiObj.BackgroundTransparency = from
	tween(uiObj, {BackgroundTransparency = to}, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))

	for _, child in uiObj:GetDescendants() do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			child.TextTransparency = from
			tween(child, {TextTransparency = to}, TweenInfo.new(duration))
		elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
			child.ImageTransparency = from
			tween(child, {ImageTransparency = to}, TweenInfo.new(duration))
		end
	end
end

function GuiAnimations.Zoom(uiObj, direction, scale, duration)
	scale = scale or 1.2
	duration = duration or 0.2

	if not canAnimate(uiObj, "Zoom") then return end
	lockAnimation(uiObj, "Zoom", duration)

	local origSize = uiObj.Size
	local bigSize = UDim2.new(origSize.X.Scale * scale, 0, origSize.Y.Scale * scale, 0)

	if direction == "in" then
		uiObj.Size = bigSize
		return tween(uiObj, {Size = origSize}, TweenInfo.new(duration))
	elseif direction == "out" then
		local t = tween(uiObj, {Size = bigSize}, TweenInfo.new(duration))
		task.spawn(function()
			t.Completed:Wait()
			uiObj.Size = origSize
		end)
		return t
	end
end

function GuiAnimations.Spin(uiObj, duration, clockwise)
	duration = duration or 1
	clockwise = (clockwise ~= false)

	local start = 0
	local finish = clockwise and 360 or -360

	task.spawn(function()
		while uiObj and uiObj.Parent do
			local t = tween(uiObj, {Rotation = finish}, TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut))
			t.Completed:Wait()
			uiObj.Rotation = start
		end
	end)
end

function GuiAnimations.Float(uiObj, margin, duration, looped)
	margin = margin or 0.02
	duration = duration or 1

	local origPos = uiObj.Position
	local endPos = origPos - UDim2.fromScale(0, margin)

	return tween(uiObj, {Position = endPos}, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, looped and -1 or 0, true))
end

return GuiAnimations