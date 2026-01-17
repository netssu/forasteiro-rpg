local PongController = {}
local LocalizationService = game:GetService("LocalizationService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local localPlayer = Players.LocalPlayer
local clientModules = localPlayer.PlayerScripts.Modules
local AnimationController = require("./AnimationController")
local Essentials = require(ReplicatedStorage.KiwiBird.Essentials)
local TimedPrompt = require(clientModules.TimedPrompt.TimedPrompt)
local UIController = require("./UIController")
local MAX_CUPS = 6
local SLOWDOWN_PRODUCT_ID = 3502295230
local PLUSCUP_PRODUCT_ID = 3466651970
local PongServiceEvent = ReplicatedStorage.Remotes.Events.PongService
local camera = workspace.CurrentCamera

-- Try to get translator if it exists
local translator = nil
pcall(function()
	translator = LocalizationService:GetTranslatorForPlayerAsync(localPlayer)
end)

local gui = localPlayer:WaitForChild("PlayerGui"):WaitForChild("MainGameUi")

local currentGame = {
	active = false,
	opponent = nil,
	table = nil,
	connections = {},
	trajectoryLine = nil,
	ball = nil,
}

local ballPowerConnection = nil
local ballCountdownConnection = nil
local trajectoryConnection = nil
local activeBallAnimations = {}

local isInRedemption = false
local redemptionRound = 0
local redemptionMaxRounds = 15

-- Prompts
local activePrompt = nil
local promptPlusCupWasShown = false
local promptSlowdownWasShown = false

-- Typewriter state tracking
local currentTypewriterThread = nil
local currentTypeSound = nil

local cameraSmoothing = {
	velocity = Vector3.new(0, 0, 0),
	angularVelocity = Vector3.new(0, 0, 0),
	smoothTime = 0.15,
	maxSpeed = 50,
}

-- ============================================
-- LOCAL POWER METER STATE (for smooth animation)
-- ============================================
local localPowerState = {
	active = false,
	power = 0,
	increasing = true,
	speed = 1,
	displayPower = 0, -- Smoothed display value
	smoothingFactor = 0.15, -- Lerp factor for smoothing (lower = smoother but more lag)
	_slowdownIsEnabled = false, -- Developer product, controls is enabled
	slowdownSpeed = 0.5, -- Speed to set when slowdown is enabled, else revert to normal
}

-- Helper function to get the local player's cup count
local function getLocalCupCount()
	if not currentGame.table then
		return 0
	end

	local tableModel = currentGame.table
	local playerSide = nil

	-- Determine which side the local player is on
	if tableModel["1"]:GetAttribute("taken") == localPlayer.Name then
		playerSide = 1
	elseif tableModel["2"]:GetAttribute("taken") == localPlayer.Name then
		playerSide = 2
	else
		return 0
	end

	local cupsFolder = tableModel.Main["cups" .. playerSide]
	if cupsFolder then
		return #cupsFolder:GetChildren()
	end

	return 0
end

-- Helper function to get the other player's cup count
local function getOtherCupCount()
	if not currentGame.table then
		return 0
	end

	local tableModel = currentGame.table
	local playerSide = nil

	-- Determine which side the other player is on
	if tableModel["1"]:GetAttribute("taken") ~= localPlayer.Name then
		playerSide = 1
	elseif tableModel["2"]:GetAttribute("taken") ~= localPlayer.Name then
		playerSide = 2
	else
		return 0
	end

	local cupsFolder = tableModel.Main["cups" .. playerSide]
	if cupsFolder then
		return #cupsFolder:GetChildren()
	end

	return 0
end

-- Helper function to determine if PlusCup prompt should be shown
local function shouldPromptPlusCup(round: number): boolean
	local cupCount = getLocalCupCount()
	local otherCupCount = getOtherCupCount()
	local isLosing = cupCount < otherCupCount
	return not promptPlusCupWasShown and isLosing and not isInRedemption and round > 1
end

-- Helper function to determine if Slowdown prompt should be shown
local function shouldPromptSlowdown(redemptionTurn: number, redemptionHitSucceeded: boolean): boolean
	return not promptSlowdownWasShown and isInRedemption and redemptionTurn > 1 and not redemptionHitSucceeded
end

-- Show a specific prompt. Handles destruction of any existing prompt, and calls the callback when activated.
local function showPrompt(containerTemplate: Instance, activatedCallback: () -> ())
	if activePrompt then
		activePrompt:Destroy()
		activePrompt = nil
	end

	activePrompt = TimedPrompt.new(containerTemplate)
	activePrompt:getMaid():GiveTask(activePrompt.activated:Once(activatedCallback))

	-- Ensure "garbage collection" for activePrompt variable, when the object is destroyed.
	activePrompt:getMaid():GiveTask(function()
		activePrompt = nil
	end)
end

-- Helper function to update PlusCup visibility based on cup count
local function updatePlusCupVisibility()
	local cupCount = getLocalCupCount()
	-- Show PlusCup only if player has less than max cups AND not in redemption
	local shouldShow = cupCount < MAX_CUPS and not isInRedemption
	gui.PlusCup.Visible = shouldShow
end

-- Typewriter function
local function typeWrite(guiObject, text, delayBetweenChars)
	PongController.cancelTypewrite()
	delayBetweenChars = delayBetweenChars or 0.03
	currentTypewriterThread = task.spawn(function()
		guiObject.Visible = true
		guiObject.AutoLocalize = false
		local displayText = text

		if translator then
			pcall(function()
				displayText = translator:Translate(guiObject, text)
			end)
		end

		displayText = displayText:gsub("<br%s*/>", "\n")

		-- Store rich text version and plain text version
		local richText = displayText
		local plainText = displayText:gsub("<[^<>]->", "")

		guiObject.MaxVisibleGraphemes = 0
		guiObject.Text = richText -- Use rich text so colors work

		local index = 0
		for first, last in utf8.graphemes(plainText) do
			index += 1

			Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.key, workspace, 2)
			guiObject.MaxVisibleGraphemes = index
			task.wait(delayBetweenChars)
		end

		-- Ensure all text is visible at the end
		guiObject.MaxVisibleGraphemes = -1

		if currentTypeSound then
			currentTypeSound:Destroy()
			currentTypeSound = nil
		end

		currentTypewriterThread = nil
	end)
