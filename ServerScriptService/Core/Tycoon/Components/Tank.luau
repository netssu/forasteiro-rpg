--// Services //--
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

--// Dependencies //--
local Shared = ReplicatedStorage.Shared
local Configs = Shared.Configs
local TankConfig = require(Configs.TankConfig)
local BrainrotConfig = require(Configs.BrainrotConfig)
local GeneralConfig = require(Configs.GeneralConfig)

local CurrencyManager = require(ServerScriptService.Core.Player.CurrencyManager)
local TycoonTypes = require(ServerScriptService.Types.TycoonTypes)

local DEV_UNLOCK_ALL_TANKS: boolean = false

--// Helper //--
local function FormatNumber(n: number): string
	if n >= 1e9 then return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then return string.format("%.1fk", n / 1e3)
	else return tostring(n) end
end

--// Setup //--
local Tank = {}
Tank.__index = Tank

export type Tank = typeof(Tank.new())

function Tank.new(BaseObject: TycoonTypes.BaseObject)
	local self = setmetatable({}, Tank)

	self.Base = BaseObject
	self.Tanks = {} :: {[string]: TycoonTypes.TankData}
	self.Connections = {} :: {RBXScriptConnection}

	Tank._initializeTanks(self)

	return self
end

function Tank._initializeTanks(self: Tank)
	for tankName, tankConfig in TankConfig.getAllTanks() do
		self.Tanks[tankName] = {
			Name = tankName,
			Unlocked = false,
			Level = tankConfig.StartingLevel,
			Brainrot = tankConfig.Brainrot or nil,
			BrainrotCount = 0,
			UsesRemaining = 0,
			Model = nil,
			Dropper = nil,
			Button = nil,
			Cell = nil,
			UsesMax = 0,
			Config = tankConfig,
			ItemTravelTime = 0,
			Debounce = false,
			Prompt = nil,
		}
	end

	if not DEV_UNLOCK_ALL_TANKS then
		if self.Tanks["Tank_1"] then
			self.Tanks["Tank_1"].Unlocked = true
		end
	else
		for _, data in pairs(self.Tanks) do
			data.Unlocked = true
		end
	end
end

--// APIs //-- (Post-claim)
function Tank.setupInstances(self: Tank, building: Model)
	local tanksFolder = building:WaitForChild("Tanks")
	if not tanksFolder then
		warn(`[Base {self.Base.ID}] Tanks folder not found`)
		return
	end

	for tankName, tankData in self.Tanks do
		local tankModel = tanksFolder:FindFirstChild(tankName)
		if tankModel and tankModel:IsA("Model") then
			-- Tank
			tankData.Model = tankModel
			tankData.Dropper = tankModel:WaitForChild("Dropper") :: Part
			tankData.Cell = tankModel:WaitForChild("Cell") :: Part

			-- Button
			-- CORREÇÃO: Permite criar botão mesmo se for Premium, desde que o modelo tenha o botão.
			tankData.Button = tankModel:FindFirstChild("Button") :: Part
			if tankData.Button then
				local prox = Instance.new("ProximityPrompt", tankData.Button)
				tankData.Prompt = prox 

				self:updatePrompt(tankName)

				local conn = prox.Triggered:Connect(function(plr: Player)
					self:_onButtonPressed(plr, tankName)
				end)
				table.insert(self.Connections, conn)
			end

			-- Dropper
			tankData.Dropper:SetAttribute("Tank", tankName)
			tankData.Dropper:SetAttribute("Item", tankData.Brainrot or "")
			tankData.Dropper:SetAttribute("Switch", false)
			CollectionService:AddTag(tankData.Dropper, "Dropper")

			-- Cell
			tankData.Cell:SetAttribute("Brainrot", tankData.Brainrot or "")
			tankData.Cell:SetAttribute("Count", tankData.BrainrotCount)
			CollectionService:AddTag(tankData.Cell, "Cell")
			tankData.Cell:SetAttribute("UsesRemaining", tankData.UsesRemaining or 0)
			tankData.Cell:SetAttribute("UsesMax", tankData.UsesMax or 0)

			-- Travel time
			tankData.ItemTravelTime = self:_calculateItemTravelTime(tankData)
		end
	end
