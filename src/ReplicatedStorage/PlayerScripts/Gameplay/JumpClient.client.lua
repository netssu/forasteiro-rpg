------------------//SERVICES
local Players: Players = game:GetService("Players")
local RunService: RunService = game:GetService("RunService")
local UserInputService: UserInputService = game:GetService("UserInputService")
local TweenService: TweenService = game:GetService("TweenService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris: Debris = game:GetService("Debris")
local MarketplaceService: MarketplaceService = game:GetService("MarketplaceService")

------------------//TYPES
type State = {
	is_grounded: boolean,
	current_combo: number,
	distance_to_ground: number,
	can_rebound: boolean,
	queued_jump: boolean,
	visual_bar_pct: number,
	visual_perfect_size: number,
	visual_white_vignette: number,
	current_jump_peak: number,
	last_jump_time: number,
	cooldown_end_time: number,
	is_stunned: boolean,
	original_walkspeed: number,
	visual_fov: number,
	is_falling: boolean,
}

type Settings = {
	base_jump_power: number,
	combo_bonus_power: number,
	max_combo_power_cap: number,
	gravity_mult: number,
	miss_penalty_duration: number,
	stun_duration: number,
	stun_walkspeed: number,
	fov_base: number,
	fov_max: number,
	visual_max_height: number,
	perfect_zone_percent: number,
	crater_enabled: boolean,
	crater_force_scale: number,
	crater_min_impact: number,
	crater_radius_min: number,
	crater_radius_max: number,
	crater_depth_min: number,
	crater_depth_max: number,
	critical_vfx_mult: number,
	crater_min_voxel: number,
	crater_reset_time: number,
	crater_fly_percent: number,
	crater_fly_cap: number,
	crater_debris_time: number,
	crater_vanish_delay: number,
	crater_velocity: number,
	crater_up_boost: number,
	[string]: any 
}

------------------//MODULES
local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility) :: any
local VoxBreaker = require(ReplicatedStorage.Modules.Libraries.VoxBreaker) :: any
local CameraShaker = require(ReplicatedStorage.Modules.Libraries.CameraShaker) :: any
local PopupModule = require(ReplicatedStorage.Modules.Libraries.PopupModule) :: any
local MaterialData = require(ReplicatedStorage.Modules.Datas.MaterialData) :: any
local NotificationUtility = require(ReplicatedStorage.Modules.Utility.NotificationUtility) :: any
local SoundController = require(ReplicatedStorage.Modules.Utility.SoundUtility) :: any
local SoundData = require(ReplicatedStorage.Modules.Datas.SoundData) :: any

------------------//CONSTANTS
local RENDER_STEP_NAME: string = "PogoLogic"
local DEFAULT_GRAVITY: number = 196.2
local JUMP_ANIM_ID: string = "rbxassetid://105821789218134"
local AUTO_JUMP_PASS_ID: number = 1699595369
local EASIER_PERFECT_PASS_ID: number = 1701310636 -- ID DA GAMEPASS

local DIST_SMOOTH_SPEED: number = 25
local BAR_SMOOTH_SPEED: number = 45
local PERFECT_SMOOTH_SPEED: number = 20
local VIGNETTE_SMOOTH: number = 10
local FOV_SMOOTH_SPEED: number = 12

local POWER_STAT_SCALE: number = 0.6

------------------//VARIABLES

local player: Player = Players.LocalPlayer
local camera: Camera = workspace.CurrentCamera or workspace:WaitForChild("Camera") :: Camera

local pogoEvent: RemoteEvent? =
	ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("PogoEvent") :: RemoteEvent

local playerGui: PlayerGui = player:WaitForChild("PlayerGui")
local uiRoot: ScreenGui = playerGui:WaitForChild("UI")
local hud: ScreenGui = uiRoot:WaitForChild("GameHUD")
local gameHud: Instance = uiRoot:WaitForChild("GameHUD")
local bottomBar: Instance = gameHud:WaitForChild("BottomBarFR")
local jumpButton: GuiButton = bottomBar:WaitForChild("JumpBT")
local autoJumpButton: GuiButton = bottomBar:WaitForChild("AutoJumpBT")

local vignette: ImageLabel = hud:WaitForChild("Vignette")
local whiteVignette: ImageLabel = hud:WaitForChild("WhiteVignette")
local barContainer: Frame = hud:WaitForChild("BarContainer")
local barFill: Frame = barContainer:WaitForChild("BarFill")
local perfectZone: Frame = barContainer:WaitForChild("PerfectZone")
local promptLabel: TextLabel = barContainer:WaitForChild("PromptLabel")

