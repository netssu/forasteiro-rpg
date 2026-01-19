local PlayerService = {}

local Packet
local CharacterService
local DataService
local KillService
local GameplayService
local CommandService

function PlayerService.PlayerAdded(Player: Player)
	if Player:HasTag("Player") then
		return
	end
	
	DataService:LoadData(Player)
	CommandService:LoadPlayer(Player)
	while not DataService:IsDataLoaded(Player) or not Player.Parent do
		task.wait()
	end
	
	if not Player.Parent then
		return
	end
	
	local PlayerData = DataService:GetData(Player)
	
	PlayerData.OpeningCrate = false
	Player:AddTag("Player")
	
	-- iniciar a contagem de kills e streaks do player
	KillService:SetPlayer(Player)
	GameplayService:InsertPlayer(Player)
	
	-- tenta carregar autoamticamente quando entra no jg, caso ja tenha uma partida iniciada, tirar pra fazer o lobby principal
	--CharacterService:LoadCharacter(Player)
end

function PlayerService.PlayerRemoving(Player: Player)
	KillService:RemovePlayer(Player)
end

function PlayerService:Init()
	CharacterService = self.Services.CharacterService
	DataService = self.Services.DataService
	KillService = self.Services.KillService
	GameplayService = self.Services.GameplayService
	CommandService = self.Services.CommandService
	
	Packet = self.Libs.Packet
	
	game.Players.PlayerAdded:Connect(PlayerService.PlayerAdded)	
	game.Players.PlayerRemoving:Connect(PlayerService.PlayerRemoving)
	for _, Player in game.Players:GetPlayers() do
		task.spawn(function()
			PlayerService.PlayerAdded(Player)
		end)
	end
end

function PlayerService:Start()

end

return PlayerService