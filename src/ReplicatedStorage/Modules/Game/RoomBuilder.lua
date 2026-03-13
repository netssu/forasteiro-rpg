local RoomBuilder = {}

RoomBuilder.Anchor = nil
RoomBuilder.LockedB = nil
RoomBuilder.Doors = {}

function RoomBuilder.reset()
	RoomBuilder.Anchor = nil
	RoomBuilder.LockedB = nil
	table.clear(RoomBuilder.Doors)
end

function RoomBuilder.add_door(doorCFrame, doorSize)
	table.insert(RoomBuilder.Doors, {CFrame = doorCFrame, Size = doorSize})
end

local function slice_wall(wallCFrame, wallSize, doorCFrame, doorSize)
	local localDoor = wallCFrame:ToObjectSpace(doorCFrame)

	-- Projeta o tamanho da porta nos eixos locais da parede para suportar qualquer rotação
	local extX = math.abs(localDoor.RightVector.X) * doorSize.X/2 + math.abs(localDoor.UpVector.X) * doorSize.Y/2 + math.abs(localDoor.LookVector.X) * doorSize.Z/2
	local extY = math.abs(localDoor.RightVector.Y) * doorSize.X/2 + math.abs(localDoor.UpVector.Y) * doorSize.Y/2 + math.abs(localDoor.LookVector.Y) * doorSize.Z/2
	local extZ = math.abs(localDoor.RightVector.Z) * doorSize.X/2 + math.abs(localDoor.UpVector.Z) * doorSize.Y/2 + math.abs(localDoor.LookVector.Z) * doorSize.Z/2

	-- Verifica se existe interseção (A porta encosta na parede?)
	if math.abs(localDoor.Position.X) > wallSize.X/2 + extX then return {{CFrame = wallCFrame, Size = wallSize}} end
	if math.abs(localDoor.Position.Y) > wallSize.Y/2 + extY then return {{CFrame = wallCFrame, Size = wallSize}} end
	if math.abs(localDoor.Position.Z) > wallSize.Z/2 + extZ then return {{CFrame = wallCFrame, Size = wallSize}} end

	-- Calcula a área do buraco ao longo do comprimento da parede (Z)
	local dMin = localDoor.Position.Z - extZ
	local dMax = localDoor.Position.Z + extZ
	local wMin = -wallSize.Z/2
	local wMax = wallSize.Z/2

	local iMin = math.max(wMin, dMin)
	local iMax = math.min(wMax, dMax)

	if iMin >= iMax then return {{CFrame = wallCFrame, Size = wallSize}} end

	local parts = {}
	local doorWallAttributes = {
		PreserveOnRoomReplace = true,
		HasDoorOpening = true,
	}

	-- Pedaço da esquerda
	if wMin < iMin then
		local len = iMin - wMin
		local centerZ = wMin + len/2
		table.insert(parts, {
			Size = Vector3.new(wallSize.X, wallSize.Y, len),
			CFrame = wallCFrame * CFrame.new(0, 0, centerZ),
			ExtraAttributes = doorWallAttributes,
		})
	end

	-- Pedaço da direita
	if iMax < wMax then
		local len = wMax - iMax
		local centerZ = iMax + len/2
		table.insert(parts, {
			Size = Vector3.new(wallSize.X, wallSize.Y, len),
			CFrame = wallCFrame * CFrame.new(0, 0, centerZ),
			ExtraAttributes = doorWallAttributes,
		})
	end

	-- Pedaço de Cima e de Baixo (para tapar o vão da porta)
	local holeTopY = localDoor.Position.Y + extY
	local holeBottomY = localDoor.Position.Y - extY
	local wallTopY = wallSize.Y/2
	local wallBottomY = -wallSize.Y/2

	local len = iMax - iMin
	local centerZ = (iMin + iMax) / 2

	-- Teto em cima da porta
	if holeTopY < wallTopY then
		local topHeight = wallTopY - holeTopY
		local centerY = holeTopY + topHeight/2
		table.insert(parts, {
			Size = Vector3.new(wallSize.X, topHeight, len),
			CFrame = wallCFrame * CFrame.new(0, centerY, centerZ),
			ExtraAttributes = doorWallAttributes,
		})
	end

	-- Batente em baixo da porta (se a porta não chegar no chão por algum motivo)
	if holeBottomY > wallBottomY then
		local botHeight = holeBottomY - wallBottomY
		local botCenterY = wallBottomY + botHeight/2
		table.insert(parts, {
			Size = Vector3.new(wallSize.X, botHeight, len),
			CFrame = wallCFrame * CFrame.new(0, botCenterY, centerZ),
			ExtraAttributes = doorWallAttributes,
		})
	end

	return parts
