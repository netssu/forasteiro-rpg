local InputController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local CameraController = require(script.Parent.CameraController)
local PongController = require(script.Parent.PongController)

local plr = Players.LocalPlayer

local FireDebounce = false
local BigFireDebounce = false
local BombDebounce = false

InputController.locked = false
local char = nil

local function updateCharacter(newCharacter)
	char = newCharacter
end

if plr.Character then
	updateCharacter(plr.Character)
end
plr.CharacterAdded:Connect(updateCharacter)

local function Actions(action, stop)
	if action == "ShoulderCam" then
		InputController.locked = not InputController.locked
		CameraController.Shoulder(char, InputController.locked)
	elseif action == "Left" then
		PongController.ToggleTrajectoryMovement("left", not stop)
	elseif action == "Right" then
		PongController.ToggleTrajectoryMovement("right", not stop)
	elseif action == "Throw" then
		PongController.ThrowBall()
	end
end

local function inputHandler()
	local inputs = ReplicatedStorage.Assets.Inputs

	for _, v in inputs:GetDescendants() do
		if v:IsA("InputAction") then
			v.Pressed:Connect(function()
				Actions(v.Name, false)
			end)

			v.Released:Connect(function()
				if v:GetAttribute("toggle") == false then
					Actions(v.Name, true)
				end
			end)
		end
	end
end

function InputController.Handler()
	inputHandler()

	-- if UIS.TouchEnabled then
	-- 	setupTouchPlacement()

	-- 	local MobileControls = plr.PlayerGui:WaitForChild("MainGameUi").MobileControls

	-- 	MobileControls.Visible = true
	-- end

	-- mobileControls()
end

return InputController
