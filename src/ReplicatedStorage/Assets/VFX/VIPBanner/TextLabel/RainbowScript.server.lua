local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Configuration
local SPEED = 2 -- Speed of the rainbow cycle (higher = faster)
local NUM_KEYPOINTS = 5 -- Number of color stops in the gradient

-- Get or create UIGradient
local uiGradient = script.Parent:FindFirstChildOfClass("UIGradient")
if not uiGradient then
	uiGradient = Instance.new("UIGradient")
	uiGradient.Parent = script.Parent
end

-- Function to create rainbow gradient keypoints
local function createRainbowGradient(offset)
	local keypoints = {}

	for i = 0, NUM_KEYPOINTS - 1 do
		local time = i / (NUM_KEYPOINTS - 1)
		local hue = ((offset + time) % 1)
		local color = Color3.fromHSV(hue, 1, 1)
		table.insert(keypoints, ColorSequenceKeypoint.new(time, color))
	end

	return ColorSequence.new(keypoints)
end

-- Rainbow loop animation
local offset = 0
RunService.Heartbeat:Connect(function(deltaTime)
	offset = (offset + SPEED * deltaTime * 0.1) % 1
	uiGradient.Color = createRainbowGradient(offset)
end)