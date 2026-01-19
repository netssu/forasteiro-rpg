local ExplosiveBarrelManager = {}

local CollectionService = game:GetService("CollectionService")
ExplosiveBarrelManager.Initialized = false

local BarrelEvent = game.ReplicatedStorage.Resources.Events.Barrel

ExplosiveBarrelManager.SETTINGS = {
	NORMAL = {
		HEALTH = 100,
		DAMAGE_PER_STUD = 150,
		RANGE = 20,
	},
}

local Barrels = {}

function ExplosiveBarrelManager:DeleteBarrel(instance: MeshPart)
	pcall(function()
		instance:Destroy()
	end)
	
	local data = Barrels[instance]
	if data then
		for k in data do
			data[k] = nil
		end
		
		Barrels[instance] = nil
	end
end

function ExplosiveBarrelManager:NewBarrel(instance: MeshPart)
	if not instance:IsDescendantOf(workspace) then
		return
	end
	
	Barrels[instance] = {
		Health = ExplosiveBarrelManager.SETTINGS.NORMAL.HEALTH,
		Type = string.upper(instance:GetAttribute("Type") or "NORMAL")
	}
	local BarrelID = math.random(0, 99999)
	instance:SetAttribute("ID", BarrelID)
	instance.Name = BarrelID
	instance.Anchored = false
	local success, err = pcall(function()
		instance:SetNetworkOwner(nil)
	end)
	if not success then
		warn("ExplosiveBarrelManager:NewBarrel", err)
	end
end

function ExplosiveBarrelManager:Knockback(Character: Model, instance: MeshPart, damage: number, weapon: string, hitPos: Vector3)
	local Direction = (instance:GetPivot().Position - Character:GetPivot().Position).Unit
	
	if weapon == "Melee" then
		instance:ApplyImpulseAtPosition(Direction * 100, hitPos)
		local BurningSound = game.SoundService.MapSounds.BarrelHit:Clone()
		BurningSound.Parent = instance
		BurningSound:Play()	
		game.Debris:AddItem(BurningSound, 3)
	else
		instance:ApplyImpulseAtPosition(Direction * (damage * 1.5), hitPos)
	end
end

function ExplosiveBarrelManager:Explode(instance: MeshPart)
	instance:SetAttribute("Exploded", true)
	local data = Barrels[instance]
	if not data then
		return
	end
	
	data.Exploded = true
	
	local EntitiesInRadius = {}
	for _, Entity in workspace.Entity:GetChildren() do
		local Distance = (Entity:GetPivot().Position - instance:GetPivot().Position).Magnitude
		if Distance <= ExplosiveBarrelManager.SETTINGS[data.Type].RANGE then
			EntitiesInRadius[Entity] = Distance
		end
	end
	
	local BarrelsInRadius = {}
	for Barrel in Barrels do
		if Barrel == instance then
			continue
		end
		local Distance = (Barrel:GetPivot().Position - instance:GetPivot().Position).Magnitude
		if Distance <= ExplosiveBarrelManager.SETTINGS[data.Type].RANGE then
			BarrelsInRadius[Barrel] = Distance
		end
	end

	
	for Entity, Distance in EntitiesInRadius do
		local Humanoid = Entity:FindFirstChildOfClass("Humanoid")
		if not Humanoid then
			continue
		end
		
		local DistanceFactor = math.clamp(Distance / ExplosiveBarrelManager.SETTINGS[data.Type].RANGE, 0, 1)
		local Damage = (1 - DistanceFactor) * ExplosiveBarrelManager.SETTINGS[data.Type].DAMAGE_PER_STUD 
		Humanoid:TakeDamage(Damage)
	end
	
	for Barrel, Distance in BarrelsInRadius do
		local DistanceFactor = math.clamp(Distance / ExplosiveBarrelManager.SETTINGS[data.Type].RANGE, 0, 1)
		local Damage = (1 - DistanceFactor) * ExplosiveBarrelManager.SETTINGS[data.Type].DAMAGE_PER_STUD * 2
		
		
		if Barrels[Barrel].Health - Damage <= 0 then
			if Barrels[Barrel].Health > 50 then
				Barrels[Barrel].Health = 50
				ExplosiveBarrelManager:DamageUpdate(Barrel)
			end
			task.delay(math.random(100, 200) / 100, function()
				if not Barrels[Barrel] then
					return
				end
				Barrels[Barrel].Health -= Damage
				ExplosiveBarrelManager:DamageUpdate(Barrel)
			end)
		end
		ExplosiveBarrelManager:Knockback(instance, Barrel, Damage / 1.5, nil, Barrel:GetPivot().Position)
	end
	
	
	instance.Transparency = 1
	instance.Anchored = true
	instance.CanCollide = false
	
	task.delay(2, function()
		ExplosiveBarrelManager:DeleteBarrel(instance)
	end)
end

function ExplosiveBarrelManager:DamageUpdate(instance: MeshPart)
	local data = Barrels[instance]
	if data then
		if data.Health <= 0 and not data.Exploded then
			ExplosiveBarrelManager:Explode(instance)
		elseif data.Health <= 50 then
			data.OnFire = true
			instance:SetAttribute("OnFire", true)
		end
	end
end

function ExplosiveBarrelManager:Hit(Character: Model, instance: MeshPart, damage: number, weapon: string, hitPos: Vector3)
	local data = Barrels[instance]
	if not data then
		return
	end
	
	ExplosiveBarrelManager:Knockback(Character, instance, damage, weapon, hitPos)
	
	if weapon == "Melee" then
		data.Health -= 5
	else
		local pivot = instance:GetPivot()
		local localHitCFrame = pivot:ToObjectSpace(CFrame.new(hitPos))
		data.Health -= damage / 2
		
		BarrelEvent:FireAllClients(instance:GetAttribute("ID"), localHitCFrame)
	end
	
	ExplosiveBarrelManager:DamageUpdate(instance)
end

function ExplosiveBarrelManager.Init()
	if ExplosiveBarrelManager.Initialized then
		return
	end
	
	
	local Barrels = CollectionService:GetTagged("ExplosiveBarrel")
	CollectionService:GetInstanceAddedSignal("ExplosiveBarrel"):Connect(function(instance)
		ExplosiveBarrelManager:NewBarrel(instance)
	end)
	
	CollectionService:GetInstanceRemovedSignal("ExplosiveBarrel"):Connect(function(instance)
		ExplosiveBarrelManager:DeleteBarrel(instance)
	end)
	
	for _, instance in Barrels do
		ExplosiveBarrelManager:NewBarrel(instance)
	end
	
	ExplosiveBarrelManager.Initialized = true
end

return ExplosiveBarrelManager