end

function Tank.updatePrompt(self: Tank, tankName: string)
	local tankData = self.Tanks[tankName]
	if not tankData or not tankData.Prompt then return end

	if not tankData.Unlocked then
		local price = tankData.Config.Price or 0
		tankData.Prompt.ObjectText = "Machine"
		if price > 0 then
			tankData.Prompt.ActionText = "Buy: $" .. FormatNumber(price)
		else
			tankData.Prompt.ActionText = "Claim (Free)"
		end
	else
		tankData.Prompt.ObjectText = tankData.Config.DisplayName or tankData.Name
		tankData.Prompt.ActionText = "Add Brainrot"
	end
end

function Tank.setUsesRemaining(self: Tank, tankName: string, usesRemaining: number): ()
	local tankData = self.Tanks[tankName]
	if not tankData then
		return
	end

	tankData.UsesRemaining = math.max(0, usesRemaining)

	if tankData.Cell then
		tankData.Cell:SetAttribute("UsesRemaining", tankData.UsesRemaining)
		tankData.Cell:SetAttribute("UsesMax", tankData.UsesMax or 0)
	end
end

function Tank._onButtonPressed(self: Tank, player: Player, tankName: string)
	local tankData = self.Tanks[tankName]
	if not tankData then return end
	if tankData.Debounce then return end

	tankData.Debounce = true
	task.delay(GeneralConfig.TANK_BUTTON_COOLDOWN or 0.5, function()
		tankData.Debounce = false
	end)

	if not player or player ~= self.Base.Owner then
		return
	end

	-- Purchasing flow:
	if not tankData.Unlocked then
		self:purchaseUnlock(tankName)
		return
	end

	self:purchaseAddBrainrot(tankName, math.huge)
end

-- Actions (no purchase)
function Tank.unlockTank(self: Tank, tankName: string): boolean
	local data = self.Tanks[tankName]
	if not data then return false end
	if data.Unlocked then return false end

	data.Unlocked = true
	self:updatePrompt(tankName)

	print(`[Base {self.Base.ID}] Unlocked {tankName}`)
	return true
end

function Tank.upgradeTank(self: Tank, tankName: string): boolean
	local tankData = self.Tanks[tankName]
	if not tankData then return false end

	if not tankData.Unlocked then
		warn(`[Base {self.Base.ID}] Cannot upgrade locked tank: {tankName}`)
		return false
	end

	if TankConfig.isMaxLevel(tankData.Level) then
		warn(`[Base {self.Base.ID}] Tank already at max level: {tankName}`)
		return false
	end

	tankData.Level += 1

	if tankData.BrainrotCount >= tankData.Config.Required then
		local upgradeInfo = TankConfig.getUpgradeInfo(tankData.Level)
		tankData.UsesRemaining = upgradeInfo and upgradeInfo.Uses or tankData.UsesRemaining
		tankData.UsesMax = tankData.UsesRemaining

		if tankData.Cell then
			tankData.Cell:SetAttribute("UsesRemaining", tankData.UsesRemaining or 0)
			tankData.Cell:SetAttribute("UsesMax", tankData.UsesMax or 0)
		end
	end

	print(`[Base {self.Base.ID}] Upgraded {tankName} to level {tankData.Level}`)
	return true
end

