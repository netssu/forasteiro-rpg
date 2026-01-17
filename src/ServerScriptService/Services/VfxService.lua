local VfxService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxServiceEvent: RemoteEvent = ReplicatedStorage.Remotes.Events.VfxService

local function listener()
	VfxServiceEvent.OnServerEvent:Connect(function(plr, arg, targetPlr, specialArg)
		VfxServiceEvent:FireAllClients(arg, targetPlr, specialArg)
	end)
end

function VfxService.Handler()
	listener()
end

return VfxService
