------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//MODULES
local MasterBuildManager = require(ReplicatedStorage.Modules.Game:WaitForChild("MasterBuildManager"))

------------------//VARIABLES
local player: Player = Players.LocalPlayer

------------------//INIT
MasterBuildManager.new(player)