local character: Model = player.Character or player.CharacterAdded:Wait()
local rootPart: BasePart = character:WaitForChild("HumanoidRootPart")
local humanoid: Humanoid = character:WaitForChild("Humanoid")

local humanoidStateConn: RBXScriptConnection? = nil
local camShake: any = nil

local last_falling_velocity: number = 0
local last_ground_distance: number = 0
local smooth_ground_distance: number = 0

local last_ground_hit_pos: Vector3? = nil
local last_ground_hit_normal: Vector3? = nil
local last_ground_material: string = "Plastic"

local is_jump_held: boolean = false
local auto_jump_active: boolean = false
local has_auto_jump_pass: boolean = false
local gravityApplied: boolean = false

local jumpAnimation: Animation? = nil
local jumpTrack: AnimationTrack? = nil
local animToken: number = 0
local animHeartbeatConn: RBXScriptConnection? = nil

local afk_jump_count: number = 0
local is_afk_mode: boolean = false

local state: State = {
	is_grounded = true,
	current_combo = 0,
	distance_to_ground = 0,
	can_rebound = false,
	queued_jump = false,
	visual_bar_pct = 0,
	visual_perfect_size = 0,
	visual_white_vignette = 1,
	current_jump_peak = 50,
	last_jump_time = 0,
	cooldown_end_time = 0,
	is_stunned = false,
	original_walkspeed = 16,
	visual_fov = camera.FieldOfView,
	is_falling = false,
}

local SETTINGS: Settings = {
	base_jump_power = 120,
	combo_bonus_power = 8,
	max_combo_power_cap = 250,
	gravity_mult = 1.4,
	miss_penalty_duration = 2,
	stun_duration = 1.5,
	stun_walkspeed = 6,
	fov_base = 70,
	fov_max = 110,
	visual_max_height = 100,

	perfect_zone_percent = 0.3, -- Valor Padrão

	crater_enabled = true,
	crater_force_scale = 0.25,
	crater_min_impact = 40,

	crater_radius_min = 1.8,
	crater_radius_max = 3.0,

	crater_depth_min = 0.8,
	crater_depth_max = 1.5,

	critical_vfx_mult = 1.4,

	crater_min_voxel = 3,
	crater_reset_time = 3,
	crater_fly_percent = 0.4,
	crater_fly_cap = 8,
	crater_debris_time = 4,
	crater_vanish_delay = 0.06,
	crater_velocity = 35,
	crater_up_boost = 45,
}

------------------//FUNCTIONS

local function exp_lerp(a: number, b: number, speed: number, dt: number): number
	local alpha = 1 - math.exp(-speed * dt)
	return a + (b - a) * alpha
end

local function apply_gravity_from_settings()
	workspace.Gravity = DEFAULT_GRAVITY
end

local function update_local_settings(newSettings: { [string]: any }?)
	if not newSettings then return end
	for key, value in pairs(newSettings) do
		SETTINGS[key] = value
	end
end

local function setup_camera_shaker()
	if camShake then camShake:Stop() end
	camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame: CFrame)
		camera.CFrame = camera.CFrame * shakeCFrame
	end)
	camShake:Start()
end

local function raycast_ground(): number
	if not rootPart or not rootPart.Parent or not humanoid or not humanoid.Parent then
		return last_ground_distance
	end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local hit = workspace:Raycast(rootPart.Position, Vector3.new(0, -5000, 0), params)
	if hit then
		last_ground_hit_pos = hit.Position
		last_ground_hit_normal = hit.Normal

		if hit.Material then
			last_ground_material = hit.Material.Name
		end

		local rootHalf = rootPart.Size.Y * 0.5
		local dist = hit.Distance - (humanoid.HipHeight + rootHalf)
		dist = math.max(dist, 0)
		last_ground_distance = dist
		return dist
	end
	return last_ground_distance
end

local function calculate_peak_height(velocity: number): number
	local g = workspace.Gravity
	if g <= 0 then g = 196.2 end
	return (velocity ^ 2) / (2 * g)
end

local function stop_jump_anim()
	animToken += 1
	if animHeartbeatConn then
		animHeartbeatConn:Disconnect()
		animHeartbeatConn = nil
	end
	if jumpTrack then
		jumpTrack:Stop(0)
	end
end

local function play_jump_anim_forward()
	if not jumpTrack then return end
	animToken += 1
	local token = animToken

	if animHeartbeatConn then
		animHeartbeatConn:Disconnect()
		animHeartbeatConn = nil
	end

	if not jumpTrack.IsPlaying then
		jumpTrack:Play(0.5)
	end

	jumpTrack:AdjustSpeed(1)
	jumpTrack.TimePosition = math.max(jumpTrack.TimePosition, 0)

	animHeartbeatConn = RunService.Heartbeat:Connect(function()
		if not jumpTrack or token ~= animToken then return end
		local len = jumpTrack.Length
		if len and len > 0 then
			if jumpTrack.TimePosition >= (len - 0.03) then
				jumpTrack.TimePosition = math.max(len - 0.001, 0)
				jumpTrack:AdjustSpeed(0)
			end
		end
	end)
