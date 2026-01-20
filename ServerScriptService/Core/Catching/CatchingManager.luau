local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CatchingConfig = require(ReplicatedStorage.Shared.Configs.CatchingConfig)
local CatchingSession = require(script.Parent.CatchingSession)

local CatchingSessionStart = ReplicatedStorage.Remotes.Events.Catching.CatchingSession
local endSession = ServerScriptService.Bindables.Catching.endSession

local Transition = ReplicatedStorage.Remotes.Events.Transition

local CatchingManager = {}

local ActiveSessions = {}

endSession.Event:Connect(function(player)
	CatchingManager.endSession(player)
end)

local function getNextOffset() -- get map offset for new map
	local count = 0
	
	print(ActiveSessions)
	
	for _ in pairs(ActiveSessions) do
		count += 1
	end
	
	return (count + 1) * CatchingConfig.Session.SlotSpacing
end

function CatchingManager.startSession(player, world) -- setup session
	warn("session: ", player, world)
	if CatchingManager.isInSession(player) then return end
	Transition:FireClient(player, 5)
	task.wait(2)

	local offset = getNextOffset()
	local SessionMap = CatchingSession.spawnSession(offset, player, world)
	
	ActiveSessions[player] = SessionMap -- saves on cache
end

function CatchingManager.endSession(player) -- end session
	local session = ActiveSessions[player]
	if not session then return end
	
	--print(ActiveSessions)

	session:Destroy()
	ActiveSessions[player] = nil
end

function CatchingManager.isInSession(player)
	return ActiveSessions[player] ~= nil -- return boolean
end

function CatchingManager.getSession(player)
	return ActiveSessions[player] -- return current player session map
end

function CatchingManager.initialize()
	Players.PlayerRemoving:Connect(function(player) -- handler for when player leaves
		if CatchingManager.isInSession(player) then
			CatchingManager.endSession(player)
		end
	end)

	CatchingSessionStart.OnServerEvent:Connect(function(player, world) -- handler for when player starts session
		CatchingManager.startSession(player, world)
	end)
end

return CatchingManager
