local module = {}

-- // Services
local Players = game:GetService('Players')
local ServerScriptService = game:GetService('ServerScriptService')

-- // Dependencies
local MetaPlayer = require(ServerScriptService.Modules.Core.MetaPlayer)

-- // Public Functions
function module:Init()
	for _, player in Players:GetChildren() do
		task.spawn(function()
			MetaPlayer.Add(player)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		MetaPlayer.Add(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MetaPlayer.Remove(player)
	end)
end

print('[PlayerService] Initialized')
return module
