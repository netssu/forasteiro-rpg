--// Services //--
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--// Modules //--
local ConfigManager = require(ReplicatedStorage.Shared.Configs.ConfigManager)
local TycoonManager = require(ServerScriptService.Core.Tycoon.TycoonManager)
local CacheSystem = require(ReplicatedStorage.Shared.Utilities.Cache)

--// Assets //--
local CatchingMaps = ReplicatedStorage.Assets.CatchingMaps

--// Setup //--
local CatchingManager = {}

--// Data //--
local ActiveSessions = {} -- [player] = SessionData

--// Types //--
export type BrainrotData = {
	Name: string,
	Model: Model,
	Health: number,
	MaxHealth: number,
	State: "Hidden" | "Emerging" | "Wandering" | "Fleeing" | "Dead",
	Position: Vector3,
	TargetPosition: Vector3?,
	Speed: number,
	SpawnPoint: Part,
}

export type SessionData = {
	Player: Player,
	Map: Model,
	Brainrots: {BrainrotData},
	CaughtBrainrots: {[string]: number},
	StartTime: number,
	Active: boolean,
	UpdateConnection: RBXScriptConnection?,
}

--// Constants //--
local BRAINROT_HEALTH_BASE = 100
local DETECTION_RANGE = 30
local FLEE_DISTANCE = 50

--// Private Methods //--

function CatchingManager._createMap(): Model
	local map = CacheSystem.RetrieveFromCache("CatchingMap") or CatchingMapTemplate:Clone()
	map.Parent = workspace.CatchingMaps
	
	-- Position map away from others
	local offset = #workspace.CatchingMaps:GetChildren() * 200
	map:PivotTo(CFrame.new(offset, 100, 0))
	
	return map
end

