--// Services //--
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Dependencies //--
local Base = require(script.Parent.Base)
local ConfigManager = require(ReplicatedStorage.Shared.Configs.ConfigManager)
local GeneralConfig = require(ReplicatedStorage.Shared.Configs.GeneralConfig)
local CurrencyManager = require(ServerScriptService.Core.Player.CurrencyManager)

--// Tables //--
local Bases = {} :: {[number]: Base.Base}
local AvailableBases = {}
local ClaimedBases = {} :: {[Player]: number}

--// Events //--

local AddBrainrotToCage = ServerScriptService.Bindables.Catching.AddBrainrotToCage

--// Main //--
local TycoonManager = {}

function TycoonManager.initialize()
	local BaseFolders = workspace.Bases:GetChildren()

	for index, baseFolder in BaseFolders do
		baseFolder.Name = `Base_{index}`
		baseFolder:SetAttribute("ID", index)
		Bases[index] = Base.new(baseFolder, index)
		table.insert(AvailableBases, index)
	end
	
	AddBrainrotToCage.Event:Connect(function(player, brainrots)
		print("Trying to put brainrot to cage")
		TycoonManager.addBrainrotsToCage(player, brainrots)
	end)
	
	ReplicatedStorage.Remotes.Events.InstantButton.OnServerEvent:Connect(function(player: Player, tankName: string)
		--if CurrencyManager.getValue(player, "Plutonium") < 20 then return end
		TycoonManager.removeBrainrotOfTank(player, tankName)
	end)

	--print(`[TYCOON] Initialized {#Bases} bases`)
end

--// APIs //--

-- Base
function TycoonManager.assignBase(player: Player, tycoonData: {}?)
	if #AvailableBases == 0 then
		warn("[TYCOON] No bases available")
		return 
	end

	local baseID = table.remove(AvailableBases, 1)
	ClaimedBases[player] = baseID

	local base = Bases[baseID]
	base:claim(player)

	if tycoonData then
		base:deserializeData(tycoonData)
		--print(`[TYCOON] Loaded data for {player.Name} on base {baseID}`)
	end
	
	if player then
		player:SetAttribute("Base",`Base_{baseID}`)
	end

	--print(`[TYCOON] Assigned base {baseID} to {player.Name}`)
end

function TycoonManager.unassignBase(player: Player)
	if player then
		player:SetAttribute("Base",nil)
	end
	
	local baseID = ClaimedBases[player]
	if not baseID then
		warn("[TYCOON] No base claimed for", player.Name)
		return
	end

	ClaimedBases[player] = nil
	Bases[baseID]:unclaim()
	table.insert(AvailableBases, baseID)

	--print(`[TYCOON] Unassigned base {baseID} from {player.Name}`)
end

function TycoonManager.getBase(player: Player): Base.Base?
	local baseID = ClaimedBases[player]
	return baseID and Bases[baseID]
end

function TycoonManager.getBaseByID(id: number): Base.Base?
	return Bases[id]
end

function TycoonManager.getAllBases()
	return Bases
end

-- Tanks
function TycoonManager.unlockTank(player: Player, tankName: string): boolean
	local base = TycoonManager.getBase(player)
	if not base then return false end
	return base.Tank:unlockTank(tankName)
end

function TycoonManager.purchaseUnlockTank(player: Player, tankName: string): boolean
	local base = TycoonManager.getBase(player)
	if not base then return false end
	return base.Tank:purchaseUnlock(tankName)
end

function TycoonManager.upgradeTank(player: Player, tankName: string): boolean
	local base = TycoonManager.getBase(player)
	if not base then return false end
	return base.Tank:upgradeTank(tankName)
end

function TycoonManager.purchaseUpgradeTank(player: Player, tankName: string): boolean
	local base = TycoonManager.getBase(player)
	if not base then return false end
	return base.Tank:purchaseUpgrade(tankName)
end

function TycoonManager.setPremiumTankBrainrot(player: Player, tankName: string, brainrotName: string): boolean
	local base = TycoonManager.getBase(player)
	if not base then return false end
	return base.Tank:setPremiumTankBrainrot(tankName, brainrotName)
end

function TycoonManager.isTankUnlocked(player: Player, tankName: string): boolean
	local base = TycoonManager.getBase(player)
	if not base then return false end
	return base.Tank:isUnlocked(tankName)
end

function TycoonManager.getTankLevel(player: Player, tankName: string): number?
	local base = TycoonManager.getBase(player)
	if not base then return nil end
	return base.Tank:getLevel(tankName)
end

function TycoonManager.getTankUpgradePrice(player: Player, tankName: string): {Cash: number, Plutonium: number}?
	local base = TycoonManager.getBase(player)
	if not base then return nil end
	local tankData = base.Tank:getTankData(tankName)
	if not tankData then return nil end
	return ConfigManager.Tank.calculateUpgradePrice(tankName, tankData.Level)
end

function TycoonManager.transferBrainrotFromCage(player: Player, tankName: string): number
	local base = TycoonManager.getBase(player)
	if not base then return 0 end
	-- Transfers up to the required amount for the tank
	return base.Tank:transferBrainrotFromCage(tankName)
end

function TycoonManager.addBrainrotToTank(player: Player, tankName: string, amount: number): number
	local base = TycoonManager.getBase(player)
	if not base then return 0 end
	return base.Tank:addBrainrotToTank(tankName, amount)
end

function TycoonManager.removeBrainrotOfTank(player: Player, tankName: string)
	local base = TycoonManager.getBase(player)
	if not base then return 0 end
	return base.Tank:removeBrainrotOfTank(tankName)
end

-- Cage
function TycoonManager.isCageFull(player: Player): (boolean, number)
	local base = TycoonManager.getBase(player)
	if not base then return false, 0 end

	local contents = base.Cage:getContents()
	local totalCount = 0
	for _, count in contents do
		totalCount += count
	end

	-- Note: Cage supports future capacity buffs while  this check uses default config capacity
	return totalCount >= (GeneralConfig.CAGE_CAPACITY or 0), totalCount, GeneralConfig.CAGE_CAPACITY
end

function TycoonManager.addBrainrotsToCage(player: Player, brainrots: {[string]: number}): number
	local base = TycoonManager.getBase(player)
	if not base then
		warn("[TYCOON] No base found for player")
		return 0
	end

	-- Delegate capacity handling to Cage component; returns actual added count
	local added = base.Cage:addBrainrots(brainrots)
	if added <= 0 then
		--warn("[TYCOON] Cage rejected additions (full or invalid)")
	end
	return added
end

function TycoonManager.getCageContents(player: Player): {[string]: number}
	local base = TycoonManager.getBase(player)
	if not base then return {} end
	return base.Cage:getContents()
end

--// Data //--
function TycoonManager.loadPlayerData(player: Player, data: {})
	local base = TycoonManager.getBase(player)
	if not base then
		warn("[TYCOON] No base found when loading data")
		return
	end
	base:deserializeData(data)
end

function TycoonManager.savePlayerData(player: Player): {}
	local base = TycoonManager.getBase(player)
	return base and base:serializeData() or {}
end

return TycoonManager