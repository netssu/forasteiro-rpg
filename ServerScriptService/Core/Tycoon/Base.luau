	--// Services //--
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Dependencies //--
local Shared = ReplicatedStorage.Shared
local Utilities = Shared.Utilities
local Cache = require(Utilities.Cache)

local Core = ServerScriptService.Core
local PlayerManager

local Components = script.Parent.Components
local Tank = require(Components.Tank)
local Production = require(Components.Production)
local Customer = require(Components.Customer)
local Cage = require(Components.Cage)

local Assets = ReplicatedStorage.Assets

--// Setup //--
local Base = {}
Base.__index = Base

export type Base = typeof(Base.new())

function Base.new(baseFolder: Folder, ID: number)
	local self = setmetatable({}, Base)

	self.ID = ID :: number
	self.Folder = baseFolder
	self.Owned = false :: boolean
	self.Owner = nil :: Player
	self.Building = nil :: Model
	self.Foundation = baseFolder:WaitForChild("Foundation",5) :: Part

	-- Conveyor checkpoints (from Building.Checkpoints)
	self.ConveyorCheckpoints = {} :: {[number]: Attachment}

	-- Components
	self.Tank = Tank.new(self) :: Tank.Tank
	self.Production = nil :: Production.Production
	self.Customer = nil :: Customer.Customer
	self.Cage = Cage.new(self) :: Cage.Cage

	self.Connections = {} :: {RBXScriptConnection}

	return self
end

function Base.claim(self: Base, player: Player)
	if self.Owned then
		warn(`[Base {self.ID}] Tried to claim owned base`)
		return
	end

	-- Ownership
	self.Owned = true
	self.Owner = player
	self.Folder:SetAttribute("Owner", player.Name)

	-- Spawn building
	self:_spawnBuilding()

	-- Components (post building spawn)
	self.Cage:onSpawnBuilding()
	self.Tank:setupInstances(self.Building)
	self.Production = Production.new(self)
	self.Customer = Customer.new(self)
	self.Customer:onSpawnBuilding()
	self.Customer:startSpawnThread()

	--print(`[Base {self.ID}] Claimed by {player.Name}`)
end

function Base.unclaim(self: Base)
	if self.Customer then
		self.Customer:cleanup()
	end
	if self.Production then
		self.Production:cleanup()
	end
	if self.Tank then
		self.Tank:cleanup()
	end
	if self.Cage then
		self.Cage:cleanup()
	end

	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)

	-- Recycle building
	if self.Building then
		Cache.AddToCache(self.Building)
		self.Building = nil
	end

	self.Owned = false
	self.Owner = nil
	self.Folder:SetAttribute("Owner", nil)

	--print(`[Base {self.ID}] Unclaimed`)
end

function Base._spawnBuilding(self: Base)
	-- Spawn
	if self.Building then
		self.Building:Destroy()
		self.Building = nil
	end

	local baseBuilding = Cache.RetrieveFromCache("BaseBuilding")
		or Assets.Models.BaseBuilding:Clone()

	self.Building = baseBuilding
	self.Building.Parent = self.Folder

	local endCF = self.Foundation.CFrame * CFrame.new(0, self.Building.PrimaryPart.Size.Y, 0)
	self.Building:PivotTo(endCF)

	-- Setup conveyor checkpoints from Building.Checkpoints
	local checkpointsFolder = self.Building:WaitForChild("Checkpoints")
	if checkpointsFolder then
		for _, child in checkpointsFolder:GetChildren() do
			local number = tonumber(string.match(child.Name,"%d+"))
			if typeof(number) == "number" then
				self.ConveyorCheckpoints[number] = child :: Attachment
			end
		end
	end

	-- Setup spawn
	local spawnPoint = self.Building:WaitForChild("SpawnPoint")
	if not PlayerManager then
		PlayerManager = require(Core.Player.PlayerManager)
	end
	
	PlayerManager.setPlayerSpawn(self.Owner, spawnPoint, true)
	PlayerManager.teleportPlayerToSpawn(self.Owner)

	self.Building:AddTag("BaseBuilding")

	--print(`[Base {self.ID}] Building spawned`)
end

function Base.serializeData(self: Base): {}
	return {
		Tanks = self.Tank and self.Tank:serializeData() or {},
		Cage = self.Cage and self.Cage:serializeData() or {},
	}
end

function Base.deserializeData(self: Base, data: {})
	if not data then return end
	if not self.Building then
		warn(`[Base {self.ID}] Cannot deserialize before building spawned`)
		return
	end

	if data.Tanks then
		self.Tank:deserializeData(data.Tanks)
	end

	if data.Cage then
		self.Cage:deserializeData(data.Cage)
	end

	-- Start production where applicable
	for _, tankData in self.Tank.Tanks do
		if tankData.Unlocked
			and tankData.BrainrotCount >= tankData.Config.Required
			and (tankData.UsesRemaining > 0 or tankData.UsesRemaining == -1)
		then
			self.Production:startProduction(tankData)
		end
	end
end

return Base