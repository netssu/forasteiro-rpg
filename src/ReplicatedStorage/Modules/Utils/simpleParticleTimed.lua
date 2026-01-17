local function simpleParticleTimed(effectTemplate: BasePart, cframe: CFrame, lifetime: number, attachTo: BasePart?)
	local effect = effectTemplate:Clone()
	effect.CFrame = if attachTo then attachTo.CFrame * cframe else cframe
	effect.Parent = workspace

	if attachTo then
		local weldConstraint = Instance.new("WeldConstraint")
		weldConstraint.Part0 = attachTo
		weldConstraint.Part1 = effect
		weldConstraint.Parent = effect
	end

	local particleEmitters = {}
	local particleLifetime = 0

	for _, v in effect:GetDescendants() do
		if not v:IsA("ParticleEmitter") then
			continue
		end

		table.insert(particleEmitters, v)
		particleLifetime = math.max(particleLifetime, v.Lifetime.Max)
	end

	task.delay(lifetime, function()
		for _, emitter in particleEmitters do
			emitter.Enabled = false
		end

		task.delay(particleLifetime, function()
			effect:Destroy()
			effect = nil
		end)
	end)
end

return simpleParticleTimed
