local MapVoteService = {}

local MapsData = require(game.ReplicatedStorage.Resources.MapsData)
local GameplayService
local MapService
local MapVotationPacket

local SelectedMaps = {}
local Votes = {}
local VotationActive = false

local Players = game:GetService("Players")

function MapVoteService:GetRandomMaps()
	local Chosen = {}
	while #Chosen < 3 do
		local randomMap = MapsData[math.random(1, #MapsData)]
		if not table.find(Chosen, randomMap) then
			table.insert(Chosen, randomMap)
		end
	end
	return Chosen
end

function MapVoteService:Vote(Player: Player, MapName: string)
	if not VotationActive then return end
	if not Votes[MapName] then return end

	local playerName = Player.Name

	for name, players in pairs(Votes) do
		for i, plr in ipairs(players) do
			if plr == Player then
				table.remove(players, i)
				local mapFolder = self.TempFolder:FindFirstChild(name)
				if mapFolder and mapFolder:FindFirstChild(playerName) then
					mapFolder[playerName]:Destroy()
				end
				break
			end
		end
	end

	table.insert(Votes[MapName], Player)

	local mapFolder = self.TempFolder:FindFirstChild(MapName)
	if mapFolder then
		local boolValue = Instance.new("BoolValue")
		boolValue.Name = playerName
		boolValue.Value = true
		boolValue.Parent = mapFolder
	end
end

function MapVoteService:GetVoteCounts()
	local counts = {}
	for name, players in pairs(Votes) do
		counts[name] = #players
	end
	return counts
end

function MapVoteService:TriggerMapVotation()
	if self.TempFolder then
		self.TempFolder:Destroy()
	end

	local tempFolder = Instance.new("Folder")
	tempFolder.Name = "MapVotation"
	tempFolder.Parent = game.ReplicatedStorage
	self.TempFolder = tempFolder

	SelectedMaps = MapVoteService:GetRandomMaps()
	Votes = {}

	for _, map in ipairs(SelectedMaps) do
		Votes[map.MapName] = {}
		local mapFolder = Instance.new("Folder")
		mapFolder.Name = map.MapName
		mapFolder.Parent = tempFolder
	end


	workspace:SetAttribute("Gamemode", "MAP VOTE")
	VotationActive = true
	MapVotationPacket:Fire(SelectedMaps)
	
	-- Countdown for 5 seconds
	GameplayService:Countdown(5)
	VotationActive = false
	
	local winner = MapVoteService:GetMostVotedMap()
	tempFolder:Destroy()

	if winner then
		MapService:SpawnMap(winner)
	else
		local random = SelectedMaps[math.random(1, #SelectedMaps)]
		MapService:SpawnMap(random.MapName)
	end

	-- clear for next round
	SelectedMaps = {}
end

function MapVoteService:GetMostVotedMap()
	local topMap, topVotes = nil, -1
	for name, players in pairs(Votes) do
		if #players > topVotes then
			topVotes = #players
			topMap = name
		end
	end
	return topMap
end

function MapVoteService:Init()
	MapService = self.Services.MapService
	GameplayService = self.Services.GameplayService

	local Packet = self.Libs.Packet
	MapVotationPacket = Packet("MapVotation", Packet.Any)

	MapVotationPacket.OnServerEvent:Connect(function(Player: Player, MapName: string)
		MapVoteService:Vote(Player, MapName)
	end)
end

function MapVoteService:Start()
	Players.PlayerAdded:Connect(function(player)
		if VotationActive and SelectedMaps and #SelectedMaps > 0 then
			for mapName, players in pairs(Votes) do
				local mapFolder = self.TempFolder:FindFirstChild(mapName)
				if mapFolder then
					for _, plr in ipairs(players) do
						local boolValue = Instance.new("BoolValue")
						boolValue.Name = plr.Name
						boolValue.Parent = mapFolder
					end
				end
			end
			task.delay(2, function()
				MapVotationPacket:FireClient(player, SelectedMaps)
			end)
		end
	end)
end

return MapVoteService
