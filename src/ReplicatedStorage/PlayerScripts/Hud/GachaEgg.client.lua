------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")

------------------//MODULES
local NotificationController = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("NotificationUtility"))
local PETS_DATA_MODULE = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("PetsData"))
local RARITYS_DATA_MODULE = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("RaritysData"))

------------------//CONSTANTS
local ASSETS_FOLDER = ReplicatedStorage:WaitForChild("Assets")
local EFFECTS_FOLDER = ASSETS_FOLDER:WaitForChild("Effects")
local EGGS_FOLDER = Workspace:WaitForChild("FolderEgg")
local EGGS_ANIMATION_FOLDER = ASSETS_FOLDER:WaitForChild("Egg")

local REMOTE_NAME = "EggGachaRemote"
local CHECK_FUNDS_REMOTE_NAME = "CheckEggFundsRemote"

local FASTER_HATCH_GAMEPASS_ID = 1702677369

local ANIM_SETTINGS = {
	DistanceStart = 12, 
	DistanceClose = 7, 

	ScriptableOffset = 6,

	HoverSpeed = 1.5,
	HoverAmp = 0.3,

	EggScale = 0.6,
	PetScale = 0.6,

	EggVerticalOffset = -1.69, 
	PetVerticalOffset = -0.5  
}

------------------//VARIABLES
local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local gachaRemote = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild(REMOTE_NAME)
local checkFundsRemote = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild(CHECK_FUNDS_REMOTE_NAME)

local isOpening = false
local renderConnection = nil

local gachaState = {
	Model = nil,
	CurrentDistance = ANIM_SETTINGS.DistanceStart,
	BaseRotation = 0,
	ShakeIntensity = 0,
	SquashFactor = Vector3.new(1, 1, 1),
	IsPet = false,
	HoverAlpha = 0,
	FixedCameraCF = CFrame.new() 
}

------------------//FUNCTIONS

local function toggleAllPrompts(status)
	for _, v in pairs(Workspace:GetDescendants()) do
		if v:IsA("ProximityPrompt") then
			v.Enabled = status
		end
	end
end

local function checkFasterHatch()
	local success, hasPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, FASTER_HATCH_GAMEPASS_ID)
	end)
	return success and hasPass
end

local function spawnParticles(model, rarityColor, isExplosion)
	if not model or not model.PrimaryPart then return end
	local particleRoot = model.PrimaryPart

	local template = EFFECTS_FOLDER:FindFirstChild("Sparkles") 
	if template then
		local visuals = template:Clone()
		visuals.Parent = particleRoot
		for _, desc in pairs(visuals:GetDescendants()) do
			if desc:IsA("ParticleEmitter") then
				desc.Color = ColorSequence.new(rarityColor)
				if isExplosion then
					desc:Emit(50)
				else
					desc.Enabled = true
				end
			end
		end
		if isExplosion then Debris:AddItem(visuals, 3) end
	end
end

