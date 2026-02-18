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

local MobileButtons = MainGui:WaitForChild("MobileButtons")
local MobilePlace = MobileButtons:WaitForChild("Place")
local MobileRotate = MobileButtons:WaitForChild("Rotate")
local MobileCancel = MobileButtons:WaitForChild("Cancel")

-- // states

local ROTATE_COOLDOWN = false
local IS_BUILDING = false
local BUILD_CONNECTION
local SELECTED_TOWER

local IS_MOBILE = UserInputService.TouchEnabled
local InputConn
local ClickConn

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
	MobileButtons.Visible = false

end

local function setModelCollision(model: Model, state: boolean)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = state
		end
	end

	model.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CanCollide = state
		end
	end)
end

local function enterBuildMode(towerName : string)
	--warn("BUILD MODE")
	if IS_BUILDING then
		exitBuildMode()
	end

	IS_BUILDING = true

	if IS_MOBILE then
		MobileButtons.Visible = true
	else
		MainGui:WaitForChild("BuildControls").Visible = true
		MobileButtons.Visible = false
	end
	
	print(towerName)

	SELECTED_TOWER = TowerStorage:FindFirstChild(towerName):Clone()
	if not SELECTED_TOWER then
		warn("Target tower doesn't exist")
		exitBuildMode()
		return
	end

	SELECTED_TOWER.Parent = workspace
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

	setModelCollision(SELECTED_TOWER, false)

	local tween = TweenService:Create(
		WhiteCircle,
		TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = TargetSize }
	)
	tween:Play()

	local Mouse = LocalPlayer:GetMouse()
	if not Mouse then return end
	if not SELECTED_TOWER.PrimaryPart then
		warn("Tower has no PrimaryPart: " .. towerName)
		return
	end

	Mouse.TargetFilter = SELECTED_TOWER
	setModelCollision(SELECTED_TOWER, false)
	local yOffset = SELECTED_TOWER.PrimaryPart.Size.Y / 2
	local currentRotation = 90
	local targetRotation = currentRotation
	local rotationTween
	local rotationValue = Instance.new("NumberValue")
	rotationValue.Value = currentRotation

	local function tweenRotation(newRotation)
		if rotationTween then rotationTween:Cancel() end
		local current = rotationValue.Value
		local delta = (newRotation - current) % 360
		if delta > 180 then delta = delta - 360 end
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

	if not IS_MOBILE then
		InputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed or not IS_BUILDING then return end
			if input.KeyCode == Enum.KeyCode.R and not(ROTATE_COOLDOWN) then
				ROTATE_COOLDOWN = true
				targetRotation = (targetRotation + 90) % 360
				tweenRotation(targetRotation)
				task.wait(.2)
				ROTATE_COOLDOWN = false
			elseif input.KeyCode == Enum.KeyCode.Q then
				exitBuildMode()
			end
		end)

		ClickConn = Mouse.Button1Down:Connect(function()
			if not IS_BUILDING then return end
			if Mouse.Target == workspace.Baseplate or (Mouse.Target and Mouse.Target:IsA("Terrain")) then
				Remotes.Building.PlaceTower:FireServer(towerName, SELECTED_TOWER.PrimaryPart.CFrame)
				exitBuildMode()
			end
		end)
	end

	if IS_MOBILE then
		local function getPlacementPositionFromScreen(touchPos)
			local ray = workspace.CurrentCamera:ScreenPointToRay(touchPos.X, touchPos.Y)
			local raycastParams = RaycastParams.new()
			raycastParams.FilterDescendantsInstances = { SELECTED_TOWER, LocalPlayer.Character }
			local result = workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
			if result and result.Instance == workspace.Baseplate then
				return result.Position + Vector3.new(0, yOffset, 0)
			end
			return nil
		end

		UserInputService.TouchTap:Connect(function(touchPositions)
			if not IS_BUILDING then return end
			local screenPos = touchPositions[1]
			local newPos = getPlacementPositionFromScreen(screenPos)
			if newPos then
				local newCFrame = CFrame.new(newPos) * CFrame.Angles(0, math.rad(currentRotation), 0)
				SELECTED_TOWER:SetPrimaryPartCFrame(newCFrame)
			end
		end)

		MobileRotate.Activated:Connect(function()
			if not IS_BUILDING then return end
			if not SELECTED_TOWER or not SELECTED_TOWER.PrimaryPart then return end
			targetRotation = (targetRotation + 90) % 360
			tweenRotation(targetRotation)
			local currentPos = SELECTED_TOWER.PrimaryPart.Position
			local newCFrame = CFrame.new(currentPos) * CFrame.Angles(0, math.rad(targetRotation), 0)
			SELECTED_TOWER:SetPrimaryPartCFrame(newCFrame)
		end)

		MobilePlace.Activated:Connect(function()
			if not IS_BUILDING then return end
			Remotes.Building.PlaceTower:FireServer(towerName, SELECTED_TOWER.PrimaryPart.CFrame)
			exitBuildMode()
		end)

		MobileCancel.Activated:Connect(function()
			exitBuildMode()
		end)
	end

	BUILD_CONNECTION = RunService.RenderStepped:Connect(function()
		if not IS_BUILDING then return end

		setModelCollision(SELECTED_TOWER, false)

		if not IS_MOBILE then
			if Mouse.Target then
				local targetPosition = Mouse.Hit.Position + Vector3.new(0, yOffset, 0)
				local newCFrame = CFrame.new(targetPosition) * CFrame.Angles(0, math.rad(currentRotation), 0)
				SELECTED_TOWER:SetPrimaryPartCFrame(newCFrame)

				if Mouse.Target == workspace.Baseplate or (Mouse.Target and Mouse.Target:IsA("Terrain")) then
					WhiteCircle.SurfaceGui.Frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					WhiteCircle.SurfaceGui.Frame.UIStroke.Color = Color3.fromRGB(255, 255, 255)
				else
					--warn(Mouse.Target)
					WhiteCircle.SurfaceGui.Frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
					WhiteCircle.SurfaceGui.Frame.UIStroke.Color = Color3.fromRGB(255, 0, 0)
				end
			end
		end

		local targetCFrame = SELECTED_TOWER.PrimaryPart.CFrame
		local towerBottomY = targetCFrame.Position.Y - (SELECTED_TOWER.PrimaryPart.Size.Y / 2)
		WhiteCircle.CFrame = CFrame.new(
			Vector3.new(targetCFrame.Position.X, towerBottomY + 0.05, targetCFrame.Position.Z)
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

return {}