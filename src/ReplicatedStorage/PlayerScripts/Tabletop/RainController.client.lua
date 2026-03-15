------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")
local Workspace: Workspace = game:GetService("Workspace")

------------------//CONSTANTS
local TABLETOP_REMOTE_NAME: string = "TabletopEvent"
local MASTER_TEAM_NAME: string = "Mestre"
local RAIN_MODEL_NAME: string = "Rain"
local RAYCAST_DISTANCE: number = 512
local RAIN_HEIGHT_OFFSET: number = 10
local CLOUDS_TWEEN_DURATION: number = 1

------------------//VARIABLES
local player: Player = Players.LocalPlayer

local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local modelsFolder: Folder = assetsFolder:WaitForChild("Models")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")

local tabletopEvent: RemoteEvent = remotesFolder:WaitForChild(TABLETOP_REMOTE_NAME)
local rainTemplate: BasePart? = modelsFolder:FindFirstChild(RAIN_MODEL_NAME)

local rainPart: BasePart? = nil
local rainWeld: WeldConstraint? = nil
local rainHeartbeatConnection: RBXScriptConnection? = nil
local characterConnection: RBXScriptConnection? = nil
local cloudsTween: Tween? = nil
local isRainEnabled: boolean = false

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

------------------//FUNCTIONS
local function is_master(): boolean
	return player.Team ~= nil and player.Team.Name == MASTER_TEAM_NAME
end

local function get_clouds(): Clouds?
	local terrain = Workspace:FindFirstChild("Terrain")

	if not terrain or not terrain:IsA("Terrain") then
		return nil
	end

	local clouds = terrain:FindFirstChild("Clouds")

	if clouds and clouds:IsA("Clouds") then
		return clouds
	end

	return nil
end

local function tween_cloud_cover(target: number): ()
	local clouds = get_clouds()

	if not clouds then
		return
	end

	if cloudsTween then
		cloudsTween:Cancel()
		cloudsTween = nil
	end

	cloudsTween = TweenService:Create(clouds, TweenInfo.new(CLOUDS_TWEEN_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Cover = target,
	})
	cloudsTween:Play()
end

local function set_particles_enabled(isEnabled: boolean): ()
	if not rainPart then
		return
	end

	local shouldEnable = isEnabled and not is_master()

	for _, descendant in rainPart:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = shouldEnable
		end
	end
end

local function set_sound_playing(isPlaying: boolean): ()
	if not rainPart then
		return
	end

	for _, descendant in rainPart:GetDescendants() do
		if descendant:IsA("Sound") then
			descendant.Looped = true
			descendant.Playing = isPlaying
		end
	end
end

local function ensure_rain_part(character: Model): ()
	if not rainTemplate or not rainTemplate:IsA("BasePart") then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	if rainPart and rainPart.Parent == character and rainWeld and rainWeld.Part1 == rootPart then
		return
	end

	if rainPart then
		rainPart:Destroy()
		rainPart = nil
		rainWeld = nil
	end

	local newRain = rainTemplate:Clone()
	newRain.Name = RAIN_MODEL_NAME
	newRain.Anchored = false
	newRain.CanCollide = false
	newRain.CFrame = rootPart.CFrame * CFrame.new(0, RAIN_HEIGHT_OFFSET, 0)
	newRain.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = newRain
	weld.Part1 = rootPart
	weld.Parent = newRain

	rainPart = newRain
	rainWeld = weld

	set_sound_playing(isRainEnabled)
	set_particles_enabled(isRainEnabled)
end

local function is_rain_blocked(character: Model): boolean
	local head = character:FindFirstChild("Head")

	if not head or not head:IsA("BasePart") then
		return false
	end

	raycastParams.FilterDescendantsInstances = {character}

	local result = Workspace:Raycast(head.Position, Vector3.new(0, RAYCAST_DISTANCE, 0), raycastParams)

	if not result or not result.Instance then
		return false
	end

	local modelAncestor = result.Instance:FindFirstAncestorOfClass("Model")

	if modelAncestor and modelAncestor:FindFirstChildOfClass("Humanoid") then
		return false
	end

	return true
end

local function update_rain_visibility(): ()
	local character = player.Character

	if not character then
		set_particles_enabled(false)
		return
	end

	if not isRainEnabled then
		set_particles_enabled(false)
		return
	end

	set_particles_enabled(not is_rain_blocked(character))
end

local function start_rain_updates(): ()
	if rainHeartbeatConnection then
		return
	end

	rainHeartbeatConnection = RunService.Heartbeat:Connect(update_rain_visibility)
end

local function stop_rain_updates(): ()
	if not rainHeartbeatConnection then
		return
	end

	rainHeartbeatConnection:Disconnect()
	rainHeartbeatConnection = nil
end

local function apply_rain_state(): ()
	local character = player.Character

	if character then
		ensure_rain_part(character)
	end

	set_sound_playing(isRainEnabled)

	if isRainEnabled then
		start_rain_updates()
		update_rain_visibility()
		tween_cloud_cover(1)
		return
	end

	stop_rain_updates()
	set_particles_enabled(false)
	tween_cloud_cover(0)
end

local function on_character_added(character: Model): ()
	ensure_rain_part(character)
	apply_rain_state()
end

local function request_snapshot(): ()
	tabletopEvent:FireServer({
		Action = "RequestSnapshot",
	})
end

------------------//MAIN
if player.Character then
	on_character_added(player.Character)
end

characterConnection = player.CharacterAdded:Connect(on_character_added)

player:GetPropertyChangedSignal("Team"):Connect(apply_rain_state)

tabletopEvent.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" or payload.Action ~= "Snapshot" or typeof(payload.State) ~= "table" then
		return
	end

	if typeof(payload.State.RainEnabled) ~= "boolean" then
		return
	end

	isRainEnabled = payload.State.RainEnabled
	apply_rain_state()
end)

request_snapshot()
