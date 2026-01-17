local XZ_PLANE_VECTOR = Vector3.new(1, 0, 1)
local random = Random.new()

local GeometryUtils = {}
GeometryUtils.PLACE_POINT_OFFSET = 1

function GeometryUtils.getClosestPointOnBlock(block, position)
	local objectSpace = block.CFrame:PointToObjectSpace(position)
	local halfSize = block.Size * 0.5
	local worldSpace = block.CFrame:PointToWorldSpace(
		Vector3.new(
			math.clamp(objectSpace.X, -halfSize.X, halfSize.X),
			math.clamp(objectSpace.Y, -halfSize.Y, halfSize.Y),
			math.clamp(objectSpace.Z, -halfSize.Z, halfSize.Z)
		)
	)
	return worldSpace
end

function GeometryUtils.getPathPlacePoint(map, originCFrame)
	local towerPosition = originCFrame.Position
	local closestPathPoint, closestPathPointDistance = GeometryUtils.getClosestPathPoint(map, towerPosition)
	local direction = -((towerPosition * XZ_PLANE_VECTOR) - (closestPathPoint * XZ_PLANE_VECTOR)).Unit
		* GeometryUtils.PLACE_POINT_OFFSET
	return CFrame.lookAlong(closestPathPoint + direction, Vector3.yAxis), closestPathPointDistance
end

function GeometryUtils.getRandomPointInCircle()
	local radius = math.sqrt(random:NextNumber(0, 1))
	local angle = random:NextNumber(0, 1) * math.pi * 2
	return Vector2.new(math.cos(angle) * radius, math.sin(angle) * radius)
end

return GeometryUtils
