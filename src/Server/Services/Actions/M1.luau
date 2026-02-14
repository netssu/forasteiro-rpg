local module = {}

------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

------------------//DEPENDENCIES
local Cooldown = require(ReplicatedStorage.Modules.Core.Cooldown)
local PinataService = require(ServerScriptService.Services.PinataService)
local WeaponsData = require(ReplicatedStorage.Modules.Constants.WeaponsData)
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local MetaPlayer = require(ServerScriptService.Modules.Core.MetaPlayer)

------------------//CONSTANTS
local HITBOX_SIZE = Vector3.new(8, 8, 8)
local SLOW_WALK_SPEED = 8
local DEFAULT_WALK_SPEED = 16

------------------//PUBLIC FUNCTIONS
function module.OnStart(player: Player, packet: any)
	warn("Clicked")
	if Cooldown:HasCooldown(player, "M1") then return end
	
	local character = player.Character
	if not character then return end
	
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	if not root or not humanoid then return end

	local equippedName = PlayerDataManager:Get(player, {"Inventory", "EquippedWeapon"})
	local weaponData = WeaponsData[equippedName] or WeaponsData["RustyKnife"]
	if not weaponData then return end
	
	local hitAnimation = ReplicatedStorage.Assets.Animations:FindFirstChild("Hit")
	if hitAnimation then
		local animator = humanoid:FindFirstChild("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		
		local track = animator:LoadAnimation(hitAnimation)
		track:Play(0.15)
	end

	local attackId = tick()
	character:SetAttribute("LastM1", attackId)
	humanoid.WalkSpeed = SLOW_WALK_SPEED
	
	task.delay(weaponData.Cooldown, function()
		if character and character.Parent and character:GetAttribute("LastM1") == attackId then
			humanoid.WalkSpeed = DEFAULT_WALK_SPEED
		end
	end)

	local metaPlayer = MetaPlayer.Get(player)
	if not metaPlayer then return end

	local plot = metaPlayer.Cache.Plot
	if not plot then return end

	local pinataFolder = plot:FindFirstChild("Pinata")
	if not pinataFolder then return end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { pinataFolder }
	
	local hitboxCFrame = root.CFrame * CFrame.new(0, 0, -3)
	local partsFound = workspace:GetPartBoundsInBox(hitboxCFrame, HITBOX_SIZE, overlapParams)
	
	local hitTargets = {}
	
	for _, part in partsFound do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not hitTargets[model] then
			if model:GetAttribute("Type") == "Pinata" then
				hitTargets[model] = true
				
				PinataService:ApplyDamage(player, model, weaponData.Damage)
				break 
			end
		end
	end
	
	Cooldown:SetCooldown(player, "M1", weaponData.Cooldown)
end

return module