function Tank.addBrainrotToTank(self: Tank, tankName: string, amount: number): (number, boolean)
	local success = false

	local tankData = self.Tanks[tankName]
	if not tankData or amount <= 0 then return 0, success end
	if not tankData.Unlocked then return 0, success end

	local needed = math.max(0, (tankData.Config.Required or 0) - tankData.BrainrotCount)
	local toAdd = math.min(amount, needed)
	if toAdd <= 0 then return 0, success end

	tankData.BrainrotCount += toAdd
	if tankData.Cell then
		tankData.Cell:SetAttribute("Count", tankData.BrainrotCount)
	end

	if tankData.BrainrotCount >= tankData.Config.Required then
		if tankData.UsesRemaining == 0 then
			local info = TankConfig.getUpgradeInfo(tankData.Level)
			tankData.UsesRemaining = info and info.Uses or 0
			tankData.UsesMax = tankData.UsesRemaining
		end

		if tankData.Cell then
			tankData.Cell:SetAttribute("UsesRemaining", tankData.UsesRemaining or 0)
			tankData.Cell:SetAttribute("UsesMax", tankData.UsesMax or 0)
		end

		self.Base.Production:startProduction(tankData)
		success = true
	end

	return toAdd, success
end

function Tank.removeBrainrotOfTank(self: Tank, tankName: string)
	local tankData = self.Tanks[tankName]
	if not tankData then return end

	self.Base.Production:_stopProduction(tankData)
end

function Tank.transferBrainrotFromCage(self: Tank, tankName: string): number
	local tankData = self.Tanks[tankName]
	if not tankData then return 0 end
	if not tankData.Brainrot then return 0 end

	local needed = math.max(0, (tankData.Config.Required or 0) - tankData.BrainrotCount)
	if needed <= 0 then return 0 end

	local removed = self.Base.Cage:removeBrainrots({ [tankData.Brainrot] = needed })
	if removed <= 0 then return 0 end

	return self:addBrainrotToTank(tankName, removed)
end

function Tank.setPremiumTankBrainrot(self: Tank, tankName: string, brainrotName: string): boolean
	local tankData = self.Tanks[tankName]
	if not tankData then return false end

	local config = TankConfig.getTankInfo(tankName)
	if not config or not config.IsPremium then return false end

	if not BrainrotConfig.isPremium(brainrotName) then return false end

	tankData.Brainrot = brainrotName

	if tankData.Dropper then
		tankData.Dropper:SetAttribute("Item", brainrotName)
	end
	if tankData.Cell then
		tankData.Cell:SetAttribute("Brainrot", brainrotName)
	end

	return true
end

-- Purchases
function Tank.purchaseUnlock(self: Tank, tankName: string): boolean
	if DEV_UNLOCK_ALL_TANKS then
		return self:unlockTank(tankName)
	end

	local price = TankConfig.getTankInfo(tankName).Price

	if not price then
		warn(`[Base {self.Base.ID}] No unlock price for ${tankName}`)
		return false
	end

	local result = CurrencyManager.purchase(self.Base.Owner, price)
	if not result or not result.success then
		return false
	end

	local unlocked = self:unlockTank(tankName)
	if unlocked then
		self:updatePrompt(tankName)
	end

	return unlocked
end

function Tank.purchaseUpgrade(self: Tank, tankName: string): boolean
	local tankData = self.Tanks[tankName]
	if not tankData then return false end
	if not tankData.Unlocked then return false end
	if TankConfig.isMaxLevel(tankData.Level) then return false end

	local nextLevel = tankData.Level + 1
	local price = nil
	local info = TankConfig.getUpgradeInfo and TankConfig.getUpgradeInfo(nextLevel)

	if info and info.Price then
		price = info.Price
	elseif TankConfig.calculateUpgradePrice then
		price = TankConfig.calculateUpgradePrice(tankName, nextLevel)
	end

	if not price then return false end

	local result = CurrencyManager.purchase(self.Base.Owner, price)
	if not result or not result.success then return false end

	return self:upgradeTank(tankName)
end


function Tank.purchaseAddBrainrot(self: Tank, tankName: string, amount: number): number
	return self:transferBrainrotFromCage(tankName)
end

-- Accessors
function Tank.getTankData(self: Tank, tankName: string)
	return self.Tanks[tankName]
end

