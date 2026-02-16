local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Packet = require(ReplicatedStorage.Packages.Packet)

local OfflineEarning = Packet('OfflineEarning', Packet.NumberU32):Response(Packet.Boolean8)
OfflineEarning.ResponseTimeout = 45
OfflineEarning.ResponseTimeoutValue = false

return {
	-- Main
	Replicator = Packet('Replicator', Packet.String, Packet.Any),
	Action = Packet('Action', Packet.String, Packet.Any),
	Machines = Packet("Machines", Packet.String, Packet.Any),
	Feed = Packet('Feed', Packet.String),
	Rebirth = Packet('Rebirth'),
	OfflineEarning = OfflineEarning,
	
	Leaderboard = Packet(
		'Leaderboard',
		Packet.String,
		{ StatPath = Packet.String, Amount = Packet.NumberF32 }
	):Response({{
		UserId = Packet.String,
		Score = Packet.String,
		Rank = Packet.String,
	}}),
	
}
