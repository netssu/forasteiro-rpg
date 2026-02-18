-- // services
local LOBBY_PLACE_ID = 77035582123606

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

-- // variables

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local ClientLoading = Remotes:FindFirstChild("ClientLoading")
local ClientLoadedEvent = ClientLoading:FindFirstChild("ClientLoaded")
local RequestGameStart_Event = Remotes:FindFirstChild("Game"):FindFirstChild("RequestGameStart")

-- // tables

local isCinematic = true
local playersLoaded = {}
local STARTING_CASH = 300

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
	
	local TempCashAttribute = Player:SetAttribute("TempCash", STARTING_CASH)
	
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

local function setupPlayer(player: Player)
	local SpawnPosition = workspace:FindFirstChild("SpawnPos")
	if not SpawnPosition then return end

	local character = player.Character
	if not character then return end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "Players"
		end
	end
	
	local joinData = player:GetJoinData()
	local teleportData = joinData.TeleportData
	if teleportData then
		PrintTableRecursive(teleportData)
		
		if teleportData and teleportData.UserData and teleportData.UserData.Quests then -- sets quest data
			for category, questData in pairs(teleportData.UserData.Quests) do
				if questData.Active then
					for questName, questInfo in pairs(questData.Active) do
						local progress = questInfo.Progress or 0
						local attributeName = string.format("Quest_%s_%s", category, questName)

						attributeName = attributeName:gsub("%s+", "_"):gsub("[^%w_]", "")

						player:SetAttribute(attributeName, progress)
						print(string.format("[🗺️] Set %s to %s for %s", attributeName, progress, player.Name))
					end
				end
			end
		end
		
	end

	character:SetPrimaryPartCFrame(SpawnPosition.CFrame)
	
	setupTempCash(player)
	
	if not(teleportData) then
		teleportData = {}
		teleportData.Difficulty = "Easy"
		teleportData.Gamemode = "endless"
	end
	
	print(teleportData.Difficulty)
	
	checkIfAllPlayersLoaded(teleportData.Difficulty, teleportData.Gamemode)
	
end

-- // connections

Remotes.Game.ReturnToLobby.OnServerEvent:Connect(function(player: Player)
	local TeleportService = game:GetService("TeleportService")
	local MAX_RETRIES = 5
	local RETRY_WAIT = 0.1

	local function gatherQuestAttributes()
		local attrs = player:GetAttributes()
		if not attrs or next(attrs) == nil then
			return {}
		end

		local out = {}
		for name, value in pairs(attrs) do
			if string.sub(name, 1, 6) == "Quest_" then
				local category, rest = string.match(name, "^Quest_([^_]+)_(.+)$")
				if category and rest then
					category = category:gsub("^%s+", ""):gsub("%s+$", "")
					local questName = rest:gsub("^%s+", ""):gsub("%s+$", "")
					questName = questName:gsub("_", " ")
					out[category] = out[category] or {}
					out[category][questName] = value
				else
					print("[ReturnToLobby] Unparsed Quest attr:", name, value)
				end
			end
		end
		return out
	end

	local questData = {}
	for i = 1, MAX_RETRIES do
		questData = gatherQuestAttributes()
		if next(questData) ~= nil then
			break
		end
		if i < MAX_RETRIES then
			task.wait(RETRY_WAIT)
		end
	end

	print("[ReturnToLobby] Player attributes snapshot for", player.Name)
	PrintTableRecursive(player:GetAttributes())

	print("[ReturnToLobby] Gathered questData (clean):")
	PrintTableRecursive({ UserData = { Quests = questData } })

	local teleportData = {
		UserData = {
			Quests = questData
		}
	}

	TeleportService:Teleport(LOBBY_PLACE_ID, player, teleportData) -- teleports playersb ack to lobby
end)

ClientLoadedEvent.OnServerEvent:Connect(function(player: Player)

	playersLoaded[player] = true
	setupPlayer(player)
	
end)

Players.PlayerRemoving:Connect(function(player)
	playersLoaded[player] = nil
end)

return {}