function Tank.isUnlocked(self: Tank, tankName: string)
	local data = self.Tanks[tankName]
	return data and data.Unlocked or false
end

function Tank.getLevel(self: Tank, tankName: string)
	local data = self.Tanks[tankName]
	return data and data.Level
end

-- Helper
function Tank._calculateItemTravelTime(self: Tank, tankData: TycoonTypes.TankData): number
	local checkpoints = tankData.Config.Checkpoints
	if not checkpoints or not self.Base or not self.Base.ConveyorCheckpoints then
		return 0
	end

	local checkpoint0 = tankData.Dropper:FindFirstChild("Checkpoint0")
	if not checkpoint0 or not tankData.Dropper then
		return 0
	end

	local totalTravelTime = 0

	local dropperPos = tankData.Dropper.Position
	local distanceToCheckpoint0 = (checkpoint0.WorldPosition - dropperPos).Magnitude
	totalTravelTime += distanceToCheckpoint0 / (GeneralConfig.ConveyorSpeed and GeneralConfig.ConveyorSpeed.Falling or 1)

	local previousCheckpoint: Attachment = checkpoint0

	for _, checkpointInfo in checkpoints do
		local targetAttachment = self.Base.ConveyorCheckpoints[checkpointInfo.Number]
		if not targetAttachment then continue end

		local distance = (targetAttachment.WorldPosition - previousCheckpoint.WorldPosition).Magnitude
		local speed = GeneralConfig.ConveyorSpeed[checkpointInfo.Movement] or 1
		totalTravelTime += distance / speed

		previousCheckpoint = targetAttachment
	end

	return totalTravelTime
end

-- Data
function Tank.serializeData(self: Tank)
	local data = {}
	for name, tankData in self.Tanks do
		data[name] = {
			Unlocked = tankData.Unlocked,
			Level = tankData.Level,
			Brainrot = tankData.Brainrot,
			BrainrotCount = tankData.BrainrotCount,
			UsesRemaining = tankData.UsesRemaining,
			UsesMax = tankData.UsesMax,
		}
	end
	return data
end

function Tank.deserializeData(self: Tank, saved)
	if not saved then return end

	for name, data in saved do
		local tankData = self.Tanks[name]
		if tankData then
			tankData.Unlocked = data.Unlocked
			tankData.Level = data.Level
			tankData.Brainrot = data.Brainrot
			tankData.BrainrotCount = data.BrainrotCount
			tankData.UsesRemaining = data.UsesRemaining
			tankData.UsesMax = data.UsesMax or tankData.UsesRemaining

			self:updatePrompt(name)

			if tankData.Dropper then
				tankData.Dropper:SetAttribute("Item", tankData.Brainrot or "")
				tankData.Dropper:SetAttribute("Base", self.Base.Folder.Name)
			end
			if tankData.Cell then
				tankData.Cell:SetAttribute("Brainrot", tankData.Brainrot or "")
				tankData.Cell:SetAttribute("Count", tankData.BrainrotCount)
				tankData.Cell:SetAttribute("UsesRemaining", tankData.UsesRemaining or 0)
				tankData.Cell:SetAttribute("UsesMax", tankData.UsesMax or 0)
			end
		end
	end
end

function Tank.cleanup(self: Tank)
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

------------------//GET TO HUD
function Tank._getBrainrotMeta(self: Tank, brainrotName: string?)
	if not brainrotName or brainrotName == "" then
		return nil
	end

	local getInfo = BrainrotConfig.getInfo or BrainrotConfig.getBrainrotInfo or BrainrotConfig.getBrainrot
	if not getInfo then
		return nil
	end

	return getInfo(brainrotName)
end

function Tank._getMoneyPerCycle(self: Tank, tankData: TycoonTypes.TankData, level: number): number
	local brainrotInfo = self:_getBrainrotMeta(tankData.Brainrot)
	if not brainrotInfo then
		return 0
	end

	local baseValue = brainrotInfo.Value or brainrotInfo.Price or brainrotInfo.Money or 0
	local upgradeInfo = TankConfig.getUpgradeInfo(level)
	local mult = (upgradeInfo and (upgradeInfo.Multiplier or upgradeInfo.MoneyMultiplier)) or 1

	return baseValue * mult
