local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)

local DataTemplate = require(ServerScriptService.Modules.Core.DataTemplate)

PlayerDataManager:SetTemplate(DataTemplate)