--// Services //--
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

--// Dependencies //--
local Shared = ReplicatedStorage.Shared
local Utilities = Shared.Utilities
local BigNum = require(Utilities.BigNum)
local ToolManager = require(ServerScriptService.Core.Player.ToolManager)

local GetPlayerObject = ServerScriptService.Bindables.GetPlayerObject

--// Setup //--
local PlayerManager = {}
PlayerManager.__index = PlayerManager

export type PlayerManager = {} & typeof(PlayerManager)
export type PlayerObject = typeof(PlayerManager.new()) & PlayerManager

export type StatMultiplierTable = {
	[string]: {
		[string]: number
	}
}

--// Internal Storage //--
local PlayerObjects = {} :: {[Player]: PlayerObject}

--// Humanoid Stat Mapping //--
local HumanoidStats = {
	WalkSpeed = "WalkSpeed",
	JumpHeight = "JumpHeight",
}

--// Constructor //--
function PlayerManager.new(player: Player)
	local self = setmetatable({}, PlayerManager)
	
	self.Player = player
	self.Data = player.Data :: Folder

	self.BaseStats = {
		WalkSpeed = 20,
		JumpHeight = 7.2,
		ProductionSpeed = 1,
		ProductionValue = 1,
		CashMultiplier = 1,
	}
	self.MainSpawn = nil :: Part
	self.Spawn = nil :: Part
	self.Multipliers = {} :: StatMultiplierTable

	self.EquippedTool = nil :: string?
	
	self.ToolManager = ToolManager.new(player)

	self.setupRespawnHandler(self.Player)
	
	return self
end

--// Private Methods //--

function PlayerManager._computeStat(self: PlayerObject, statName: string)
	local base = self.BaseStats[statName]
	if base == nil then
		return 1
	end

	local total = 1
	local list = self.Multipliers[statName]

	if list then
		for _, multiplier in list do
			total *= multiplier
		end
	end

	return base * total
end

function PlayerManager._applyToHumanoid(self: PlayerObject, statName: string)
	local property = HumanoidStats[statName]
	if not property then
		return
	end

	local character = self.Player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid[property] = self:_computeStat(statName)
	end
end

function PlayerManager._refreshStat(self: PlayerObject, statName: string)
	self:_applyToHumanoid(statName)
end

--// Spawn Management //--

function PlayerManager.setPlayerSpawn(player:Player, spawnPoint:Part, isMainSpawn:boolean)
	local playerObject = PlayerObjects[player]
	if not playerObject then
		warn("[PLAYER MANAGER] No PlayerObject when setting spawn: ",player)
		return
	end
	if isMainSpawn then 
		playerObject.MainSpawn = spawnPoint
	end
	
	playerObject.Spawn = spawnPoint or playerObject.Spawn
end

function PlayerManager.resetPlayerSpawn(player:Player)
	local playerObject = PlayerObjects[player]
	if not playerObject or not playerObject.MainSpawn then
		warn("[PLAYER MANAGER] No PlayerObject/MainSpawn when resetting spawn")
		return
	end

	playerObject.Spawn = playerObject.MainSpawn
end

function PlayerManager.teleportPlayerToSpawn(player: Player)
	local self = PlayerManager.getPlayerObject(player)
	if not self.Spawn then
		self.Spawn = workspace.SpawnLocation
		warn(`[PLAYER MANAGER] No spawn point for {player.Name}`)
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)

	if humanoidRootPart then
		task.wait(0.1)
		character:PivotTo(self.Spawn.CFrame)
		--print(`[PLAYER MANAGER] Spawned {player.Name} at their base`)
	end
end

function PlayerManager.setupRespawnHandler(player: Player)
	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		PlayerManager.teleportPlayerToSpawn(player)
	end)
end

--// Stat Management //--

function PlayerManager.setStatMultiplier(self: PlayerObject, statName: string, source: string, value: number)
	if not self.BaseStats[statName] then
		warn(`[PLAYER MANAGER] Invalid stat: {statName}`)
		return
	end

	self.Multipliers[statName] = self.Multipliers[statName] or {}
	self.Multipliers[statName][source] = value

	self:_refreshStat(statName)
end

function PlayerManager.removeStatMultiplier(self: PlayerObject, statName: string, source: string)
	local list = self.Multipliers[statName]
	if not list then
		return
	end

	list[source] = nil
	self:_refreshStat(statName)
end

function PlayerManager.getStat(self: PlayerObject, statName: string)
	return self:_computeStat(statName)
end

--// Tool State Management //--

function PlayerManager.setEquippedTool(self: PlayerObject, toolName: string?)
	self.EquippedTool = toolName
end

function PlayerManager.getEquippedTool(self: PlayerObject): string?
	return self.EquippedTool
end

function PlayerManager.giveTools(self: PlayerObject)
	self.ToolManager:giveTools()
end

--// Character Setup //--

function PlayerManager.setupCharacter(self: PlayerObject)
	for statName in pairs(HumanoidStats) do
		self:_refreshStat(statName)
	end
end

--// Tutorial //--

function PlayerManager.setTutorialStage(self: PlayerObject, stage: number)
	self.Data.TutorialStage.Value = stage
end

--// API //--

function PlayerManager.getPlayerObject(player: Player)
	return PlayerObjects[player]
end

function PlayerManager.createPlayerObject(player: Player)
	local object = PlayerManager.new(player)
	PlayerObjects[player] = object

	if player.Character then
		object:setupCharacter()
	end

	player.CharacterAdded:Connect(function()
		object:setupCharacter()
	end)

	return object
end

function PlayerManager.removePlayerObject(player: Player)
	PlayerObjects[player] = nil
end

--// Serialization //--

function PlayerManager.serializePlayerData(player: Player)
	local obj = PlayerObjects[player]
	if not obj then
		return {}
	end

	return {
		BaseStats = obj.BaseStats,
		Multipliers = obj.Multipliers,
		Tools = obj.ToolManager:serialize(),
	}
end

function PlayerManager.deserializePlayerData(player: Player, data)
	local obj = PlayerObjects[player]
	if not obj then
		return
	end

	if data.BaseStats then
		obj.BaseStats = data.BaseStats
	end

	if data.Multipliers then
		obj.Multipliers = data.Multipliers
		for stat in obj.BaseStats do
			obj:_refreshStat(stat)
		end
	end

	if data.Tools then
		obj.ToolManager:deserialize(data.Tools)
	end
end

GetPlayerObject.OnInvoke = function(player: Player)
	return PlayerManager.getPlayerObject(player)
end

return PlayerManager :: PlayerManager