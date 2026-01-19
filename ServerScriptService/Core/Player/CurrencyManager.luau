--[[ --// Overview //--
	Handles all currency operations
	Handles getting, setting, adjusting currencies
	Handles pricing, affordability checks, and purchases
	Handles earnings with multipliers
]]

--// Services //--
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Dependencies //--
local Core = ServerScriptService.Core
local PlayerManager = require(Core.Player.PlayerManager)
local Utilities = ReplicatedStorage.Shared.Utilities
local BigNum = require(Utilities.BigNum)
local MissionManager = require(ServerScriptService.Core.Player.MissionManager)

--// Setup //--
local CurrencyManager = {}

--// Types //--
export type Price = number | {Cash: number?, Plutonium: number?}
export type NormalizedPrice = {Cash: any, Plutonium: any}
export type CurrencyName = "Cash" | "Plutonium"

--// Private Functions //--

-- Converts dictionary with prices to bignum or single value to dictionary
-- Adds Plutonium at 0 if not given
local function normalizePriceToBigNum(price: Price): NormalizedPrice
	if type(price) == "table" then
		return {
			Cash = price.Cash and BigNum.new(price.Cash) or BigNum.new(0),
			Plutonium = price.Plutonium and BigNum.new(price.Plutonium) or BigNum.new(0)
		}
	else
		-- received string/number
		return {
			Cash = BigNum.new(price),
			Plutonium = BigNum.new(0)
		}
	end
end

--// Low-level Currency Operations //--

-- Retrieve currency value as BigNum
function CurrencyManager.get(player: Player, currencyName: CurrencyName)
	local data = player:FindFirstChild("Data")
	local currency = data and data:FindFirstChild(currencyName)
	if not currency then
		warn(`[CURRENCY] {currencyName} not found on player`)
		return nil
	end

	return BigNum.new(currency.Value)
end

function CurrencyManager.getValue(player: Player, currencyName: CurrencyName)
	local number = CurrencyManager.get(player, currencyName)
	if not number then return end
	
	return number:toNumber()
end

-- Directly set currency value as bignum storage string
function CurrencyManager.set(player: Player, currencyName: CurrencyName, amount: any)
	local data = player:FindFirstChild("Data")
	local currency = data and data:FindFirstChild(currencyName)
	if not currency then
		warn(`[CURRENCY] {currencyName} not found on player`)
		return
	end

	local value = BigNum.new(amount)
	currency.Value = value:toStorageString()
end

--[[
Adjust currency value, given amount can be positive for addition or negative for subtraction.
Uses bignum for both currencies
]]
function CurrencyManager.adjust(player: Player, currencyName: CurrencyName, amount: any): boolean
	local data = player:FindFirstChild("Data")
	local currency = data and data:FindFirstChild(currencyName)
	if not currency then
		warn(`[CURRENCY] {currencyName} not found on player`)
		return false
	end

	local currentAmount = BigNum.new(currency.Value)
	local changeAmount = BigNum.new(amount)

	if changeAmount:isNegative() and currentAmount:lessThan(changeAmount:abs()) then
		return false
	end

	local newAmount = currentAmount + changeAmount

	if newAmount:isNegative() then
		newAmount = BigNum.new(0)
	end

	currency.Value = newAmount:toStorageString()
	return true
end

--// High-level Currency Operations //--

--[[
Price is dictionary
e.g {Cash = 67, Plutonium = 2} or {Cash = 89}
]]
function CurrencyManager.canAfford(player: Player, price: Price): boolean
	if not price then return false end

	local normalizedPrice = normalizePriceToBigNum(price)

	local currentCash = CurrencyManager.get(player, "Cash")
	warn(currentCash,price)
	if not currentCash or currentCash < normalizedPrice.Cash then
		return false
	end

	local currentPlut = CurrencyManager.get(player, "Plutonium")
	if not currentPlut or currentPlut < normalizedPrice.Plutonium then
		return false
	end

	return true
end

-- Deducts currencies with validation
function CurrencyManager.deduct(player: Player, price: Price): boolean
	local normalizedPrice = normalizePriceToBigNum(price)

	if not CurrencyManager.canAfford(player, price) then
		return false
	end

	if normalizedPrice.Cash > BigNum.new(0) then
		if not CurrencyManager.adjust(player, "Cash", -normalizedPrice.Cash) then
			return false
		end
	end

	if normalizedPrice.Plutonium > BigNum.new(0) then
		if not CurrencyManager.adjust(player, "Plutonium", -normalizedPrice.Plutonium) then
			-- Refund cash if plutonium purchase fails
			CurrencyManager.adjust(player, "Cash", normalizedPrice.Cash)
			return false
		end
	end

	return true
end

-- Grants currency with multipliers
function CurrencyManager.grantEarnings(player: Player, baseAmount: any, trackProgress: boolean?)
	local playerObj = PlayerManager.getPlayerObject(player)
	if not playerObj then
		warn("[CURRENCY] No PlayerObject found for earnings")
		return
	end

	local multiplier = playerObj:getStat("ProductionValue")
	local base = BigNum.new(baseAmount)
	local final = base * multiplier

	CurrencyManager.adjust(player, "Cash", final)

	if trackProgress then
		if MissionManager then
			MissionManager.updateProgress(player, {
				CashEarned = final:toStorageString(),
			})
		end
	end
end

--// Display Helpers //--

-- Formats price for display
function CurrencyManager.formatPrice(price: Price): string
	local normalizedPrice = normalizePriceToBigNum(price)
	local parts = {}

	if normalizedPrice.Cash > BigNum.new(0) then
		table.insert(parts, "$" .. normalizedPrice.Cash:toString())
	end

	if normalizedPrice.Plutonium > BigNum.new(0) then
		table.insert(parts, normalizedPrice.Plutonium:toString() .. " Plutonium")
	end

	if #parts == 0 then
		return "Free"
	end

	return table.concat(parts, " + ")
end

--[[
	Complete purchase function
]]
function CurrencyManager.purchase(player: Player, price: Price): {success: boolean, message: string?}
	if not price then
		warn("[CURRENCY] No price provided")
		return {success = false, message = "Invalid price"}
	end

	if not CurrencyManager.canAfford(player, price) then
		warn("[CURRENCY] Player cannot afford")
		return {
			success = false, 
			message = `Need {CurrencyManager.formatPrice(price)}`
		}
	end

	if not CurrencyManager.deduct(player, price) then
		warn("[CURRENCY] Deduction failed")
		return {
			success = false,
			message = "Transaction failed"
		}
	end

	return {success = true}
end

return CurrencyManager