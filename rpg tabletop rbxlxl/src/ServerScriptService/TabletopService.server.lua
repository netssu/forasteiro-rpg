------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting: Lighting = game:GetService("Lighting")
local SoundService: SoundService = game:GetService("SoundService")

------------------//CONSTANTS
local MASTER_TEAM_NAME: string = "Mestre"
local PLAYER_TEAM_NAME: string = "Jogador"

local REMOTE_NAME: string = "TabletopEvent"
local DEFAULT_PRESET_NAME: string = "NeutralDay"
local AUDIO_FOLDER_NAME: string = "TabletopAudio"
local RAIN_SOUND_NAME: string = "RainAmbient"
local MANAGED_ATTRIBUTE_NAME: string = "TabletopManaged"

------------------//VARIABLES
local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local lightingPresetsFolder: Folder = assetsFolder:WaitForChild("LightingPresets")
local tabletopEvent: RemoteEvent = remotesFolder:WaitForChild(REMOTE_NAME)

local state = {
	clockTime = 12,
	presetName = DEFAULT_PRESET_NAME,
	rainEnabled = false,
	manualLocks = {},
	combatStarted = false,
	activeTurnIndex = 0,
	combatOrder = {},
	healthData = {},
}

local healthChangedConnections = {}
local maxHealthChangedConnections = {}

------------------//FUNCTIONS
local function get_team_name(player: Player): string
	local team = player.Team

	if not team then
		return ""
	end

	return team.Name
end

local function is_master(player: Player): boolean
	return get_team_name(player) == MASTER_TEAM_NAME
end

local function get_player_by_user_id(userId: number): Player?
	for _, player in Players:GetPlayers() do
		if player.UserId == userId then
			return player
		end
	end

	return nil
end

local function get_player_label(player: Player): string
	if player.DisplayName ~= player.Name then
		return player.DisplayName .. " (@" .. player.Name .. ")"
	end

	return player.Name
end

local function get_humanoid(player: Player): Humanoid?
	local character = player.Character

	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		return humanoid
	end

	return nil
end

local function ensure_health_entry(player: Player): {}
	local entry = state.healthData[player.UserId]

	if entry then
		return entry
	end

	local humanoid = get_humanoid(player)
	local maxHealth = 100
	local currentHealth = 100

	if humanoid then
		maxHealth = math.max(1, humanoid.MaxHealth)
		currentHealth = math.clamp(humanoid.Health, 0, maxHealth)
	end

	entry = {
		Max = maxHealth,
		Current = currentHealth,
	}

	state.healthData[player.UserId] = entry

	return entry
end

local function capture_health_from_character(player: Player): ()
	local humanoid = get_humanoid(player)

	if not humanoid then
		return
	end

	local entry = ensure_health_entry(player)

	entry.Max = math.max(1, humanoid.MaxHealth)
	entry.Current = math.clamp(humanoid.Health, 0, entry.Max)
end

local function apply_health_to_character(player: Player): ()
	local humanoid = get_humanoid(player)

	if not humanoid then
		return
	end

	local entry = ensure_health_entry(player)

	humanoid.MaxHealth = math.max(1, entry.Max)
	humanoid.Health = math.clamp(entry.Current, 0, humanoid.MaxHealth)
end

local function disconnect_health_connections(userId: number): ()
	local healthConnection = healthChangedConnections[userId]

	if healthConnection then
		healthConnection:Disconnect()
		healthChangedConnections[userId] = nil
	end

	local maxHealthConnection = maxHealthChangedConnections[userId]

	if maxHealthConnection then
		maxHealthConnection:Disconnect()
		maxHealthChangedConnections[userId] = nil
	end
end

local function connect_character_health(player: Player): ()
	local humanoid = get_humanoid(player)

	disconnect_health_connections(player.UserId)

	if not humanoid then
		return
	end

	if state.healthData[player.UserId] then
		apply_health_to_character(player)
	else
		capture_health_from_character(player)
	end

	healthChangedConnections[player.UserId] = humanoid.HealthChanged:Connect(function()
		capture_health_from_character(player)
		push_snapshot()
	end)

	maxHealthChangedConnections[player.UserId] = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		capture_health_from_character(player)
		push_snapshot()
	end)
end

local function remove_managed_lighting_effects(): ()
	for _, child in Lighting:GetChildren() do
		if child:GetAttribute(MANAGED_ATTRIBUTE_NAME) == true then
			child:Destroy()
		end
	end
end

local function get_setting_value(settingsFolder: Folder, name: string): Instance?
	local valueObject = settingsFolder:FindFirstChild(name)

	if valueObject then
		return valueObject
	end

	return nil
