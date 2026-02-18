local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ServerStorage = game:GetService("ServerStorage")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotificationRemote = Remotes:WaitForChild("Notification")
local Matchmaking = Remotes.Matchmaking

local PVP_QUEUE_KEY = "PVPQueue"
local PendingPVP = {}
local LocalQueue = {}

local TELEPORT_IDS = {
	["Tutorial"] = 85841322739304,
	["Frosty Peaks"] = 74693752415649,
	["Jungle"] = 100446623326294,
	["Wild West"] = 130499453325606,
	["Toyland"] = 119232273357893,
}

local PVP_IDS = {
	["Frosty Peaks"] = 135072435156585,
	["Jungle"] = 80721907443358,
	["Wild West"] = 88229996824169,
	["Toyland"] = 137821835172386,
}

local SQUAD_SIZES = {
	["Solo"] = 1,
	["Duos"] = 2,
	["Trios"] = 3,
	["Squads"] = 4,
}

local function queuePVP(player, squadSize, map) -- adds to queue
	local queue = MemoryStoreService:GetQueue(PVP_QUEUE_KEY)
	local success, err = pcall(function()
		queue:AddAsync({
			UserId = player.UserId,
			SquadSize = squadSize,
			Map = map
		}, 60) -- adds to the MemoryStoreService with a timeout of 60 seconds (removes after 60 secs)
	end)
	if success then
		PendingPVP[player.UserId] = true
		LocalQueue[player.UserId] = { UserId = player.UserId, SquadSize = squadSize, Map = map }
		print("Queued Player", player.Name)
	else
		warn("Failed to queue:", err)
		Remotes.Notification.SendNotification:FireClient(player, "[!] Failed to join the matchmaking queue. Try again later.", "Error")
	end
end

local function tryMatchPVP(player, squadSize, map, timeout)
	timeout = timeout or 60 -- Time out before sending to user (failed)
	local startTime = tick()
	local queue = MemoryStoreService:GetQueue(PVP_QUEUE_KEY, 0)

	while tick() - startTime < timeout do
		local ok, packed = pcall(function()
			return table.pack(queue:ReadAsync(1, false, 1))
		end)

		if not ok then
			warn("Error accessing queue for", player.Name)
			Matchmaking.ClientSearching:FireClient(player, "Search failed.")
			Remotes.Notification.SendNotification:FireClient(player, "[!] Error while searching for a match.", "Error")
			return nil
		end

		local items = packed[1]
		local readId = packed[2]

		if items and #items > 0 and readId then
			local entry = items[1]
			if entry and entry.UserId and entry.UserId ~= player.UserId and PendingPVP[entry.UserId] then
				local removeOk, removeErr = pcall(function()
					queue:RemoveAsync(readId)
				end)
				if not removeOk then
					warn("Failed to remove queue item:", tostring(removeErr))
				else
					Remotes.Notification.SendNotification:FireClient(player, "[!] Match found!", "Success")
					PendingPVP[entry.UserId] = nil
					print("Matched Player", player.Name, "with", entry.UserId)
					return entry
				end
			else
				print("ignoring, continue")
			end
		end

		task.wait(1)
	end

	Matchmaking.ClientSearching:FireClient(player, "Search failed.")
	Remotes.Notification.SendNotification:FireClient(player, "[!] No opponents found. Matchmaking timed out.", "Error")
	return nil
end

local function UserDataToTable(folder)
	local data = {}
	if not folder then return data end
	for _, obj in ipairs(folder:GetChildren()) do
		if obj:IsA("Folder") then
			data[obj.Name] = UserDataToTable(obj)
		elseif obj:IsA("ValueBase") then
			data[obj.Name] = obj.Value
		end
	end
	return data
end

local function getSquadName(squad)
	if not squad or type(squad) ~= "string" then return "Solo" end
	local s = squad:lower():gsub("%s+", ""):gsub("[%p%d]", "")
	local map = {
		solo = "Solo",
		solos = "Solo",
		duo = "Duos",
		duos = "Duos",
		duosize = "Duos",
		trio = "Trios",
		trios = "Trios",
		squad = "Squads",
		squads = "Squads",
	}
	return map[s] or (s:sub(1,4) == "duo" and "Duos") or (s:sub(1,4) == "trio" and "Trios") or (s:sub(1,5) == "squad" and "Squads") or "Solo"