local function flashScreen(color, duration)
	local gui = Instance.new("ScreenGui")
	gui.IgnoreGuiInset = true
	gui.Parent = Player.PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color or Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0
	frame.Parent = gui

	local tween = TweenService:Create(frame, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
	tween:Play()
	tween.Completed:Connect(function() gui:Destroy() end)
end

local function togglePlayerControl(lock)
	local char = Player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		char.HumanoidRootPart.Anchored = lock
		if lock then
			local offsetCamCF = Camera.CFrame * CFrame.new(0, 0, ANIM_SETTINGS.ScriptableOffset)
			Camera.CFrame = offsetCamCF
			gachaState.FixedCameraCF = offsetCamCF

			Camera.CameraType = Enum.CameraType.Scriptable

			char.Humanoid.WalkSpeed = 0
			char.Humanoid.JumpPower = 0
		else
			Camera.CameraType = Enum.CameraType.Custom

			char.Humanoid.WalkSpeed = 16
			char.Humanoid.JumpPower = 50
		end
	end
end

local function startRenderLoop()
	if renderConnection then renderConnection:Disconnect() end
	local startTime = os.clock()

	renderConnection = RunService.RenderStepped:Connect(function(dt)
		if not gachaState.Model or not gachaState.Model.PrimaryPart then return end

		local timeNow = os.clock() - startTime

		gachaState.HoverAlpha = gachaState.HoverAlpha + (dt * ANIM_SETTINGS.HoverSpeed)
		local hoverY = math.sin(gachaState.HoverAlpha) * ANIM_SETTINGS.HoverAmp

		local shakeOffset = Vector3.new(0,0,0)
		local shakeAngle = CFrame.new()

		if gachaState.ShakeIntensity > 0 then
			local i = gachaState.ShakeIntensity
			shakeOffset = Vector3.new(
				(math.random() - 0.5) * 0.2 * i,
				(math.random() - 0.5) * 0.2 * i,
				0
			)
			shakeAngle = CFrame.Angles(
				math.rad((math.random() - 0.5) * 2 * i),
				math.rad((math.random() - 0.5) * 2 * i),
				math.rad((math.random() - 0.5) * 5 * i)
			)
		end

		local rotationCF = CFrame.Angles(0, math.rad(gachaState.BaseRotation), 0)

		local currentVerticalOffset = gachaState.IsPet and ANIM_SETTINGS.PetVerticalOffset or ANIM_SETTINGS.EggVerticalOffset

		local finalCF = gachaState.FixedCameraCF 
			* CFrame.new(0, 0, -gachaState.CurrentDistance) 
			* CFrame.new(0, hoverY + currentVerticalOffset, 0)
			* CFrame.new(shakeOffset)
			* rotationCF
			* shakeAngle

		gachaState.Model:PivotTo(finalCF)

		local baseScale = gachaState.IsPet and ANIM_SETTINGS.PetScale or ANIM_SETTINGS.EggScale
		local squash = 1 + (math.sin(timeNow * 8) * 0.01 * gachaState.ShakeIntensity)

		if baseScale * squash <= 0.01 then
			gachaState.Model:ScaleTo(0.01)
		else
			gachaState.Model:ScaleTo(baseScale * squash)
		end
	end)
end

local function cleanup()
	isOpening = false
	if renderConnection then renderConnection:Disconnect() end
	if gachaState.Model then gachaState.Model:Destroy() end

	togglePlayerControl(false)
	toggleAllPrompts(true)

	TweenService:Create(Camera, TweenInfo.new(0.8), {FieldOfView = 70}):Play()
end

local function getAnimationEggName(eggName)
	local searchName = eggName .. " Egg Rep"
	local foundEgg = EGGS_ANIMATION_FOLDER:FindFirstChild(searchName)

	if not foundEgg then
		for _, egg in ipairs(EGGS_ANIMATION_FOLDER:GetChildren()) do
			if egg.Name:find(eggName) then
				return egg.Name
			end
		end
	end

	return searchName
end

local function playGachaSequence(eggName)
	toggleAllPrompts(false)
	Player:SetAttribute("EggAnimationFinished", false)
	Player:SetAttribute("LastEggPurchase", eggName)

	local petNameResult = nil
	local petData = nil
	local rarityColor = Color3.new(1,1,1)

	local isFaster = checkFasterHatch()
	local speedMult = isFaster and 0.5 or 2

	local animEggName = getAnimationEggName(eggName)
	local eggModelSource = EGGS_ANIMATION_FOLDER:FindFirstChild(animEggName)

	if not eggModelSource then
		NotificationController:Error("Egg model not found: " .. animEggName)
		cleanup()
		return
	end

	for _, v in eggModelSource:GetDescendants() do
		if v:IsA("ParticleEmitter") then 
			v:Emit(v:GetAttribute("EmitCount")) 
		end 
	end

	togglePlayerControl(true)

	local visualEgg = eggModelSource:Clone()
	for _, v in pairs(visualEgg:GetDescendants()) do
		if v:IsA("BasePart") then v.CanCollide = false v.Anchored = true end
	end

	visualEgg.Parent = Camera
	if not visualEgg.PrimaryPart then visualEgg.PrimaryPart = visualEgg:FindFirstChild("RootPart") or visualEgg:FindFirstChildWhichIsA("BasePart") end

	gachaState.Model = visualEgg
	gachaState.CurrentDistance = ANIM_SETTINGS.DistanceStart
	gachaState.BaseRotation = 180 
	gachaState.ShakeIntensity = 0
	gachaState.IsPet = false
	gachaState.HoverAlpha = 0

	startRenderLoop()

	task.spawn(function()
		local success, result = pcall(function()
			return gachaRemote:InvokeServer(eggName)
		end)
		petNameResult = success and result or "ERROR"
	end)

	task.wait(0.5 * speedMult)

	local distValue = Instance.new("NumberValue")
	distValue.Value = gachaState.CurrentDistance
	distValue.Changed:Connect(function(v) gachaState.CurrentDistance = v end)
	TweenService:Create(distValue, TweenInfo.new(2.0 * speedMult, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Value = ANIM_SETTINGS.DistanceClose}):Play()

	local shakeValue = Instance.new("NumberValue")
	shakeValue.Value = 0
	shakeValue.Changed:Connect(function(v) gachaState.ShakeIntensity = v end)
	TweenService:Create(shakeValue, TweenInfo.new(2.0 * speedMult, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Value = 1.0}):Play()

	local timeout = 0
	while not petNameResult and timeout < 5 do
		task.wait(0.1)
		timeout += 0.1
	end

	if petNameResult == "ERROR" or not petNameResult then
		NotificationController:Error("Failed to open egg!")
		if distValue then distValue:Destroy() end
		if shakeValue then shakeValue:Destroy() end
		cleanup()
		return
	end

	petData = PETS_DATA_MODULE.GetPetData(petNameResult)
	local rarityInfo = RARITYS_DATA_MODULE[petData.Raritys]
	rarityColor = rarityInfo and rarityInfo.Color or Color3.new(1,1,1)

	TweenService:Create(shakeValue, TweenInfo.new(0.8 * speedMult, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Value = 3.0}):Play()
	TweenService:Create(Camera, TweenInfo.new(0.8 * speedMult, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = 55}):Play() 

	task.wait(0.8 * speedMult)

	flashScreen(Color3.new(1,1,1), 0.6 * speedMult)
	spawnParticles(visualEgg, rarityColor, true)

	visualEgg:Destroy()
	shakeValue:Destroy()
	distValue:Destroy()

	local visualPet = petData.Model:Clone()
	visualPet.Parent = Camera
	if not visualPet.PrimaryPart then visualPet.PrimaryPart = visualPet:FindFirstChildWhichIsA("BasePart") end

	gachaState.Model = visualPet
	gachaState.IsPet = true
	gachaState.ShakeIntensity = 0 
	gachaState.BaseRotation = 180
	gachaState.CurrentDistance = ANIM_SETTINGS.DistanceClose

	visualPet:ScaleTo(0.01)
	local popSpeed = 0.04 / (isFaster and 2 or 1)
	for i = 0, 1, popSpeed do 
		local scale = math.pow(2, -8 * i) * math.sin((i * 10 - 0.75) * (2 * math.pi) / 0.4) + 1
		if i < 0.1 then scale = i * 10 end 
		if scale < 0.01 then scale = 0.01 end
		visualPet:ScaleTo(ANIM_SETTINGS.PetScale * scale)
		RunService.RenderStepped:Wait()
	end
	visualPet:ScaleTo(ANIM_SETTINGS.PetScale)

	spawnParticles(visualPet, rarityColor, false)

	NotificationController:Show({
		message = "You hatched a " .. petData.DisplayName .. "!",
		type = "success",
		icon = "🎉",
		sound = true
	})

	Player:SetAttribute("EggAnimationFinished", true) 

	local rotationValue = Instance.new("NumberValue")
	rotationValue.Value = 180
	rotationValue.Changed:Connect(function(v) gachaState.BaseRotation = v end)
	TweenService:Create(rotationValue, TweenInfo.new(5 * speedMult, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Value = 180 + 360}):Play()

	TweenService:Create(Camera, TweenInfo.new(2 * speedMult, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {FieldOfView = 70}):Play()

	task.wait(3 * speedMult) 

	local exitSpeed = 0.05 * (isFaster and 2 or 1)
	for i = 1, 0, -exitSpeed do
		local s = math.max(0.01, ANIM_SETTINGS.PetScale * i)
		visualPet:ScaleTo(s)
		RunService.RenderStepped:Wait()
	end

	rotationValue:Destroy()
	cleanup()
end

local function validateEggFunds(eggName)
	local success, result = pcall(function()
		return checkFundsRemote:InvokeServer(eggName)
	end)

	if not success then return false, "Connection Error" end
	if not result.success then
		if result.reason == "InsufficientFunds" then
			return false, "Not enough coins!", "error"
		end
		return false, result.reason or "Error", "error"
	end
	return true
end

local function onEggTriggered(eggModel)
	if isOpening then return end

	local canBuy, msg, typeInfo = validateEggFunds(eggModel.Name)
	if not canBuy then
		NotificationController:Show({message = msg, type = typeInfo, duration = 3})
		return
	end

	isOpening = true
	task.spawn(function() playGachaSequence(eggModel.Name) end)
end

------------------//INIT
for _, egg in ipairs(EGGS_FOLDER:GetChildren()) do
	local key = egg:WaitForChild("Key", 5)
	if key then
		local prompt = key:FindFirstChild("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function() onEggTriggered(egg) end)
		end
	end
end