function CatchingManager._spawnBrainrot(map: Model, brainrotName: string): BrainrotData?
	-- Find random spawn point (mud puddle)
	local spawnPoints = map:FindFirstChild("SpawnPoints")
	if not spawnPoints then return nil end
	
	local spawnPointsArray = spawnPoints:GetChildren()
	if #spawnPointsArray == 0 then return nil end
	
	local spawnPoint = spawnPointsArray[math.random(1, #spawnPointsArray)]
	
	-- Create brainrot model
	local brainrotTemplate = ReplicatedStorage.Assets.Brainrots:FindFirstChild(brainrotName)
	if not brainrotTemplate then
		warn(`Brainrot template not found: {brainrotName}`)
		return nil
	end
	
	local brainrotModel = brainrotTemplate:Clone()
	brainrotModel:PivotTo(spawnPoint.CFrame * CFrame.new(0, -5, 0)) -- Hidden underground
	brainrotModel.Parent = map
	
	local brainrotInfo = ConfigManager.Brainrot.getInfo(brainrotName)
	
	return {
		Name = brainrotName,
		Model = brainrotModel,
		Health = BRAINROT_HEALTH_BASE,
		MaxHealth = BRAINROT_HEALTH_BASE,
		State = "Hidden",
		Position = brainrotModel:GetPivot().Position,
		TargetPosition = nil,
		Speed = brainrotInfo and brainrotInfo.Speed or 16,
		SpawnPoint = spawnPoint,
	}
end

function CatchingManager._updateBrainrot(session: SessionData, brainrot: BrainrotData, deltaTime: number)
	if brainrot.State == "Dead" then return end
	
	local player = session.Player
	local character = player.Character
	if not character then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	
	local playerPosition = humanoidRootPart.Position
	local brainrotPosition = brainrot.Model:GetPivot().Position
	
	-- Check for brains nearby
	local brainsFolder = session.Map:FindFirstChild("Brains")
	local nearestBrain = nil
	local nearestBrainDistance = math.huge
	
	if brainsFolder then
		for _, brain in ipairs(brainsFolder:GetChildren()) do
			local distance = (brain.Position - brainrotPosition).Magnitude
			if distance < nearestBrainDistance and distance < DETECTION_RANGE then
				nearestBrain = brain
				nearestBrainDistance = distance
			end
		end
	end
	
	-- State machine
	if brainrot.State == "Hidden" then
		if nearestBrain then
			-- Emerge and move towards brain
			brainrot.State = "Emerging"
			brainrot.TargetPosition = brainrot.SpawnPoint.Position + Vector3.new(0, 5, 0)
		end
		
	elseif brainrot.State == "Emerging" then
		-- Move up from underground
		if brainrot.TargetPosition then
			local direction = (brainrot.TargetPosition - brainrotPosition).Unit
			local newPosition = brainrotPosition + direction * brainrot.Speed * deltaTime
			
			brainrot.Model:PivotTo(CFrame.new(newPosition))
			
			if (newPosition - brainrot.TargetPosition).Magnitude < 1 then
				brainrot.State = "Wandering"
				brainrot.TargetPosition = nil
			end
		end
		
	elseif brainrot.State == "Wandering" then
		-- Check for player proximity
		local distanceToPlayer = (playerPosition - brainrotPosition).Magnitude
		
		if distanceToPlayer < DETECTION_RANGE then
			-- Start fleeing
			brainrot.State = "Fleeing"
			
			-- Calculate flee direction (away from player, towards lane then to end)
			local laneCenter = session.Map:FindFirstChild("Lane")
			if laneCenter then
				brainrot.TargetPosition = laneCenter.Position
			end
		elseif nearestBrain then
			-- Move towards brain
			local direction = (nearestBrain.Position - brainrotPosition).Unit
			local newPosition = brainrotPosition + direction * (brainrot.Speed * 0.5) * deltaTime
			
			brainrot.Model:PivotTo(CFrame.new(newPosition))
			
			-- Consume brain if close enough
			if (nearestBrain.Position - newPosition).Magnitude < 2 then
				nearestBrain:Destroy()
			end
		end
		
	elseif brainrot.State == "Fleeing" then
		if brainrot.TargetPosition then
			-- Move towards target
			local direction = (brainrot.TargetPosition - brainrotPosition).Unit
			local newPosition = brainrotPosition + direction * brainrot.Speed * deltaTime
			
			brainrot.Model:PivotTo(CFrame.new(newPosition))
			
			-- Check if reached lane
			if (newPosition - brainrot.TargetPosition).Magnitude < 5 then
				-- Now flee to end
				local endPoint = session.Map:FindFirstChild("EscapeEnd")
				if endPoint then
					brainrot.TargetPosition = endPoint.Position
				end
			end
			
			-- Check if escaped
			local escapeEnd = session.Map:FindFirstChild("EscapeEnd")
			if escapeEnd and (newPosition - escapeEnd.Position).Magnitude < 10 then
				-- Escaped!
				brainrot.Model:Destroy()
				brainrot.State = "Dead"
			end
		end
	end
end

function CatchingManager._checkSessionEnd(session: SessionData): boolean
	-- Check if all brainrots are gone
	for _, brainrot in ipairs(session.Brainrots) do
		if brainrot.State ~= "Dead" then
			return false
		end
	end
	
	return true
end

function CatchingManager._endSession(session: SessionData)
	session.Active = false
	
	-- Stop update loop
	if session.UpdateConnection then
		session.UpdateConnection:Disconnect()
	end
	
	-- Add caught brainrots to cage
	if #session.CaughtBrainrots > 0 then
		TycoonManager.addBrainrotsToCage(session.Player, session.CaughtBrainrots)
	end
	
	-- Update mission progress
	local totalCaught = 0
	for _, count in pairs(session.CaughtBrainrots) do
		totalCaught += count
	end
	
	if totalCaught > 0 then
		local MissionManager = require(ServerScriptService.Core.Player.MissionManager)
		MissionManager.updateProgress(session.Player, {
			BrainrotsCaught = totalCaught
		})
	end
	
	-- Clean up map
	CacheSystem.AddToCache(session.Map)
	session.Map.Parent = nil
	
	-- Teleport player back to base
	local base = TycoonManager.getBase(session.Player)
	if base and base.SpawnPoint then
		local character = session.Player.Character
		if character then
			character:PivotTo(base.SpawnPoint.CFrame)
		end
	end
	
	-- Remove session
	ActiveSessions[session.Player] = nil
	
	-- Notify client
	CatchingSessionUpdate:FireClient(session.Player, {
		Type = "End",
		CaughtBrainrots = session.CaughtBrainrots,
		TotalCaught = totalCaught,
	})
end

--// Main APIs //--

function CatchingManager.startSession(player: Player): boolean
	-- Check if already in session
	if ActiveSessions[player] then
		return false
	end
	
	-- Get unlocked tanks to determine available brainrots
	local base = TycoonManager.getBase(player)
	if not base then return false end
	
	local availableBrainrots = {}
	for tankName, tankData in pairs(base.Tanks) do
		if tankData.Unlocked and tankData.Brainrot then
			table.insert(availableBrainrots, tankData.Brainrot)
		end
	end
	
	if #availableBrainrots == 0 then
		warn("No brainrots available for catching")
		return false
	end
	
	-- Create map
	local map = CatchingManager._createMap()
	
	-- Create session
	local session = {
		Player = player,
		Map = map,
		Brainrots = {},
		CaughtBrainrots = {},
		StartTime = tick(),
		Active = true,
		UpdateConnection = nil,
	}
	
	-- Spawn brainrots
	for i = 1, 10 do -- Spawn 10 brainrots
		local brainrotName = availableBrainrots[math.random(1, #availableBrainrots)]
		local brainrot = CatchingManager._spawnBrainrot(map, brainrotName)
		if brainrot then
			table.insert(session.Brainrots, brainrot)
		end
	end
	
	-- Teleport player to map
	local character = player.Character
	if character then
		local startPoint = map:FindFirstChild("PlayerStart")
		if startPoint then
			character:PivotTo(startPoint.CFrame)
		end
	end
	
	-- Start update loop
	local lastUpdate = tick()
	session.UpdateConnection = RunService.Heartbeat:Connect(function()
		local now = tick()
		local deltaTime = now - lastUpdate
		lastUpdate = now
		
		-- Update all brainrots
		for _, brainrot in ipairs(session.Brainrots) do
			CatchingManager._updateBrainrot(session, brainrot, deltaTime)
		end
		
		-- Check if session should end
		if CatchingManager._checkSessionEnd(session) then
			CatchingManager._endSession(session)
		end
	end)
	
	ActiveSessions[player] = session
	
	-- Notify client
	CatchingSessionUpdate:FireClient(player, {
		Type = "Start",
		BrainrotCount = #session.Brainrots,
	})
	
	return true
end

function CatchingManager.endSessionManually(player: Player)
	local session = ActiveSessions[player]
	if not session then return end
	
	CatchingManager._endSession(session)
end

function CatchingManager.damageBrainrot(player: Player, brainrotModel: Model, damage: number)
	local session = ActiveSessions[player]
	if not session then return end
	
	-- Find brainrot
	for _, brainrot in ipairs(session.Brainrots) do
		if brainrot.Model == brainrotModel and brainrot.State ~= "Dead" then
			brainrot.Health -= damage
			
			if brainrot.Health <= 0 then
				-- Caught!
				brainrot.State = "Dead"
				brainrot.Model:Destroy()
				
				-- Add to caught list
				session.CaughtBrainrots[brainrot.Name] = (session.CaughtBrainrots[brainrot.Name] or 0) + 1
				
				-- Notify client
				CatchingSessionUpdate:FireClient(player, {
					Type = "Caught",
					BrainrotName = brainrot.Name,
					TotalCaught = session.CaughtBrainrots[brainrot.Name],
				})
			end
			
			break
		end
	end
end

function CatchingManager.isInSession(player: Player): boolean
	return ActiveSessions[player] ~= nil
end

function CatchingManager.getSession(player: Player): SessionData?
	return ActiveSessions[player]
end

--// Cleanup //--

Players.PlayerRemoving:Connect(function(player)
	if ActiveSessions[player] then
		CatchingManager._endSession(ActiveSessions[player])
	end
end)

return CatchingManager