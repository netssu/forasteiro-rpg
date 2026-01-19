local DiedService = {}

local PlayersDiedAction = {}


--[[ 
	Serve para definir o metodo de respawn utilizado, em caso de minigames que o personagem respawna
	Se nn definir então ele voltará ao lobby e recarregara o personagem em 3s
]]

function DiedService:SetPlayerDiedAction(Player: Player, Action: () -> nil | nil)
	PlayersDiedAction[Player] = Action
end

function DiedService:GetPlayerDiedAction(Player: Player)
	return PlayersDiedAction[Player]
end

function DiedService.Init()
	game.Players.PlayerRemoving:Connect(function(Player: Player)
		PlayersDiedAction[Player] = nil
	end)
end


return DiedService