-- Billboard GUI Distance Disabler with Smooth Fading
-- Place this in StarterPlayerScripts as a LocalScript

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Configuration
local MAX_DISTANCE = 20 -- Full visibility within this range
local FADE_DISTANCE = 30 -- Completely hidden beyond this range
local UPDATE_INTERVAL = 0.1

local player = Players.LocalPlayer
local lastUpdate = 0

-- Track original transparency values
local originalTransparencies = {}

local function getAllBillboardGuis()
	local billboards = {}

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BillboardGui") and descendant.Name ~= "VipBanner" and descendant.Name ~= "leaderboardB" then
			table.insert(billboards, descendant)
		end
	end

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer.Character then
			for _, descendant in ipairs(otherPlayer.Character:GetDescendants()) do
				if descendant:IsA("BillboardGui") then
					table.insert(billboards, descendant)
				end
			end
		end
	end

	return billboards
end

local function getBillboardPosition(billboard)
	if billboard.Adornee then
		if billboard.Adornee:IsA("BasePart") then
			return billboard.Adornee.Position
		elseif billboard.Adornee:IsA("Attachment") then
			return billboard.Adornee.WorldPosition
		end
	end

	if billboard.Parent and billboard.Parent:IsA("BasePart") then
		return billboard.Parent.Position
	end

	return nil
end

local function storeOriginalTransparency(billboard)
	if not originalTransparencies[billboard] then
		originalTransparencies[billboard] = {}
		for _, child in ipairs(billboard:GetDescendants()) do
			local data = {}
			local hasData = false

			-- GuiObject base properties (Frame, TextLabel, ImageLabel, etc.)
			if child:IsA("GuiObject") then
				data.BackgroundTransparency = child.BackgroundTransparency
				hasData = true
			end

			-- TextLabel, TextButton, TextBox
			if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
				data.TextTransparency = child.TextTransparency
				data.TextStrokeTransparency = child.TextStrokeTransparency
				hasData = true
			end

			-- ImageLabel, ImageButton
			if child:IsA("ImageLabel") or child:IsA("ImageButton") then
				data.ImageTransparency = child.ImageTransparency
				hasData = true
			end

			-- UIStroke
			if child:IsA("UIStroke") then
				data.Transparency = child.Transparency
				hasData = true
			end

			-- ScrollingFrame
			if child:IsA("ScrollingFrame") then
				data.ScrollBarImageTransparency = child.ScrollBarImageTransparency
				hasData = true
			end

			-- ViewportFrame
			if child:IsA("ViewportFrame") then
				data.ImageTransparency = child.ImageTransparency
				hasData = true
			end

			-- CanvasGroup
			if child:IsA("CanvasGroup") then
				data.GroupTransparency = child.GroupTransparency
				hasData = true
			end

			if hasData then
				originalTransparencies[billboard][child] = data
			end
		end
	end
end

local function setFade(billboard, fadeAmount)
	storeOriginalTransparency(billboard)

	for child, originalValues in pairs(originalTransparencies[billboard] or {}) do
		if child and child.Parent then
			-- Calculate new transparency (higher fadeAmount = more transparent)

			-- BackgroundTransparency (GuiObjects)
			if originalValues.BackgroundTransparency then
				local bgTransparency = originalValues.BackgroundTransparency + (1 - originalValues.BackgroundTransparency) * fadeAmount
				child.BackgroundTransparency = math.clamp(bgTransparency, 0, 1)
			end

			-- TextTransparency (TextLabel, TextButton, TextBox)
			if originalValues.TextTransparency then
				local textTransparency = originalValues.TextTransparency + (1 - originalValues.TextTransparency) * fadeAmount
				child.TextTransparency = math.clamp(textTransparency, 0, 1)
			end

			-- TextStrokeTransparency (TextLabel, TextButton, TextBox)
			if originalValues.TextStrokeTransparency then
				local textStrokeTransparency = originalValues.TextStrokeTransparency + (1 - originalValues.TextStrokeTransparency) * fadeAmount
				child.TextStrokeTransparency = math.clamp(textStrokeTransparency, 0, 1)
			end

			-- ImageTransparency (ImageLabel, ImageButton, ViewportFrame)
			if originalValues.ImageTransparency then
				local imageTransparency = originalValues.ImageTransparency + (1 - originalValues.ImageTransparency) * fadeAmount
				child.ImageTransparency = math.clamp(imageTransparency, 0, 1)
			end

			-- UIStroke Transparency
			if originalValues.Transparency then
				local strokeTransparency = originalValues.Transparency + (1 - originalValues.Transparency) * fadeAmount
				child.Transparency = math.clamp(strokeTransparency, 0, 1)
			end

			-- ScrollBarImageTransparency (ScrollingFrame)
			if originalValues.ScrollBarImageTransparency then
				local scrollTransparency = originalValues.ScrollBarImageTransparency + (1 - originalValues.ScrollBarImageTransparency) * fadeAmount
				child.ScrollBarImageTransparency = math.clamp(scrollTransparency, 0, 1)
			end

			-- GroupTransparency (CanvasGroup)
			if originalValues.GroupTransparency then
				local groupTransparency = originalValues.GroupTransparency + (1 - originalValues.GroupTransparency) * fadeAmount
				child.GroupTransparency = math.clamp(groupTransparency, 0, 1)
			end
		end
	end
end

local function updateBillboards()
	local character = player.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local playerPosition = humanoidRootPart.Position
	local billboards = getAllBillboardGuis()

	for _, billboard in ipairs(billboards) do
		if billboard:IsDescendantOf(character) then
			continue
		end

		local billboardPosition = getBillboardPosition(billboard)

		if billboardPosition then
			local distance = (playerPosition - billboardPosition).Magnitude

			if distance <= MAX_DISTANCE then
				-- Full visibility
				setFade(billboard, 0)
			elseif distance >= FADE_DISTANCE then
				-- Completely hidden
				setFade(billboard, 1)
			else
				-- Fade based on distance
				local fadeAmount = (distance - MAX_DISTANCE) / (FADE_DISTANCE - MAX_DISTANCE)
				setFade(billboard, fadeAmount)
			end
		end
	end
end

RunService.Heartbeat:Connect(function(deltaTime)
	lastUpdate = lastUpdate + deltaTime

	if lastUpdate >= UPDATE_INTERVAL then
		lastUpdate = 0
		updateBillboards()
	end
end)

workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("BillboardGui") then
		task.wait(0.1)
		updateBillboards()
	end
end)

task.wait(1)
updateBillboards()

print("Billboard GUI Smooth Fader loaded!")
print("Full visibility:", MAX_DISTANCE, "studs | Fade out:", FADE_DISTANCE, "studs")