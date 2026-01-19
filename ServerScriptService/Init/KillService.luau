local KillService = {}

-- services

local Players = game:GetService("Players")

local RoundService
local DataService
local RewardService

-- tables

local PlayerStreaks = {}
local PlayerSuccessiveKills = {}
local PlayerKills = {}

-- datastores data
local DataTable = {}

-- packets

local KillDataPacket
local LeaderboardPacket

local KillCountPacket
local KillCountRequest



function KillService:ResetLeaderboard()
	for _, player in pairs(Players:GetPlayers()) do
		KillService:ResetPlayerStats(player)
	end
end


-- sends the PlayerKills table to the client containing all the players and their current kill count
function KillService:TriggerLeaderboard()
	LeaderboardPacket:Fire(PlayerKills)
	KillService:RewardLeaders()
end


-- rewards the top three on the leaderboard
function KillService:RewardLeaders()
	local Sorted = {}
	for player, kills in pairs(PlayerKills) do
		if kills <= 0 then
			continue
		end
		table.insert(Sorted, {Player = player, Kills = kills})
	end

	table.sort(Sorted, function(a, b)
		return a.Kills > b.Kills
	end)
	
	local rewards = {
		[1] = "MVPReward",
		[2] = "SecondPlaceReward",
		[3] = "ThirdPlaceReward",
	}
	
	for i, reward in pairs(rewards) do
		local position = Sorted[i]
		if not position then
			continue
		end
		
		local player = position.Player
		if not player then
			continue
		end
		
		RewardService:RewardPlayer(player,reward)
	end
end


-- adding kill to user's kills data
function KillService:LogKill(player:Player, killed:Player)
	local PlayerData = DataTable[player]
	if not PlayerData then
		return
	end
	
	PlayerData.Kills += 1
	KillCountPacket:FireClient(PlayerData.Kills)
	
	return true
end


-- whenever a player gets a kill, log the kill and updates streak and add the kill to the database
function KillService:Kill(Player: Player, Killed: Model)
	
	-- making sure these exist
	if not PlayerKills[Player] then
		PlayerKills[Player] = 0
	end
	if not PlayerSuccessiveKills[Player] then
		PlayerSuccessiveKills[Player] = 0
	end
	if not PlayerStreaks[Player] then
		PlayerStreaks[Player] = 0
	end
	
	
	PlayerKills[Player] += 1
	PlayerSuccessiveKills[Player] += 1 -- this resets everytime the streak ends
	
	if PlayerSuccessiveKills[Player] > 1 then -- if consecutive kills is greater than 1, then it is a streak
		PlayerStreaks[Player] += 1
	end
	
	local lastStreak = PlayerStreaks[Player]
	-- wait 5 seconds and check if streak has changed, if not, reset streak
	task.delay(5,function()
		if PlayerStreaks[Player] == lastStreak then
			KillService:ResetStreak(Player)
		end
	end)
	
	
	local value = nil
	-- save kill to datastore if killed is a player
	local killedPlayer = Players:GetPlayerFromCharacter(Killed)
	if not killedPlayer then
		local amount = RewardService:RewardKill(Player, true)
		if amount then
			value = amount
		end
	else
		local amount = RewardService:RewardKill(Player, false)
		if amount then
			value = amount
		end
		KillService:LogKill(Player, killedPlayer)
	end
	
	KillService:UpdatePlayerStats(Player , Killed, value)
end


-- resets a player's streak and updates their client
function KillService:ResetStreak(Player:Player)
	PlayerStreaks[Player] = 0
	PlayerSuccessiveKills[Player] = 0
	KillService:UpdatePlayerStats(Player)
end


-- updates the client on their current kills and streaks
function KillService:UpdatePlayerStats(Player : Player, LastKill : Model, Ether: number)
	local KillData = {
		Kills = PlayerKills[Player] or 0,
		Streak = PlayerStreaks[Player] or 0,
		LastKillName = LastKill and LastKill.Name or nil,
		Money = Ether
	}
	KillDataPacket:FireClient(Player,KillData)
end


-- sets all current stats to 0 and updates the client
function KillService:ResetPlayerStats(player:Player)
	PlayerSuccessiveKills[player] = 0
	PlayerStreaks[player] = 0
	PlayerKills[player] = 0
	KillService:UpdatePlayerStats(player)
end


-- setup the player
function KillService:SetPlayer(player:Player)
	
	local PlayerData = DataService:GetData(player)
	if not PlayerData then
		return false
	end
	
	local currentKills = PlayerData.Kills
	
	DataTable[player] = PlayerData
	
	-- creates stats
	KillService:ResetPlayerStats(player)
	
	player.CharacterAdded:Connect(function(character:Model)
		-- reset streak when character added
		KillService:ResetStreak(player)
	end)
	
	KillCountPacket:FireClient(player,currentKills)
end


-- removes player from the kill tables
function KillService:RemovePlayer(player:Player)
	PlayerSuccessiveKills[player] = nil
	PlayerStreaks[player] = nil
	PlayerKills[player] = nil
	DataTable[player] = nil
end





function KillService:Init()
	local Packet = self.Libs.Packet
	
	LeaderboardPacket = Packet("ShowLeaderboard", Packet.Any)
	KillDataPacket = Packet("KillData", Packet.Any)
	KillCountPacket = Packet("AllKills", Packet.Any) -- all the kills the player has ever gotten
	
	KillCountRequest = Packet("KillRequest",Packet.Any):Response(Packet.Any)
end



function KillService:Start()
	RoundService = self.Services.RoundService
	DataService = self.Services.DataService
	RewardService = self.Services.RewardService

	KillCountRequest.OnServerInvoke = function(player:Player)
		local PlayerData = DataTable[player]
		if not PlayerData then
			return
		end
		return PlayerData.Kills
	end
end



return KillService
