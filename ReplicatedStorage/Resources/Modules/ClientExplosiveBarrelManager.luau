local ClientExplosiveBarrelManager = {}

local CollectionService = game:GetService("CollectionService")

local RenderController
ClientExplosiveBarrelManager.Initialized = false

local VFXs = game.ReplicatedStorage.Resources.VFX.ExplosiveBarrel
local BarrelEvent = game.ReplicatedStorage.Resources.Events.Barrel

function ClientExplosiveBarrelManager:BindBarrel(instance: MeshPart)
	local Connections = {}
	
	
	local function Exploded()
		if instance and instance.Parent and instance:GetAttribute("Exploded") and not instance:GetAttribute("ClientExploded") then
			instance:SetAttribute("ClientExploded", true)
			
			for _, child in instance:GetDescendants() do
				if child:IsA("ParticleEmitter")  then
					child.Enabled = false
				elseif child:IsA("Sound") and child.Name ~= "BarrelExplode" then
					child:Destroy()
				end
			end
			
			local ExplodeSound = instance:FindFirstChild("BarrelExplode")
			if ExplodeSound then
				ExplodeSound:Play()
			end
			
			instance.Transparency = 1
			instance.Anchored = true
			instance.CanCollide = false
			instance.Parent = workspace.VFX
			
			local VFX = VFXs.Explosion:Clone()
			VFX.Parent = instance
			
			
			RenderController:EmitParticles(VFX)
			
			task.wait(2)
			
			if instance and instance.Parent then
				instance:Destroy()
			end
			if VFX and VFX.Parent then
				VFX:Destroy()
			end
		end
	end

	local function BeenShot(localHitCFrame)
		if not instance or not instance.Parent then
			return
		end

		if instance:GetAttribute("ClientExploded") then
			return
		end

		local size = instance.Size
		local radius = math.max(size.X, size.Z) * 0.5 + 0.02

		local lp = localHitCFrame.Position
		local flat = Vector3.new(lp.X, 0, lp.Z)

		if flat.Magnitude > 0 then
			flat = flat.Unit * radius
		end

		local localPos = Vector3.new(flat.X, lp.Y, flat.Z)

		local Direction = CFrame.lookAt(instance.CFrame.Position, instance.CFrame.Position + localHitCFrame.Position)
		local hitCFrame = CFrame.new(localPos) * CFrame.Angles(Direction:ToOrientation())

		local FireAttachment = VFXs.FireHole:Clone()
		FireAttachment.Parent = instance
		FireAttachment.CFrame = hitCFrame

		FireAttachment.GasLeak:Play()

		for _, particle in FireAttachment:GetChildren() do
			if particle:IsA("ParticleEmitter") then
				particle.Enabled = true
			end
		end
	end

	
	local function OnFire()
		if instance:GetAttribute("OnFire") and not instance:GetAttribute("ClientOnFire") and not instance:GetAttribute("ClientExploded") then
			instance:SetAttribute("ClientOnFire", true)
			
			local ExplodeSound = game.SoundService.MapSounds.BarrelExplode:Clone()
			ExplodeSound.Parent = instance
			
			local BurningSound = game.SoundService.MapSounds.BarrelBurning:Clone()
			BurningSound.Parent = instance
			
			BurningSound:Play()
			local FireVFX = VFXs.OnFire:GetChildren()
			for _, Fire in FireVFX do
				Fire = Fire:Clone()
				Fire.Parent = instance
				Fire.Enabled = true
			end
		end
	end

	local function Cleanup()
		if not Connections then return end
		
		for i,v in Connections do
			v:Disconnect()
		end
		Connections = nil
	end
	
	
	local ID = instance:GetAttribute("ID")	
	table.insert(Connections, BarrelEvent.OnClientEvent:Connect(function(_ID, offset)
		if ID == _ID then
			BeenShot(offset)
		end
	end))
		
	
	table.insert(Connections, instance:GetAttributeChangedSignal("ID"):Once(function()
		ID = instance:GetAttribute("ID")
	end))
	table.insert(Connections, instance:GetAttributeChangedSignal("Exploded"):Once(function()
		Exploded()
	end))
	table.insert(Connections, instance:GetAttributeChangedSignal("OnFire"):Once(function()
		OnFire()
	end))
	table.insert(Connections, instance.Destroying:Connect(function()
		Cleanup()
	end))
end

function ClientExplosiveBarrelManager.Init()
	if ClientExplosiveBarrelManager.Initialized then
		return
	end
	
	ClientExplosiveBarrelManager.Initialized = true
	
	RenderController = _G.Controllers.RenderController

	local Barrels = CollectionService:GetTagged("ExplosiveBarrel")
	CollectionService:GetInstanceAddedSignal("ExplosiveBarrel"):Connect(function(instance)
		ClientExplosiveBarrelManager:BindBarrel(instance)
	end)
	
	for _, instance in Barrels do
		ClientExplosiveBarrelManager:BindBarrel(instance)
	end
end


return ClientExplosiveBarrelManager