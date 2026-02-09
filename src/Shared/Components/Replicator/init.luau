-- // Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- // Dependencies
local Packets = require(ReplicatedStorage.Modules.Game.Packets)

-- // Variables
local module = {}
local ModulesFolder = script:WaitForChild('Client')

local LoadedModules = {}

-- // Private Functions
local function GetModule(Name: string)
	if LoadedModules[Name] then return LoadedModules[Name] end

	local Module: ModuleScript = ModulesFolder:FindFirstChild(Name)
	if not Module then
		warn(`[Replicator] Module "{Name}" not found in Replicator/Client`)
		return nil
	end

	local Success, Required = pcall(require, Module)
	if not Success then
		warn(`[Replicator] Failed to require module "{Name}":`, Required)
		return nil
	end

	LoadedModules[Name] = Required
	return Required
end

-- // Public Functions
function module:Init()
	Packets.Replicator.OnClientEvent:Connect(function(a0: string, a1: { any })
		module.Emit(a0, a1)
	end)
end

module.Emit = function(a0, a1)
	local Module = GetModule(a0)
	if not Module then
		warn(`[Replicator] No valid module for event "{a0}"`)
		return
	end

	if typeof(Module.Start) ~= 'function' then
		warn(`[Replicator] Module "{a0}" has no Start() function`)
		return
	end

	task.spawn(function()
		Module:Start(a1)
	end)
end

return module
