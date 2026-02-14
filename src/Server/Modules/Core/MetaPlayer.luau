local MetaPlayer = {}
MetaPlayer.__index = MetaPlayer

-- // Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- // Dependencies
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Signal = require(ReplicatedStorage.Packages.Signal)

-- // Variables
local ActivePlayers = {}
MetaPlayer.Signals = {
	PlayerAdded = Signal.new(),
	PlayerRemoving = Signal.new(),
}

-- // API
function MetaPlayer.new(player: Player)
	local self = setmetatable({}, MetaPlayer)

	self.Instance = player
	self.UserId = player.UserId
	self.Cache = {}
	self.Connections = {}
	self.Plot = nil

	MetaPlayer.Signals.PlayerAdded:Fire(self)

	print('[METAPLAYER] Player added: ' .. player.Name)

	return self
end

function MetaPlayer:AssignPlot(plot: Model)
	self.Plot = plot
end

function MetaPlayer:Cleanup()
	MetaPlayer.Signals.PlayerRemoving:Fire(self)
end

-- // Manager
function MetaPlayer.Get(player: Player): any
	return ActivePlayers[player]
end

function MetaPlayer.Add(player: Player)
	local meta = MetaPlayer.new(player)
	ActivePlayers[player] = meta
	return meta
end

function MetaPlayer.Remove(player: Player)
	local meta = ActivePlayers[player]
	if meta then
		meta:Cleanup()
		ActivePlayers[player] = nil
	end
end

return MetaPlayer
