local VfxController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vfxTable = require(ReplicatedStorage.Arrays.VfxTable)

local VfxServiceEvent: RemoteEvent = ReplicatedStorage.Remotes.Events.VfxService

local function listener()
	VfxServiceEvent.OnClientEvent:Connect(function(arg, targetPlr, specialArg)
		vfxTable[arg](targetPlr, specialArg)
	end)
end

function VfxController.Handler()
	listener()
end

return VfxController
