-- // Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local HttpService = game:GetService("HttpService")

-- // Dependencies
local Packets = require(ReplicatedStorage.Modules.Game.Packets)

-- // Variables
local module = {}
local ModulesFolder = script:WaitForChild('Client')
local LoadedModules = {}

-- // Private Functions
local function GetModule(Name: string)
	if LoadedModules[Name] then return LoadedModules[Name] end

	local Module = ModulesFolder:FindFirstChild(Name)
	if not Module then
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
	Packets.Replicator.OnClientEvent:Connect(function(...)
		local args = {...}
		local data = nil
		
		for _, arg in pairs(args) do
			local argType = type(arg)

			if argType == "table" and arg.Type then
				data = arg
				break
			
			elseif argType == "string" then
				if string.sub(arg, 1, 1) == "{" then
					local success, decoded = pcall(function() 
						return HttpService:JSONDecode(arg) 
					end)
					
					if success and decoded and decoded.Type then
						data = decoded
						break
					end
				end
			end
		end

		if data then
			if data.Position and typeof(data.Position) ~= "Vector3" then
				local x = data.Position.X or data.Position[1] or 0
				local y = data.Position.Y or data.Position[2] or 0
				local z = data.Position.Z or data.Position[3] or 0
				data.Position = Vector3.new(x, y, z)
			end
			
			module.Emit(data.Type, data)
		end
	end)
end

module.Emit = function(eventName, data)
	local Module = GetModule(eventName)
	warn(Module,eventName)
	if not Module then return end

	if typeof(Module.Start) ~= 'function' then
		warn(`[Replicator] Module "{eventName}" has no Start() function`)
		return
	end

	task.spawn(function()
		Module:Start(data)
	end)
end

return module