end

local function getPartyInfoFromPlayer(player)
	local inParty = player:GetAttribute("inParty")
	local leaderName = player:GetAttribute("PartyLeader")
	if not inParty or not leaderName then return nil end

	if leaderName ~= player.Name then
		local leader = Players:FindFirstChild(leaderName)
		if leader then
			local partyFolder = ServerStorage:FindFirstChild("Parties")
			if partyFolder then
				local leaderFolder = partyFolder:FindFirstChild(leaderName)
				if leaderFolder then
					local membersFolder = leaderFolder:FindFirstChild("Members")
					if membersFolder then
						local members = { leader }
						for _, mv in ipairs(membersFolder:GetChildren()) do
							local member = mv.Value
							if member and member ~= leader and member.Parent == Players then
								table.insert(members, member)
							end
						end
						return { leader = leader, members = members }
					end
				end
			end
			return { leader = leader, members = { leader, player } }
		else
			return nil
		end
	else
		local partyFolder = ServerStorage:FindFirstChild("Parties")
		if partyFolder then
			local leaderFolder = partyFolder:FindFirstChild(player.Name)
			if leaderFolder then
				local membersFolder = leaderFolder:FindFirstChild("Members")
				if membersFolder then
					local members = {}
					for _, mv in ipairs(membersFolder:GetChildren()) do
						local member = mv.Value
						if member and member.Parent == Players then
							local found = false
							for _, existing in ipairs(members) do
								if existing == member then found = true break end
							end
							if not found then table.insert(members, member) end
						end
					end
					local existsLeader = false
					for _, m in ipairs(members) do if m == player then existsLeader = true break end end
					if not existsLeader then table.insert(members, 1, player) end
					return { leader = player, members = members }
				end
			end
		end
		return { leader = player, members = { player } }
	end
end

local function safeReserveServer(placeId)
	for _ = 1, 3 do
		local success, code = pcall(function()
			return TeleportService:ReserveServer(placeId)
		end)
		if success and code then return code end
		task.wait(1)
	end
	return nil
end

local function teleportPlayers(players, placeId, teleportData)
	local code = safeReserveServer(placeId)
	if not code then
		for _, plr in ipairs(players) do
			Remotes.Notification.SendNotification:FireClient(plr, "[!] Failed to join match. Try again later.", "Error")
		end
		return
	end

	for _, plr in ipairs(players) do
		if plr and plr.Parent == Players then
			Remotes.Game.ShowLoadingScreen:FireClient(plr)
		end
	end

	pcall(function()
		TeleportService:TeleportToPrivateServer(placeId, code, players, nil, teleportData)
	end)
end

local function teleportSolo(player, data)
	local gamemode = data.Gamemode and data.Gamemode:lower() or "survival"
	local placeId = (gamemode == "pvp") and PVP_IDS[data.Map] or TELEPORT_IDS[data.Map]
	if not placeId then
		Remotes.Notification.SendNotification:FireClient(player, "[!] Invalid map selected.", "Error")
		return
	end

	local teleportData = {
		Player = player.UserId,
		Gamemode = gamemode,
		Difficulty = data.Difficulty,
		Squad = "Solo",
		Map = data.Map,
		UserData = UserDataToTable(player:FindFirstChild("UserData")),
	}

	Remotes.Notification.SendNotification:FireClient(player, "[!] Starting solo match...", "Info")
	teleportPlayers({player}, placeId, teleportData)
end

