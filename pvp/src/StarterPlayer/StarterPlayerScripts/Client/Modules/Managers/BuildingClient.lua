-- // services

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- // variables

local LocalPlayer = Players.LocalPlayer
local TowerStorage = ReplicatedStorage:FindFirstChild("Storage"):FindFirstChild("Towers")
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")

local PlayerGui = LocalPlayer.PlayerGui
local MainGui = PlayerGui:WaitForChild("InGame_UI")

-- // states

local IS_BUILDING = false
local BUILD_CONNECTION
local SELECTED_TOWER

-- // functions

local function canPlace(position: Vector3, rotation: number, size: Vector3): boolean
	local cf = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation), 0)
	
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Blacklist
	overlapParams.FilterDescendantsInstances = {SELECTED_TOWER, LocalPlayer.Character}

	local partsInRegion = workspace:GetPartBoundsInBox(cf, size, overlapParams)

	for _, part in pairs(partsInRegion) do
		if part.Name ~= "Baseplate" and part.CanCollide and part.Transparency < 1 then
			return false
		end
	end

	return true
end

local function exitBuildMode()
	
	IS_BUILDING = false
	
	if BUILD_CONNECTION then
		BUILD_CONNECTION:Disconnect()
		BUILD_CONNECTION = nil
	end
	if SELECTED_TOWER then
		SELECTED_TOWER:Destroy()
		SELECTED_TOWER = nil
	end
	
	MainGui:WaitForChild("BuildControls").Visible = false
	
end