end

-- Quick text set (for countdowns and rapid updates - no typewriter)
local function setTextInstant(guiObject, text)
	PongController.cancelTypewrite()
	guiObject.MaxVisibleGraphemes = -1
	guiObject.Text = text
end

function PongController.PongButtons()
	local pongButtons = gui.ControlContainer.ButtonHolder

	gui.Slowdown.Visible = false

	gui.Slowdown.Activated:Connect(function()
		MarketplaceService:PromptProductPurchase(localPlayer, SLOWDOWN_PRODUCT_ID)
	end)

	pongButtons.Launch.MouseButton1Click:Connect(function()
		PongController.ThrowBall()
	end)

	pongButtons.Left.MouseButton1Down:Connect(function()
		PongController.ToggleTrajectoryMovement("left", true)
	end)

	pongButtons.Left.MouseButton1Up:Connect(function()
		PongController.ToggleTrajectoryMovement("left", false)
	end)

	pongButtons.Right.MouseButton1Down:Connect(function()
		PongController.ToggleTrajectoryMovement("right", true)
	end)

	pongButtons.Right.MouseButton1Up:Connect(function()
		PongController.ToggleTrajectoryMovement("right", false)
	end)
end

local trajectoryMovement = {
	direction = 0,
	rotationSpeed = 0.3,
	currentRotation = 0,
	connection = nil,
	debounce = false,
	debounceTime = 0.15,
}

function PongController.SmoothDampVector3(current, target, velocity, smoothTime, maxSpeed, deltaTime)
	smoothTime = math.max(0.0001, smoothTime)
	local omega = 2 / smoothTime
	local x = omega * deltaTime
	local exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)

	local change = current - target
	local originalTo = target

	local maxChange = maxSpeed * smoothTime
	local changeLength = change.Magnitude
	if changeLength > maxChange then
		change = change * (maxChange / changeLength)
	end

	target = current - change

	local temp = (velocity + omega * change) * deltaTime
	velocity = (velocity - omega * temp) * exp
	local output = target + (change + temp) * exp

	local origMinusCurrent = originalTo - current
	local outMinusOrig = output - originalTo
	if origMinusCurrent:Dot(outMinusOrig) > 0 then
		output = originalTo
		velocity = (output - originalTo) / deltaTime
	end

	return output, velocity
end

function PongController.SmoothCameraLookAt(targetPosition, deltaTime)
	if not camera or camera.CameraType ~= Enum.CameraType.Scriptable then
		return
	end

	local cameraPosition = camera.CFrame.Position
	local currentLookAt = cameraPosition + camera.CFrame.LookVector * 10

	local smoothedLookAt, newVelocity = PongController.SmoothDampVector3(
		currentLookAt,
		targetPosition,
		cameraSmoothing.velocity,
		cameraSmoothing.smoothTime,
		cameraSmoothing.maxSpeed,
		deltaTime
	)
	cameraSmoothing.velocity = newVelocity

	local newCFrame = CFrame.new(cameraPosition, smoothedLookAt)

	camera.CFrame = camera.CFrame:Lerp(newCFrame, math.min(1, deltaTime * 12))
end

function PongController.ResetCameraSmoothing()
	cameraSmoothing.velocity = Vector3.new(0, 0, 0)
	cameraSmoothing.angularVelocity = Vector3.new(0, 0, 0)
end

function PongController.FindTable(plr1, plr2)
	for _, v in workspace.QueueTables:GetChildren() do
		local podium1 = v:FindFirstChild("1")
		local podium2 = v:FindFirstChild("2")
		if
			(podium1:GetAttribute("taken") == plr1.Name and podium2:GetAttribute("taken") == plr2.Name)
			or (podium1:GetAttribute("taken") == plr2.Name and podium2:GetAttribute("taken") == plr1.Name)
		then
			return v
		end
	end
	return
end

function PongController.FindBall()
	for _, v in workspace.QueueTables:GetDescendants() do
		if v.Name == localPlayer.Name .. "_Ball" then
			return v
		end
	end
	return
end

function PongController.CreateTrajectoryLine()
	if currentGame.trajectoryLine then
		currentGame.trajectoryLine:Destroy()
	end

	local trajectoryFolder = Instance.new("Folder")
	trajectoryFolder.Name = "TrajectoryLine"
	trajectoryFolder.Parent = workspace.CurrentCamera
	currentGame.trajectoryLine = trajectoryFolder

	for i = 1, 20 do
		local segment = Instance.new("Part")
		segment.Name = "Segment" .. i
		segment.Size = Vector3.new(0.1, 0.1, 0.1)
		segment.Shape = Enum.PartType.Ball
		segment.Anchored = true
		segment.CanCollide = false
		segment.Material = Enum.Material.Neon
		segment.Color = Color3.fromRGB(255, 255, 255)
		segment.Transparency = 0.4
		segment.Parent = trajectoryFolder

		local attachment = Instance.new("Attachment")
		attachment.Parent = segment
	end

	return trajectoryFolder
end

function PongController.CalculateTrajectoryPoint(startPos, direction, t, power)
	local minDistance = 3
	local maxDistance = 12
	local distance = minDistance + ((power / 100) * (maxDistance - minDistance))
	local peakHeight = 0.8 + (power / 100) * 1.2
	local peakPosition = 0.4
	local dropSteepness = 1.8

	local segmentDistance = distance * t
	local position = startPos + (direction * segmentDistance)

	local verticalOffset
	if t < peakPosition then
		local riseT = t / peakPosition
		local easeOut = 1 - math.pow(1 - riseT, 2.5)
		verticalOffset = peakHeight * easeOut
	else
		local fallT = (t - peakPosition) / (1 - peakPosition)
		local peakToEnd = 1 - math.pow(fallT, dropSteepness)
		verticalOffset = peakHeight * peakToEnd - (fallT * fallT * 1)
	end

	position = position + Vector3.new(0, verticalOffset, 0)

	return position
end

