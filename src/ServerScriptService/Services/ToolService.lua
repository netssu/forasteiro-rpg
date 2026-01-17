local ToolService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolTable = require(ReplicatedStorage.Arrays.ToolTable)

local ToolServiceEvent = ReplicatedStorage.Remotes.Events.ToolService

local function listener()
	ToolServiceEvent.OnServerEvent:Connect(function(plr, arg, tool, argTable)
		if arg == "Use" then
			ToolTable[tool.Name]["ServerUse"](plr, tool, argTable)
		elseif arg == "SecondaryUse" then
			ToolTable[tool.Name]["ServerSecondaryUse"](plr, tool, argTable)
		elseif arg == "Unequip" then
			ToolTable[tool.Name]["ServerUnequip"](plr, tool)
		end
	end)
end

function ToolService.Handler()
	listener()
end

return ToolService