local function disableCollisions(Model : Model)
	for _, descendant in ipairs(Model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
		end
	end
end

local function enterBuildMode(towerName : string)
	
	if IS_BUILDING then
		exitBuildMode()
	end
	
	IS_BUILDING = true
	
	MainGui:WaitForChild("BuildControls").Visible = true
	
	SELECTED_TOWER = TowerStorage:FindFirstChild(towerName):Clone()
	if not SELECTED_TOWER then
		warn("target tower doesn't exist")
		exitBuildMode()
		return
	end
	
	SELECTED_TOWER.Parent = workspace
	disableCollisions(SELECTED_TOWER)
	
	Remotes.Building.CloseTowerInfo:Fire()

	local WhiteCircle = ReplicatedStorage.Storage.Circles.WhiteCircle:Clone()
	if not WhiteCircle then return end
	
	local Range = SELECTED_TOWER:GetAttribute("Range")
	local TargetSize = Vector3.new(0.375, Range * 2, Range * 2)
	local StartingSize = Vector3.new(0.01, 0.01, 0.01)
	
	WhiteCircle.Size = StartingSize
	
	WhiteCircle.Parent = SELECTED_TOWER
	WhiteCircle.Anchored = true
	WhiteCircle.CanCollide = false
	
	local tweenInfo = TweenInfo.new(
		0.2,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	)
	local tween = TweenService:Create(WhiteCircle, tweenInfo, { Size = TargetSize })
	tween:Play()

	local Mouse = LocalPlayer:GetMouse()
	if not Mouse then return end

	if not SELECTED_TOWER.PrimaryPart then
		warn("Tower has no Primary Part, please report ; " .. towerName)
		return
	end

	Mouse.TargetFilter = SELECTED_TOWER
	local yOffset = SELECTED_TOWER.PrimaryPart.Size.Y / 2
	
	local currentRotation = 90
	local targetRotation = currentRotation
	local rotationTween
	local rotationValue = Instance.new("NumberValue")
	rotationValue.Value = currentRotation

	local function tweenRotation(newRotation)
		if rotationTween then
			rotationTween:Cancel()
		end

		local current = rotationValue.Value
		local delta = (newRotation - current) % 360
		if delta > 180 then
			delta = delta - 360
		end
		local adjustedTarget = current + delta

		local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		rotationTween = TweenService:Create(rotationValue, tweenInfo, { Value = adjustedTarget })

		rotationTween.Completed:Connect(function()
			currentRotation = newRotation % 360
			rotationValue.Value = currentRotation
		end)

		rotationTween:Play()
	end

	rotationValue:GetPropertyChangedSignal("Value"):Connect(function()
		currentRotation = rotationValue.Value
	end)
	
	local InputConn
	local ClickConn

	InputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if not IS_BUILDING then return end

		if input.KeyCode == Enum.KeyCode.R then
			targetRotation = (targetRotation + 90) % 360
			tweenRotation(targetRotation)
		elseif input.KeyCode == Enum.KeyCode.Q then
			exitBuildMode()
		end
	end)

	ClickConn = Mouse.Button1Down:Connect(function()
		if not IS_BUILDING then return end
		if Mouse.Target then
			local targetPosition = Mouse.Hit.Position + Vector3.new(0, yOffset, 0)
			local size = SELECTED_TOWER.PrimaryPart.Size
			local canPlaceHere = canPlace(targetPosition, currentRotation, size)
			
			if Mouse.Target == workspace.Baseplate or Mouse.Target:IsA("Terrain") then
				Remotes.Building.PlaceTower:FireServer(towerName, SELECTED_TOWER.PrimaryPart.CFrame)
				exitBuildMode()
			end
			--[[
			if canPlaceHere then
				Remotes.Building.PlaceTower:FireServer(towerName, SELECTED_TOWER.PrimaryPart.CFrame)
				exitBuildMode()
			end
			]]
		end
	end)

	BUILD_CONNECTION = RunService.RenderStepped:Connect(function()
		if not IS_BUILDING then return end
		if not Mouse.Target then return end

		local TowersFolder = workspace:FindFirstChild("Towers")
		if not TowersFolder then
			TowersFolder = Instance.new("Folder")
			TowersFolder.Name = "Towers"
			TowersFolder.Parent = workspace
		end

		if SELECTED_TOWER.Parent ~= workspace then
			SELECTED_TOWER.Parent = workspace
		end

		Mouse.TargetFilter = SELECTED_TOWER

		if Mouse.Target ~= workspace.Baseplate and not(Mouse.Target:IsA("Terrain")) then
			WhiteCircle.SurfaceGui.Frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
			WhiteCircle.SurfaceGui.Frame.UIStroke.Color = Color3.fromRGB(255, 0, 0)
		else
			WhiteCircle.SurfaceGui.Frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			WhiteCircle.SurfaceGui.Frame.UIStroke.Color = Color3.fromRGB(255, 255, 255)
		end

		for _, BasePart in ipairs(SELECTED_TOWER:GetDescendants()) do
			if BasePart:IsA("BasePart") then
				BasePart.CanCollide = false
			end
		end

		local targetPosition = Mouse.Hit.Position + Vector3.new(0, yOffset, 0)
		local newCFrame = CFrame.new(targetPosition) * CFrame.Angles(0, math.rad(currentRotation), 0)
		SELECTED_TOWER:SetPrimaryPartCFrame(newCFrame)

		local towerBottomY = SELECTED_TOWER.PrimaryPart.Position.Y - (SELECTED_TOWER.PrimaryPart.Size.Y / 2)
		WhiteCircle.CFrame = CFrame.new(
			Vector3.new(SELECTED_TOWER.PrimaryPart.Position.X, towerBottomY + 0.05, SELECTED_TOWER.PrimaryPart.Position.Z)
		) * CFrame.Angles(0, 0, math.pi / 2)
	end)
	
end

ReplicatedStorage.Remotes.Building.ClientRequest.Event:Connect(function(SlotNumber : number)
	
	local UserData = LocalPlayer:FindFirstChild("UserData")
	if not UserData then return end
	
	local Inventory = UserData:FindFirstChild("Hotbar")
	if not Inventory then return end 
	
	local SlotData = Inventory:FindFirstChild(SlotNumber)
	if not SlotData then return end 
	
	local TargetUnit = SlotData.Value
	if not TargetUnit then return end
	
	if SlotData.Value == "" or SlotData.Value == nil then return end
	
	enterBuildMode(TargetUnit)
	
end)

Remotes.Building.Cancel.Event:Connect(function()
	exitBuildMode()
end)

Remotes.PVP.UnblockZone.OnClientEvent:Connect(function(TargetPart : BasePart)
	if TargetPart then
		TargetPart:Destroy()
	end
end)

return {}