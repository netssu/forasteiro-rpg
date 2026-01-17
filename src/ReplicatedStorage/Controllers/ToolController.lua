local ToolController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local AnimationsController = require(script.Parent.AnimationController)

local ToolTable = require(ReplicatedStorage.Arrays.ToolTable)

local plr = Players.LocalPlayer
local mouse = plr:GetMouse()

ToolController.CurrentTool = nil
ToolController.CurrentToolName = nil

local function onToolEquipped(tool)
	if plr.Character.Humanoid.Health <= 0 and plr.Character.plrValues.Parried.Value then
		return
	end
	print("tool equipped " .. tool.Name)

	UserInputService.MouseIconEnabled = true

	mouse.Icon = "rbxassetid://13985600873"

	for _, v in pairs(plr.Character:GetChildren()) do
		if v:IsA("Model") and not v:IsA("Tool") then
			v:Destroy()
		end
	end

	ToolController.CurrentTool = tool
	ToolController.CurrentToolName = tool.Name

	for _, v in pairs(tool:GetDescendants()) do
		if v:IsA("MeshPart") then
			v.Transparency = 1

			task.delay(0.4, function()
				if ToolController.CurrentTool then
					v.Transparency = 0
				end
			end)
		end
	end

	ToolTable[ToolController.CurrentToolName]["Equip"](tool)

	AnimationsController.PlayLoopedAnimation(
		plr.Character.Humanoid.Animator,
		ReplicatedStorage.Assets.Animations[tool:GetAttribute("AnimType")].Equip,
		false
	)

	task.delay(0.3, function()
		if ToolController.CurrentTool then
			AnimationsController.PlayLoopedAnimation(
				plr.Character.Humanoid.Animator,
				ReplicatedStorage.Assets.Animations[tool:GetAttribute("AnimType")].Equipped,
				false
			)
		end
	end)
end

local function onToolUnequipped(tool)
	if plr.Character.Humanoid.Health <= 0 and plr.Character.plrValues.Parried.Value then
		return
	end
	print("tool unequipped " .. tool.Name)

	local Model = Instance.new("Model")
	Model.Parent = plr.Character
	Model.Name = tool.Name

	mouse.Icon = ""

	for _, v in pairs(tool:GetChildren()) do
		local clone = v:Clone()

		clone.Parent = Model

		if clone.Name == "Handle" then
			clone.OGWeld.Part1 = Model:FindFirstChild(Model.Name).PrimaryPart

			local weld = Instance.new("WeldConstraint")
			weld.Parent = clone
			weld.Part0 = clone

			if plr.Character:FindFirstChild("RightHand") then
				weld.Part1 = plr.Character.RightHand
			else
				weld.Part1 = plr.Character["Right Arm"]
			end
		end
	end

	task.delay(0.3, function()
		if not ToolController.CurrentTool then
			Model:Destroy()
		end
	end)

	ToolTable[ToolController.CurrentToolName]["Unequip"](plr, ToolController.CurrentTool)

	ToolController.CurrentTool = nil
	ToolController.CurrentToolName = nil

	AnimationsController.PlayLoopedAnimation(
		plr.Character.Humanoid.Animator,
		ReplicatedStorage.Assets.Animations[tool:GetAttribute("AnimType")].Unequipped,
		false
	)
end

local function monitorCharacter(character)
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Tool") then
			onToolEquipped(item)
		end
	end

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			onToolEquipped(child)
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			onToolUnequipped(child)
		end
	end)

	-- Death listener
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			print("Player died, clearing current tool...")
			ToolController.CurrentTool = nil
			ToolController.CurrentToolName = nil
		end)
	end
end

plr.CharacterAdded:Connect(function(character)
	monitorCharacter(character)
end)

if plr.Character then
	monitorCharacter(plr.Character)
end

function ToolController.Usetool()
	if plr.Character.Humanoid.Health <= 0 then
		return
	end
	if ToolController.CurrentTool and not plr.Character.plrValues.Parried.Value then
		ToolTable[ToolController.CurrentToolName]["Use"](ToolController.CurrentTool)
	end
end

function ToolController.SecondaryUseTool(stopped)
	if plr.Character.Humanoid.Health <= 0 then
		return
	end
	if ToolController.CurrentTool and not plr.Character.plrValues.Parried.Value then
		ToolTable[ToolController.CurrentToolName]["SecondaryUse"](ToolController.CurrentTool, stopped)
	end
end

function ToolController.Handler() end

return ToolController
