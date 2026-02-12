------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

------------------//VARIABLES
local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility)
local RebirthConfig = require(ReplicatedStorage.Modules.Datas.RebirthConfig)

------------------//SETUP
local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local rebirthEvent = remotesFolder:FindFirstChild("RebirthAction")

if not rebirthEvent then
	rebirthEvent = Instance.new("RemoteEvent")
	rebirthEvent.Name = "RebirthAction"
	rebirthEvent.Parent = remotesFolder
end

------------------//FUNCTIONS
local function handle_rebirth(player: Player)
	local currentRebirths = DataUtility.server.get(player, "Rebirths") or 0
	local currentCoins = DataUtility.server.get(player, "Coins") or 0
	local currentPower = DataUtility.server.get(player, "PogoSettings.base_jump_power") or 0

	local coinsReq, powerReq = RebirthConfig.GetRequirement(currentRebirths)

	if currentCoins >= coinsReq and currentPower >= powerReq then
		local newRebirthCount = currentRebirths + 1
		local currentTokens = DataUtility.server.get(player, "RebirthTokens") or 0

		DataUtility.server.set(player, "Coins", 0)
		DataUtility.server.set(player, "PogoSettings.base_jump_power", RebirthConfig.POWER_RESET_VALUE)

		DataUtility.server.set(player, "OwnedPogos", {
			["BasicPogo"] = true
		})
		DataUtility.server.set(player, "EquippedPogoId", "BasicPogo")
		
		DataUtility.server.set(player, "OwnedPets", {})
		DataUtility.server.set(player, "EquippedPets", "")

		DataUtility.server.set(player, "Rebirths", newRebirthCount)
		DataUtility.server.set(player, "RebirthTokens", currentTokens + RebirthConfig.TOKENS_PER_REBIRTH)

		return true
	end

	return false
end

------------------//INIT
rebirthEvent.OnServerEvent:Connect(handle_rebirth)