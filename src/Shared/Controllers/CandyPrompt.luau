local module = {}

------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

------------------//DEPENDENCIES
local Packets = require(ReplicatedStorage.Modules.Game.Packets)

------------------//CONSTANTS
local PLAYER = Players.LocalPlayer

------------------//PRIVATE FUNCTIONS
local function GetLocalPinata()
	local map = workspace:FindFirstChild("Map")
	if not map then return nil end
	local plotsFolder = map:FindFirstChild("Plots")
	if not plotsFolder then return nil end

	for _, p in plotsFolder:GetChildren() do
		if p:GetAttribute("Owner") == PLAYER.UserId then
			local pinataFolder = p:FindFirstChild("Pinata")
			if pinataFolder then
				return pinataFolder:FindFirstChild("Pinata") or pinataFolder:FindFirstChildWhichIsA("Model")
			end
		end
	end
	return nil
end

local function GetEquippedCandy(character)
	if not character then return nil end
	local tool = character:FindFirstChildWhichIsA("Tool")
	if tool and (tool.Name:match("Candy") or tool:GetAttribute("Type") == "Candy") then
		return tool
	end
	return nil
end

local function UpdatePromptState()
	local character = PLAYER.Character
	if not character then return end

	local pinata = GetLocalPinata()
	if not pinata then return end

	local prompt = nil
	for _, desc in pinata:GetDescendants() do
		if desc:IsA("ProximityPrompt") and desc.Name == "FeedPrompt" then
			prompt = desc
			break
		end
	end

	if not prompt then return end

	local candy = GetEquippedCandy(character)
	prompt.Enabled = (candy ~= nil)
end

------------------//PUBLIC FUNCTIONS
function module:Init()
	-- Loop lento para garantir atualização caso a pinata renasça
	task.spawn(function()
		while true do
			UpdatePromptState()
			task.wait(0.5)
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if player ~= PLAYER then return end
		if prompt.Name ~= "FeedPrompt" then return end

		local candy = GetEquippedCandy(PLAYER.Character)
		if not candy then 
			prompt.Enabled = false 
			return 
		end

		local data = { ToolName = candy.Name }
		local json = HttpService:JSONEncode(data)

		if Packets.Feed.Fire then
			Packets.Feed:Fire(json)
		else
			Packets.Feed:Send(json)
		end
	end)
end

return module