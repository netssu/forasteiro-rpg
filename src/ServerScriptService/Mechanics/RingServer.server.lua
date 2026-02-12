------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local RINGS_FOLDER: Folder = workspace:WaitForChild("Rings")
local REQUIRED_FALL_VELOCITY_Y: number = -1
local MAX_MULTIPLIER_CAP: number = 20.0

------------------//VARIABLES
local remotesFolder: Folder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local ringEvent: RemoteEvent = remotesFolder:WaitForChild("RingEvent")

local collectedByPlayer: {[number]: {[Instance]: boolean}} = {}
local ringBonusByPlayer: {[number]: number} = {} -- Armazena apenas o valor somado pelos anéis
local pogoStateConns: {[number]: RBXScriptConnection} = {}

------------------//FUNCTIONS
local function ensure_player_table(player: Player): {[Instance]: boolean}
	local t = collectedByPlayer[player.UserId]
	if not t then
		t = {}
		collectedByPlayer[player.UserId] = t
	end
	return t
end

local function reset_player(player: Player): ()
	collectedByPlayer[player.UserId] = {}

	local currentBonus = ringBonusByPlayer[player.UserId] or 0
	local currentMult = player:GetAttribute("Multiplier") or 1

	if currentBonus > 0 then
		local restoredMult = math.max(1, currentMult - currentBonus)
		player:SetAttribute("Multiplier", restoredMult)
	end

	ringBonusByPlayer[player.UserId] = 0
	ringEvent:FireClient(player, "Restore")
end

local function can_collect(player: Player): boolean
	local pogoState = player:GetAttribute("PogoState")
	if pogoState == "Idle" or pogoState == "Stunned" then
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return false
	end

	if rootPart.AssemblyLinearVelocity.Y >= REQUIRED_FALL_VELOCITY_Y then
		return false
	end

	return true
end

local function get_ring_value(ring: BasePart): number?
	local raw = tonumber(ring.Name)
	if not raw then
		return nil
	end

	if raw >= 1 then
		return raw / 10
	end

	return raw
end

local function on_ring_touch(ring: BasePart, hit: BasePart): ()
	local character = hit.Parent
	if not character then return end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	if not can_collect(player) then
		return
	end

	local ringValue = get_ring_value(ring)
	if not ringValue then
		return
	end

	local collected = ensure_player_table(player)
	if collected[ring] then
		return
	end
	collected[ring] = true

	local currentMult = player:GetAttribute("Multiplier") or 1
	local currentBonus = ringBonusByPlayer[player.UserId] or 0

	local potentialMult = currentMult + ringValue

	if potentialMult > MAX_MULTIPLIER_CAP then
		local difference = MAX_MULTIPLIER_CAP - currentMult
		if difference <= 0 then 
			return 
		end
		ringValue = difference
		potentialMult = MAX_MULTIPLIER_CAP
	end

	local newBonus = currentBonus + ringValue

	ringBonusByPlayer[player.UserId] = newBonus
	player:SetAttribute("Multiplier", potentialMult)

	ringEvent:FireClient(player, "Collect", potentialMult, ring, ringValue)
end

local function connect_ring(inst: Instance): ()
	if not inst:IsA("BasePart") then
		return
	end

	inst.Touched:Connect(function(hit: BasePart)
		on_ring_touch(inst, hit)
	end)
end

local function bind_player(player: Player): ()
	collectedByPlayer[player.UserId] = {}
	ringBonusByPlayer[player.UserId] = 0

	if pogoStateConns[player.UserId] then
		pogoStateConns[player.UserId]:Disconnect()
	end

	pogoStateConns[player.UserId] = player:GetAttributeChangedSignal("PogoState"):Connect(function()
		local pogoState = player:GetAttribute("PogoState")
		if pogoState == "Idle" or pogoState == "Stunned" or pogoState == "Cooldown" then
			reset_player(player)
		end
	end)
end

local function unbind_player(player: Player): ()
	if pogoStateConns[player.UserId] then
		pogoStateConns[player.UserId]:Disconnect()
		pogoStateConns[player.UserId] = nil
	end

	collectedByPlayer[player.UserId] = nil
	ringBonusByPlayer[player.UserId] = nil
end

------------------//INIT
local rings = RINGS_FOLDER:GetChildren()
for _, ring in rings do
	connect_ring(ring)
end

RINGS_FOLDER.ChildAdded:Connect(function(child: Instance)
	connect_ring(child)
end)

local players = Players:GetPlayers()
for _, p in players do
	bind_player(p)
end

Players.PlayerAdded:Connect(bind_player)
Players.PlayerRemoving:Connect(unbind_player)