------------------//VARIABLES
local module = {}

------------------//FUNCTIONS
function module.sanitize_text_number(text: string, fallback: number, minimum: number): number
	local numberValue = tonumber(text)
	if not numberValue then
		return fallback
	end

	return math.max(minimum, numberValue)
end

function module.clamp_color_channel(value: number): number
	return math.clamp(math.floor(value + 0.5), 0, 255)
end

function module.snap_number(value: number, stepValue: number): number
	local safeStep = math.max(0.25, stepValue)
	return math.floor((value / safeStep) + 0.5) * safeStep
end

function module.snap_vector3(value: Vector3, stepValue: number): Vector3
	return Vector3.new(
		module.snap_number(value.X, stepValue),
		module.snap_number(value.Y, stepValue),
		module.snap_number(value.Z, stepValue)
	)
end

function module.vector_from_normal_id(normalId: Enum.NormalId, cframe: CFrame): Vector3
	if normalId == Enum.NormalId.Right then
		return cframe.RightVector
	end

	if normalId == Enum.NormalId.Left then
		return -cframe.RightVector
	end

	if normalId == Enum.NormalId.Top then
		return cframe.UpVector
	end

	if normalId == Enum.NormalId.Bottom then
		return -cframe.UpVector
	end

	if normalId == Enum.NormalId.Front then
		return cframe.LookVector
	end

	return -cframe.LookVector
end

function module.vector_from_character_normal_id(normalId: Enum.NormalId, cframe: CFrame): Vector3
	if normalId == Enum.NormalId.Right then
		return cframe.RightVector
	end

	if normalId == Enum.NormalId.Left then
		return -cframe.RightVector
	end

	if normalId == Enum.NormalId.Top then
		return cframe.UpVector
	end

	if normalId == Enum.NormalId.Bottom then
		return -cframe.UpVector
	end

	if normalId == Enum.NormalId.Front then
		return cframe.LookVector
	end

	return -cframe.LookVector
end

function module.local_axis_name_from_normal(normalId: Enum.NormalId): string
	if normalId == Enum.NormalId.Right or normalId == Enum.NormalId.Left then
		return "X"
	end

	if normalId == Enum.NormalId.Top or normalId == Enum.NormalId.Bottom then
		return "Y"
	end

	return "Z"
end

function module.rotation_cframe_from_axis(axis: Enum.Axis, angle: number): CFrame
	if axis == Enum.Axis.X then
		return CFrame.Angles(angle, 0, 0)
	end

	if axis == Enum.Axis.Y then
		return CFrame.Angles(0, angle, 0)
	end

	return CFrame.Angles(0, 0, angle)
end

function module.get_rotation_only_cframe(cframe: CFrame): CFrame
	local rx, ry, rz = cframe:ToOrientation()
	return CFrame.fromOrientation(rx, ry, rz)
end

function module.get_flat_wall_unit(vector: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude <= 0.0001 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

function module.build_box_from_two_points(pointA: Vector3, pointB: Vector3, minSize: number): (CFrame, Vector3)
	local size = Vector3.new(
		math.max(minSize, math.abs(pointB.X - pointA.X)),
		math.max(minSize, math.abs(pointB.Y - pointA.Y)),
		math.max(minSize, math.abs(pointB.Z - pointA.Z))
	)

	local center = Vector3.new(
		(pointA.X + pointB.X) / 2,
		(pointA.Y + pointB.Y) / 2,
		(pointA.Z + pointB.Z) / 2
	)

	return CFrame.new(center), size
end

function module.build_wall_from_points(pointA: Vector3, pointB: Vector3, height: number, thickness: number, gridSize: number): (CFrame, Vector3)
	local flatPointA = Vector3.new(pointA.X, pointA.Y, pointA.Z)
	local flatPointB = Vector3.new(pointB.X, pointA.Y, pointB.Z)

	local horizontal = flatPointB - flatPointA
	local length = horizontal.Magnitude

	if length < gridSize then
		length = gridSize
		horizontal = Vector3.new(0, 0, -length)
	end

	local direction = horizontal.Unit
	local center = (flatPointA + flatPointB) / 2 + Vector3.new(0, height / 2, 0)
	local cframe = CFrame.lookAt(center, center + direction)
	local size = Vector3.new(thickness, height, length)

	return cframe, size
end

return module