end

local function play_jump_anim_reverse()
	if not jumpTrack then return end
	animToken += 1
	local token = animToken

	if animHeartbeatConn then
		animHeartbeatConn:Disconnect()
		animHeartbeatConn = nil
	end

	if not jumpTrack.IsPlaying then
		jumpTrack:Play(0.5)
	end

	local len = jumpTrack.Length
	if len and len > 0 then
		if jumpTrack.TimePosition <= 0.02 then
			jumpTrack.TimePosition = math.max(len - 0.001, 0)
		end
	end

	jumpTrack:AdjustSpeed(-1)

	animHeartbeatConn = RunService.Heartbeat:Connect(function()
		if not jumpTrack or token ~= animToken then return end
		if jumpTrack.TimePosition <= 0.02 then
			jumpTrack.TimePosition = 0
			jumpTrack:AdjustSpeed(0)
		end
	end)
end

local function trigger_landing_vfx(impactForce: number, isCritical: boolean)
	if not SETTINGS.crater_enabled then return end
	if is_afk_mode then return end
	if not last_ground_hit_pos or not last_ground_hit_normal then return end

	local matData = MaterialData.Get(last_ground_material)
	local resistance = matData.MinBreakForce or 40

	local force = math.abs(impactForce)

	if force < resistance then return end

	force *= SETTINGS.crater_force_scale

	local effectiveForce = math.max(0, force - (resistance * SETTINGS.crater_force_scale))
	local t = math.clamp(effectiveForce / 120, 0, 1)
	local tCurve = t ^ 0.65

	local radius = SETTINGS.crater_radius_min + (SETTINGS.crater_radius_max - SETTINGS.crater_radius_min) * tCurve
	local depth = SETTINGS.crater_depth_min + (SETTINGS.crater_depth_max - SETTINGS.crater_depth_min) * tCurve

	local flyCapMultiplier = 1

	if isCritical then
		radius *= SETTINGS.critical_vfx_mult
		depth *= SETTINGS.critical_vfx_mult
		flyCapMultiplier = 1.8
	end

	radius *= (1 + 0.6 * tCurve)
	depth *= (1 + 0.8 * tCurve)

	local normal = last_ground_hit_normal.Unit

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }

	local cframe = CFrame.new(last_ground_hit_pos + normal * (depth * 0.15))
	local size = Vector3.new(radius * 2, radius * 2, radius * 2)

	local voxels = VoxBreaker:CreateHitbox(
		size,
		cframe,
		Enum.PartType.Ball,
		SETTINGS.crater_min_voxel,
		SETTINGS.crater_reset_time,
		overlap
	)

	if not voxels or not voxels[1] then return end

	local function return_cached_part(p: BasePart)
		if not p or not p.Parent then return end

		p.AssemblyLinearVelocity = Vector3.zero
		p.AssemblyAngularVelocity = Vector3.zero
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 0

		VoxBreaker:ReturnPart(p :: any)
	end

	local function fade_and_return(p: BasePart, fadeTime: number)
		if not p or not p.Parent then return end
		local tween = TweenService:Create(p, TweenInfo.new(fadeTime), { Transparency = 1 })
		tween:Play()
		tween.Completed:Connect(function()
			if p and p.Parent then
				return_cached_part(p)
			end
		end)
	end

	local center = last_ground_hit_pos
	local removeList: { BasePart } = {}

	for _, v in ipairs(voxels) do
		if v and v.Parent and v:IsA("BasePart") then
			local rel = v.Position - center
			local alongNormal = (-rel):Dot(normal)

			if alongNormal >= -0.9 then
				local planar = rel - normal * rel:Dot(normal)
				local planarDist = planar.Magnitude

				local nVal = math.noise(v.Position.X * 1.1, v.Position.Z * 1.1, 0.5)
				local ruggedRadius = radius * (0.92 + (nVal * 0.28))

				local depthNoise = math.noise(v.Position.X * 0.55, v.Position.Z * 0.55, 42)
				local effectiveDepth = depth * (0.75 + (depthNoise * 0.45))

				if planarDist <= ruggedRadius and alongNormal <= effectiveDepth then
					removeList[#removeList + 1] = v
				end
			end
		end
	end

	local total = #removeList
	if total <= 0 then return end

	local vanishDelay = SETTINGS.crater_vanish_delay or 0.06

	local sideVel = SETTINGS.crater_velocity * (0.8 + 0.7 * tCurve)
	local upVel = SETTINGS.crater_up_boost * (0.45 + 0.35 * tCurve)

	local PIECE_LIFE = 2
	local FADE_TIME = 0.25

	local flyPercent = math.clamp((SETTINGS.crater_fly_percent or 0.25) + (0.25 * tCurve), 0, 1)
	local flyCapBase = SETTINGS.crater_fly_cap or 12
	local flyCap = math.floor((flyCapBase + (flyCapBase * 1.2 * tCurve)) * flyCapMultiplier)

	local up = normal
	local ref = Vector3.new(0, 0, -1)
	if math.abs(up:Dot(ref)) > 0.95 then
		ref = Vector3.new(1, 0, 0)
	end
	local right = (up:Cross(ref)).Unit
	local forward = (right:Cross(up)).Unit

	local spawnedFlying = 0

	for _, v in ipairs(removeList) do
		if v and v.Parent then
			v.Transparency = 1
			v.CanCollide = false
			v.CanQuery = false
			v.CanTouch = false

			task.delay(vanishDelay, function()
				if not v or not v.Parent then return end

				if SETTINGS.crater_reset_time and SETTINGS.crater_reset_time >= 0 then
					v.Transparency = 1
					v.CanCollide = false
					v.CanQuery = false
					v.CanTouch = false
					return
				end

				return_cached_part(v)
			end)

			if spawnedFlying < flyCap and math.random() <= flyPercent then
				spawnedFlying += 1

				local debrisPart: BasePart?
				if VoxBreaker["GetCachedPart"] then
					debrisPart = VoxBreaker:GetCachedPart()
				else
					local p = Instance.new("Part")
					p.Anchored = true
					debrisPart = p
				end

				if debrisPart then
					debrisPart.Size = v.Size
					debrisPart.CFrame = v.CFrame + (normal * (0.75 + (0.35 * tCurve)))
					debrisPart.Color = v.Color
					debrisPart.Material = v.Material
					debrisPart.Transparency = 0

					debrisPart.CanCollide = false
					debrisPart.CanQuery = false
					debrisPart.CanTouch = false
					debrisPart.Anchored = false
					debrisPart.Parent = workspace

					task.delay(0.05, function()
						if debrisPart and debrisPart.Parent then
							debrisPart.CanCollide = true
							debrisPart.CanQuery = true
							debrisPart.CanTouch = true
						end
					end)

					local sx = (math.random(-100, 100) / 100)
					local sz = (math.random(-100, 100) / 100)
					local lateral = (right * sx + forward * sz)
					if lateral.Magnitude < 0.001 then
						lateral = right
					else
						lateral = lateral.Unit
					end

					local finalSideVel = sideVel * (0.75 + math.random() * 0.7)
					local finalUpVel = upVel * (0.7 + math.random() * 0.6)

					if isCritical then
						finalSideVel *= 1.3
						finalUpVel *= 1.3
					end

					debrisPart.AssemblyLinearVelocity = lateral * finalSideVel + up * finalUpVel
					debrisPart.AssemblyAngularVelocity = Vector3.new(
						math.random(-14, 14),
						math.random(-14, 14),
						math.random(-14, 14)
					)

					task.delay(PIECE_LIFE, function()
						if debrisPart and debrisPart.Parent then
							fade_and_return(debrisPart, FADE_TIME)
						end
					end)
				end
			end
		end
	end
end

local function apply_stun()
	if state.is_stunned then return end
	state.is_stunned = true

	if pogoEvent then pogoEvent:FireServer("Stunned", {}) end

	PopupModule.Create(rootPart, "CRASH!", Color3.fromRGB(255, 50, 50), {
		IsCritical = true,
		Direction = Vector3.new(0, 2, 0),
	})

	local attr = player:GetAttribute("Multiplier") :: number?
	local multi = (attr and attr > 0 and attr or 1)

	local maxShakeMagnitude = 6
	local maxShakeRoughness = 12
	local maxDuration = 1.5

	local magnitude = math.clamp(3.5 * (multi * 0.2), 3, maxShakeMagnitude)
	local roughness = math.clamp(8 * multi, 2, maxShakeRoughness)

	if camShake then
		camShake:ShakeOnce(magnitude, roughness, 0.1, maxDuration)
	end

	state.original_walkspeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = SETTINGS.stun_walkspeed

	task.delay(SETTINGS.stun_duration, function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = state.original_walkspeed
		end
		state.is_stunned = false
		if pogoEvent then pogoEvent:FireServer("Land", { status = "Idle" }) end
	end)
end

local function lock_text_visuals()
	promptLabel.Visible = true
	vignette.ImageColor3 = Color3.new(0, 0, 0)
	whiteVignette.ImageColor3 = Color3.new(1, 1, 1)
end

local function perform_jump(isPerfectRebound: boolean, isChained: boolean)
	if not rootPart or not rootPart.Parent or not humanoid or not humanoid.Parent then return end
	if state.is_stunned then return end

	if not isPerfectRebound then 
		local currentJumps = player:GetAttribute("Jumps") :: number? or 0
		player:SetAttribute("Jumps", (currentJumps :: number) + 1)
	end

	state.last_jump_time = os.clock()
	state.is_falling = false

	play_jump_anim_forward()

	local scaledBasePower = SETTINGS.base_jump_power * POWER_STAT_SCALE
	local finalPower = 0
	local comboBonus = state.current_combo * SETTINGS.combo_bonus_power

	if isPerfectRebound then
		local critBonus = SETTINGS.base_jump_power * 0.3
		finalPower = scaledBasePower + comboBonus + critBonus
	else
		finalPower = scaledBasePower + comboBonus

		local visualBar = math.clamp(state.visual_bar_pct, 0, 1)
		local timingMultiplier = 1.5 - visualBar
		finalPower *= timingMultiplier
	end

	finalPower = math.min(finalPower, SETTINGS.max_combo_power_cap)

	local velocityLimited = finalPower / math.sqrt(SETTINGS.gravity_mult)
	state.current_jump_peak = math.max(calculate_peak_height(velocityLimited), 10)

	local currentVel = rootPart.AssemblyLinearVelocity
	rootPart.AssemblyLinearVelocity = Vector3.new(currentVel.X, velocityLimited, currentVel.Z)

	humanoid.JumpPower = 0
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	state.is_grounded = false

	SoundController.PlaySFX(SoundData.SFX.Jump, rootPart)

	local TutorialEvent = ReplicatedStorage.Modules.Utility:FindFirstChild("TutorialEvent") :: RemoteEvent?

	if isPerfectRebound then
		if TutorialEvent then TutorialEvent:Fire("PerfectJump") end

		state.current_combo += 1
		local comboColor = Color3.fromRGB(255, 200, 50)
		local isHighCombo = false
		if state.current_combo >= 5 then
			comboColor = Color3.fromRGB(255, 100, 255)
			isHighCombo = true
		end

		PopupModule.Create(rootPart, "x" .. state.current_combo, comboColor, {
			Direction = Vector3.new(math.random(-2, 2), 2, 0),
			Spread = 1,
			IsCritical = isHighCombo,
		})

		-- Lógica do Flash Branco (modificada para não usar TweenService que conflita com o loop)
		whiteVignette.ImageColor3 = Color3.new(1, 1, 1) -- Força branco para o flash
		state.visual_white_vignette = 0.2 -- Define transparencia baixa (muito visível) instantaneamente

		if pogoEvent then
			pogoEvent:FireServer("Rebound", { combo = state.current_combo, isCritical = true, impactForce = math.abs(last_falling_velocity) })
		end
	else
		if TutorialEvent then TutorialEvent:Fire("Jump") end

		if state.current_combo > 0 then
			PopupModule.Create(rootPart, "x0", Color3.fromRGB(255, 80, 80), {
				Direction = Vector3.new(0, 2, 0),
				Spread = 1,
				IsCritical = false,
			})
		end

		state.current_combo = 0
		if isChained then
			if pogoEvent then pogoEvent:FireServer("Jump", { impactForce = math.abs(last_falling_velocity) }) end
		else
			if pogoEvent then pogoEvent:FireServer("Jump", { impactForce = math.abs(last_falling_velocity) }) end
		end
	end

	state.can_rebound = false
	state.queued_jump = false
	state.visual_perfect_size = 0
	perfectZone.Visible = false
	barFill.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
end

local function land()
	local visualImpact = last_falling_velocity * 0.8
	state.is_falling = false

	stop_jump_anim()

	local currentVel = rootPart.AssemblyLinearVelocity
	local horizSpeed = Vector3.new(currentVel.X, 0, currentVel.Z).Magnitude

	if is_jump_held and not state.queued_jump and horizSpeed < 2 then
		afk_jump_count += 1
	else
		afk_jump_count = 0
		if is_afk_mode then
			is_afk_mode = false
			NotificationUtility:Success("Welcome back! VFX Enabled.", 4)
		end
	end

	if afk_jump_count > 5 and not is_afk_mode then
		is_afk_mode = true
		NotificationUtility:Warning("You seem AFK. Destruction VFX disabled for performance.", 5)
	end

	if state.queued_jump and not state.is_stunned then
		perform_jump(true, true)
		trigger_landing_vfx(math.abs(last_falling_velocity), true)
		return
	elseif (is_jump_held or (auto_jump_active and has_auto_jump_pass)) and not state.is_stunned then
		perform_jump(false, true)
		trigger_landing_vfx(math.abs(last_falling_velocity), false)
		return
	end

	if state.is_grounded then return end

	trigger_landing_vfx(math.abs(last_falling_velocity), false)

	if last_falling_velocity < -40 then
		apply_stun()
		if pogoEvent then pogoEvent:FireServer("Land", { status = "Stunned" }) end
	else
		if pogoEvent then pogoEvent:FireServer("Land", { status = "Cooldown" }) end
	end

	state.is_grounded = true
	state.can_rebound = false
	state.current_combo = 0
	state.cooldown_end_time = os.clock() + SETTINGS.miss_penalty_duration
end

local function handle_input()
	local now = os.clock()
	if state.is_stunned then return end

	if state.is_grounded then
		if now < state.cooldown_end_time then return end
		perform_jump(false, false)
		return
	end

	if state.can_rebound then
		state.queued_jump = true
		barFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	end
end

------------------//MAIN FUNCTIONS
local function update_loop(dt: number)
	if not rootPart or not rootPart.Parent or not humanoid or not humanoid.Parent then return end

	local velocity = rootPart.AssemblyLinearVelocity
	local speedTotal = velocity.Magnitude
	local now = os.clock()

	state.distance_to_ground = raycast_ground()
	smooth_ground_distance = exp_lerp(smooth_ground_distance, state.distance_to_ground, DIST_SMOOTH_SPEED, dt)
	state.distance_to_ground = smooth_ground_distance

	if math.abs(velocity.Y) < 5 and state.distance_to_ground < 3.5 then
		if not state.is_grounded then land() end
	end

	if state.is_grounded and (is_jump_held or (auto_jump_active and has_auto_jump_pass)) and not state.is_stunned then
		if now >= state.cooldown_end_time then perform_jump(false, true) end
	end

	if velocity.Y < 0 then
		last_falling_velocity = velocity.Y
		if not state.is_grounded and not state.is_falling and velocity.Y < -2 then
			state.is_falling = true
			play_jump_anim_reverse()
		end
	else
		if not state.is_grounded then
			state.is_falling = false
		end
	end

	local targetFov = SETTINGS.fov_base
	local targetBarPct = 0
	local targetPerfectSize = 0

	local targetScale = 1

	barFill.BackgroundTransparency = 0
	perfectZone.BackgroundTransparency = 0

	barContainer.Rotation = exp_lerp(barContainer.Rotation, 0, BAR_SMOOTH_SPEED, dt)

	-- 1. Vinheta Escura (Normal, baseada em velocidade)
	local targetVignetteTransparency = 1
	-- Removida a verificação do auto_jump aqui, agora a vinheta escura só reage à velocidade
	if velocity.Y > 10 then
		local speedFactor = math.clamp((velocity.Y - 10) / 100, 0, 0.6)
		targetVignetteTransparency = 1 - speedFactor
	end
	vignette.ImageTransparency = exp_lerp(vignette.ImageTransparency, targetVignetteTransparency, VIGNETTE_SMOOTH, dt)

	-- 2. Vinheta Clara/Verde (Auto Jump & Flash de Perfect)
	local targetWhiteTransparency = 1
	local targetWhiteColor = Color3.new(1, 1, 1) -- Branco padrão

	if auto_jump_active then
		targetWhiteTransparency = 0.5 -- Define o quão visível é a luz verde (menor = mais forte)
		targetWhiteColor = Color3.fromRGB(50, 255, 100) -- Verde AutoJump
	end

	-- Interpola a cor atual para a cor alvo (permite transição suave de Branco->Verde após um Perfect Jump)
	whiteVignette.ImageColor3 = whiteVignette.ImageColor3:Lerp(targetWhiteColor, dt * 5)

	-- Interpola a transparência atual para o alvo
	state.visual_white_vignette = exp_lerp(state.visual_white_vignette, targetWhiteTransparency, VIGNETTE_SMOOTH, dt)
	whiteVignette.ImageTransparency = state.visual_white_vignette

	if state.is_grounded then
		promptLabel.Text = "JUMP!"
		targetScale = 1

		if now < state.cooldown_end_time or state.is_stunned then
			local remaining = state.cooldown_end_time - now
			local duration = state.is_stunned and SETTINGS.stun_duration or SETTINGS.miss_penalty_duration
			targetBarPct = math.clamp(remaining / duration, 0, 1)
			barFill.BackgroundColor3 = Color3.fromRGB(110, 125, 145)
		else
			targetBarPct = 0
			if auto_jump_active then
				barFill.BackgroundColor3 = Color3.fromRGB(50, 255, 100)
			else
				barFill.BackgroundColor3 = Color3.fromRGB(0, 160, 255)
			end
		end
	else
		targetBarPct = math.clamp(state.distance_to_ground / state.current_jump_peak, 0, 1)
		targetPerfectSize = SETTINGS.perfect_zone_percent

		if velocity.Y > 0 then
			promptLabel.Text = "WAIT..."
			targetScale = 1.0

			if auto_jump_active then
				barFill.BackgroundColor3 = is_jump_held and Color3.fromRGB(30, 180, 60) or Color3.fromRGB(50, 255, 100)
			else
				barFill.BackgroundColor3 = is_jump_held and Color3.fromRGB(0, 60, 180) or Color3.fromRGB(0, 190, 255)
			end

		elseif velocity.Y < -5 then

			local inWindow = targetBarPct <= SETTINGS.perfect_zone_percent

			if inWindow then
				state.can_rebound = true
				promptLabel.Text = "TAP NOW!"
				barFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

				local pulse = (math.sin(now * 20) * 0.05) + 1.3
				targetScale = pulse

			else
				state.can_rebound = false
				state.queued_jump = false
				promptLabel.Text = "PREPARE..."

				local tensionFactor = math.clamp(1 - targetBarPct, 0, 1)
				targetScale = 1 + (tensionFactor * 0.15)

				if auto_jump_active then
					barFill.BackgroundColor3 = is_jump_held and Color3.fromRGB(30, 180, 60) or Color3.fromRGB(50, 255, 100)
				else
					barFill.BackgroundColor3 = is_jump_held and Color3.fromRGB(0, 60, 180) or Color3.fromRGB(0, 190, 255)
				end
			end
		else
			promptLabel.Text = "WAIT..."
			targetScale = 1.0
			state.can_rebound = false

			if auto_jump_active then
				barFill.BackgroundColor3 = is_jump_held and Color3.fromRGB(30, 180, 60) or Color3.fromRGB(50, 255, 100)
			else
				barFill.BackgroundColor3 = is_jump_held and Color3.fromRGB(0, 60, 180) or Color3.fromRGB(0, 190, 255)
			end
		end
	end

	local containerScale = barContainer:FindFirstChild("UIScale") :: UIScale
	if not containerScale then
		containerScale = Instance.new("UIScale")
		containerScale.Parent = barContainer
	end

	containerScale.Scale = exp_lerp(containerScale.Scale, targetScale, 20, dt)

	state.visual_bar_pct = exp_lerp(state.visual_bar_pct, targetBarPct, BAR_SMOOTH_SPEED, dt)
	barFill.Size = UDim2.new(math.clamp(state.visual_bar_pct, 0, 1), 0, 1, 0)

	state.visual_perfect_size = exp_lerp(state.visual_perfect_size, targetPerfectSize, PERFECT_SMOOTH_SPEED, dt)
	local clampedPerfectSize = math.min(state.visual_perfect_size, state.visual_bar_pct)

	if not state.is_grounded and clampedPerfectSize > 0.001 then
		perfectZone.Size = UDim2.new(clampedPerfectSize, 0, 1, 0)
		perfectZone.Visible = true
		perfectZone.BackgroundColor3 = Color3.fromRGB(100, 220, 255)
	else
		perfectZone.Visible = false
	end

	if speedTotal > 10 then
		local percent = math.clamp(speedTotal / 200, 0, 1)
		targetFov = SETTINGS.fov_base + (SETTINGS.fov_max - SETTINGS.fov_base) * percent
	end
	state.visual_fov = exp_lerp(state.visual_fov, targetFov, FOV_SMOOTH_SPEED, dt)
	camera.FieldOfView = state.visual_fov
end

local function bind_character(newCharacter: Model)
	character = newCharacter
	rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	humanoid = character:WaitForChild("Humanoid") :: Humanoid

	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0

	task.spawn(function()
		pcall(function()
			local touchGui = playerGui:WaitForChild("TouchGui", 5) :: ScreenGui?
			if touchGui then
				local touchFrame = touchGui:FindFirstChild("TouchControlFrame")
				if touchFrame then
					local jumpBtn = touchFrame:FindFirstChild("JumpButton") :: GuiButton?
					if jumpBtn then
						jumpBtn.Visible = false
					end
				end
			end
		end)

	end)

	state.is_grounded = true
	state.current_combo = 0
	state.distance_to_ground = 0
	state.can_rebound = false
	state.queued_jump = false
	state.visual_bar_pct = 0
	state.visual_perfect_size = 0
	state.visual_white_vignette = 1
	state.last_jump_time = 0
	state.cooldown_end_time = 0
	state.is_stunned = false
	state.current_jump_peak = SETTINGS.visual_max_height
	state.is_falling = false

	last_falling_velocity = 0
	last_ground_distance = 0
	smooth_ground_distance = 0
	last_ground_hit_pos = nil
	last_ground_hit_normal = nil

	lock_text_visuals()
	setup_camera_shaker()

	gravityApplied = false
	apply_gravity_from_settings()

	animToken += 1
	if animHeartbeatConn then
		animHeartbeatConn:Disconnect()
		animHeartbeatConn = nil
	end

	if jumpTrack then
		jumpTrack:Stop(0)
		jumpTrack = nil
	end

	jumpAnimation = Instance.new("Animation")
	jumpAnimation.AnimationId = JUMP_ANIM_ID
	jumpTrack = humanoid:LoadAnimation(jumpAnimation)
	jumpTrack.Looped = false
	jumpTrack.Priority = Enum.AnimationPriority.Action

	if humanoidStateConn then
		humanoidStateConn:Disconnect()
		humanoidStateConn = nil
	end

	humanoidStateConn = humanoid.StateChanged:Connect(function(_, newState: Enum.HumanoidStateType)
		if newState == Enum.HumanoidStateType.Landed then
			land()
		elseif newState == Enum.HumanoidStateType.Freefall or newState == Enum.HumanoidStateType.Jumping then
			state.is_grounded = false
		end
	end)
end

------------------//INIT

task.wait(2)

DataUtility.client.ensure_remotes()

local initialSettings = DataUtility.client.get("PogoSettings")
update_local_settings(initialSettings)
apply_gravity_from_settings()

DataUtility.client.bind("PogoSettings", function(newSettings: { [string]: any })
	update_local_settings(newSettings)
end)

DataUtility.client.bind("PogoSettings.base_jump_power", function(newPower: number)
	SETTINGS.base_jump_power = newPower
end)

DataUtility.client.bind("PogoSettings.gravity_mult", function(newMult: number)
	SETTINGS.gravity_mult = newMult
	gravityApplied = false
end)

local success, owns = pcall(function()
	return MarketplaceService:UserOwnsGamePassAsync(player.UserId, EASIER_PERFECT_PASS_ID)
end)

if success and owns then
	SETTINGS.perfect_zone_percent = 0.5
end

barFill.AnchorPoint = Vector2.new(0, 0)
barFill.Position = UDim2.new(0, 0, 0, 0)
barFill.Size = UDim2.new(0, 0, 1, 0)

perfectZone.AnchorPoint = Vector2.new(0, 0)
perfectZone.Position = UDim2.new(0, 0, 0, 0)
perfectZone.Size = UDim2.new(0, 0, 1, 0)

lock_text_visuals()

last_ground_distance = SETTINGS.visual_max_height
smooth_ground_distance = SETTINGS.visual_max_height

bind_character(character)

player.CharacterAdded:Connect(function(newCharacter: Model)
	bind_character(newCharacter)
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr: Player, passId: number, wasPurchased: boolean)
	if plr == player and wasPurchased then
		if passId == AUTO_JUMP_PASS_ID then
			has_auto_jump_pass = true
			if autoJumpButton then autoJumpButton.Visible = true end
		elseif passId == EASIER_PERFECT_PASS_ID then
			SETTINGS.perfect_zone_percent = 0.5
		end
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.Space or input.UserInputType == Enum.UserInputType.Touch then
		is_jump_held = true
		handle_input()
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject, gpe: boolean)
	if input.KeyCode == Enum.KeyCode.Space or input.UserInputType == Enum.UserInputType.Touch then
		is_jump_held = false
	end
end)

if jumpButton then
	jumpButton.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			is_jump_held = true
			handle_input()
		end
	end)

	jumpButton.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			is_jump_held = false
		end
	end)
end

if autoJumpButton then
	autoJumpButton.MouseButton1Click:Connect(function()
		if not has_auto_jump_pass then
			MarketplaceService:PromptGamePassPurchase(player, AUTO_JUMP_PASS_ID)
			return
		end

		auto_jump_active = not auto_jump_active

		local targetSize = auto_jump_active and UDim2.new(1.2, 0, 1.2, 0) or UDim2.new(1, 0, 1, 0)
		TweenService:Create(autoJumpButton, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = targetSize
		}):Play()
	end)
end

task.spawn(function()
	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, AUTO_JUMP_PASS_ID)
	end)

	if success and owns then
		has_auto_jump_pass = true
		if autoJumpButton then
			autoJumpButton.Visible = true
		end
	end
end)

RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, update_loop)