local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Packet = require(ReplicatedStorage.Packages.Packet)

return {
	-- Definimos como Packet.String para enviar tudo como JSON seguro
	Replicator = Packet('Replicator', Packet.String),
	Feed = Packet('Feed', Packet.String),
	Action = Packet('Action', Packet.String, { Packet.Any }),
	Dropper = Packet("Dropper", Packet.String, { Packet.Any }),
	Rebirth = Packet('Rebirth'),
}