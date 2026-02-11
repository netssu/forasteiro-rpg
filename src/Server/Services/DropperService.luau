--!strict

local ServerScriptService = game:GetService("ServerScriptService")

-- Compatibility wrapper (old DropperService). Use MachinesService instead.
local MachinesService = require(ServerScriptService.Services.MachinesService)

return MachinesService
