local TeleportService = {}

-- SERVICES
local ServerScriptService = game:GetService('ServerScriptService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Workspace = game:GetService('Workspace')

-- CONSTANTS
local MetaPlayer = require(ServerScriptService.Modules.Core.MetaPlayer)
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local CENTER_TP_PART = Workspace.Map.Assets.TpPart

-- VARIABLES

-- FUNCTIONS
local function teleportToPlot(player)
	local metaPlayer = MetaPlayer.Get(player)
	if not metaPlayer then return end

	local plot = metaPlayer.Cache.Plot
	if not plot then return end

	local spawnPart = plot.PrimaryPart
	if not spawnPart then return end

	local character = player.Character
	if not character then return end

	character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
end

local function teleportToCenter(player)
	local character = player.Character
	if not character then return end
	
	if not CENTER_TP_PART then
		warn("TpPart não encontrada no Workspace.Map.Assets")
		return
	end

	character:PivotTo(CENTER_TP_PART.CFrame + Vector3.new(0, 3, 0))
end

function TeleportService:Init()
	Packets.Action.OnServerEvent:Connect(function(player, action, _data)
		if action == 'TeleportToPlot' then
			teleportToPlot(player)
		elseif action == 'TeleportToCenter' then
			teleportToCenter(player)
		end
	end)
end

return TeleportService