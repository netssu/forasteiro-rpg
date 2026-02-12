------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

------------------//MODULES
local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility)
local WorldConfig = require(ReplicatedStorage.Modules.Datas.WorldConfig)

------------------//SETUP REMOTES
local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local travelEvent = remotesFolder:FindFirstChild("TravelAction")

------------------//FUNCTIONS
local function teleport_player(player: Player, worldData: any)
	local character = player.Character
	if character then
		DataUtility.server.set(player, "PogoSettings.gravity_mult", worldData.gravityMult)
		character:PivotTo(worldData.entryCFrame)
	end
end

local function handle_travel_request(player: Player, targetWorldId: number)
	local currentPower = DataUtility.server.get(player, "PogoSettings.base_jump_power") or 0
	local currentRebirths = DataUtility.server.get(player, "Rebirths") or 0
	local currentWorld = DataUtility.server.get(player, "CurrentWorld") or 1

	local targetWorld = WorldConfig.GetWorld(targetWorldId)

	if not targetWorld then return end

	if targetWorldId < currentWorld then
		DataUtility.server.set(player, "CurrentWorld", targetWorldId)
		teleport_player(player, targetWorld)
		return true
	end

	local powerOk = currentPower >= targetWorld.requiredPogoPower
	local rebirthsOk = currentRebirths >= targetWorld.requiredRebirths

	if powerOk and rebirthsOk then
		DataUtility.server.set(player, "CurrentWorld", targetWorld.id)
		teleport_player(player, targetWorld)
		return true
	end

	return false
end

local function on_player_added(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.wait(0.5)

		local savedWorldId = DataUtility.server.get(player, "CurrentWorld") or 1
		local worldData = WorldConfig.GetWorld(savedWorldId)

		teleport_player(player, worldData)
	end)

	local lastRebirths = DataUtility.server.get(player, "Rebirths") or 0

	DataUtility.server.bind(player, "Rebirths", function(newVal)
		if newVal > lastRebirths then
			DataUtility.server.set(player, "CurrentWorld", 1)

			local worldOne = WorldConfig.GetWorld(1)
			teleport_player(player, worldOne)
		end
		lastRebirths = newVal
	end)
end

------------------//INIT
Players.PlayerAdded:Connect(on_player_added)

travelEvent.OnServerEvent:Connect(function(player, targetId)
	handle_travel_request(player, targetId)
end)