end

local function apply_lighting_settings(settingsFolder: Folder): ()
	local clockTimeValue = get_setting_value(settingsFolder, "ClockTime")
	local brightnessValue = get_setting_value(settingsFolder, "Brightness")
	local exposureValue = get_setting_value(settingsFolder, "ExposureCompensation")
	local fogStartValue = get_setting_value(settingsFolder, "FogStart")
	local fogEndValue = get_setting_value(settingsFolder, "FogEnd")
	local diffuseValue = get_setting_value(settingsFolder, "EnvironmentDiffuseScale")
	local specularValue = get_setting_value(settingsFolder, "EnvironmentSpecularScale")
	local shadowSoftnessValue = get_setting_value(settingsFolder, "ShadowSoftness")
	local ambientValue = get_setting_value(settingsFolder, "Ambient")
	local outdoorAmbientValue = get_setting_value(settingsFolder, "OutdoorAmbient")

	if clockTimeValue and clockTimeValue:IsA("NumberValue") then
		state.clockTime = clockTimeValue.Value
		Lighting.ClockTime = clockTimeValue.Value
	end

	if brightnessValue and brightnessValue:IsA("NumberValue") then
		Lighting.Brightness = brightnessValue.Value
	end

	if exposureValue and exposureValue:IsA("NumberValue") then
		Lighting.ExposureCompensation = exposureValue.Value
	end

	if fogStartValue and fogStartValue:IsA("NumberValue") then
		Lighting.FogStart = fogStartValue.Value
	end

	if fogEndValue and fogEndValue:IsA("NumberValue") then
		Lighting.FogEnd = fogEndValue.Value
	end

	if diffuseValue and diffuseValue:IsA("NumberValue") then
		Lighting.EnvironmentDiffuseScale = diffuseValue.Value
	end

	if specularValue and specularValue:IsA("NumberValue") then
		Lighting.EnvironmentSpecularScale = specularValue.Value
	end

	if shadowSoftnessValue and shadowSoftnessValue:IsA("NumberValue") then
		Lighting.ShadowSoftness = shadowSoftnessValue.Value
	end

	if ambientValue and ambientValue:IsA("Color3Value") then
		Lighting.Ambient = ambientValue.Value
	end

	if outdoorAmbientValue and outdoorAmbientValue:IsA("Color3Value") then
		Lighting.OutdoorAmbient = outdoorAmbientValue.Value
	end
end

local function clone_preset_effects(effectsFolder: Folder): ()
	remove_managed_lighting_effects()

	for _, child in effectsFolder:GetChildren() do
		local clone = child:Clone()
		clone:SetAttribute(MANAGED_ATTRIBUTE_NAME, true)
		clone.Parent = Lighting
	end
end

local function apply_preset(presetName: string): ()
	local presetFolder = lightingPresetsFolder:FindFirstChild(presetName)

	if not presetFolder or not presetFolder:IsA("Folder") then
		return
	end

	local settingsFolder = presetFolder:FindFirstChild("Settings")
	local effectsFolder = presetFolder:FindFirstChild("Effects")

	if settingsFolder and settingsFolder:IsA("Folder") then
		apply_lighting_settings(settingsFolder)
	end

	if effectsFolder and effectsFolder:IsA("Folder") then
		clone_preset_effects(effectsFolder)
	else
		remove_managed_lighting_effects()
	end

	state.presetName = presetName
end

local function set_clock_time(clockTime: number): ()
	local normalizedClockTime = math.clamp(clockTime, 0, 24)

	state.clockTime = normalizedClockTime
	Lighting.ClockTime = normalizedClockTime
end

local function get_rain_sound(): Sound?
	local audioFolder = SoundService:FindFirstChild(AUDIO_FOLDER_NAME)

	if not audioFolder or not audioFolder:IsA("Folder") then
		return nil
	end

	local rainSound = audioFolder:FindFirstChild(RAIN_SOUND_NAME)

	if rainSound and rainSound:IsA("Sound") then
		return rainSound
	end

	return nil
end

local function set_rain_enabled(isEnabled: boolean): ()
	local rainSound = get_rain_sound()

	state.rainEnabled = isEnabled

	if not rainSound then
		return
	end

	rainSound.Looped = true
	rainSound.Playing = isEnabled
end

