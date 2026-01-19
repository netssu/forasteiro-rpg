local ServerStorage = game:GetService("ServerStorage")

local Resources = ServerStorage:WaitForChild("Resources")
local Modules = Resources.Modules

require(Modules.ServerGunFramework).Initialize(script.Parent)