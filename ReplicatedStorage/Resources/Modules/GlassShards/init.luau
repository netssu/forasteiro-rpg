local GlassShards = {}

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SHARD_LIFETIME = 5
local IMPULSE = 20

local CurrentActiveShards = 0
local PoolFolder = Instance.new("Folder")
PoolFolder.Name = "GlassShardPool"
PoolFolder.Parent = ReplicatedStorage

local ShardPool = {}

local Vfxs = script.VFX:GetChildren()
local Sounds = script.SFX:GetChildren()

local function GetShard()
	local shard = table.remove(ShardPool)
	if not shard then
		shard = Instance.new("WedgePart")
		shard.CastShadow = false
		shard.CanTouch = false
		--shard.CanQuery = false
		
		for _, VFX in Vfxs do
			local VFXClone = VFX:Clone()
			VFXClone.Parent = shard
		end
	end
	CurrentActiveShards += 1
	return shard
end

local function ReturnToPool(shard)
	shard.Anchored = true
	shard.CanCollide = false
	shard.CanTouch = false
	shard.CanQuery = false
	shard.Parent = PoolFolder
	table.insert(ShardPool, shard)
	CurrentActiveShards -= 1
end

local function Normalize(glass)
	local cf = glass.CFrame
	local size = glass.Size

	local axes = {
		{axis = cf.RightVector, value = size.X},
		{axis = cf.UpVector, value = size.Y},
		{axis = cf.LookVector, value = size.Z}
	}

	table.sort(axes, function(a, b)
		return a.value < b.value
	end)

	return
		CFrame.fromMatrix(
			cf.Position,
			axes[2].axis,
			axes[3].axis,
			axes[1].axis
		),
		Vector3.new(
			axes[2].value,
			axes[3].value,
			axes[1].value
		)
end

local function applyProperties(w, glass)
	w.Material = glass.Material
	w.MaterialVariant = glass.MaterialVariant
	w.Transparency = glass.Transparency
	w.Reflectance = glass.Reflectance
	w.Color = glass.Color
	w.CanTouch = false
	w.CanQuery = false
	w.CanCollide = true
	w.Anchored = false
	w.CollisionGroup = "Debris"
end

local function CreatePanel(cf, size, glass, contactPosition, normal)
	local w1 = GetShard()
	w1.Size = Vector3.new(math.max(size.Y, 0.2), size.Z, size.X)
	w1.CFrame = cf * CFrame.Angles(0, math.pi/2, 0)
	applyProperties(w1, glass)
	w1.Parent = workspace

	local w2 = GetShard()
	w2.Size = Vector3.new(math.max(size.Y, 0.2), size.Z, size.X)
	w2.CFrame = cf * CFrame.Angles(0, -math.pi/2, math.pi)
	applyProperties(w2, glass)
	w2.Parent = workspace
	
	for _, Particle in w1:GetDescendants() do
		if Particle:IsA("ParticleEmitter") then
			Particle:Emit(Particle:GetAttribute("EmitCount"))
		end
	end
	
	for _, Particle in w2:GetDescendants() do
		if Particle:IsA("ParticleEmitter") then
			Particle:Emit(Particle:GetAttribute("EmitCount"))
		end
	end

	if contactPosition and normal then
		w1:ApplyImpulseAtPosition(normal * w1.Mass * IMPULSE , contactPosition)
		w2:ApplyImpulseAtPosition(normal * w2.Mass * IMPULSE, contactPosition)
	else
		local rngDir = Vector3.new(math.random(-100, 100)/100, math.random(-100, 100)/100, math.random(-100, 100)/100)
		w1:ApplyImpulseAtPosition(rngDir * w1.Mass * IMPULSE, w2.Position)
		w2:ApplyImpulseAtPosition(rngDir * w2.Mass * IMPULSE, w1.Position)
	end
	
	task.delay(0.5, function()
		w1.AssemblyLinearVelocity = Vector3.new()
		w2.AssemblyLinearVelocity = Vector3.new()
		w2.AssemblyAngularVelocity = Vector3.new()
		w1.AssemblyAngularVelocity = Vector3.new()
	end)

	task.delay(SHARD_LIFETIME, function()
		ReturnToPool(w1)
		ReturnToPool(w2)
	end)
end

local function SplitQuad(minX, maxX, minY, maxY, rng)
	local biasX = rng:NextNumber(0.2, 0.8)
	local biasY = rng:NextNumber(0.2, 0.8)

	local cx = minX * biasX + maxX * (1 - biasX)
	local cy = minY * biasY + maxY * (1 - biasY)

	return {
		{minX = minX, maxX = cx, minY = cy, maxY = maxY},
		{minX = cx, maxX = maxX, minY = cy, maxY = maxY},
		{minX = minX, maxX = cx, minY = minY, maxY = cy},
		{minX = cx, maxX = maxX, minY = minY, maxY = cy}
	}
end

function GlassShards:DestroyGlass(glass)
	glass.Transparency = 1
	glass.CanCollide = false
	glass.CanQuery = false
	glass.CanTouch = false
	for i,v in glass:GetDescendants() do
		if v:IsA("Decal") or v:IsA("Texture") then
			v:Destroy()
		end
	end
	
	
	local Sound = Sounds[math.random(1, #Sounds)]:Clone()
	Sound.Parent = glass
	Sound:Play()
	
	Debris:AddItem(glass, SHARD_LIFETIME)
end

function GlassShards:Break(glass: BasePart, contactPosition, normal)
	local quality = UserSettings().GameSettings.SavedQualityLevel.Value
	if quality == 0 then quality = 5 end -- Handle 'Automatic' setting

	local maxAllowedShards = quality * 25 
	local useSubdivision = (quality >= 6)
	local shardsToCreate = useSubdivision and 32 or 8

	if (CurrentActiveShards + shardsToCreate) > maxAllowedShards then
		GlassShards:DestroyGlass(glass)
		
		return
	end
	
	local cf, size = Normalize(glass)
	local rng = Random.new()

	local halfX = size.X * 0.5
	local halfY = size.Y * 0.5

	local primary = SplitQuad(-halfX, halfX, -halfY, halfY, rng)

	for _, quad in ipairs(primary) do
		local targets = {quad}

		if useSubdivision then
			targets = SplitQuad(quad.minX, quad.maxX, quad.minY, quad.maxY, rng)
		end

		for _, panel in ipairs(targets) do
			local sx = panel.maxX - panel.minX
			local sy = panel.maxY - panel.minY

			if sx > 0 and sy > 0 then
				local cx = (panel.minX + panel.maxX) * 0.5
				local cy = (panel.minY + panel.maxY) * 0.5

				local panelCF = cf * CFrame.new(cx, cy, 0)
				local panelSize = Vector3.new(sx, size.Z, sy)

				CreatePanel(panelCF, panelSize, glass, contactPosition, normal)
			end
		end
	end

	GlassShards:DestroyGlass(glass)
end

return GlassShards