function PongController.FindTrajectoryHitPoint(ball, power, cameraDirection)
	local startPos = ball.Position
	local hitT = 1
	local hitPosition = nil
	local hitPart = nil

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {
		ball,
		workspace.CurrentCamera,
		localPlayer.Character,
		currentGame.trajectoryLine,
	}

	local numSamples = 40
	local prevPosition = startPos

	for i = 1, numSamples do
		local t = i / numSamples
		local currentPosition = PongController.CalculateTrajectoryPoint(startPos, cameraDirection, t, power)

		local direction = currentPosition - prevPosition
		local distance = direction.Magnitude

		if distance > 0 then
			local rayResult = workspace:Raycast(prevPosition, direction, raycastParams)

			if rayResult then
				local hitDistance = (rayResult.Position - prevPosition).Magnitude
				local segmentProgress = hitDistance / distance
				hitT = ((i - 1) / numSamples) + (segmentProgress / numSamples)
				hitPosition = rayResult.Position
				hitPart = rayResult.Instance
				break
			end
		end

		prevPosition = currentPosition
	end

	return hitT, hitPosition, hitPart
end

function PongController.UpdateTrajectoryLine(ball)
	if not currentGame.trajectoryLine or not ball or not ball.Parent then
		return
	end

	-- Use local power state for smooth trajectory updates
	local power = localPowerState.displayPower
	local baseCameraDirection = camera.CFrame.LookVector
	local rotationRadians = math.rad(trajectoryMovement.currentRotation)
	local cameraDirection = CFrame.Angles(0, rotationRadians, 0) * baseCameraDirection
	local startPos = ball.Position
	local hitT = PongController.FindTrajectoryHitPoint(ball, power, cameraDirection)
	local segments = currentGame.trajectoryLine:GetChildren()
	local segmentCount = #segments

	for i, segment in ipairs(segments) do
		local t = (i / segmentCount) * hitT

		if t > hitT then
			segment.Transparency = 1
			continue
		end

		local position = PongController.CalculateTrajectoryPoint(startPos, cameraDirection, t, power)

		local nextT = math.min(((i + 1) / segmentCount) * hitT, hitT)
		local nextPosition = PongController.CalculateTrajectoryPoint(startPos, cameraDirection, nextT, power)

		segment.CFrame = CFrame.new(position, nextPosition)

		local normalizedT = t / hitT
		local distanceToEnd = math.abs(normalizedT - 1)

		if distanceToEnd < 0.15 then
			local greenIntensity = 1 - (distanceToEnd / 0.15)
			segment.Color = Color3.fromRGB(
				math.floor(255 * (1 - greenIntensity)),
				255,
				math.floor(255 * (1 - greenIntensity) * 0.5)
			)
			segment.Transparency = 0.2
			segment.Size = Vector3.new(0.1, 0.1, 0.1) * (1 + greenIntensity * 0.5)
		else
			local powerIntensity = power / 100
			local r = 255
			local g = math.max(180, 255 - (powerIntensity * normalizedT * 100))
			local b = math.max(200, 255 - (powerIntensity * normalizedT * 50))
			segment.Color = Color3.fromRGB(r, g, b)
			segment.Transparency = 0.7
			segment.Size = Vector3.new(0.1, 0.1, 0.1)
		end
	end
end

function PongController.StartTrajectoryTracking(ball)
	if trajectoryConnection then
		trajectoryConnection:Disconnect()
		trajectoryConnection = nil
	end

	PongController.CreateTrajectoryLine()

	trajectoryConnection = RunService.RenderStepped:Connect(function()
		PongController.UpdateTrajectoryLine(ball)
	end)
end

function PongController.StopTrajectoryTracking()
	if trajectoryConnection then
		trajectoryConnection:Disconnect()
		trajectoryConnection = nil
	end

	if currentGame.trajectoryLine then
		currentGame.trajectoryLine:Destroy()
		currentGame.trajectoryLine = nil
	end
end

function PongController.ToggleTrajectoryMovement(direction, active)
	if not currentGame.active or not currentGame.ball then
		return
	end

	local newDirection = 0

	if active then
		if direction == "left" then
			newDirection = 1
		elseif direction == "right" then
			newDirection = -1
		end
	end

	if trajectoryMovement.connection then
		trajectoryMovement.connection:Disconnect()
		trajectoryMovement.connection = nil
	end

	trajectoryMovement.direction = newDirection

	if newDirection ~= 0 then
		trajectoryMovement.connection = RunService.RenderStepped:Connect(function(deltaTime)
			if trajectoryMovement.direction ~= 0 then
				local rotationChange = trajectoryMovement.direction * trajectoryMovement.rotationSpeed
				trajectoryMovement.currentRotation = trajectoryMovement.currentRotation + rotationChange
				trajectoryMovement.currentRotation = math.clamp(trajectoryMovement.currentRotation, -45, 45)
			end
		end)
	end

	print("Trajectory movement:", newDirection == 1 and "LEFT" or newDirection == -1 and "RIGHT" or "STOPPED")
end

function PongController.ResetTrajectoryRotation()
	trajectoryMovement.currentRotation = 0
	trajectoryMovement.direction = 0
	if trajectoryMovement.connection then
		trajectoryMovement.connection:Disconnect()
		trajectoryMovement.connection = nil
	end
end

