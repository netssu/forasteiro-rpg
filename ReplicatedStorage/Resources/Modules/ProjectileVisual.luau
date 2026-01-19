local ProjectileVisual = {}

local Config = {
	TracerColor = Color3.fromRGB(255, 170, 0),
	TracerDuration = 0.3,
	TracerThickness = 0.08,
	HitEffectColor = Color3.fromRGB(255, 100, 100),
}

function ProjectileVisual.CreateTracer(startPos, endPos)
	--local distance = (endPos - startPos).Magnitude
	--local midpoint = (startPos + endPos) / 2

	--local tracer = Instance.new("Part")
	--tracer.Transparency = 1
	--tracer.Anchored = true
	--tracer.CanCollide = false
	--tracer.Material = Enum.Material.Neon
	--tracer.Color = Config.TracerColor
	--tracer.Size = Vector3.new(Config.TracerThickness, Config.TracerThickness, distance)
	--tracer.CFrame = CFrame.lookAt(midpoint, endPos)
	--tracer.Parent = workspace

	--task.spawn(function()
	--	local transparency = 0
	--	local increment = 0.1
	--	while transparency < 1 do
	--		transparency += increment
	--		tracer.Transparency = transparency
	--		task.wait(Config.TracerDuration / 10)
	--	end
	--	tracer:Destroy()
	--end)
end

function ProjectileVisual.CreateHitEffect(position)
	--local hitEffect = Instance.new("Part")
	--hitEffect.Anchored = true
	--hitEffect.CanCollide = false
	--hitEffect.Material = Enum.Material.Neon
	--hitEffect.Color = Config.HitEffectColor
	--hitEffect.Size = Vector3.new(0.5, 0.5, 0.5)
	--hitEffect.Shape = Enum.PartType.Ball
	--hitEffect.Position = position
	--hitEffect.Parent = workspace

	--task.delay(0.1, function()
	--	hitEffect:Destroy()
	--end)
end

return ProjectileVisual
