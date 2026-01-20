------------------//SERVICES
local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//VARIABLES
local Core = ServerScriptService.Core
local PlayerManager = require(Core.Player.PlayerManager)

local Shared = ReplicatedStorage.Shared
local Configs = Shared.Configs
local Utilities = Shared.Utilities

local TankConfig = require(Configs.TankConfig)
local BrainrotConfig = require(Configs.BrainrotConfig)
local GeneralConfig = require(Configs.GeneralConfig)
local BigNum = require(Utilities.BigNum)

local TycoonTypes = require(ServerScriptService.Types.TycoonTypes)

local Production = {}
Production.__index = Production

export type Production = typeof(Production.new())

------------------//FUNCTIONS
local function sync_uses_attributes(tankData: TycoonTypes.TankData): ()
	local cell = tankData.Cell
	if not cell then
		return
	end

	local usesRemaining = tankData.UsesRemaining or 0
	local usesMax = tankData.UsesMax or 0

	cell:SetAttribute("UsesRemaining", usesRemaining)
	cell:SetAttribute("UsesMax", usesMax)
end

local function ensure_uses_max(tankData: TycoonTypes.TankData, upgradeInfo): ()
	if upgradeInfo.Uses == -1 then
		tankData.UsesMax = 1
		if (tankData.UsesRemaining or 0) <= 0 then
			tankData.UsesRemaining = 1
		end
		return
	end

	if upgradeInfo.Uses > 0 then
		if (tankData.UsesMax or 0) <= 0 then
			tankData.UsesMax = upgradeInfo.Uses
		end
	end
end

------------------//MAIN FUNCTIONS
function Production.new(BaseObject: TycoonTypes.BaseObject)
	local self = setmetatable({}, Production)
	self.Base = BaseObject
	self.Storage = {} :: {TycoonTypes.ProductionItemData}
	return self
end

function Production._getProductionDetails(self: Production, tankData: TycoonTypes.TankData)
	local brainrotInfo = tankData.Brainrot and BrainrotConfig.getInfo(tankData.Brainrot)
	if not brainrotInfo then
		warn(`[Base {self.Base.ID}][Production] Couldn't get brainrot info for tank`)
		return false
	end

	local upgradeInfo = TankConfig.getUpgradeInfo(tankData.Level)
	if not upgradeInfo then
		warn(`[Base {self.Base.ID}][Production] Couldn't get upgrade info for tank`)
		return false
	end

	return true, brainrotInfo, upgradeInfo
end

function Production._produceItem(self: Production, tankData: TycoonTypes.TankData): ()
	if (tankData.BrainrotCount or 0) < (tankData.Config.Required or 1) then
		self:_stopProduction(tankData)
		return
	end
	
	if not self.Base or not self.Base.Owned then
		return
	end

	local ok, brainrotInfo, upgradeInfo = self:_getProductionDetails(tankData)
	if not ok then
		return
	end

	local baseValue = BigNum.new(brainrotInfo.Value)
	local multiplier = BigNum.new(upgradeInfo.Multiplier or 1)
	local playerObj = self.Base.Owner and PlayerManager.getPlayerObject(self.Base.Owner) or nil
	local productionMult = playerObj and playerObj:getStat("ProductionValue") or 1
	local itemValue = baseValue * multiplier * BigNum.new(productionMult)

	local travelTime = tankData.ItemTravelTime or 0

	local itemData: TycoonTypes.ProductionItemData = {
		Name = (tankData.Brainrot or "Unknown") .. "_Item",
		Value = itemValue:toString(),
		SpawnTime = tick(),
		ArrivalTime = tick() + travelTime,
	}

	if tankData.Dropper then
		local currentSwitch = tankData.Dropper:GetAttribute("Switch")
		tankData.Dropper:SetAttribute("Switch", not currentSwitch)
	end
	
	if tankData.Cell then
		tankData.Cell:SetAttribute("CycleStart", tick())
		tankData.Cell:SetAttribute("CycleDuration", upgradeInfo.Cooldown or 1)
		tankData.Cell:SetAttribute("CycleRunning", true)
		tankData.Cell:SetAttribute("UsesInfinite", upgradeInfo.Uses == -1)
	end

	task.delay(travelTime, function()
		if not self.Base or not self.Base.Owned then
			return
		end
		table.insert(self.Storage, itemData)
	end)

	ensure_uses_max(tankData, upgradeInfo)

	if upgradeInfo.Uses > 0 then
		tankData.UsesRemaining = math.max(0, (tankData.UsesRemaining or 0) - 1)
		sync_uses_attributes(tankData)
	end

	if upgradeInfo.Uses == -1 or (tankData.UsesRemaining or 0) > 0 then
		task.delay(upgradeInfo.Cooldown or 1, function()
			if not self.Base or not self.Base.Owned then
				return
			end
			self:_produceItem(tankData)
		end)
	else
		self:_stopProduction(tankData)
	end
end

function Production.startProduction(self: Production, tankData: TycoonTypes.TankData): ()
	if (tankData.BrainrotCount or 0) < (tankData.Config.Required or 1) then
		return
	end

	local upgradeInfo = TankConfig.getUpgradeInfo(tankData.Level)
	if not upgradeInfo then
		return
	end

	ensure_uses_max(tankData, upgradeInfo)

	if upgradeInfo.Uses > 0 and (tankData.UsesRemaining or 0) <= 0 then
		tankData.UsesRemaining = upgradeInfo.Uses
		if (tankData.UsesMax or 0) <= 0 then
			tankData.UsesMax = upgradeInfo.Uses
		end
		
		sync_uses_attributes(tankData)
	elseif upgradeInfo.Uses == -1 then
		sync_uses_attributes(tankData)
	end
	
	self:_produceItem(tankData)
end

function Production._stopProduction(self: Production, tankData: TycoonTypes.TankData): ()
	tankData.BrainrotCount = 0
	tankData.UsesRemaining = 0

	if tankData.Cell then
		tankData.Cell:SetAttribute("Count", 0)
		
		tankData.Cell:SetAttribute("CycleRunning", false)
		tankData.Cell:SetAttribute("CycleStart", 0)
		tankData.Cell:SetAttribute("CycleDuration", 0)
		tankData.Cell:SetAttribute("UsesInfinite", false)
	end

	sync_uses_attributes(tankData)
end

function Production.getStorage(self: Production): {TycoonTypes.ProductionItemData}
	return self.Storage
end

function Production.removeItemFromStorage(self: Production, index: number): TycoonTypes.ProductionItemData?
	return table.remove(self.Storage, index)
end

function Production.cleanup(self: Production): ()
	table.clear(self.Storage)
end

------------------//INIT
return Production