end

function RoomBuilder.get_room_data(exactPos, gridSize, wallHeight, wallThickness, doorWidth, doorHeight, createWithFloor, createWithCeil, previewDoor)
	local A = RoomBuilder.Anchor
	if not A then return {}, nil end
	local B = RoomBuilder.LockedB or exactPos

	if (A - B).Magnitude < 0.1 then
		B = A + Vector3.new(gridSize, 0, gridSize)
	end

	local minX = math.min(A.X, B.X)
	local maxX = math.max(A.X, B.X)
	local minZ = math.min(A.Z, B.Z)
	local maxZ = math.max(A.Z, B.Z)
	local baseY = A.Y

	if maxX - minX < gridSize then maxX = minX + gridSize end
	if maxZ - minZ < gridSize then maxZ = minZ + gridSize end

	local widthX = maxX - minX
	local widthZ = maxZ - minZ
	local centerX = minX + widthX / 2
	local centerZ = minZ + widthZ / 2

	local currentWalls = {
		{CFrame = CFrame.new(centerX, baseY + wallHeight/2, minZ) * CFrame.Angles(0, math.pi/2, 0), Size = Vector3.new(wallThickness, wallHeight, widthX)},
		{CFrame = CFrame.new(centerX, baseY + wallHeight/2, maxZ) * CFrame.Angles(0, math.pi/2, 0), Size = Vector3.new(wallThickness, wallHeight, widthX)},
		{CFrame = CFrame.new(minX, baseY + wallHeight/2, centerZ), Size = Vector3.new(wallThickness, wallHeight, widthZ)},
		{CFrame = CFrame.new(maxX, baseY + wallHeight/2, centerZ), Size = Vector3.new(wallThickness, wallHeight, widthZ)}
	}

	local hoveringDoor = nil
	if previewDoor then
		local bestWall = currentWalls[1]
		local minDistance = math.huge
		for _, w in currentWalls do
			local dist = (Vector3.new(w.CFrame.Position.X, exactPos.Y, w.CFrame.Position.Z) - exactPos).Magnitude
			if dist < minDistance then
				minDistance = dist
				bestWall = w
			end
		end

		local actualDoorWidth = math.min(doorWidth, bestWall.Size.Z - 0.5)
		if actualDoorWidth <= 0.5 then actualDoorWidth = bestWall.Size.Z / 2 end

		local localHit = bestWall.CFrame:ToObjectSpace(CFrame.new(exactPos))

		local minLimit = -bestWall.Size.Z/2 + actualDoorWidth/2
		local maxLimit = bestWall.Size.Z/2 - actualDoorWidth/2
		if minLimit > maxLimit then minLimit = 0; maxLimit = 0 end

		local clampZ = math.clamp(localHit.Position.Z, minLimit, maxLimit)
		hoveringDoor = {
			CFrame = bestWall.CFrame * CFrame.new(0, -wallHeight/2 + doorHeight/2, clampZ),
			Size = Vector3.new(wallThickness + 2, doorHeight, actualDoorWidth)
		}
	end

	local allDoors = {}
	for _, d in RoomBuilder.Doors do table.insert(allDoors, d) end
	if hoveringDoor then table.insert(allDoors, hoveringDoor) end

	for _, door in allDoors do
		local nextWalls = {}
		for _, wall in currentWalls do
			local sliced = slice_wall(wall.CFrame, wall.Size, door.CFrame, door.Size)

			for _, s in sliced do table.insert(nextWalls, s) end
		end
		currentWalls = nextWalls
	end

	local parts = {}
	for _, w in currentWalls do
		table.insert(parts, {
			Size = w.Size,
			CFrame = w.CFrame,
			BuildKind = "Wall",
			ExtraAttributes = w.ExtraAttributes,
		})
	end

	if createWithFloor then
		table.insert(parts, {Size = Vector3.new(widthX, 1, widthZ), CFrame = CFrame.new(centerX, baseY - 0.45, centerZ), BuildKind = "Part"})
	end
	if createWithCeil then
		table.insert(parts, {Size = Vector3.new(widthX, 1, widthZ), CFrame = CFrame.new(centerX, baseY + wallHeight + 0.5, centerZ), BuildKind = "Part"})
	end

	return parts, hoveringDoor
end

return RoomBuilder
