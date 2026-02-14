-- SERVICES
local TeleportController = {}
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

-- CONSTANTS
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local Main = playerGui:WaitForChild("Main")
local teleportFR = Main:WaitForChild('TeleportFR')
local teleportBG = teleportFR:WaitForChild('TeleportBG')
local listScrollingFrame = teleportBG:WaitForChild('ListScrollingFrame')
local mapBG = listScrollingFrame:WaitForChild('MapBG')

-- VARIABLES
local teleportLocations = {
	{
		Name = "Center",
		Action = "TeleportToCenter"
	},
	{
		Name = "My Plot",
		Action = "TeleportToPlot"
	}
}

-- FUNCTIONS
local function createTeleportButton(locationData)
	local button = mapBG:Clone()
	button.Name = locationData.Name
	button.MapNameTX.Text = locationData.Name
	button.Visible = true
	button.Parent = listScrollingFrame
	
	button.MouseButton1Click:Connect(function()
		Packets.Action:Fire(locationData.Action)
	end)
	
	return button
end

local function setupUI()
	mapBG.Visible = false
	
	for _, locationData in ipairs(teleportLocations) do
		createTeleportButton(locationData)
	end
end

-- INIT
setupUI()
return TeleportController