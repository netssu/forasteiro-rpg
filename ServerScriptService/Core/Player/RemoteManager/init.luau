--// Services //--
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage.Remotes
local Events = Remotes.Events
local Functions = Remotes.Functions

local RemoteConfig = require(script.RemoteConfig)

local RemoteManager = {}

--// Config //--
local Config = {
	DefaultCooldown = 0.5,
	MaxViolations = 10,
	ViolationWindow = 60
}

--// Data //--
local PlayerCooldowns = {} -- [Player][RemoteName] = lastCallTime
local PlayerViolations = {} -- [Player] = {count, lastViolation}

--// Player Lifecycle //--
function RemoteManager.InitializePlayer(player)
	PlayerCooldowns[player] = {}
	PlayerViolations[player] = {count = 0, lastViolation = 0}
end

function RemoteManager.CleanupPlayer(player)
	PlayerCooldowns[player] = nil
	PlayerViolations[player] = nil
end

--// Helper Functions //--
local function IsOnCooldown(player, remoteName:string)
	if not RemoteConfig[remoteName] then
		warn(`[RemoteManager] Invalid remote name: {remoteName}`)
		return false
	end
	
	local cooldowns = PlayerCooldowns[player]
	if not cooldowns then return false end

	local lastCall = cooldowns[remoteName]
	if not lastCall then return false end

	local cooldownTime = RemoteConfig[remoteName].Cooldown or Config.DefaultCooldown
	local currentTime = tick()

	return (currentTime - lastCall) < cooldownTime
end

local function UpdateCooldown(player, remoteName)
	if not PlayerCooldowns[player] then
		RemoteManager.InitializePlayer(player)
	end
	PlayerCooldowns[player][remoteName] = tick()
end

local function HandleViolation(player, remoteName)
	local violations = PlayerViolations[player]
	if not violations then
		RemoteManager.InitializePlayer(player)
		violations = PlayerViolations[player]
	end

	local currentTime = tick()

	if (currentTime - violations.lastViolation) > Config.ViolationWindow then
		violations.count = 0
	end

	violations.count += 1
	violations.lastViolation = currentTime

--[[	warn(string.format("Player %s violated cooldown for %s (Violation %d/%d)", 
		player.Name, remoteName, violations.count, Config.MaxViolations))]]

	if violations.count >= Config.MaxViolations then
		player:Kick("")
	end
end

--// Main //--
function RemoteManager.ProcessEvent(remoteName, player, ...)
	-- Validation
	local handler = RemoteConfig[remoteName].Handler
	if not handler then
		warn("No handler found for event:", remoteName)
		return
	end

	-- Cooldown
	if IsOnCooldown(player, remoteName) then
		HandleViolation(player, remoteName)
		return
	end

	UpdateCooldown(player, remoteName)

	-- Call handler
	local success, err = pcall(handler, player, ...)
	if not success then
		warn(string.format("Error in handler for %s: %s", remoteName, tostring(err)))
	end
end

function RemoteManager.ProcessFunction(remoteName, player, ...)
	-- Validation
	local handler = RemoteConfig[remoteName].Handler(player,...)
	if not handler then
		warn("No handler found for function:", remoteName)
		return nil
	end

	-- Cooldown
	if IsOnCooldown(player, remoteName) then
		HandleViolation(player, remoteName)
		return nil
	end
	UpdateCooldown(player, remoteName)

	-- Call handler
	local success, result = pcall(handler, player, ...)
	if not success then
		warn(string.format("Error in handler for %s: %s", remoteName, tostring(result)))
		return nil
	end

	return result
end

--// Initialization //--
function RemoteManager.Initialize()
	-- Setup existing players
	for _, player in Players:GetPlayers() do
		RemoteManager.InitializePlayer(player)
	end

	for _, remoteEvent:RemoteEvent in Events:GetDescendants() do
		if not remoteEvent:IsA("RemoteEvent") then continue end

		local handler = RemoteConfig[remoteEvent.Name]
		if not handler then
			--warn("No handler found for event:", remoteEvent.Name)
			continue
		end

		remoteEvent.OnServerEvent:Connect(function(player,...)
			RemoteManager.ProcessEvent(remoteEvent.Name, player, ...)
		end)
	end


	for _, remoteFunction:RemoteFunction in Functions:GetDescendants() do
		if not remoteFunction:IsA("RemoteFunction") then continue end
		local remoteFunction = remoteFunction :: RemoteFunction

		local handler = RemoteConfig[remoteFunction.Name]
		if not handler then
			--warn("No handler found for event:", remoteFunction.Name)
			continue
		end

		remoteFunction.OnServerInvoke = function(player,...)
			return RemoteManager.ProcessFunction(remoteFunction.Name, player, ...)
		end
	end

	--print("[RemoteManager] Initialized")
end

return RemoteManager