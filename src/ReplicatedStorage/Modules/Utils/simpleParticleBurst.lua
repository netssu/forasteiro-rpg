local EMIT_NUMBER_ATTRIBUTE_NAME = "EmitNumber"

local function simpleParticleBurst(effectTemplate: BasePart, cframe: CFrame, attachTo: BasePart?)
	local effect = effectTemplate:Clone()
	effect.CFrame = if attachTo then attachTo.CFrame * cframe else cframe
	effect.Parent = workspace

	if attachTo then
		local weldConstraint = Instance.new("WeldConstraint")
		weldConstraint.Part0 = attachTo
		weldConstraint.Part1 = effect
		weldConstraint.Parent = effect
	end

	local lifetime = 0

	for _, v in effect:GetDescendants() do
		if not v:IsA("ParticleEmitter") then
			continue
		end

		lifetime = math.max(lifetime, v.Lifetime.Max)

		local emitAmount = v:GetAttribute(EMIT_NUMBER_ATTRIBUTE_NAME)

		if emitAmount then
			v:Emit(emitAmount)
		end
	end

	task.delay(lifetime, function()
		effect:Destroy()
		effect = nil
	end)
end

return simpleParticleBurst
