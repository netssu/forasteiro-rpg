local GameplayService = {}

local Resources = game.ReplicatedStorage.Resources
local LobbyFolder = workspace.Lobby

-- services

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local RoundService
local KillService
local DiedService
local MapService
local MapVoteService
local LobbyService
local LoadoutService
local CharacterService

-- coisax

local InGamePlayers = {}

local removalConnections = {}
local ActiveCountdownId = 0

local LobbyTeam = Teams.Lobby
local InGameTeam = Teams.InGame

-- packets

local LobbyPacket


local RespawnFunctions = {
	["FFA"] = function(player:Player)
		task.wait(3)
		CharacterService:LoadCharacter(player)
		if player:GetAttribute("InLobby") then
			return
		end
		if workspace:GetAttribute("Gamemode") ~= "FFA" then
			return
		end
		LoadoutService:LoadLoadout(player)
	end,
}



function GameplayService:InsertPlayer(player:Player)
	removalConnections[player] = {}
	GameplayService:ReturnToLobby(player)
end


-- puts a player in the current running game if any
function GameplayService:JoinGame(player: Player)

	-- verificar se tem uma partida em progresso e buscar a função de respawn do gamemode atual para colocar no diedservice abaixo
	local currentGamemode = workspace:GetAttribute("Gamemode")
	
	-- se n tiver partida, retorna pq n tem como entrar na partida
	if currentGamemode == "INTERMISSION" or currentGamemode == "MAP VOTE" then
		return
	end
	
	local gamemodeRespawnFunction = RespawnFunctions[currentGamemode] or nil -- função de respawn
	

	local inGameIndex = GameplayService:IsInGame(player)
	if not inGameIndex then
		table.insert(InGamePlayers,player)
	end
	
	player.Team = InGameTeam
	
	GameplayService:SpawnCharacter(player,false,gamemodeRespawnFunction)
	GameplayService:SetMenu(player,"InGame")
	MapService:LoadLightingForPlayer(player,false)

end


-- puts a player back into the lobby
function GameplayService:ReturnToLobby(player:Player,ignoreMenu)

	local inGameIndex = GameplayService:IsInGame(player)
	if inGameIndex then
		table.remove(InGamePlayers,inGameIndex)
	end
	
	player.Team = LobbyTeam
	
	GameplayService:RemoveWeapons(player)
	GameplayService:DespawnCharacter(player)
	task.wait(.1)
	GameplayService:SpawnCharacter(player,true,nil)
	
	if not ignoreMenu then
		GameplayService:SetMenu(player,"Lobby")
	end
	MapService:LoadLightingForPlayer(player,true)
end



function GameplayService:SetMenu(player:Player,menuName)
	LobbyPacket:FireClient(player,menuName)
end


-- checks if a player is in a running game or in the lobby
function GameplayService:IsInGame(player:Player)
	local inGameIndex = table.find(InGamePlayers,player)
	if inGameIndex then
		return inGameIndex
	end
	return false
end



function GameplayService:GetLobbyPlayers(player:Player)
	local playerList = {}
	
	for _, plr in pairs(Players:GetPlayers()) do
		if GameplayService:IsInGame(plr) then
			table.insert(playerList,plr)
		end
	end
	
	return playerList
end


-- sends all players to the lobby
function GameplayService:ReturnPlayersToLobby()
	for _, plr in pairs(InGamePlayers) do
		GameplayService:ReturnToLobby(plr,true)
	end
end


-- countdown
function GameplayService:Countdown(amount, check)
	ActiveCountdownId += 1
	local id = ActiveCountdownId
	
	workspace:SetAttribute("Countdown", amount)
	
	while amount > 0 and id == ActiveCountdownId do
		task.wait(1)
		if check and not check() then break end
		amount -= 1
		workspace:SetAttribute("Countdown", amount)
	end

	workspace:SetAttribute("Countdown", 0)
end