function PongController.AnimateBallLocally(startPos, direction, power, duration, ballName)
	local visualBall = nil

	for _, v in workspace.QueueTables:GetDescendants() do
		if v.Name == ballName then
			visualBall = v:Clone()
			visualBall.Name = "VisualBall_" .. ballName
			visualBall.Transparency = 0
			visualBall.CanCollide = false
			visualBall.Anchored = true
			visualBall.Parent = workspace.CurrentCamera
			break
		end
	end

	if not visualBall then
		warn("Could not find ball to animate:", ballName)
		return
	end

	if activeBallAnimations[ballName] then
		activeBallAnimations[ballName]:Disconnect()
		activeBallAnimations[ballName] = nil
	end

	PongController.ResetCameraSmoothing()

	local minDistance = 3
	local maxDistance = 12
	local distance = minDistance + ((power / 100) * (maxDistance - minDistance))
	local peakHeight = 0.8 + (power / 100) * 1.2
	local peakPosition = 0.4
	local dropSteepness = 1.8

	local startTime = tick()

	local connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not visualBall or not visualBall.Parent then
			if activeBallAnimations[ballName] then
				activeBallAnimations[ballName]:Disconnect()
				activeBallAnimations[ballName] = nil
			end
			return
		end

		local elapsed = tick() - startTime
		local t = math.min(elapsed / duration, 1)

		local segmentDistance = distance * t
		local position = startPos + (direction * segmentDistance)

		local verticalOffset
		if t < peakPosition then
			local riseT = t / peakPosition
			local easeOut = 1 - math.pow(1 - riseT, 2.5)
			verticalOffset = peakHeight * easeOut
		else
			local fallT = (t - peakPosition) / (1 - peakPosition)
			local peakToEnd = 1 - math.pow(fallT, dropSteepness)
			verticalOffset = peakHeight * peakToEnd - (fallT * fallT * 1)
		end

		position = position + Vector3.new(0, verticalOffset, 0)

		local nextT = math.min(t + 0.016, 1)
		local nextDistance = distance * nextT
		local nextPosition = startPos + (direction * nextDistance)

		local nextVerticalOffset
		if nextT < peakPosition then
			local nextRiseT = nextT / peakPosition
			local nextEaseOut = 1 - math.pow(1 - nextRiseT, 2.5)
			nextVerticalOffset = peakHeight * nextEaseOut
		else
			local nextFallT = (nextT - peakPosition) / (1 - peakPosition)
			local nextPeakToEnd = 1 - math.pow(nextFallT, dropSteepness)
			nextVerticalOffset = peakHeight * nextPeakToEnd - (nextFallT * nextFallT * 1)
		end

		nextPosition = nextPosition + Vector3.new(0, nextVerticalOffset, 0)

		if t < 1 then
			visualBall.CFrame = CFrame.new(position, nextPosition)
		else
			visualBall.Position = position
		end

		if camera and camera.CameraType == Enum.CameraType.Scriptable then
			local lookAtPosition = position + Vector3.new(0, 0.5, 0)
			PongController.SmoothCameraLookAt(lookAtPosition, deltaTime)
		end

		if t >= 1 then
			task.delay(0.5, function()
				if visualBall and visualBall.Parent then
					visualBall:Destroy()
				end
			end)

			if activeBallAnimations[ballName] then
				activeBallAnimations[ballName]:Disconnect()
				activeBallAnimations[ballName] = nil
			end

			PongController.ResetCameraSmoothing()
		end
	end)

	activeBallAnimations[ballName] = connection
end

function PongController.AnimateBallIntoCup(ballName, ballPosition, cupPosition)
	if activeBallAnimations[ballName] then
		activeBallAnimations[ballName]:Disconnect()
		activeBallAnimations[ballName] = nil
	end

	local visualBall = nil
	for _, obj in workspace.CurrentCamera:GetChildren() do
		if obj.Name == "VisualBall_" .. ballName then
			visualBall = obj
			break
		end
	end

	if not visualBall then
		for _, v in workspace.QueueTables:GetDescendants() do
			if v.Name == ballName then
				visualBall = v:Clone()
				visualBall.Name = "VisualBall_" .. ballName
				visualBall.Transparency = 0
				visualBall.CanCollide = false
				visualBall.Anchored = true
				visualBall.Position = ballPosition
				visualBall.Parent = workspace.CurrentCamera
				break
			end
		end
	end

	if not visualBall then
		warn("Could not find or create visual ball for sink animation")
		return
	end

	local originalSize = visualBall.Size

	visualBall.Transparency = 0
	visualBall.Position = ballPosition

	local sinkTarget = cupPosition + Vector3.new(0, -0.4, 0)

	local sinkDuration = 0.5
	local startTime = tick()
	local startPos = ballPosition

	local sinkConnection
	sinkConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if not visualBall or not visualBall.Parent then
			if sinkConnection then
				sinkConnection:Disconnect()
			end
			return
		end

		local elapsed = tick() - startTime
		local t = math.min(elapsed / sinkDuration, 1)

		local easedT = t * t

		local currentPos = startPos:Lerp(sinkTarget, easedT)

		local wobbleAmount = (1 - t) * 0.03
		local wobbleSpeed = 8
		local wobbleX = math.sin(t * math.pi * wobbleSpeed) * wobbleAmount
		local wobbleZ = math.cos(t * math.pi * wobbleSpeed) * wobbleAmount

		visualBall.Position = currentPos + Vector3.new(wobbleX, 0, wobbleZ)

		local spinSpeed = 360 * 2
		local rotation = math.rad(t * spinSpeed)
		visualBall.CFrame = CFrame.new(visualBall.Position) * CFrame.Angles(rotation, rotation * 0.5, 0)

		local scaleMultiplier = 1 - (easedT * 0.3)
		visualBall.Size = originalSize * scaleMultiplier

		if t > 0.6 then
			local fadeProgress = (t - 0.6) / 0.4
			visualBall.Transparency = fadeProgress
		end

		if camera and camera.CameraType == Enum.CameraType.Scriptable then
			local lookAtPosition = cupPosition + Vector3.new(0, 0.2, 0)
			PongController.SmoothCameraLookAt(lookAtPosition, deltaTime)
		end

		if t >= 1 then
			sinkConnection:Disconnect()

			task.delay(0.1, function()
				if visualBall and visualBall.Parent then
					visualBall:Destroy()
				end
			end)

			if activeBallAnimations[ballName .. "_sink"] then
				activeBallAnimations[ballName .. "_sink"] = nil
			end

			PongController.ResetCameraSmoothing()
		end
	end)

	activeBallAnimations[ballName .. "_sink"] = sinkConnection
end

-- ============================================
-- START LOCAL POWER METER (runs entirely on client for smooth visuals)
-- ============================================
function PongController.StartLocalPowerMeter(speed)
	speed = speed or 1

	-- Reset local power state
	localPowerState.active = true
	localPowerState.power = 0
	localPowerState.displayPower = 0
	localPowerState.increasing = true
	localPowerState.initialSpeed = speed
	localPowerState.speed = speed

	print("Starting local power meter with speed:", localPowerState.speed)
end

--[[
	Returns if slowdown is enabled.
]]
function PongController.GetIsSlowdownEnabled(): boolean
	return localPowerState._slowdownIsEnabled
end

--[[
	Sets if slowdown is enabled.
]]
function PongController.SetIsSlowdownEnabled(isEnabled: boolean)
	assert(PongController.GetIsSlowdownEnabled() ~= isEnabled, "The slowdown is already set to that state.")
	localPowerState._slowdownIsEnabled = isEnabled
	localPowerState.speed = if isEnabled then localPowerState.slowdownSpeed else localPowerState.initialSpeed
