---------------------------//SERVICES
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

----------------------------//VARIABLES
local statusEffect = {}

---------------------------//CONTANTS
local DEFAULT_BLEEDING_CONSTANTS = {
	totalTime = 10,
	damagePerLevel = 1,
	levelMax = 5,
	tickTime = 0.2
}

local STUNN_CONSTANTS = {
	totalTime = 0.3,
}

----------------------------//EFFECTS FUNCTIONS
statusEffect.Stun = function(cfg : {})
	local character = cfg.character
	local isHeadshot = cfg.IsHeadshot
	local player = cfg.player
	
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	
	
	
end

statusEffect.BackStab = function(cfg : {})
	local character = cfg.character
	local isHeadshot = cfg.IsHeadshot
	local player = cfg.player
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local source = player.Character
	
	if not source then
		return
	end

	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end

	if not source then
		return
	end

	local sourceRoot = source:FindFirstChild("HumanoidRootPart")
	if not sourceRoot then
		return
	end

	local vectorToAttacker = (sourceRoot.Position - rootPart.Position).Unit
	local targetLookVector = rootPart.CFrame.LookVector

	local dotProduct = targetLookVector:Dot(vectorToAttacker)

	if dotProduct < -0.2 then
		humanoid.Health = 0
		if _G.Services and _G.Services.KillService then
			_G.Services.KillService:Kill(player, character)
		end
		local backstabvfx = ReplicatedStorage.Resources.VFX.BackstabVFXAttachment:Clone()
		backstabvfx.Parent = rootPart
		backstabvfx.BackstabVFX:Emit(backstabvfx.BackstabVFX:GetAttribute("EmitCount"))
		
		local backstabSound = SoundService.EffectSounds.Backstab:Clone()
		backstabSound.Parent = rootPart
		backstabSound:Play()
		game.Debris:AddItem(backstabSound, 3)
		game.Debris:AddItem(backstabvfx, 3)
	end
end

statusEffect.Decapitation = function(cfg : {})
	local character = cfg.character
	local checkHS = cfg.checkHS
	local player = cfg.player
	
	local humanoid = character:FindFirstChild("Humanoid")
	local head = character:FindFirstChild("Head")

	if not checkHS then
		return
	end

	--if not humanoid or not head then
	--	return
	--end

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") then
			if descendant.Name == "Neck" then
				descendant:Destroy()
			end
		end
	end
	
	local ripheadsound = SoundService.EffectSounds.RipHead:Clone()
	ripheadsound.Parent = head
	ripheadsound:Play()
	game.Debris:AddItem(ripheadsound, 3)
	
	head.CanCollide = true
	head:ApplyImpulse(Vector3.new(0, 50 * head:GetMass(), 0))
	head:ApplyAngularImpulse(Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10)))
end

statusEffect.Bleeding = function(cfg : {})
	local character = cfg.character
	local isHeadshot = cfg.IsHeadshot
	local player = cfg.player
	local BleedingSounds = SoundService.EffectSounds.Bleeding:GetChildren()
	
	local bleedingSettings = cfg.commons.BLEEDING_CONSTANTS or DEFAULT_BLEEDING_CONSTANTS
	
	local humanoid = character:FindFirstChildOfClass("Humanoid") 
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local currentLevel = character:GetAttribute("Bleeding") or 0
	local newLevel = math.min(currentLevel + 1, bleedingSettings.levelMax)

	character:SetAttribute("Bleeding", newLevel)
	character:SetAttribute("BleedingExpire", os.clock() + bleedingSettings.totalTime)

	if character:GetAttribute("BleedingActive") then
		return
	end

	character:SetAttribute("BleedingActive", true)
	local RandomBleed = BleedingSounds[math.random(1, #BleedingSounds)]:Clone()
	RandomBleed.Parent = character:FindFirstChild("HumanoidRootPart")
	RandomBleed:Play()
	
	
	local BleedingVFX = ReplicatedStorage.Resources.VFX.BloodVFX.Bleeding:Clone()
	BleedingVFX.Parent = character:FindFirstChild("Torso")


	task.spawn(function()
		while character and character.Parent do
			local expireTime = character:GetAttribute("BleedingExpire") or 0
			if os.clock() > expireTime then
				break
			end

			if humanoid.Health <= 0 then
				break
			end

			local level = character:GetAttribute("Bleeding") or 1
			local damage = level * bleedingSettings.damagePerLevel

			humanoid:TakeDamage(damage)

			if humanoid.Health <= 0 then
				if _G.Services and _G.Services.KillService then
					_G.Services.KillService:Kill(player, character)
				end
				break
			end

			task.wait(bleedingSettings.tickTime)
		end

		if character then
			character:SetAttribute("Bleeding", nil)
			character:SetAttribute("BleedingExpire", nil)
			character:SetAttribute("BleedingActive", nil)
			task.spawn(function()
				BleedingVFX.Enabled = false
				TweenService:Create(RandomBleed, TweenInfo.new(3), {Volume = 0}):Play()
				task.wait(3)
				RandomBleed:Destroy()
				BleedingVFX:Destroy()
			end)
		end
	end)
end

----------------------------//FUNCTIONS
function statusEffect:apply_status_effect(statusName : string, cfg : {}) : ()
	local character = cfg.character
	
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if humanoid.Health <= 0 then
		return
	end

	local effectFunction = statusEffect[statusName]
	if not effectFunction then
		return
	end

	effectFunction(cfg)
end

return statusEffect