local function cleanup_combat_order(): ()
	local connectedPlayers = {}

	for _, player in Players:GetPlayers() do
		connectedPlayers[player.UserId] = true
	end

	local newOrder = {}

	for _, entry in state.combatOrder do
		if connectedPlayers[entry.UserId] then
			table.insert(newOrder, entry)
		end
	end

	state.combatOrder = newOrder

	if #state.combatOrder == 0 then
		state.combatStarted = false
		state.activeTurnIndex = 0
		return
	end

	if state.activeTurnIndex < 1 then
		state.activeTurnIndex = 1
	end

	if state.activeTurnIndex > #state.combatOrder then
		state.activeTurnIndex = 1
	end
end

local function get_active_order_entry(): {}?
	if not state.combatStarted then
		return nil
	end

	if state.activeTurnIndex < 1 or state.activeTurnIndex > #state.combatOrder then
		return nil
	end

	return state.combatOrder[state.activeTurnIndex]
end

local function refresh_turn_and_lock_state(): ()
	cleanup_combat_order()

	local activeEntry = get_active_order_entry()

	for _, player in Players:GetPlayers() do
		local isTurnActive = activeEntry and activeEntry.UserId == player.UserId or false
		local movementLocked = false

		if get_team_name(player) == PLAYER_TEAM_NAME then
			movementLocked = state.manualLocks[player.UserId] == true

			if state.combatStarted then
				movementLocked = movementLocked or not isTurnActive
			end
		end

		player:SetAttribute("IsTurnActive", isTurnActive)
		player:SetAttribute("MovementLocked", movementLocked)
	end
end

local function serialize_players(): {any}
	local playersData = {}

	for _, player in Players:GetPlayers() do
		local entry = ensure_health_entry(player)

		table.insert(playersData, {
			UserId = player.UserId,
			Name = player.Name,
			Label = get_player_label(player),
			RoleName = get_team_name(player),
			ManualMovementLocked = state.manualLocks[player.UserId] == true,
			MovementLocked = player:GetAttribute("MovementLocked") == true,
			IsTurnActive = player:GetAttribute("IsTurnActive") == true,
			CurrentHealth = entry.Current,
			MaxHealth = entry.Max,
		})
	end

	table.sort(playersData, function(a, b)
		return a.Label < b.Label
	end)

	return playersData
end

local function serialize_order(): {any}
	local orderData = {}

	for index, entry in state.combatOrder do
		local player = get_player_by_user_id(entry.UserId)
		local label = player and get_player_label(player) or ("UserId " .. tostring(entry.UserId))
		local roleName = player and get_team_name(player) or ""

		table.insert(orderData, {
			Index = index,
			UserId = entry.UserId,
			Label = label,
			RoleName = roleName,
			IsActive = state.combatStarted and state.activeTurnIndex == index,
		})
	end

	return orderData
end

local function build_snapshot(): {}
	local activeEntry = get_active_order_entry()

	return {
		Action = "Snapshot",
		State = {
			ClockTime = state.clockTime,
			PresetName = state.presetName,
			RainEnabled = state.rainEnabled,
			CombatStarted = state.combatStarted,
			ActiveTurnIndex = state.activeTurnIndex,
			ActiveTurnUserId = activeEntry and activeEntry.UserId or 0,
			Players = serialize_players(),
			Order = serialize_order(),
		},
	}
end

function push_snapshot(targetPlayer: Player?): ()
	local snapshot = build_snapshot()

	if targetPlayer then
		tabletopEvent:FireClient(targetPlayer, snapshot)
		return
	end

	for _, player in Players:GetPlayers() do
		tabletopEvent:FireClient(player, snapshot)
	end
end

local function add_order_entry(userId: number): ()
	local targetPlayer = get_player_by_user_id(userId)

	if not targetPlayer then
		return
	end

	table.insert(state.combatOrder, {
		UserId = userId,
	})
end

local function remove_order_entry(index: number): ()
	if index < 1 or index > #state.combatOrder then
		return
	end

	table.remove(state.combatOrder, index)

	if #state.combatOrder == 0 then
		state.combatStarted = false
		state.activeTurnIndex = 0
		return
	end

	if state.activeTurnIndex > #state.combatOrder then
		state.activeTurnIndex = 1
	end
end

local function set_combat_order(orderUserIds: {any}): ()
	local newOrder = {}

	for index = 1, #orderUserIds do
		local userId = orderUserIds[index]

		if typeof(userId) == "number" then
			local targetPlayer = get_player_by_user_id(userId)

			if targetPlayer then
				table.insert(newOrder, {
					UserId = userId,
				})
			end
		end
	end

	state.combatOrder = newOrder

	if #state.combatOrder == 0 then
		state.combatStarted = false
		state.activeTurnIndex = 0
		return
	end

	if state.activeTurnIndex < 1 or state.activeTurnIndex > #state.combatOrder then
		state.activeTurnIndex = 1
	end
