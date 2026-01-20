local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local CatchingConfig = require(ReplicatedStorage.Shared.Configs.CatchingConfig)
local ToolConfig = require(ReplicatedStorage.Shared.Configs.ToolConfig)

local CatchingMaps = ReplicatedStorage.Assets.MapStorage
local ClientEvent = ReplicatedStorage.Remotes.Events.EnterSession
local AddBrainrotToCage = ServerScriptService.Bindables.Catching.AddBrainrotToCage
local UpgradeMissionProgress = ServerScriptService.Bindables.UpdateMissionProgress
local Transition = ReplicatedStorage.Remotes.Events.Transition
local GetPlayerObject = ServerScriptService.Bindables.GetPlayerObject
local endSession = ServerScriptService.Bindables.Catching.endSession

local CatchingSession = {}
local CaughtBrainrots = {}

function CatchingSession.AddBrainrotCatch(player, brainrot)
	if not CaughtBrainrots[player] then
		CaughtBrainrots[player] = {}
	end

	local playerTable = CaughtBrainrots[player]
	table.insert(playerTable, brainrot)
end

local function GetCaughtBrainrots(player)
	return CaughtBrainrots[player]
end

-----// TOOLS MANAGER \\------

--// Helper //--
local function initializeStats(toolName: string)
	local toolInfo = ToolConfig.getInfo(toolName)
	local toolStats = {}

	if toolInfo and toolInfo.Stats then
		for statName in pairs(toolInfo.Stats) do
			toolStats[statName] = 1
		end
	end

	return toolStats
end

--// Private Methods //--

-- Tool stuff
local function createTool(player: Player, toolName: string, toolStats: {[string]: number})
	if toolName == "Jetpack" then player:SetAttribute("Jetpack", true) return end

	local toolTemplate = ReplicatedStorage.Assets.Tools:FindFirstChild(toolName)
	if not toolTemplate then
		warn(`Tool template not found: {toolName}`)
		return
	end

	local tool = toolTemplate:Clone()

	if toolStats then
		for statName, level in toolStats do
			local statInfo = ToolConfig.getStat(toolName, statName, level)
			if statInfo then
				tool:SetAttribute(statName, statInfo.Value)
			end
		end
	end

	local starterGear = player:FindFirstChild("StarterGear")
	if starterGear then
		tool:Clone().Parent = starterGear
	end

	tool.Parent = player.Backpack
end

--// Tool Management //--
local function removeTools(player: Player)
	local backpack = player:FindFirstChild("Backpack")
	local starterGear = player:FindFirstChild("StarterGear")

	if backpack then
		backpack:ClearAllChildren()
	end
	if starterGear then
		starterGear:ClearAllChildren()
	end

	player:SetAttribute("Jetpack", nil)

	local character = player.Character or player.CharacterAdded:Wait()
	for _, tool in character:GetChildren() do
		if tool:IsA("Tool") then
			tool:Destroy()
		end
	end
end

local function giveTools(player: Player)
	local playerObject = GetPlayerObject:Invoke(player)
	if not playerObject then return end

	for toolName, toolData in pairs(playerObject.ToolManager.Tools) do
		if toolData.Unlocked then
			createTool(player, toolName, toolData.Stats)
		end
	end
end

function CatchingSession.spawnSession(offset, player, world)
	giveTools(player)

	local World = CatchingMaps[world]

	local RandomIndex = math.random(1, #World:GetChildren())
	local map = World[RandomIndex]:Clone() :: Model

	map:PivotTo(CFrame.new(offset, 0, 0))
	map.Name = `MapOf{player.UserId}`
	map.Parent = workspace.CatchingMaps

	local spawns = map.BrainrotSpawns:GetChildren()
	local quantity = math.random(4, 7)

	local character = player.Character
	character:PivotTo(map.PlayerSpawn.CFrame)

	ClientEvent:FireClient(player, true, quantity)

	local available = table.clone(spawns)
	local chosen = {}
	local ValidBrainrots = {}

	for i = 1, quantity do
		if #available == 0 then break end
		local index = math.random(#available)
		table.insert(chosen, available[index])
		table.remove(available, index)
	end

	for _, spawn in ipairs(spawns) do
		spawn.Transparency = 1
	end

	for _, spawn in ipairs(chosen) do
		spawn.Transparency = 0
		for _, v in ReplicatedStorage.Assets.VFX.MudPuddleVfx:GetChildren() do
			v:Clone().Parent = spawn
		end
	end

	for _, spawn in ipairs(chosen) do
		local brainrotName = CatchingConfig.getRandomBrainrot(world)
		local brainrot = ReplicatedStorage.Assets.Brainrots[brainrotName]:Clone()

		table.insert(ValidBrainrots, brainrotName)

		local y = brainrot:GetExtentsSize().Y / 2
		brainrot:PivotTo(spawn.CFrame + Vector3.new(0, -(y + 1), 0))
		brainrot.Parent = map.Brainrots

		local hole = Instance.new("ObjectValue")
		hole.Name = "hole"
		hole.Value = spawn
		hole.Parent = brainrot
	end

	task.wait(5)

	task.spawn(function()
		while task.wait(1) do
			if map:FindFirstChild("Brainrots") and map.Brainrots:GetChildren()[1] == nil then -- SESSION ENDED
				--print("Checking brainrots:", map.Brainrots:GetChildren()[1])
				local character = player.Character

				Transition:FireClient(player, 5)
				task.wait(2)

				local caught = GetCaughtBrainrots(player)

				local ValidedBrainrots = {}

				local selected = false

				for _, brainrotName in caught do
					selected = false

					for _, valid in ValidBrainrots do
						if selected == true then continue end
						if brainrotName == valid then
							if ValidedBrainrots[brainrotName] then
								ValidedBrainrots[brainrotName] += 1
								--print("mais um para:", brainrotName)
								selected = true
							else
								ValidedBrainrots[brainrotName] = 1
								--print("definido um para:", brainrotName)
								selected = true
							end
						end
					end
				end

				removeTools(player)

				endSession:Fire(player)

				character:PivotTo(workspace.SpawnLocation.CFrame)

				ClientEvent:FireClient(player, false, 0, ValidedBrainrots)
				--warn("[Catching Session] Valided Brainrots:", ValidedBrainrots)
				AddBrainrotToCage:Fire(player, ValidedBrainrots)
				
				UpgradeMissionProgress:Fire(player, {
					BrainrotsCaught = #caught
				})
				break
			end
		end
	end)

	return map
end

return CatchingSession