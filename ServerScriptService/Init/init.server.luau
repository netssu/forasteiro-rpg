local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Resources = ReplicatedStorage:WaitForChild("Resources")

local Data = Resources.Data
local Miscs = Resources.Miscs
local Modules = Resources.Modules

local Timer = require(Modules.Timer)

PhysicsService:RegisterCollisionGroup("Players")
PhysicsService:RegisterCollisionGroup("Viewmodel")
PhysicsService:RegisterCollisionGroup("Debris")

PhysicsService:CollisionGroupSetCollidable("Players", "Viewmodel", false)
PhysicsService:CollisionGroupSetCollidable("Viewmodel", "Viewmodel", false)
PhysicsService:CollisionGroupSetCollidable("Viewmodel", "Players", false)

PhysicsService:CollisionGroupSetCollidable("Debris", "Debris", false)
PhysicsService:CollisionGroupSetCollidable("Debris", "Players", false)
PhysicsService:CollisionGroupSetCollidable("Debris", "Viewmodel", false)

for _, UI in game.StarterGui:GetChildren() do
	UI.Parent = game.ReplicatedStorage.Resources.UIS
end

local VM_WM_AnimConstructTimer = Timer:Start()

for _, ModuleScript in Data:GetDescendants() do
	if ModuleScript:IsA("ModuleScript") then
		if ModuleScript.Name:find("Animations") then
			local Animations = require(ModuleScript)
			if Animations then
				for AnimName: string, Value in Animations do
					if typeof(Value) == "table" then
						for _, Value in Value do
							if Value and Value ~= nil or Value ~= 0 then
								local NewTrack = Instance.new("Animation")
								NewTrack.AnimationId = ("rbxassetid://%d"):format(Value)
								NewTrack.Name = AnimName:gsub("AnimationId", "") 
								NewTrack.Parent = ModuleScript
							end
						end
					else
						if Value and Value ~= nil or Value ~= 0 then
							local NewTrack = Instance.new("Animation")
							NewTrack.AnimationId = ("rbxassetid://%d"):format(Value)
							NewTrack.Name = AnimName:gsub("AnimationId", "") 
							NewTrack.Parent = ModuleScript
						end
					end
				end
			end
		end
	end
end

-- SERVICES INITIALIZATION

local Services = {}
local Libs = {}

-- Require
for _, Service in script:GetDescendants() do
	if Service:IsA("ModuleScript") and Service.Name:find("Service$") then
		Services[Service.Name] = require(Service)
	end
end

for _, Lib in game.ReplicatedStorage.Resources.Modules.SharedLibraries:GetChildren() do -- Client and Server
	Libs[Lib.Name] = require(Lib)
end

for _, Lib in game.ServerStorage.Resources.Modules.ServerLibraries:GetChildren() do -- Server Only
	Libs[Lib.Name] = require(Lib)
end


for _, Service in Services do
	Service.Services = Services
	Service.Libs = Libs
end

for Name, Service in Services do
	if Service.Init then
		local success, err = pcall(function()
			Service:Init()
		end)

		if not success then
			task.spawn(function()
				error(`[CRITICAL ERROR WHILE LOADING IN]: {Name}: {err}`)		
			end)			
		end
	end
end

for _, Service in Services do
	task.spawn(function()
		if Service.Start then
			Service:Start()
		end
	end)
end

_G.Services = Services

local ExplosiveBarrelManager = require(game.ServerStorage.Resources.Modules.ExplosiveBarrelManager)
ExplosiveBarrelManager.Init()