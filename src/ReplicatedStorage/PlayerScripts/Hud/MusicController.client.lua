-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- CONSTANTS
local SoundController = require(ReplicatedStorage.Modules.Utility.SoundUtility)
local SoundData = require(ReplicatedStorage.Modules.Datas.SoundData)

-- INIT
SoundController.PlayMusic(SoundData.Music.MainMenu, true, true)