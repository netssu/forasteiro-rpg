-- // services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

-- // variables

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local ClientLoading = Remotes:FindFirstChild("ClientLoading")
local ClientLoadedEvent = ClientLoading:FindFirstChild("ClientLoaded")
local RequestGameStart_Event = Remotes:FindFirstChild("Game"):FindFirstChild("RequestGameStart")

-- // tables

local isCinematic = false
local playersLoaded = {}
local playerSpawnAssignments = {}
local STARTING_CASH = 500

-- // functions

local function checkIfAllPlayersLoaded(Difficulty, Gamemode)
	for _, player in ipairs(Players:GetPlayers()) do
		if not playersLoaded[player] then
			return false
		end
	end

	print("[🛡️] All clients loaded, starting game.")
	RequestGameStart_Event:Fire(Difficulty, Gamemode)
	if isCinematic then
		Remotes.Game.StartCinematic:FireAllClients()
	end

	return true
end

local function setupTempCash(Player : Player)
	Player:SetAttribute("TempCash", STARTING_CASH)
end

local function PrintTableRecursive(tbl, indent)
	indent = indent or ""
	for key, value in pairs(tbl) do
		if typeof(value) == "table" then
			print(indent .. tostring(key) .. ": {")
			PrintTableRecursive(value, indent .. "  ")
			print(indent .. "}")
		else
			print(indent .. tostring(key) .. ": " .. tostring(value))
		end
	end
end

local function getUserData(Player)
	local userData
	repeat
		userData = Player:FindFirstChild("UserData")
		if not userData then
			task.wait(0.1)
		end
	until userData
	return userData
end

local function getPlayerSpawn(player)
	local spawnPoints = workspace:FindFirstChild("SpawnPoints")
	if not spawnPoints then
		warn("[⚠️] No 'SpawnPoints' folder found in Workspace.")
		return nil
	end

	local availableSpawns = spawnPoints:GetChildren()

	if playerSpawnAssignments[player] then
		return playerSpawnAssignments[player]
	end

	for _, spawn in ipairs(availableSpawns) do
		local assigned = false
		for _, usedSpawn in pairs(playerSpawnAssignments) do
			if usedSpawn == spawn then
				assigned = true
				break
			end
		end

		if not assigned then
			playerSpawnAssignments[player] = spawn
			return spawn
		end
	end

	return availableSpawns[1]
end

local function setupPlayer(player: Player)
	
	for i, plr in ipairs(Players:GetPlayers()) do
		if i == 1 then
			plr:SetAttribute("PathSide", "A")
			ReplicatedStorage.Remotes.PVP.UnblockZone:FireClient(player, workspace.BuildBlocks.ABlock)
		else
			plr:SetAttribute("PathSide", "B")
			ReplicatedStorage.Remotes.PVP.UnblockZone:FireClient(player, workspace.BuildBlocks.BBlock)
		end
	end
	
	local SpawnA = workspace.SpawnPoints.SpawnPos
	local SpawnB = workspace.SpawnPoints.SpawnPos2
	
	local spawnPart = nil
	
	if player:GetAttribute("PathSide") == "A" then
		spawnPart = SpawnA
	else
		spawnPart = SpawnB
	end

	local character = player.Character or player.CharacterAdded:Wait()

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "Players"
		end
	end

	local joinData = player:GetJoinData()
	local teleportData = joinData.TeleportData or {}
	PrintTableRecursive(teleportData)

	character:PivotTo(spawnPart.CFrame)

	setupTempCash(player)

	checkIfAllPlayersLoaded(teleportData.Difficulty, teleportData.Gamemode)
end

-- // connections

Remotes.Game.ReturnToLobby.OnServerEvent:Connect(function(Player : Player)
	TeleportService:Teleport(77035582123606, Player)
end)

ClientLoadedEvent.OnServerEvent:Connect(function(player: Player)
	playersLoaded[player] = true
	setupPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
	playersLoaded[player] = nil
	playerSpawnAssignments[player] = nil
end)

return {}