end

function Tank._getProductionTime(self: Tank, tankData: TycoonTypes.TankData, level: number): number
	local upgradeInfo = TankConfig.getUpgradeInfo(level)
	return (upgradeInfo and upgradeInfo.Cooldown) or tankData.Config.Cooldown or 0
end

function Tank._getCapacity(self: Tank, tankData: TycoonTypes.TankData, level: number): number
	local upgradeInfo = TankConfig.getUpgradeInfo(level)
	-- CORREÇÃO: Adicionado check por 'Amount', pois é o que está no Config
	return (upgradeInfo and (upgradeInfo.Capacity or upgradeInfo.Amount or upgradeInfo.Required)) or tankData.Config.Required or 0
end

function Tank._buildTankSnapshot(self: Tank, tankName: string)
	local tankData = self.Tanks[tankName]
	if not tankData then
		return nil
	end

	local maxLevel = (TankConfig.getMaxLevel and TankConfig.getMaxLevel()) or 3

	local level = tankData.Level or 1
	if level < 1 then level = 1 end
	if level > maxLevel then level = maxLevel end

	local isMax = (TankConfig.isMaxLevel and TankConfig.isMaxLevel(level)) or (level >= maxLevel)
	local nextLevel = not isMax and (level + 1) or nil

	local brainrotInfo = self:_getBrainrotMeta(tankData.Brainrot)
	local photo = brainrotInfo and (brainrotInfo.Image or brainrotInfo.Icon or brainrotInfo.ImageId) or tankData.Config.Image or ""
	local displayName = tankData.Config.DisplayName or tankName

	local current = {
		productionTime = self:_getProductionTime(tankData, level),
		capacity = self:_getCapacity(tankData, level),
		moneyNow = self:_getMoneyPerCycle(tankData, level),
	}

	local nextInfo = nil
	local nextPrice = nil

	if nextLevel then
		nextInfo = {
			productionTime = self:_getProductionTime(tankData, nextLevel),
			capacity = self:_getCapacity(tankData, nextLevel),
			moneyNow = self:_getMoneyPerCycle(tankData, nextLevel),
		}

		local info = TankConfig.getUpgradeInfo(nextLevel)
		nextPrice = info and info.Price or nil

		if not nextPrice and TankConfig.calculateUpgradePrice then
			nextPrice = TankConfig.calculateUpgradePrice(tankName, nextLevel)
		end
	end

	local max = {
		productionTime = self:_getProductionTime(tankData, maxLevel),
		capacity = self:_getCapacity(tankData, maxLevel),
		moneyNow = self:_getMoneyPerCycle(tankData, maxLevel),
	}

	return {
		id = tankName,
		name = displayName,
		level = level,
		maxLevel = maxLevel,
		photo = photo,

		unlocked = tankData.Unlocked == true,
		isPremium = tankData.Config.IsPremium or false,
		brainrot = tankData.Brainrot or "",
		brainrotCount = tankData.BrainrotCount or 0,
		usesRemaining = tankData.UsesRemaining or 0,

		current = current,
		next = nextInfo,
		max = max,

		nextPrice = nextPrice,
		isMax = isMax,
	}
end

function Tank.getAllMachinesSnapshot(self: Tank)
	local list = {}

	for tankName in self.Tanks do
		local snap = self:_buildTankSnapshot(tankName)
		if snap and snap.unlocked then
			list[#list + 1] = snap
		end
	end

	if #list == 0 then
		return nil
	end

	return list
end

function Tank.getMachineSnapshot(self: Tank, tankName: string)
	local snap = self:_buildTankSnapshot(tankName)
	if not snap or not snap.unlocked then
		return nil
	end
	return snap
end

return Tank