local BoostController = {}

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

-- CONSTANTS
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local BoostData = require(ReplicatedStorage.Modules.Constants.BoostsData)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local PLAYER = Players.LocalPlayer
local UI_PATH = PLAYER.PlayerGui:WaitForChild("Main"):WaitForChild("HUDFR"):WaitForChild("BoostsFR")
local TEMPLATE = UI_PATH:WaitForChild("GlowBG")

-- VARIABLES
local activeUI = {}
local janitor = Janitor.new()

-- FUNCTIONS
local function formatTime(seconds)
	if seconds == math.huge then return "∞" end
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%02d:%02d", m, s)
end

local function removeUI(boostKey)
	if activeUI[boostKey] then
		activeUI[boostKey]:Destroy()
		activeUI[boostKey] = nil
	end
end

local function createUI(boostKey)
	removeUI(boostKey)

	local data = BoostData[boostKey]
	if not data then return end

	local uiJanitor = Janitor.new()
	activeUI[boostKey] = uiJanitor

	local clone = TEMPLATE:Clone()
	clone.Name = boostKey
	clone.Parent = UI_PATH
	clone.Visible = true

	local icon = clone:FindFirstChild("ImageLabel") or clone:FindFirstChild("BoostIcon")
	local nameTx = clone:WaitForChild("ItemNameTX")
	local timeTx = clone:FindFirstChild("ItemTimeTX") or clone:FindFirstChild("PercentageTX") or clone:FindFirstChild("PermanentTX")

	if icon then icon.Image = data.Image end
	if nameTx then nameTx.Text = data.Title or data.Name end

	uiJanitor:Add(clone, "Destroy")

	if data.IsPermanent or data.Duration == math.huge then
		if timeTx then timeTx.Text = "∞" end
		return
	end

	local startTime = os.time()
	local endTime = startTime + data.Duration

	local connection = RunService.Heartbeat:Connect(function()
		if not timeTx then return end

		local remaining = endTime - os.time()
		if remaining >= 0 then
			timeTx.Text = formatTime(remaining)
		else
			timeTx.Text = "00:00"
			uiJanitor:Remove("TimerLoop")
		end
	end)

	uiJanitor:Add(connection, "Disconnect", "TimerLoop")
end

local function onBoostChanged(boostKey, isActive)
	if isActive then
		createUI(boostKey)
	else
		removeUI(boostKey)
	end
end

local function checkGamepass(boostKey, data)
	task.spawn(function()
		local success, hasPass = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(PLAYER.UserId, data.GamepassId)
		end)

		if success and hasPass then
			onBoostChanged(boostKey, true)
		else
			local cachedValue = PlayerDataManager:Get(PLAYER, {"Boost", boostKey})
			if cachedValue then
				onBoostChanged(boostKey, true)
			end
		end
	end)
end

-- INIT
function BoostController:Start()
	TEMPLATE.Visible = false

	for key, data in pairs(BoostData) do
		local path = {"Boost", key}

		janitor:Add(
			PlayerDataManager:GetValueChangedSignal(PLAYER, path):Connect(function(newValue)
				onBoostChanged(key, newValue)
			end),
			"Disconnect"
		)

		if data.GamepassId then
			checkGamepass(key, data)
		else
			local currentValue = PlayerDataManager:Get(PLAYER, path)
			if currentValue == true then
				onBoostChanged(key, true)
			end
		end
	end
end

return BoostController