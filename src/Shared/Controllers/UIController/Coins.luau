-- SERVICES
local Coins = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Format = require(ReplicatedStorage.Modules.Math.FormatCurrency)

-- CONSTANTS
local PLAYER = Players.LocalPlayer
local DATA_MANAGER = require(ReplicatedStorage.Packages.PlayerDataManager)
local PATH_COINS = { "Currency", "Coins" }

-- VARIABLES
local playerGui = PLAYER.PlayerGui
local mainGui = playerGui:WaitForChild("Main")
local hudFrame = mainGui:WaitForChild("HUDFR")
local coinsFrame = hudFrame:WaitForChild("CoinsFR")
local amountLabel = coinsFrame:WaitForChild("AmountLabel")

-- FUNCTIONS
local function updateDisplay(newValue)
	amountLabel.Text = "$" .. Format(newValue)
end

-- INIT
local currentCoins = DATA_MANAGER:Get(PLAYER, PATH_COINS)
if currentCoins then
	updateDisplay(currentCoins)
end

DATA_MANAGER:GetValueChangedSignal(PLAYER, PATH_COINS):Connect(function(newValue)
	updateDisplay(newValue)
end)
return Coins