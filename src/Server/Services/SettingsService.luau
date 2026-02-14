local SettingsService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local Packets = require(ReplicatedStorage.Modules.Game.Packets)

local DEFAULT_SETTINGS = {
	MuteMusic = false,
	MuteSFX = false,
	Shadows = true,
	MusicVolume = 0.5,
	SFXVolume = 0.5,
}

local function getSetting(player, key)
	local value = PlayerDataManager:Get(player, { "Settings", key })
	if value == nil then
		return DEFAULT_SETTINGS[key]
	end
	return value
end

local function setSetting(player, key, value)
	PlayerDataManager:Set(player, { "Settings", key }, value)
end

local function applySettings(player)
	local settings = {}
	for key, default in pairs(DEFAULT_SETTINGS) do
		settings[key] = getSetting(player, key)
	end

	Packets.Action:FireClient(player, "ApplySettings", { settings })
end

local function onSettingChanged(player, key, value)
	setSetting(player, key, value)
	Packets.Action:FireClient(player, "SettingChanged", { key, value })
end

function SettingsService.Init()
	Packets.Action.OnServerEvent:Connect(function(player, action, args)
		if action == "ChangeSetting" then
			local key = args[1]
			local value = args[2]

			if DEFAULT_SETTINGS[key] == nil then return end
			if typeof(value) ~= typeof(DEFAULT_SETTINGS[key]) then return end

			onSettingChanged(player, key, value)
		elseif action == "RequestSettings" then
			applySettings(player)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		applySettings(player)
	end)
end

function SettingsService.GetSetting(player, key)
	return getSetting(player, key)
end

function SettingsService.GetAllSettings(player)
	local settings = {}
	for key in pairs(DEFAULT_SETTINGS) do
		settings[key] = getSetting(player, key)
	end
	return settings
end

return SettingsService