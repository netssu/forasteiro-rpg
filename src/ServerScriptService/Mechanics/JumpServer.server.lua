------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")

------------------//MODULES
local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility)
local PogoData = require(ReplicatedStorage.Modules.Datas.PogoData)
local MaterialData = require(ReplicatedStorage.Modules.Datas.MaterialData)

------------------//SETUP REMOTES
local REMOTE_NAME: string = "PogoEvent"
local pogoEvent: RemoteEvent = ReplicatedStorage.Assets.Remotes:WaitForChild(REMOTE_NAME) :: RemoteEvent

------------------//CONSTANTS
local SETTINGS = {
	BaseCoinReward = 10,
	ComboCoinBonus = 5,

	MaxReboundDistance = 60,
	MinTimeBetweenRebounds = 0.2,

	RebirthPowerScale = 0.5,
}

------------------//VARIABLES
local playerStates: {[number]: {lastActionTime: number, serverCombo: number}} = {}

------------------//FUNCTIONS
local function get_state(player: Player): {lastActionTime: number, serverCombo: number}
	local st = playerStates[player.UserId]
	if not st then
		st = {
			lastActionTime = 0,
			serverCombo = 0,
		}
		playerStates[player.UserId] = st
	end
	return st
end

local function update_attributes(player: Player, status: string, combo: number): ()
	player:SetAttribute("PogoState", status)
	player:SetAttribute("CurrentCombo", combo)
end

local function get_ground_material(character: Model): string?
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return nil
	end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local hit = workspace:Raycast(rootPart.Position, Vector3.new(0, -SETTINGS.MaxReboundDistance, 0), params)

	if hit then
		return hit.Material.Name
	end
	return nil
end

local function recalculate_player_stats(player: Player)
	local equippedId = DataUtility.server.get(player, "EquippedPogoId") or "BasicPogo"
	local rebirths = DataUtility.server.get(player, "Rebirths") or 0

	local pogoStats = PogoData.Get(equippedId)
	local basePower = pogoStats.Power

	local rebirthMult = 1 + (rebirths * SETTINGS.RebirthPowerScale)

	local globalMult = player:GetAttribute("Multiplier") or 1.0
	globalMult = math.max(1.0, globalMult)

	local finalPower = math.floor(basePower * rebirthMult * globalMult)

	DataUtility.server.set(player, "PogoSettings.base_jump_power", finalPower)
end

local function award_coins(player: Player, combo: number, isCritical: boolean, matMult: number)
	local rebirths = DataUtility.server.get(player, "Rebirths") or 0
	local rebirthMult = 1 + (rebirths * SETTINGS.RebirthPowerScale)

	local mult = player:GetAttribute("Multiplier") or 1.0
	if type(mult) ~= "number" then mult = 1.0 end
	mult = math.max(1.0, mult)

	local critMultiplier = isCritical and 2 or 1
	local materialMultiplier = matMult or 1

	local reward = (SETTINGS.BaseCoinReward + (combo * SETTINGS.ComboCoinBonus)) * rebirthMult * mult * critMultiplier * materialMultiplier

	local currentCoins = DataUtility.server.get(player, "Coins") or 0
	DataUtility.server.set(player, "Coins", currentCoins + reward)
end

local function handle_jump(player: Player, payload: any): ()
	local state = get_state(player)
	state.serverCombo = 0

	local totalJumps = DataUtility.server.get(player, "Stats.TotalJumps") or 0
	DataUtility.server.set(player, "Stats.TotalJumps", totalJumps + 1)

	local character = player.Character
	local matMultiplier = 1

	if character then
		local matName = get_ground_material(character)
		local impactForce = (payload and payload.impactForce) or 0

		if matName then
			local matInfo = MaterialData.Get(matName)
			if impactForce >= (matInfo.MinBreakForce or 40) then
				matMultiplier = matInfo.CoinMultiplier
			else
				matMultiplier = 0
			end
		end
	end

	if matMultiplier > 0 then
		award_coins(player, 0, false, matMultiplier)
	end

	update_attributes(player, "Jumping", 0)
end

local function handle_rebound(player: Player, _clientCombo: number, isCritical: boolean, payload: any): ()
	local state = get_state(player)
	local now = os.clock()

	local character = player.Character
	if not character then return end

	if (now - state.lastActionTime) < SETTINGS.MinTimeBetweenRebounds then return end

	local matName = get_ground_material(character)

	if not matName then
		warn("[SERVER] Rebound rejected:", player.Name)
		state.serverCombo = 0
		update_attributes(player, "Reset", 0)
		return
	end

	state.serverCombo += 1
	local finalCombo = state.serverCombo

	local totalLandings = DataUtility.server.get(player, "Stats.TotalLandings") or 0
	DataUtility.server.set(player, "Stats.TotalLandings", totalLandings + 1)

	if isCritical then
		local perfectLandings = DataUtility.server.get(player, "Stats.PerfectLandings") or 0
		DataUtility.server.set(player, "Stats.PerfectLandings", perfectLandings + 1)
	end

	local highestCombo = DataUtility.server.get(player, "Stats.HighestCombo") or 0
	if finalCombo > highestCombo then
		DataUtility.server.set(player, "Stats.HighestCombo", finalCombo)
	end

	local matInfo = MaterialData.Get(matName)
	local matMultiplier = matInfo.CoinMultiplier

	local impactForce = (payload and payload.impactForce) or 0
	if impactForce < (matInfo.MinBreakForce or 40) then
		matMultiplier = 0
	end

	if matMultiplier > 0 then
		award_coins(player, finalCombo, isCritical, matMultiplier)
	end

	update_attributes(player, "Rebounding", finalCombo)
	state.lastActionTime = now
end

local function handle_land(player: Player, status: string?): ()
	local state = get_state(player)
	state.serverCombo = 0

	local finalStatus = status or "Cooldown"
	update_attributes(player, finalStatus, 0)
end

------------------//INIT
DataUtility.server.ensure_remotes()

pogoEvent.OnServerEvent:Connect(function(player: Player, action: string, payload: any)
	if action == "Jump" then
		handle_jump(player, payload)

	elseif action == "Rebound" then
		local combo = (payload and payload.combo) or 1
		local isCritical = (payload and payload.isCritical) == true
		handle_rebound(player, combo, isCritical, payload)

	elseif action == "Land" then
		local status = payload and payload.status
		handle_land(player, status)

	elseif action == "Stunned" then
		local state = get_state(player)
		state.serverCombo = 0
		update_attributes(player, "Stunned", 0)
	end
end)

Players.PlayerAdded:Connect(function(player: Player)
	get_state(player)
	update_attributes(player, "Idle", 0)
	recalculate_player_stats(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	playerStates[player.UserId] = nil
end)