end

local function clear_combat_order(): ()
	state.combatOrder = {}
	state.combatStarted = false
	state.activeTurnIndex = 0
end

local function start_combat(): ()
	if #state.combatOrder == 0 then
		return
	end

	state.combatStarted = true

	if state.activeTurnIndex < 1 or state.activeTurnIndex > #state.combatOrder then
		state.activeTurnIndex = 1
	end
end

local function stop_combat(): ()
	state.combatStarted = false
	state.activeTurnIndex = 0
end

local function advance_turn(): ()
	if not state.combatStarted then
		return
	end

	if #state.combatOrder == 0 then
		state.combatStarted = false
		state.activeTurnIndex = 0
		return
	end

	state.activeTurnIndex += 1

	if state.activeTurnIndex > #state.combatOrder then
		state.activeTurnIndex = 1
	end
end

local function set_player_health(userId: number, currentHealth: number, maxHealth: number): ()
	local targetPlayer = get_player_by_user_id(userId)

	if not targetPlayer then
		return
	end

	local entry = ensure_health_entry(targetPlayer)

	entry.Max = math.max(1, maxHealth)
	entry.Current = math.clamp(currentHealth, 0, entry.Max)

	apply_health_to_character(targetPlayer)
end

local function on_tabletop_request(player: Player, payload: any): ()
	if typeof(payload) ~= "table" then
		return
	end

	local action = payload.Action

	if action == "RequestSnapshot" then
		push_snapshot(player)
		return
	end

	if not is_master(player) then
		return
	end

	if action == "SetClockTime" and typeof(payload.Value) == "number" then
		set_clock_time(payload.Value)
	elseif action == "ApplyPreset" and typeof(payload.PresetName) == "string" then
		apply_preset(payload.PresetName)
	elseif action == "SetRain" and typeof(payload.Enabled) == "boolean" then
		set_rain_enabled(payload.Enabled)
	elseif action == "SetMovementLock" and typeof(payload.UserId) == "number" and typeof(payload.Enabled) == "boolean" then
		state.manualLocks[payload.UserId] = payload.Enabled
	elseif action == "AddOrderEntry" and typeof(payload.UserId) == "number" then
		add_order_entry(payload.UserId)
	elseif action == "RemoveOrderEntry" and typeof(payload.Index) == "number" then
		remove_order_entry(payload.Index)
	elseif action == "SetCombatOrder" and typeof(payload.OrderUserIds) == "table" then
		set_combat_order(payload.OrderUserIds)
	elseif action == "ClearCombatOrder" then
		clear_combat_order()
	elseif action == "StartCombat" then
		start_combat()
	elseif action == "StopCombat" then
		stop_combat()
	elseif action == "NextTurn" then
		advance_turn()
	elseif action == "SetPlayerHealth"
		and typeof(payload.UserId) == "number"
		and typeof(payload.CurrentHealth) == "number"
		and typeof(payload.MaxHealth) == "number" then
		set_player_health(payload.UserId, payload.CurrentHealth, payload.MaxHealth)
	else
		return
	end

	refresh_turn_and_lock_state()
	push_snapshot()
end

local function on_player_added(player: Player): ()
	if player:GetAttribute("MovementLocked") == nil then
		player:SetAttribute("MovementLocked", false)
	end

	if player:GetAttribute("IsTurnActive") == nil then
		player:SetAttribute("IsTurnActive", false)
	end

	ensure_health_entry(player)

	player:GetPropertyChangedSignal("Team"):Connect(function()
		refresh_turn_and_lock_state()
		push_snapshot()
	end)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			connect_character_health(player)
			refresh_turn_and_lock_state()
			push_snapshot()
		end)
	end)

	task.defer(function()
		connect_character_health(player)
		push_snapshot(player)
	end)
end

local function on_player_removing(player: Player): ()
	state.manualLocks[player.UserId] = nil
	state.healthData[player.UserId] = nil

	disconnect_health_connections(player.UserId)

	cleanup_combat_order()
	refresh_turn_and_lock_state()
	push_snapshot()
end

------------------//MAIN FUNCTIONS
tabletopEvent.OnServerEvent:Connect(on_tabletop_request)

------------------//INIT
apply_preset(DEFAULT_PRESET_NAME)
set_rain_enabled(false)
refresh_turn_and_lock_state()

for _, player in Players:GetPlayers() do
	on_player_added(player)
end

Players.PlayerAdded:Connect(on_player_added)
Players.PlayerRemoving:Connect(on_player_removing)