end

-- ============================================
-- STOP LOCAL POWER METER
-- ============================================
function PongController.StopLocalPowerMeter()
	localPowerState.active = false
end

-- ============================================
-- GET CURRENT POWER (returns the actual power value for throwing)
-- ============================================
function PongController.GetCurrentPower()
	return localPowerState.power
end

function PongController.ThrowBall()
	if not currentGame.ball then
		return
	end

	-- Use local power value instead of server's ball.Power.Value
	local power = PongController.GetCurrentPower()

	local baseCameraDirection = camera.CFrame.LookVector
	local rotationRadians = math.rad(trajectoryMovement.currentRotation)
	local cameraDirection = CFrame.Angles(0, rotationRadians, 0) * baseCameraDirection

	local throwForce = (power / 100) * 8

	PongController.StopTrajectoryTracking()
	PongController.ResetTrajectoryRotation()
	PongController.StopLocalPowerMeter()

	if ballPowerConnection then
		ballPowerConnection:Disconnect()
		ballPowerConnection = nil
	end

	if ballCountdownConnection then
		ballCountdownConnection:Disconnect()
		ballCountdownConnection = nil
	end

	PongServiceEvent:FireServer({
		["Action"] = "Throw",
		["Power"] = power,
		["Direction"] = cameraDirection,
		["Force"] = throwForce,
	})

	currentGame.ball = nil
end

--[[
	Cancel any typewriter effect
]]
function PongController.cancelTypewrite()
	if currentTypewriterThread then
		task.cancel(currentTypewriterThread)
		currentTypewriterThread = nil
	end

	if currentTypeSound then
		currentTypeSound:Destroy()
		currentTypeSound = nil
	end
end

function PongController.ResetClient()
	print("Resetting client game state")

	PongController.cancelTypewrite()

	-- Reset redemption flags
	isInRedemption = false
	redemptionRound = 0
	redemptionMaxRounds = 15

	-- Reset prompt flags
	promptPlusCupWasShown = false
	promptSlowdownWasShown = false

	-- Stop local power meter
	PongController.StopLocalPowerMeter()
	PongController.StopTrajectoryTracking()
	PongController.ResetTrajectoryRotation()

	for ballName, connection in activeBallAnimations do
		if connection and typeof(connection) == "RBXScriptConnection" and connection.Connected then
			connection:Disconnect()
			connection = nil
		end
	end

	activeBallAnimations = {}

	for _, obj in workspace.CurrentCamera:GetChildren() do
		if obj.Name:match("^VisualBall_") then
			obj:Destroy()
		end
	end

	PongController.ResetCameraSmoothing()

	local ballPowerMeter = gui.PowerBar.PowerHolder

	TweenService
		:Create(ballPowerMeter, TweenInfo.new(1, Enum.EasingStyle.Quint), { Position = UDim2.fromScale(1.2, 0.5) })
		:Play()

	local controlsHolder = gui.ControlContainer.ButtonHolder
	controlsHolder.Visible = false

	if ballPowerConnection then
		ballPowerConnection:Disconnect()
		ballPowerConnection = nil
	end

	if ballCountdownConnection then
		ballCountdownConnection:Disconnect()
		ballCountdownConnection = nil
	end

	for _, conn in currentGame.connections do
		if conn.Connected then
			conn:Disconnect()
			conn = nil
		end
	end

	table.clear(currentGame.connections)

	local guiText = gui.TopGameText
	setTextInstant(guiText, "")

	local inkGui = gui.Ink

	inkGui.Visible = false
	gui.PlusCup.Visible = false
	gui.Slowdown.Visible = false
	gui.MMContainer.Visible = true

	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid")

	currentGame.active = false
	currentGame.opponent = nil
	currentGame.table = nil
	currentGame.ball = nil

	print("Client reset complete")
end

function PongController.MonitorLocalPlayer()
	for _, conn in currentGame.connections do
		if conn.Connected then
			conn:Disconnect()
			conn = nil
		end
	end

	table.clear(currentGame.connections)

	local function setupDeathMonitoring()
		if localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid") then
			local deathConn = localPlayer.Character.Humanoid.Died:Connect(function()
				print("Local player died, resetting game")
				PongController.ResetClient()
			end)
			table.insert(currentGame.connections, deathConn)
		end
	end

	if localPlayer.Character then
		setupDeathMonitoring()
	end

	local charAddedConn = localPlayer.CharacterAdded:Connect(function()
		if currentGame.active then
			print("Local player respawned during game, resetting")
			PongController.ResetClient()
		end
		setupDeathMonitoring()
	end)
	table.insert(currentGame.connections, charAddedConn)
end

function PongController.MonitorOpponent(opponent)
	if not opponent then
		return
	end

	local opponentRemovedConn = opponent.AncestryChanged:Connect(function()
		if not opponent:IsDescendantOf(game) and currentGame.active then
			print("Opponent left the game, resetting")
			PongController.ResetClient()
		end
	end)
	table.insert(currentGame.connections, opponentRemovedConn)

	local function setupOpponentDeathMonitoring()
		if opponent.Character and opponent.Character:FindFirstChild("Humanoid") then
			local opponentDeathConn = opponent.Character.Humanoid.Died:Connect(function()
				if currentGame.active then
					print("Opponent died, resetting game")
					PongController.ResetClient()
				end
			end)
			table.insert(currentGame.connections, opponentDeathConn)
		end
	end

	if opponent.Character then
		setupOpponentDeathMonitoring()
	end

	local opponentCharAddedConn = opponent.CharacterAdded:Connect(function()
		if currentGame.active then
			print("Opponent respawned during game, resetting")
			PongController.ResetClient()
		end
		setupOpponentDeathMonitoring()
	end)
	table.insert(currentGame.connections, opponentCharAddedConn)
end

