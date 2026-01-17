local WeldUtils = {}

function WeldUtils.createBetween(part0, part1)
	assert(typeof(part0) == "Instance" and part0:IsA("BasePart"), "Part0 must be a BasePart.")
	assert(typeof(part1) == "Instance" and part1:IsA("BasePart"), "Part1 must be a BasePart.")

	local weldConstraint = Instance.new("WeldConstraint")
	weldConstraint.Part0 = part0
	weldConstraint.Part1 = part1
	return weldConstraint
end

return WeldUtils
