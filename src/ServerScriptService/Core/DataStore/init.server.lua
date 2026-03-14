------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local STORE_NAME: string = "Released_Data.01"
local DEFAULT_MAX_LIFE: number = 100
local DEFAULT_CURRENT_LIFE: number = 100
local POSITION_SAVE_PERIOD: number = 2

------------------//VARIABLES
local ProfileStore = require(script:WaitForChild("ProfileStore"))
local ProfileTemplate = require(script:WaitForChild("ProfileTemplate"))
local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))

local store = ProfileStore.New(STORE_NAME, ProfileTemplate)
local profilesByUserId: {[number]: any} = {}
local playerConnectionsByUserId: {[number]: {RBXScriptConnection}} = {}

------------------//FUNCTIONS
local function sanitize_life_values(maxLifeValue: any, currentLifeValue: any): (number, number)
	local maxLife = typeof(maxLifeValue) == "number" and math.max(1, maxLifeValue) or DEFAULT_MAX_LIFE
	local currentLife = typeof(currentLifeValue) == "number" and math.clamp(currentLifeValue, 0, maxLife) or DEFAULT_CURRENT_LIFE

	return maxLife, currentLife
end

local function to_position_table(positionValue: any): {X: number, Y: number, Z: number}
	if typeof(positionValue) ~= "table" then
		return { X = 0, Y = 0, Z = 0 }
	end

	local x = typeof(positionValue.X) == "number" and positionValue.X or 0
	local y = typeof(positionValue.Y) == "number" and positionValue.Y or 0
	local z = typeof(positionValue.Z) == "number" and positionValue.Z or 0

	return {
		X = x,
		Y = y,
		Z = z,
	}
end

local function bind_player_connection(player: Player, connection: RBXScriptConnection): ()
	local userId = player.UserId
	if not playerConnectionsByUserId[userId] then
		playerConnectionsByUserId[userId] = {}
	end

	table.insert(playerConnectionsByUserId[userId], connection)
end

local function disconnect_player_connections(player: Player): ()
	local userId = player.UserId
	local connections = playerConnectionsByUserId[userId]
	if not connections then
		return
	end

	for _, connection in connections do
		connection:Disconnect()
	end

	playerConnectionsByUserId[userId] = nil
end

local function set_player_life_attributes(player: Player, maxLife: number, currentLife: number): ()
	player:SetAttribute("MaxLife", maxLife)
	player:SetAttribute("CurrentLife", currentLife)
end

local function save_current_character_position(player: Player): ()
	local profile = profilesByUserId[player.UserId]
	if not profile then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	DataUtility.server.set(player, "Position", {
		X = rootPart.Position.X,
		Y = rootPart.Position.Y,
		Z = rootPart.Position.Z,
	}, false)
end

local function apply_life_from_profile_to_character(player: Player, profile: any, character: Model): ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local maxLife, currentLife = sanitize_life_values(profile.Data.MaxLife, profile.Data.CurrentLife)
	humanoid.MaxHealth = maxLife
	humanoid.Health = math.clamp(currentLife, 0, maxLife)
	set_player_life_attributes(player, maxLife, humanoid.Health)
end

local function apply_position_from_profile_to_character(profile: any, character: Model): ()
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local savedPosition = to_position_table(profile.Data.Position)
	local _, y, _ = rootPart.CFrame:ToOrientation()
	local targetCFrame = CFrame.new(savedPosition.X, savedPosition.Y, savedPosition.Z) * CFrame.Angles(0, y, 0)
	character:PivotTo(targetCFrame)
end

local function apply_loaded_data_to_player(player: Player, profile: any): ()
	player:SetAttribute("RoleImageId", profile.Data.Image or "")

	local maxLife, currentLife = sanitize_life_values(profile.Data.MaxLife, profile.Data.CurrentLife)
	set_player_life_attributes(player, maxLife, currentLife)

	DataUtility.server.set(player, "Image", player:GetAttribute("RoleImageId"), false)
	DataUtility.server.set(player, "MaxLife", maxLife, false)
	DataUtility.server.set(player, "CurrentLife", currentLife, false)
	DataUtility.server.set(player, "Position", to_position_table(profile.Data.Position), false)
end