-- removes the weapons of a player and prevents new ones until the connections are removed
function GameplayService:RemoveWeapons(player:Player)
	local function destroy(Child)
		if Child:IsA("Tool") then
			if Child then
				Child:Destroy()
			end
		end
	end

	local backpack = player.Backpack
	local character = player.Character

	for _,obj in pairs(backpack:GetChildren()) do
		destroy(obj)
	end
	removalConnections[player]["backpack_removal"] = backpack.ChildAdded:Connect(destroy)
	if character then
		for _,obj in pairs(character:GetChildren()) do
			destroy(obj)
		end
		removalConnections[player]["character_removal"] = character.ChildAdded:Connect(destroy)
	end
	
	removalConnections[player]["characterAdded_removal"] = player.CharacterAdded:Connect(function(characterr)
		removalConnections[player]["character_character_removal"] = characterr.ChildAdded:Connect(destroy)
		
		backpack = player.Backpack
		removalConnections[player]["character_backpack_removal"] = backpack.ChildAdded:Connect(destroy)
		for _,obj in pairs(backpack:GetChildren()) do
			destroy(obj)
		end
	end)
end


-- removes the weapon removal connections
function GameplayService:RemoveConnections(player:Player)
	local userId = player.UserId

	for connectionName, connection in removalConnections[player] do
		connection:Disconnect()
		removalConnections[player][connectionName] = nil
	end
end


-- load the character and if in lobby set connections again
function GameplayService:SpawnCharacter(player:Player,InLobby,spawnFn)
	
	GameplayService:RemoveConnections(player)
	
	-- set the respawn function
	DiedService:SetPlayerDiedAction(player,spawnFn)
	
	player:SetAttribute("InLobby",InLobby)
	
	task.spawn(function()
		self.Services.CharacterService:LoadCharacter(player)
		if InLobby then
			GameplayService:RemoveWeapons(player)
		else
			task.defer(function()
				LoadoutService:LoadLoadout(player)
			end)
		end
	end)
	
end



function GameplayService:DespawnCharacter(player:Player)
	GameplayService:RemoveConnections(player)

	local Character = player.Character
	if Character then
		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if Humanoid then
			Humanoid:TakeDamage(Humanoid.Health)
		end

		Character:Destroy()
	end
end



function GameplayService:Init()
	local Packet = self.Libs.Packet

	LobbyPacket = Packet("LobbyPacket", Packet.Any):Response(Packet.Any)
end


local LobbyPacketDebounces = {}

function GameplayService:Start()
	LoadoutService = self.Services.LoadoutService
	RoundService = self.Services.RoundService
	KillService = self.Services.KillService
	DiedService = self.Services.DiedService
	CharacterService = self.Services.CharacterService
	
	MapService = self.Services.MapService
	MapVoteService = self.Services.MapVoteService
	LobbyService = self.Services.LobbyService
	
	LobbyPacket.OnServerInvoke = function(player:Player)
		if LobbyPacketDebounces[player] then
			return
		end
		
		LobbyPacketDebounces[player] = true
		task.delay(1, function()
			LobbyPacketDebounces[player] = nil
		end)
		
		local isInGame = GameplayService:IsInGame(player)
		if isInGame then
			GameplayService:ReturnToLobby(player)
		else
			GameplayService:JoinGame(player)
		end
	end
	
	while true do
		
		workspace:SetAttribute("Gamemode", "INTERMISSION")
		
		GameplayService:ReturnPlayersToLobby()
		
		KillService:TriggerLeaderboard()
		KillService:ResetLeaderboard()
		
		GameplayService:Countdown(15)
		
		--GamemodeVoteService:TriggerModeVoting()   isso não existe, só botei aí pq seria meio assim
		
		MapVoteService:TriggerMapVotation()
		
		-- iniciar gamemode votado não sei
		workspace:SetAttribute("Gamemode", "FFA")
		
		GameplayService:Countdown(300) -- tempo de partida
		
	end
	
	
	
end



return GameplayService
