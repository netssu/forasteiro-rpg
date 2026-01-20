--// Services //--
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Dependencies //--
local Core = ServerScriptService.Core
local PlayerManager = require(Core.Player.PlayerManager)

local Shared = ReplicatedStorage.Shared
local Configs = Shared.Configs
local Utilities = Shared.Utilities

local Cache = require(Utilities.Cache)
local TankConfig = require(Configs.TankConfig)
local GeneralConfig = require(Configs.GeneralConfig)
local BrainrotConfig = require(Configs.BrainrotConfig)

local TycoonTypes = require(ServerScriptService.Types.TycoonTypes)

--// Setup //--
local Cage = {}
Cage.__index = Cage

export type Cage = typeof(Cage.new())

function Cage.new(baseObject: TycoonTypes.BaseObject)
	local self = setmetatable({}, Cage)

	self.Base = baseObject
	self.Values = nil :: (Folder & {StringValue})?
	self.Contents = {} :: {[string]: number}

	return self
end

function Cage.onSpawnBuilding(self: Cage)
	if not self.Base.Building then
		warn(`[Base {self.Base.ID}][Cage] No building`)
		return
	end
	self.Values = self.Base.Building:WaitForChild("CageValues") :: (Folder & {StringValue})?
	if not self.Values then
		warn(`[Base {self.Base.ID}][Cage] No CageValues folder`)
		return
	end
end

--// APIs //--
function Cage._getCapacity(self: Cage): number
	-- Supports future player-specific capacity buffs
	local playerObj = self.Base.Owner and PlayerManager.getPlayerObject(self.Base.Owner) or nil
	local bonus = playerObj and playerObj:getStat("CageCapacityBonus") or 0
	return (GeneralConfig.CAGE_CAPACITY or 0) + bonus
end

function Cage._getCurrentCount(self: Cage): number
	local total = 0
	for _, count in self.Contents do
		total += count
	end
	return total
end

function Cage.addBrainrots(self: Cage, brainrots: {[string]: number}): number
	if not self.Values then
		warn(`[Base {self.Base.ID}][Cage] Values folder not ready`)
		return 0
	end
	
	if typeof(brainrots) == "string" then 
		brainrots = {[brainrots] = 1} 
	end

	local capacity = self:_getCapacity()
	local current = self:_getCurrentCount()
	local available = math.max(0, capacity - current)
	if available <= 0 then
		return 0
	end

	local totalAdded = 0
	for name, requested in brainrots do
		if requested > 0 and BrainrotConfig.getInfo(name) then
			local toAdd = math.min(requested, available)
			if toAdd > 0 then
				if TankConfig.isPremiumBrainrot(name) then
					local tankName = TankConfig.getBrainrotTank(name)
					
					local _, success = self.Base.Tank:addBrainrotToTank(tankName, toAdd)
					if success then continue end
				end
				
				-- Update data
				self.Contents[name] = (self.Contents[name] or 0) + toAdd

				-- Create one StringValue per unit
				for i = 1, toAdd do
					if available <= 0 then break end
					totalAdded += 1
					available -= 1
					local value = Cache.RetrieveFromCache("StringValue") or Instance.new("StringValue")
					value.Name = name
					value.Parent = self.Values
				end
			end
		end
	end

	if totalAdded > 0 then
		print(`[Base {self.Base.ID}][Cage] Added total ${totalAdded}`)
	else
		print(`[Base {self.Base.ID}][Cage] No brainrots added`)
	end

	return totalAdded
end

function Cage.removeBrainrots(self: Cage, brainrots: {[string]: number}): number
	if not self.Values then
		warn(`[Base {self.Base.ID}][Cage] Values folder not ready`)
		return 0
	end

	local totalRemoved = 0

	for name, requested in brainrots do
		local current = self.Contents[name] or 0
		local toRemove = math.min(current, math.max(0, requested))

		if toRemove > 0 then
			-- Update data
			self.Contents[name] = current - toRemove
			if self.Contents[name] <= 0 then
				self.Contents[name] = nil
			end

			-- Recycle one StringValue per unit
			local removed = 0
			for _, child in self.Values:GetChildren() do
				if child:IsA("StringValue") and child.Name == name then
					child.Name = "StringValue"
					Cache.AddToCache(child)
					removed += 1
					if removed >= toRemove then print("break") break end
				end
			end
			
			print(removed)

			totalRemoved += removed
		end
	end

	if totalRemoved > 0 then
		print("removed nothing")
		--print(`[Base {self.Base.ID}][Cage] Removed total ${totalRemoved}`)
	end

	return totalRemoved
end

function Cage.getContents(self: Cage): {[string]: number}
	return table.clone(self.Contents)
end

function Cage.serializeData(self: Cage): {}
	return table.clone(self.Contents)
end

function Cage.deserializeData(self: Cage, data: {})
	if not self.Values then
		warn(`[Base {self.Base.ID}][Cage] Values folder not ready for deserialize`)
		return
	end
	if not data then return end

	-- Clear current values
	for _, child in ipairs(self.Values:GetChildren()) do
		if child:IsA("StringValue") then
			child.Name = "StringValue"
			Cache.AddToCache(child)
		end
	end
	table.clear(self.Contents)

	-- Restore data and visuals
	local total = 0
	for name, count in data do
		if typeof(name) == "string" and typeof(count) == "number" and count > 0 then
			self.Contents[name] = count
			for i = 1, count do
				if total >= GeneralConfig.CAGE_CAPACITY then
					self.Contents[name] = i
					break
				end
				total += 1
				local sv = Cache.RetrieveFromCache("StringValue") or Instance.new("StringValue")
				sv.Name = name
				sv.Parent = self.Values
			end
		end
	end
end

--// Cleanup //--
function Cage.cleanup(self: Cage)
	if self.Values then
		for _, child in ipairs(self.Values:GetChildren()) do
			if child:IsA("StringValue") then
				child.Name = "StringValue"
				Cache.AddToCache(child)
			end
		end
	end
	table.clear(self.Contents)
	self.Values = nil
end

return Cage