local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Resources = ReplicatedStorage:WaitForChild("Resources")
local Modules = Resources.Modules

require(Modules.ClientGunFramework).Initialize(script.Parent)