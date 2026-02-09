local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Packet = require(ReplicatedStorage.Packages.Packet)

return {
	-- Main
	Replicator = Packet('Replicator', Packet.String, { Packet.Any }),
	Action = Packet('Action', Packet.String, { Packet.Any }),
}
