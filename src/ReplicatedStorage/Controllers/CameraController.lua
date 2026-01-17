local CameraController = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local camera = workspace.CurrentCamera
local shakeConnection
local shaking = false

local currentFOV = camera.FieldOfView

function CameraController.ShakeCameraSwitch(enabled, direction, intensity)
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	if enabled then
		if shaking then
			return
		end
		shaking = true
		local originalOffset = humanoid.CameraOffset

		shakeConnection = RunService.Heartbeat:Connect(function()
			local shakeX = (math.random() - 0.5) * 2 * intensity
			local shakeY = (math.random() - 0.5) * 2 * intensity
			local shakeZ = (math.random() - 0.5) * 2 * intensity

			if direction then
				shakeX = shakeX * (direction.X or 1)
				shakeY = shakeY * (direction.Y or 1)
				shakeZ = shakeZ * (direction.Z or 1)
			end

			local shakeOffset = Vector3.new(shakeX, shakeY, shakeZ)
			humanoid.CameraOffset = originalOffset + shakeOffset
		end)
	else
		if not shaking then
			return
		end
		shaking = false
		if shakeConnection then
			shakeConnection:Disconnect()
			shakeConnection = nil
		end
		TweenService:Create(humanoid, TweenInfo.new(0.1), { CameraOffset = humanoid.CameraOffset }):Play()
	end
end

function CameraController.ShakeCamera(direction, intensity, length)
	if shaking then
		return
	end

	local player = Players.LocalPlayer
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	shaking = true
	local originalOffset = humanoid.CameraOffset
	local startTime = tick()

	local connection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = tick() - startTime

		if elapsed >= length then
			humanoid.CameraOffset = originalOffset
			shaking = false
			connection:Disconnect()
			return
		end

		local progress = elapsed / length
		local currentIntensity = intensity * (1 - progress)

		local shakeX = (math.random() - 0.5) * 2 * currentIntensity
		local shakeY = (math.random() - 0.5) * 2 * currentIntensity
		local shakeZ = (math.random() - 0.5) * 2 * currentIntensity

		if direction then
			shakeX = shakeX * (direction.X or 1)
			shakeY = shakeY * (direction.Y or 1)
			shakeZ = shakeZ * (direction.Z or 1)
		end

		local shakeOffset = Vector3.new(shakeX, shakeY, shakeZ)
		humanoid.CameraOffset = originalOffset + shakeOffset
	end)
end

function CameraController.FovChange(Enabled, Tweenlength, TargetFOV)
	TweenService:Create(camera, TweenInfo.new(Tweenlength or 1), { FieldOfView = Enabled and TargetFOV or currentFOV })
		:Play()
end

function CameraController.MoveCameraABit(direction)
	local player = Players.LocalPlayer

	local ogOffSet = player.Character.Humanoid.CameraOffset

	TweenService:Create(
		player.Character.Humanoid,
		TweenInfo.new(0.25, Enum.EasingStyle.Circular),
		{ CameraOffset = player.Character.Humanoid.CameraOffset + direction }
	):Play()

	task.delay(0.1, function()
		TweenService
			:Create(player.Character.Humanoid, TweenInfo.new(1, Enum.EasingStyle.Circular), { CameraOffset = ogOffSet })
			:Play()
	end)
end

function CameraController.Shoulder(char, enabled)
	TweenService:Create(
		char.Humanoid,
		TweenInfo.new(0.1),
		{ CameraOffset = Vector3.new(enabled and 2 or 0, enabled and 1.3 or 0, 0) }
	):Play()

	UserGameSettings.RotationType = enabled and Enum.RotationType.CameraRelative or Enum.RotationType.MovementRelative
	UserInputService.MouseBehavior = enabled and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default

	if enabled and char.HelicopterValue.Value == false then
		UserInputService.MouseIconEnabled = false
	elseif enabled == false then
		UserInputService.MouseIconEnabled = true
	end
end

function CameraController.Handler() end

return CameraController