local function beginMatchmaking(player: Player, data)
	if not player or not player.Parent then return end

	local gamemode = data.Gamemode and data.Gamemode:lower() or "survival"
	local squadCanonical = getSquadName(data.Squad)
	local desiredSize = SQUAD_SIZES[squadCanonical] or 1

	print(squadCanonical, desiredSize)

	if gamemode ~= "pvp" and squadCanonical == "Solo" then
		if player:GetAttribute("inParty") then
			Remotes.Notification.SendNotification:FireClient(player, "[!] Leave your party to play solo.", "Error")
			return
		end

		Matchmaking.ClientSearching:FireClient(player, "Found a match!")
		task.wait(math.random(1, 5))
		teleportSolo(player, data)
		return
	end
	
	if gamemode == "pvp" then
		local partyInfo = getPartyInfoFromPlayer(player)
		local squadCount = #((partyInfo and partyInfo.members) or {player})
		
		Matchmaking.ClientSearching:FireClient(player, "Searching..")
		
		if squadCount == 2 then
			local teleportData = {
				Leader = player.UserId,
				Members = {player.UserId, partyInfo.members[2].UserId},
				Gamemode = data.Gamemode,
				Difficulty = data.Difficulty,
				Squad = "Duos",
				Map = data.Map,
				UserData = UserDataToTable(player:FindFirstChild("UserData"))
			}
			teleportPlayers(partyInfo.members, PVP_IDS[data.Map], teleportData)
			return
		end

		queuePVP(player, squadCount, data.Map)
		local opponentData = tryMatchPVP(player, squadCount, data.Map)

		if opponentData then
			local opponentPlayer = Players:GetPlayerByUserId(opponentData.UserId)
			if opponentPlayer then
				local teleportData = {
					Leader = player.UserId,
					Members = {player.UserId, opponentData.UserId},
					Gamemode = "PVP",
					Difficulty = data.Difficulty,
					Squad = "Duos",
					Map = data.Map,
					UserData = UserDataToTable(player:FindFirstChild("UserData"))
				}
				teleportPlayers({player, opponentPlayer}, PVP_IDS[data.Map], teleportData)
				return
			end
		end

		Remotes.Notification.SendNotification:FireClient(player, "[!] Searching for an opponent...", "Info")
		return
	end

	local placeId = (gamemode == "pvp") and PVP_IDS[data.Map] or TELEPORT_IDS[data.Map]
	if not placeId then
		Remotes.Notification.SendNotification:FireClient(player, "[!] Invalid map selected.", "Error")
		return
	end

	local partyInfo = getPartyInfoFromPlayer(player)
	local membersList = { player }

	if partyInfo then
		if partyInfo.leader and partyInfo.leader.UserId ~= player.UserId then
			Remotes.Notification.SendNotification:FireClient(player, "[!] Only the party leader can queue the party.", "Error")
			return
		end

		membersList = {}
		for _, mem in ipairs(partyInfo.members) do
			if mem and mem.Parent == Players then
				table.insert(membersList, mem)
			end
		end
	end

	local actualCount = #membersList

	if actualCount == desiredSize then
		for _, plr in ipairs(membersList) do
			Remotes.Notification.SendNotification:FireClient(plr, "[!] Found a match! Joining...", "Success")
		end

		local teleportData = {
			Leader = player.UserId,
			Members = table.create(#membersList),
			Gamemode = data.Gamemode,
			Difficulty = data.Difficulty,
			Squad = squadCanonical,
			Map = data.Map,
			UserData = UserDataToTable(player:FindFirstChild("UserData")),
		}
		for i, plr in ipairs(membersList) do
			teleportData.Members[i] = plr.UserId
		end

		teleportPlayers(membersList, placeId, teleportData)
		return
	end
	
	Remotes.Notification.SendNotification:FireClient(player, "[!] Your party size doesn't match the selected squad.", "Error")
end

local function getPlayerCounts()
	local survivalCount = 0
	local pvpCount = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local gamemode = (player:GetAttribute("Gamemode") or ""):lower()
		if gamemode == "pvp" then
			pvpCount += 1
		else
			survivalCount += 1
		end
	end

	for _, queued in pairs(LocalQueue) do
		if queued.Map and PVP_IDS[queued.Map] then
			pvpCount += 1
		elseif queued.Map and TELEPORT_IDS[queued.Map] then
			survivalCount += 1
		end
	end

	return {
		Survival = survivalCount,
		PVP = pvpCount
	}
end

Matchmaking.RequestQueue.OnServerEvent:Connect(beginMatchmaking)
Matchmaking.CancelMatchmaking.OnServerEvent:Connect(function(player)
	if PendingPVP[player.UserId] then
		PendingPVP[player.UserId] = nil
		Remotes.Notification.SendNotification:FireClient(player, "[!] You have left the matchmaking queue.", "Info")
	end
end)

Matchmaking.GetPlayerCount.OnServerInvoke = function(Player : Player)
	return getPlayerCounts()
end

return {}
