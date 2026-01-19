local module = {}

function module.get9BottomPositions(part:Part) : {Vector3}
	local cf = part.CFrame
	local size = part.Size

	local bottomCenter = cf.Position - (cf.UpVector * (size.Y / 2))

	local xOffsets = { -size.X/2, 0, size.X/2 }
	local zOffsets = { -size.Z/2, 0, size.Z/2 }

	local positions = {}

	for _, x in ipairs(xOffsets) do
		for _, z in ipairs(zOffsets) do
			local pos = bottomCenter 
				+ (cf.RightVector * x)
				+ (cf.LookVector * z)

			table.insert(positions, pos)
		end
	end

	return positions
end


return module
