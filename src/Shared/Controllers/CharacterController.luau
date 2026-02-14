local module = {}

-- // SERVICES
local Players = game:GetService("Players")

-- // VARIABLES
local Characters = {}

-- // FUNCTIONS
local function DisconnectAll(player: Player)
	local data = Characters[player]
	if not data then
		return
	end

	for _, connection: RBXScriptConnection in ipairs(data.Connections) do
		connection:Disconnect()
	end

	Characters[player] = nil
end

local function SetupCharacter(player: Player, character: Model)
	DisconnectAll(player)

	Characters[player] = {
		Connections = {},
	}
	local Connections: { RBXScriptConnection } = Characters[player].Connections
end

-- // INIT
function module:Start()
	local function setupPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			SetupCharacter(player, character)
		end)

		player.CharacterRemoving:Connect(function()
			DisconnectAll(player)
		end)

		if player.Character then
			SetupCharacter(player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(setupPlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		DisconnectAll(player)
	end)
end

return module