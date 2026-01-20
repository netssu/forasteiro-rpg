------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")

------------------//VARIABLES
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local FunctionsFolder = RemotesFolder:WaitForChild("Functions")
local EventsFolder = RemotesFolder:WaitForChild("Events")

local GetMachinesRF: RemoteFunction = FunctionsFolder:WaitForChild("GetMachines")
local UpgradeMachineRF: RemoteFunction = FunctionsFolder:WaitForChild("UpgradeMachine")

local TycoonManager = require(ServerScriptService.Core.Tycoon.TycoonManager)

------------------//FUNCTIONS
local function getBaseAndTank(player: Player)
	local base = TycoonManager.getBase(player)
	if not base or not base.Tank then
		return nil, nil
	end
	return base, base.Tank
end

------------------//MAIN FUNCTIONS
GetMachinesRF.OnServerInvoke = function(player: Player)
	local _, tankManager = getBaseAndTank(player)
	if not tankManager then
		return
	end

	return tankManager:getAllMachinesSnapshot()
end

UpgradeMachineRF.OnServerInvoke = function(player: Player, tankName: string)
	local base, tankManager = getBaseAndTank(player)
	if not base or not tankManager then
		warn("[UPGRADE] Invalid base or tankManager")
		return false
	end

	if base.Owner ~= player then
		warn("[UPGRADE] Player not owner of base")
		return false
	end

	if type(tankName) ~= "string" or tankName == "" then
		warn("[UPGRADE] Invalid tankName")
		return false
	end

	local ok = TycoonManager.purchaseUpgradeTank(player, tankName)
	if ok then
		local snap = tankManager:getMachineSnapshot(tankName)
	else
		warn("[UPGRADE] Failed to upgrade tank:", tankName)
	end

	return ok
end