function PongController.Listener()
	PongServiceEvent.OnClientEvent:Connect(function(argtable)
		local guiText = gui.TopGameText

		if argtable["Action"] == "Start" then
			-- Reset redemption flags when game starts
			isInRedemption = false
			redemptionRound = 0
			redemptionMaxRounds = 15

			local table = PongController.FindTable(localPlayer, argtable["Opponent"])
			local opponent = argtable["Opponent"]

			currentGame.active = true
			currentGame.opponent = opponent
			currentGame.table = table

			PongController.MonitorLocalPlayer()
			PongController.MonitorOpponent(opponent)

			local leaveButton = gui.Leave
			leaveButton.Visible = false

			local gui2 = gui.Invite
			gui2.Visible = false

			gui.MMContainer.Visible = false

			typeWrite(guiText, "Game is Starting!!", 0.04)

			local inkGui = gui.Ink
			inkGui.Visible = false
			gui.PlusCup.Visible = false
			gui.Slowdown.Visible = false

			PongController.ResetCameraSmoothing()

			camera.CameraType = Enum.CameraType.Scriptable
			TweenService:Create(camera, TweenInfo.new(2, Enum.EasingStyle.Quint), { CFrame = table.Cams.cam3.CFrame })
				:Play()
		elseif argtable["Action"] == "AnimateBall" then
			local startPos = argtable["StartPos"]
			local direction = argtable["Direction"]
			local power = argtable["Power"]
			local duration = argtable["Duration"]
			local ballName = argtable["BallName"]

			print("Animating ball locally:", ballName, "Power:", power, "Duration:", duration)

			PongController.StopTrajectoryTracking()
			PongController.ResetTrajectoryRotation()
			PongController.StopLocalPowerMeter()

			if ballPowerConnection then
				ballPowerConnection:Disconnect()
				ballPowerConnection = nil
			end

			if ballCountdownConnection then
				ballCountdownConnection:Disconnect()
				ballCountdownConnection = nil
			end

			currentGame.ball = nil

			PongController.AnimateBallLocally(startPos, direction, power, duration, ballName)
		elseif argtable["Action"] == "BallInCup" then
			local ballName = argtable["BallName"]
			local ballPosition = argtable["BallPosition"]
			local cupPosition = argtable["CupPosition"]

			print("Ball going into cup:", ballName)

			PongController.AnimateBallIntoCup(ballName, ballPosition, cupPosition)
		elseif argtable["Action"] == "SlowdownActivate" then
			gui.Slowdown.Visible = false
			PongController.SetIsSlowdownEnabled(true)
		elseif argtable["Action"] == "YourTurn" then
			TweenService
				:Create(camera, TweenInfo.new(2, Enum.EasingStyle.Quint), { CFrame = argtable["CamSide"].CFrame })
				:Play()

			-- Get power speed from server
			local powerSpeed = argtable["PowerSpeed"] or 1

			task.delay(0.15, function()
				local ball = PongController.FindBall()
				currentGame.ball = ball

				if isInRedemption then
					typeWrite(
						guiText,
						"<font color='rgb(255,200,0)'>OVERTIME</font> Round "
							.. redemptionRound
							.. "/"
							.. redemptionMaxRounds
							.. " - Your shot!",
						0.03
					)
				else
					typeWrite(guiText, "Its your turn!", 0.04)
				end

				local inkGui = gui.Ink
				inkGui.Visible = false

				-- Update PlusCup visibility based on cup count (hidden if 6 cups or in redemption)
				updatePlusCupVisibility()

				gui.Slowdown.Visible = true

				if shouldPromptPlusCup(argtable["Round"]) then
					promptPlusCupWasShown = true

					showPrompt(gui.PromptPlusCup, function()
						MarketplaceService:PromptProductPurchase(localPlayer, PLUSCUP_PRODUCT_ID)
					end)
				end

				if shouldPromptSlowdown(argtable["RedemptionTurn"], argtable["RedemptionHitSucceeded"]) then
					promptSlowdownWasShown = true

					showPrompt(gui.PromptSlowdown, function()
						MarketplaceService:PromptProductPurchase(localPlayer, SLOWDOWN_PRODUCT_ID)
					end)
				end

				task.delay(0.3, function()
					local ballPowerMeter = gui.PowerBar.PowerHolder

					TweenService:Create(
						ballPowerMeter,
						TweenInfo.new(1, Enum.EasingStyle.Quint),
						{ Position = UDim2.fromScale(0.97, 0.5) }
					):Play()

					if ballPowerConnection then
						ballPowerConnection:Disconnect()
						ballPowerConnection = nil
					end

					if ballCountdownConnection then
						ballCountdownConnection:Disconnect()
						ballCountdownConnection = nil
					end

					-- Start local power meter with the speed from server
					PongController.StartLocalPowerMeter(powerSpeed)

					-- ============================================
					-- SMOOTH LOCAL POWER METER UPDATE
					-- Runs entirely on client for butter-smooth animation
					-- ============================================
					ballPowerConnection = RunService.PreRender:Connect(function(deltaTime)
						if not ball or not ball.Parent then
							if ballPowerConnection then
								ballPowerConnection:Disconnect()
								ballPowerConnection = nil
							end

							if PongController.GetIsSlowdownEnabled() then
								PongController.SetIsSlowdownEnabled(false)
							end

							PongController.StopLocalPowerMeter()
							return
						end

						if not localPowerState.active then
							return
						end

						-- Update the actual power value (oscillating)
						local speed = localPowerState.speed
						if localPowerState.increasing then
							localPowerState.power = localPowerState.power + (speed * deltaTime * 60)
							if localPowerState.power >= 100 then
								localPowerState.power = 100
								localPowerState.increasing = false
							end
						else
							localPowerState.power = localPowerState.power - (speed * deltaTime * 60)
							if localPowerState.power <= 0 then
								localPowerState.power = 0
								localPowerState.increasing = true
							end
						end

						-- Smooth the display value using exponential smoothing
						-- This creates fluid motion even at high speeds
						local smoothingFactor = math.min(1, deltaTime * 20) -- Adjust for responsiveness
						localPowerState.displayPower = localPowerState.displayPower
							+ (localPowerState.power - localPowerState.displayPower) * smoothingFactor

						-- Update the UI with the smoothed display value
						local displayValue = localPowerState.displayPower / 100
						ballPowerMeter.barHolderParent.barHolder.trueBarHolder.bar.Size =
							UDim2.fromScale(1, displayValue)
						ballPowerMeter.barHolderParent.barHolder.Arrow.Position =
							UDim2.fromScale(0.46, 1 - displayValue)
					end)

					-- Countdown still comes from server (for sync)
					local ballCountdown = ball:WaitForChild("Countdown", 0.5)

					if ballCountdown then
						ballCountdownConnection = ballCountdown.Changed:Connect(function(newValue)
							-- Use instant text for countdown (no typewriter - needs to be fast)
							if newValue <= 5 and newValue > 0 then
								setTextInstant(guiText, "Throw!! <font color='rgb(255,0,0)'>" .. newValue .. "s</font>")
							elseif newValue <= 0 then
								setTextInstant(guiText, "TIME'S UP!")
							else
								setTextInstant(guiText, "Throw! <font color='rgb(255,0,0)'>" .. newValue .. "s</font>")
							end
						end)
					end

					PongController.StartTrajectoryTracking(ball)

					local controlsHolder = gui.ControlContainer.ButtonHolder
					controlsHolder.Visible = true

					if PongController.GetIsSlowdownEnabled() then
						PongController.SetIsSlowdownEnabled(false)
					end
				end)
			end)
		elseif argtable["Action"] == "OpponentsTurn" then
			print("OpponentsTurn")
			TweenService
				:Create(camera, TweenInfo.new(2, Enum.EasingStyle.Quint), { CFrame = argtable["CamSide"].CFrame })
				:Play()

			local ballPowerMeter = gui.PowerBar.PowerHolder

			-- Stop local power meter when it's not our turn
			PongController.StopLocalPowerMeter()

			if isInRedemption then
				typeWrite(
					guiText,
					"<font color='rgb(255,200,0)'>OVERTIME</font> Round "
						.. redemptionRound
						.. "/"
						.. redemptionMaxRounds
						.. " - Opponent's shot!",
					0.03
				)
			else
				typeWrite(guiText, "Wait for your turn!", 0.04)
			end

			local inkGui = gui.Ink
			inkGui.Visible = true

			-- Update PlusCup visibility based on cup count (hidden if 6 cups or in redemption)
			updatePlusCupVisibility()

			gui.Slowdown.Visible = false

			TweenService
				:Create(
					ballPowerMeter,
					TweenInfo.new(1, Enum.EasingStyle.Quint),
					{ Position = UDim2.fromScale(1.2, 0.5) }
				)
				:Play()

			local controlsHolder = gui.ControlContainer.ButtonHolder
			controlsHolder.Visible = false
		elseif argtable["Action"] == "MiddleTurn" then
			local cam = argtable["Cam"]

			local ballPowerMeter = gui.PowerBar.PowerHolder
			local inkGui = gui.Ink
			inkGui.Visible = false
			gui.PlusCup.Visible = false
			gui.Slowdown.Visible = false

			-- Stop local power meter
			PongController.StopLocalPowerMeter()

			TweenService
				:Create(
					ballPowerMeter,
					TweenInfo.new(1, Enum.EasingStyle.Quint),
					{ Position = UDim2.fromScale(1.2, 0.5) }
				)
				:Play()

			local controlsHolder = gui.ControlContainer.ButtonHolder
			controlsHolder.Visible = false

			camera.CameraType = Enum.CameraType.Scriptable
			TweenService:Create(camera, TweenInfo.new(2, Enum.EasingStyle.Quint), { CFrame = cam.CFrame }):Play()

			if argtable["Drink"] then
				if argtable["Target"].Name == localPlayer.Name then
					AnimationController.PlayLoopedAnimation(
						argtable["Target"].Character.Humanoid.Animator,
						ReplicatedStorage.Assets.Animations.PongAnimations.Drink
					)
				end
			else
				print("sigam")
			end
		elseif argtable["Action"] == "Inked" then
			local inkGui = gui.inkscreen
			inkGui.ImageTransparency = 0
			inkGui.Visible = true

			UIController.showNotification("You have been inked!")

			task.delay(3, function()
				TweenService:Create(inkGui, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { ImageTransparency = 1 })
					:Play()

				task.delay(0.6, function()
					inkGui.Visible = false
				end)
			end)

			-- ============================================
			-- RedemptionStart - Initialize redemption phase
			-- ============================================
		elseif argtable["Action"] == "RedemptionStart" then
			isInRedemption = true
			redemptionRound = argtable["Round"]
			redemptionMaxRounds = argtable["MaxRounds"]

			local firstShooter = argtable["FirstShooter"]

			typeWrite(
				guiText,
				"<font color='rgb(255,200,0)'>OVERTIME!</font> "
					.. firstShooter.Name
					.. " shoots first! (Round 1/"
					.. redemptionMaxRounds
					.. ")",
				0.03
			)

			UIController.showNotification("OVERTIME MODE! Both players take turns - miss then hit to win!")

			-- ============================================
			-- RedemptionHit - Player made their shot
			-- ============================================
		elseif argtable["Action"] == "RedemptionHit" then
			local shooter = argtable["Shooter"]
			local cam = argtable["Cam"]

			typeWrite(
				guiText,
				"<font color='rgb(0,255,0)'>" .. shooter.Name .. " MADE IT!</font> Waiting for other player...",
				0.03
			)

			-- Handle drinking animation
			if argtable["Drink"] and argtable["Target"] and argtable["Target"].Name == localPlayer.Name then
				AnimationController.PlayLoopedAnimation(
					argtable["Target"].Character.Humanoid.Animator,
					ReplicatedStorage.Assets.Animations.PongAnimations.Drink
				)
			end

			camera.CameraType = Enum.CameraType.Scriptable
			TweenService:Create(camera, TweenInfo.new(2, Enum.EasingStyle.Quint), { CFrame = cam.CFrame }):Play()

			-- ============================================
			-- RedemptionMiss - Player missed their shot
			-- ============================================
		elseif argtable["Action"] == "RedemptionMiss" then
			local shooter = argtable["Shooter"]
			local nextShooter = argtable["NextShooter"]

			if nextShooter and nextShooter.Name then
				typeWrite(
					guiText,
					"<font color='rgb(255,100,100)'>"
						.. shooter.Name
						.. " MISSED!</font> "
						.. nextShooter.Name
						.. "'s turn to shoot!",
					0.03
				)
			end

			-- ============================================
			-- RedemptionRoundReset - Both players had same result
			-- ============================================
		elseif argtable["Action"] == "RedemptionRoundReset" then
			local resultText = argtable["ResultText"]
			redemptionRound = argtable["Round"]
			redemptionMaxRounds = argtable["MaxRounds"]

			typeWrite(
				guiText,
				"<font color='rgb(255,200,0)'>"
					.. resultText
					.. "</font> Starting Round "
					.. redemptionRound
					.. "/"
					.. redemptionMaxRounds,
				0.03
			)

			UIController.showNotification(resultText .. " Round " .. redemptionRound .. " starting!")

			-- ============================================
			-- Draw - Game ended in a tie
			-- ============================================
		elseif argtable["Action"] == "Draw" then
			isInRedemption = false
			redemptionRound = 0

			local cam = argtable["Cam"]
			local splitMoney = argtable["SplitMoney"]

			-- Stop local power meter
			PongController.StopLocalPowerMeter()

			typeWrite(
				guiText,
				"<font color='rgb(255,200,0)'>DRAW!</font> Money split: $" .. math.floor(splitMoney),
				0.03
			)

			UIController.showNotification("It's a DRAW! You earned $" .. math.floor(splitMoney))

			Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.boo, workspace, 2)

			local ballPowerMeter = gui.PowerBar.PowerHolder
			TweenService
				:Create(
					ballPowerMeter,
					TweenInfo.new(1, Enum.EasingStyle.Quint),
					{ Position = UDim2.fromScale(1.2, 0.5) }
				)
				:Play()

			local controlsHolder = gui.ControlContainer.ButtonHolder
			controlsHolder.Visible = false
			camera.CameraType = Enum.CameraType.Scriptable
			TweenService:Create(camera, TweenInfo.new(2, Enum.EasingStyle.Quint), { CFrame = cam.CFrame }):Play()

			task.delay(3, function()
				PongController.ResetClient()

				-- Re-enable proximity prompts
				for _, v in workspace:GetDescendants() do
					if v:IsA("ProximityPrompt") then
						v.Enabled = true

						if v.Parent.Name == "1" or v.Parent.Name == "2" then
							task.delay(0.1, function()
								if v.Parent:GetAttribute("taken") ~= "" then
									v.Enabled = false
								end
							end)
						end
					end
				end
			end)
		elseif argtable["Action"] == "TurnTransition" then
			-- Reset redemption flag when transitioning out of redemption
			isInRedemption = false
			redemptionRound = 0

			-- Stop local power meter
			PongController.StopLocalPowerMeter()

			typeWrite(guiText, "", 0.04)
		elseif argtable["Action"] == "FinishGame" then
			-- Reset redemption flags when game ends
			isInRedemption = false
			redemptionRound = 0

			-- Stop local power meter
			PongController.StopLocalPowerMeter()

			local cam = argtable["Cam"]
			local ballPowerMeter = gui.PowerBar.PowerHolder

			gui.MMContainer.Visible = true

			TweenService
				:Create(
					ballPowerMeter,
					TweenInfo.new(1, Enum.EasingStyle.Quint),
					{ Position = UDim2.fromScale(1.2, 0.5) }
				)
				:Play()

			local controlsHolder = gui.ControlContainer.ButtonHolder
			controlsHolder.Visible = false

			camera.CameraType = Enum.CameraType.Scriptable
			TweenService:Create(camera, TweenInfo.new(2, Enum.EasingStyle.Quint), { CFrame = cam.CFrame }):Play()

			if argtable["Drink"] then
				if argtable["Target"].Name == localPlayer.Name then
					AnimationController.PlayLoopedAnimation(
						argtable["Target"].Character.Humanoid.Animator,
						ReplicatedStorage.Assets.Animations.PongAnimations.Drink
					)
				end
			else
				print("sigam")
			end

			task.delay(1, function()
				PongController.ResetClient()
			end)
		elseif argtable["Action"] == "Win" then
			task.wait(2)

			-- Reset redemption flags
			isInRedemption = false
			redemptionRound = 0

			-- Stop local power meter
			PongController.StopLocalPowerMeter()

			local winScreen = gui.WinScreen
			UIController.MenuOpenClose(winScreen)

			local bar = winScreen.barContainer.barHolder.bar
			setTextInstant(guiText, "")

			Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.Win, workspace)

			bar.Size = UDim2.fromScale(1, 1)
			TweenService:Create(bar, TweenInfo.new(5, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()

			task.delay(5, function()
				if winScreen.Visible then
					UIController.MenuOpenClose(winScreen)
				end

				task.delay(1, function()
					bar.Size = UDim2.fromScale(0, 1)
				end)
			end)

			gui.TopButtons.Play.Visible = true
			gui.TopButtons.Play.Active = true

			for _, v in workspace:GetDescendants() do
				if v:IsA("ProximityPrompt") then
					v.Enabled = true

					if v.Parent.Name == "1" or v.Parent.Name == "2" then
						task.delay(0.1, function()
							if v.Parent:GetAttribute("taken") ~= "" then
								v.Enabled = false
							end
						end)
					end
				end
			end
		elseif argtable["Action"] == "Lose" then
			task.wait(2)

			-- Reset redemption flags
			isInRedemption = false
			redemptionRound = 0

			-- Stop local power meter
			PongController.StopLocalPowerMeter()

			local loseScreen = gui.LoseScreen
			UIController.MenuOpenClose(loseScreen)

			local bar = loseScreen.barContainer.barHolder.bar
			setTextInstant(guiText, "")

			Essentials.PlaySound(ReplicatedStorage.Assets.Sounds.Lose, workspace)

			bar.Size = UDim2.fromScale(1, 1)
			TweenService:Create(bar, TweenInfo.new(5, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()

			task.delay(5, function()
				if loseScreen.Visible then
					UIController.MenuOpenClose(loseScreen)
				end

				task.delay(1, function()
					bar.Size = UDim2.fromScale(0, 1)
				end)
			end)

			gui.TopButtons.Play.Visible = true
			gui.TopButtons.Play.Active = true

			for _, v in workspace:GetDescendants() do
				if v:IsA("ProximityPrompt") then
					v.Enabled = true

					if v.Parent.Name == "1" or v.Parent.Name == "2" then
						task.delay(0.1, function()
							if v.Parent:GetAttribute("taken") ~= "" then
								v.Enabled = false
							end
						end)
					end
				end
			end
		end
	end)
end

function PongController.Handler()
	PongController.Listener()
	PongController.PongButtons()
end

return PongController