local function connect_character_tracking(player: Player, profile: any, character: Model): ()
	task.defer(function()
		if profilesByUserId[player.UserId] ~= profile or not character.Parent then
			return
		end

		apply_position_from_profile_to_character(profile, character)
		apply_life_from_profile_to_character(player, profile, character)

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		bind_player_connection(player, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
			if profilesByUserId[player.UserId] ~= profile then
				return
			end

			local newMax = math.max(1, humanoid.MaxHealth)
			local newCurrent = math.clamp(humanoid.Health, 0, newMax)
			set_player_life_attributes(player, newMax, newCurrent)
			DataUtility.server.set(player, "MaxLife", newMax, false)
			DataUtility.server.set(player, "CurrentLife", newCurrent, false)
		end))

		bind_player_connection(player, humanoid.HealthChanged:Connect(function(newHealth: number)
			if profilesByUserId[player.UserId] ~= profile then
				return
			end

			local maxLife = math.max(1, humanoid.MaxHealth)
			local clampedHealth = math.clamp(newHealth, 0, maxLife)
			set_player_life_attributes(player, maxLife, clampedHealth)
			DataUtility.server.set(player, "CurrentLife", clampedHealth, false)
		end))
	end)
end

local function attach_player_profile(player: Player): ()
	local profile = store:StartSessionAsync(tostring(player.UserId))

	if not profile then
		warn("Falha ao iniciar sessão do perfil para " .. player.Name)
		return
	end

	profile:Reconcile()
	profile:AddUserId(player.UserId)

	profilesByUserId[player.UserId] = profile

	DataUtility.server.attach_profile(player, profile)
	apply_loaded_data_to_player(player, profile)

	bind_player_connection(player, player:GetAttributeChangedSignal("RoleImageId"):Connect(function()
		DataUtility.server.set(player, "Image", player:GetAttribute("RoleImageId") or "", false)
	end))

	bind_player_connection(player, player:GetAttributeChangedSignal("MaxLife"):Connect(function()
		local maxLife, currentLife = sanitize_life_values(player:GetAttribute("MaxLife"), player:GetAttribute("CurrentLife"))
		DataUtility.server.set(player, "MaxLife", maxLife, false)
		DataUtility.server.set(player, "CurrentLife", currentLife, false)
	end))

	bind_player_connection(player, player:GetAttributeChangedSignal("CurrentLife"):Connect(function()
		local maxLife, currentLife = sanitize_life_values(player:GetAttribute("MaxLife"), player:GetAttribute("CurrentLife"))
		DataUtility.server.set(player, "MaxLife", maxLife, false)
		DataUtility.server.set(player, "CurrentLife", currentLife, false)
	end))

	bind_player_connection(player, player.CharacterAdded:Connect(function(character: Model)
		connect_character_tracking(player, profile, character)
	end))

	if player.Character then
		connect_character_tracking(player, profile, player.Character)
	end

	task.spawn(function()
		while player.Parent and profilesByUserId[player.UserId] == profile do
			task.wait(1)

			if profilesByUserId[player.UserId] ~= profile then
				break
			end

			local currentTime = profile.Data.TimePlayed or 0
			DataUtility.server.set(player, "TimePlayed", currentTime + 1, false)

			if currentTime % POSITION_SAVE_PERIOD == 0 then
				save_current_character_position(player)
			end
		end
	end)

	profile.OnSessionEnd:Connect(function()
		disconnect_player_connections(player)
		DataUtility.server.detach_profile(player)
		profilesByUserId[player.UserId] = nil
	end)
end

local function release_player_profile(player: Player): ()
	local profile = profilesByUserId[player.UserId]
	if not profile then
		return
	end

	save_current_character_position(player)

	local maxLife, currentLife = sanitize_life_values(player:GetAttribute("MaxLife"), player:GetAttribute("CurrentLife"))
	DataUtility.server.set(player, "MaxLife", maxLife, false)
	DataUtility.server.set(player, "CurrentLife", currentLife, false)
	DataUtility.server.set(player, "Image", player:GetAttribute("RoleImageId") or "", false)

	profile:Save()
	profile:EndSession()
	disconnect_player_connections(player)
	profilesByUserId[player.UserId] = nil
end

------------------//MAIN FUNCTIONS
local function on_player_added(player: Player): ()
	attach_player_profile(player)
end

local function on_player_removing(player: Player): ()
	release_player_profile(player)
end

------------------//INIT
DataUtility.server.ensure_remotes()

for _, p in Players:GetPlayers() do
	on_player_added(p)
end

Players.PlayerAdded:Connect(on_player_added)
Players.PlayerRemoving:Connect(on_player_removing)

ProfileStore.OnError:Connect(function(msg: string, storeName: string, key: string)
	warn(("[ProfileStore:%s %s] %s"):format(storeName, key, msg))
end)
