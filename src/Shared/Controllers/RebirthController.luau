local module = {}

local HttpService = game:GetService('HttpService')
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)

local PLAYER = Players.LocalPlayer

local function GetRequiredLevel(currentRebirths: number)
	return (currentRebirths + 1) * 10
end

function module:Init()
	local playerGui = PLAYER:WaitForChild('PlayerGui')
	local mainUI = playerGui:WaitForChild('Main')
	local rebirthFrame = mainUI:WaitForChild('RebirthFR')
	local holder = rebirthFrame:WaitForChild('ConfirmationBG')

	local txLabel = holder:WaitForChild('TX')
	local confirmButton = holder:WaitForChild('ConfirmBT')

	local function UpdateUI()
		local currentRebirths = PlayerDataManager:Get(
			PLAYER,
			{ 'Currency', 'RebirthCount' }
		) or 0
		local requiredLevel = GetRequiredLevel(currentRebirths)

		txLabel.Text = string.format(
			'You will start over from the beginning; you need to have %d level for that',
			requiredLevel
		)
	end

	confirmButton.MouseButton1Click:Connect(function()
		local currentRebirths = PlayerDataManager:Get(PLAYER, { 'Currency', 'RebirthCount' }) or 0
		local requiredLevel = GetRequiredLevel(currentRebirths)
		local currentLevel = PlayerDataManager:Get(PLAYER, { 'Pinata', 'Level' }) or 0

		if currentLevel >= requiredLevel then
			if Packets.Rebirth then
				Packets.Rebirth:Fire()
			end
		else
			txLabel.Text = 'You do not meet the requirements for rebirth!'
			
			task.delay(2, function()
				UpdateUI()
			end)
		end
	end)

	UpdateUI()
end

return module