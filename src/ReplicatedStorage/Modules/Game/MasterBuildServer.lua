------------------//CONSTANTS
local MASTER_TEAM_NAME: string = "Mestre"
local BUILD_FOLDER_NAME: string = "TabletopBuildParts"
local MIN_PART_SIZE: number = 1
local MAX_PART_SIZE: number = 512
local DEFAULT_COLOR: Color3 = Color3.fromRGB(163, 162, 165)

local OVERLAP_PADDING: number = 0.05
local WALL_THICKNESS_RATIO: number = 0.45
local WALL_HEIGHT_RATIO: number = 1.25
local WALL_ALIGNMENT_DOT: number = 0.92

------------------//VARIABLES
local MasterBuildManager = {}

------------------//FUNCTIONS
local function get_build_folder(): Folder?
	local folder = workspace:FindFirstChild(BUILD_FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		return folder
	end

	return nil
end

local function get_build_kind(inst: Instance?): string
	if not inst or not inst:IsA("BasePart") then
		return ""
	end

	local buildKind = inst:GetAttribute("BuildKind")
	if typeof(buildKind) == "string" then
		return buildKind
	end

	return "Part"
end

local function is_valid_build_part(inst: Instance?): boolean
	if not inst or not inst:IsA("BasePart") then
		return false
	end

	local folder = get_build_folder()
	return folder ~= nil and inst.Parent == folder and inst:GetAttribute("IsTabletopBuildPart") == true
end

local function sanitize_size(size: Vector3): Vector3
	return Vector3.new(
		math.clamp(size.X, MIN_PART_SIZE, MAX_PART_SIZE),
		math.clamp(size.Y, MIN_PART_SIZE, MAX_PART_SIZE),
		math.clamp(size.Z, MIN_PART_SIZE, MAX_PART_SIZE)
	)
end

local function sanitize_color(color: Color3?): Color3
	if color then
		return color
	end

	return DEFAULT_COLOR
end

local function get_overlap_query_size(size: Vector3): Vector3
	return Vector3.new(
		math.max(0.05, size.X - OVERLAP_PADDING),
		math.max(0.05, size.Y - OVERLAP_PADDING),
		math.max(0.05, size.Z - OVERLAP_PADDING)
	)
end

local function is_wall_like_size(size: Vector3): boolean
	local horizontalMin = math.min(size.X, size.Z)
	local horizontalMax = math.max(size.X, size.Z)

	return size.Y >= (horizontalMin * WALL_HEIGHT_RATIO)
		and horizontalMin <= (horizontalMax * WALL_THICKNESS_RATIO)
end

local function is_wall_like_kind(buildKind: string, size: Vector3): boolean
	return buildKind == "Wall" or (buildKind == "Part" and is_wall_like_size(size))
end

local function get_flat_unit(vector: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude <= 0.0001 then
		return Vector3.new(0, 0, -1)
	end

	return flat.Unit
end

local function get_primary_horizontal_axis(size: Vector3, cframe: CFrame): Vector3
	if size.Z >= size.X then
		return get_flat_unit(cframe.LookVector)
	end

	return get_flat_unit(cframe.RightVector)
end

local function have_similar_wall_orientation(sizeA: Vector3, cframeA: CFrame, sizeB: Vector3, cframeB: CFrame): boolean
	local axisA = get_primary_horizontal_axis(sizeA, cframeA)
	local axisB = get_primary_horizontal_axis(sizeB, cframeB)

	return math.abs(axisA:Dot(axisB)) >= WALL_ALIGNMENT_DOT
end

local function should_room_replace_wall(newKind: string, newSize: Vector3, newCFrame: CFrame, existingPart: BasePart): boolean
	local existingKind = get_build_kind(existingPart)

	if not is_wall_like_kind(newKind, newSize) then
		return false
	end

	if not is_wall_like_kind(existingKind, existingPart.Size) then
		return false
	end

	return have_similar_wall_orientation(newSize, newCFrame, existingPart.Size, existingPart.CFrame)
end

local collect_overlapping_build_parts: (size: Vector3, cframe: CFrame) -> {BasePart}

local function subtract_wall_overlap(wallSize: Vector3, wallCFrame: CFrame, cutSize: Vector3, cutCFrame: CFrame): {{Size: Vector3, CFrame: CFrame}}
	local localCut = wallCFrame:ToObjectSpace(cutCFrame)

	local extX = math.abs(localCut.RightVector.X) * cutSize.X/2 + math.abs(localCut.UpVector.X) * cutSize.Y/2 + math.abs(localCut.LookVector.X) * cutSize.Z/2
	local extY = math.abs(localCut.RightVector.Y) * cutSize.X/2 + math.abs(localCut.UpVector.Y) * cutSize.Y/2 + math.abs(localCut.LookVector.Y) * cutSize.Z/2
	local extZ = math.abs(localCut.RightVector.Z) * cutSize.X/2 + math.abs(localCut.UpVector.Z) * cutSize.Y/2 + math.abs(localCut.LookVector.Z) * cutSize.Z/2

	if math.abs(localCut.Position.X) > wallSize.X/2 + extX then return {{CFrame = wallCFrame, Size = wallSize}} end
	if math.abs(localCut.Position.Y) > wallSize.Y/2 + extY then return {{CFrame = wallCFrame, Size = wallSize}} end
	if math.abs(localCut.Position.Z) > wallSize.Z/2 + extZ then return {{CFrame = wallCFrame, Size = wallSize}} end

	local dMin = localCut.Position.Z - extZ
	local dMax = localCut.Position.Z + extZ
	local wMin = -wallSize.Z/2
	local wMax = wallSize.Z/2

	local iMin = math.max(wMin, dMin)
	local iMax = math.min(wMax, dMax)

	if iMin >= iMax then return {{CFrame = wallCFrame, Size = wallSize}} end

	local parts = {}

	if wMin < iMin then
		local len = iMin - wMin
		local centerZ = wMin + len/2
		table.insert(parts, {Size = Vector3.new(wallSize.X, wallSize.Y, len), CFrame = wallCFrame * CFrame.new(0, 0, centerZ)})
	end

	if iMax < wMax then
		local len = wMax - iMax
		local centerZ = iMax + len/2
		table.insert(parts, {Size = Vector3.new(wallSize.X, wallSize.Y, len), CFrame = wallCFrame * CFrame.new(0, 0, centerZ)})
	end

	local holeTopY = localCut.Position.Y + extY
	local holeBottomY = localCut.Position.Y - extY
	local wallTopY = wallSize.Y/2
	local wallBottomY = -wallSize.Y/2

	local len = iMax - iMin
	local centerZ = (iMin + iMax) / 2

	if holeTopY < wallTopY then
		local topHeight = wallTopY - holeTopY
		local centerY = holeTopY + topHeight/2
		table.insert(parts, {Size = Vector3.new(wallSize.X, topHeight, len), CFrame = wallCFrame * CFrame.new(0, centerY, centerZ)})
	end

	if holeBottomY > wallBottomY then
		local botHeight = holeBottomY - wallBottomY
		local botCenterY = wallBottomY + botHeight/2
		table.insert(parts, {Size = Vector3.new(wallSize.X, botHeight, len), CFrame = wallCFrame * CFrame.new(0, botCenterY, centerZ)})
	end

	return parts
end

local function resolve_room_wall_fragments(size: Vector3, cframe: CFrame, buildKind: string): {{Size: Vector3, CFrame: CFrame}}
	local fragments = {{Size = size, CFrame = cframe}}
	local overlaps = collect_overlapping_build_parts(size, cframe)

	for _, hitPart in overlaps do
		local nextFragments = {}

		for _, fragment in fragments do
			if should_room_replace_wall(buildKind, fragment.Size, fragment.CFrame, hitPart) then
				local sliced = subtract_wall_overlap(fragment.Size, fragment.CFrame, hitPart.Size, hitPart.CFrame)
				for _, slicedPart in sliced do
					table.insert(nextFragments, slicedPart)
				end
			else
				table.insert(nextFragments, fragment)
			end
		end

		fragments = nextFragments
	end

	return fragments
end

local function resolve_existing_wall_fragments(size: Vector3, cframe: CFrame, buildKind: string, extraAttributes: {[string]: any}?): ({[BasePart]: {{Size: Vector3, CFrame: CFrame}}}, {[BasePart]: boolean})
	local overlaps = collect_overlapping_build_parts(size, cframe)
	local replacementsByPart = {}
	local partsToDestroy = {}
	local cutouts = {
		{Size = size, CFrame = cframe},
	}

	if extraAttributes and extraAttributes.HasDoorOpening == true
		and typeof(extraAttributes.DoorCutCFrame) == "CFrame"
		and typeof(extraAttributes.DoorCutSize) == "Vector3" then
		table.insert(cutouts, {
			Size = extraAttributes.DoorCutSize,
			CFrame = extraAttributes.DoorCutCFrame,
		})
	end

	for _, hitPart in overlaps do
		if should_room_replace_wall(buildKind, size, cframe, hitPart) then
			local sliced = {{Size = hitPart.Size, CFrame = hitPart.CFrame}}

			for _, cutout in cutouts do
				local nextSliced = {}
				for _, fragment in sliced do
					local fragmentPieces = subtract_wall_overlap(fragment.Size, fragment.CFrame, cutout.Size, cutout.CFrame)
					for _, piece in fragmentPieces do
						table.insert(nextSliced, piece)
					end
				end
				sliced = nextSliced
			end

			replacementsByPart[hitPart] = sliced
			partsToDestroy[hitPart] = true
		end
	end

	return replacementsByPart, partsToDestroy
end

collect_overlapping_build_parts = function(size: Vector3, cframe: CFrame): {BasePart}
	local folder = get_build_folder()
	if not folder then
		return {}
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = {folder}

	local foundParts = workspace:GetPartBoundsInBox(cframe, get_overlap_query_size(size), overlapParams)
	local result = {}

	for _, hitPart in foundParts do
		if hitPart:IsA("BasePart") and is_valid_build_part(hitPart) then
			table.insert(result, hitPart)
		end
	end

	return result
end

local function destroy_room_overlapping_walls(size: Vector3, cframe: CFrame, buildKind: string): ()
	local overlaps = collect_overlapping_build_parts(size, cframe)
	local destroyedMap = {}

	for _, hitPart in overlaps do
		if not destroyedMap[hitPart] and should_room_replace_wall(buildKind, size, cframe, hitPart) then
			destroyedMap[hitPart] = true
			hitPart:Destroy()
		end
	end
end

local function apply_part_visuals(part: BasePart, color: Color3?, buildKind: string, lightRange: number?, lightBrightness: number?): ()
	part.Color = sanitize_color(color)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Shape = Enum.PartType.Block
	part:SetAttribute("IsTabletopBuildPart", true)
	part:SetAttribute("BuildKind", buildKind)

	if buildKind == "Light" then
		part.Material = Enum.Material.Neon

		local pointLight = part:FindFirstChildOfClass("PointLight")
		if not pointLight then
			pointLight = Instance.new("PointLight")
			pointLight.Parent = part
		end

		pointLight.Color = part.Color
		pointLight.Range = typeof(lightRange) == "number" and lightRange or 20
		pointLight.Brightness = typeof(lightBrightness) == "number" and lightBrightness or 2
		pointLight.Shadows = true
	else
		part.Material = Enum.Material.SmoothPlastic

		local pointLight = part:FindFirstChildOfClass("PointLight")
		if pointLight then
			pointLight:Destroy()
		end
	end
end

local function apply_extra_attributes(part: BasePart, extraAttributes: {[string]: any}?): ()
	if not extraAttributes then
		return
	end

	for attributeName, attributeValue in extraAttributes do
		part:SetAttribute(attributeName, attributeValue)
	end
end

local function create_build_part(size: Vector3, cframe: CFrame, color: Color3?, buildKind: string?, lightRange: number?, lightBrightness: number?, extraAttributes: {[string]: any}?, allowRoomReplacement: boolean?, preferNewWall: boolean?): BasePart?
	local folder = get_build_folder()
	if not folder then
		return nil
	end

	local finalSize = sanitize_size(size)
	local finalKind = buildKind or "Part"
	local fragments = {{Size = finalSize, CFrame = cframe}}
	local minFragmentHeight = finalSize.Y - 0.01

	if allowRoomReplacement == true then
		if is_wall_like_kind(finalKind, finalSize) then
			local shouldPreferNewWall = preferNewWall == true

			if shouldPreferNewWall then
				local replacementsByPart, partsToDestroy = resolve_existing_wall_fragments(finalSize, cframe, finalKind, extraAttributes)
				for partToDestroy in partsToDestroy do
					local sourceColor = partToDestroy.Color
					local sourceKind = get_build_kind(partToDestroy)
					local sourceAttributes = partToDestroy:GetAttributes()
					partToDestroy:Destroy()

					local replacements = replacementsByPart[partToDestroy]
					if replacements then
						for _, replacement in replacements do
							if replacement.Size.Y < minFragmentHeight then
								continue
							end

							local replacementPart = Instance.new("Part")
							replacementPart.Name = "BuildPart"
							replacementPart.Anchored = true
							replacementPart.CanCollide = true
							replacementPart.CanTouch = true
							replacementPart.CanQuery = true
							replacementPart.Size = sanitize_size(replacement.Size)
							replacementPart.CFrame = replacement.CFrame
							apply_part_visuals(replacementPart, sourceColor, sourceKind, nil, nil)
							for attributeName, attributeValue in sourceAttributes do
								replacementPart:SetAttribute(attributeName, attributeValue)
							end
							replacementPart.Parent = folder
						end
					end
				end
			else
				fragments = resolve_room_wall_fragments(finalSize, cframe, finalKind)
			end
		else
			destroy_room_overlapping_walls(finalSize, cframe, finalKind)
		end
	end

	local firstPart = nil
	for _, fragment in fragments do
		if fragment.Size.Y < minFragmentHeight then
			continue
		end

		local part = Instance.new("Part")
		part.Name = "BuildPart"
		part.Anchored = true
		part.CanCollide = true
		part.CanTouch = true
		part.CanQuery = true
		part.Size = sanitize_size(fragment.Size)
		part.CFrame = fragment.CFrame

		apply_part_visuals(part, color, finalKind, lightRange, lightBrightness)
		apply_extra_attributes(part, extraAttributes)

		part.Parent = folder
		if firstPart == nil then
			firstPart = part
		end
	end

	return firstPart
end

local function update_build_part(part: BasePart, size: Vector3?, cframe: CFrame?, color: Color3?, lightRange: number?, lightBrightness: number?): ()
	local finalSize = size and sanitize_size(size) or part.Size
	local finalCFrame = cframe or part.CFrame
	local buildKind = get_build_kind(part)

	part.Size = finalSize
	part.CFrame = finalCFrame

	if color or buildKind == "Light" then
		apply_part_visuals(part, color or part.Color, buildKind, lightRange, lightBrightness)
	end

	if lightRange or lightBrightness then
		local light = part:FindFirstChildOfClass("PointLight")
		if light then
			if lightRange then
				light.Range = lightRange
			end

			if lightBrightness then
				light.Brightness = lightBrightness
			end
		end
	end
end

local function delete_build_part(part: BasePart): ()
	part:Destroy()
end

local function move_character_to_cframe(character: Model, targetCFrame: CFrame): ()
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	rootPart.CFrame = targetCFrame
end

------------------//MAIN FUNCTIONS
function MasterBuildManager.process_request(player: Player, payload: any): ()
	if player.Team == nil or player.Team.Name ~= MASTER_TEAM_NAME then
		return
	end

	if typeof(payload) ~= "table" then
		return
	end

	local action = payload.Action

	if action == "CreatePart" then
		if typeof(payload.Size) ~= "Vector3" or typeof(payload.CFrame) ~= "CFrame" then
			return
		end

		local color = typeof(payload.Color) == "Color3" and payload.Color or nil
		local buildKind = typeof(payload.BuildKind) == "string" and payload.BuildKind or nil
		local lightRange = typeof(payload.LightRange) == "number" and payload.LightRange or nil
		local lightBrightness = typeof(payload.LightBrightness) == "number" and payload.LightBrightness or nil

		create_build_part(payload.Size, payload.CFrame, color, buildKind, lightRange, lightBrightness, nil, false, false)
		return
	end

	if action == "CreateRoomParts" then
		if typeof(payload.Parts) ~= "table" then
			return
		end

		local color = typeof(payload.Color) == "Color3" and payload.Color or nil
		local roomId = typeof(payload.RoomId) == "string" and payload.RoomId or nil
		local roomHasDoors = typeof(payload.Doors) == "table" and #payload.Doors > 0

		for _, partData in payload.Parts do
			if typeof(partData) == "table"
				and typeof(partData.Size) == "Vector3"
				and typeof(partData.CFrame) == "CFrame" then
				local extraAttributes = {}
				if roomId then
					extraAttributes.RoomId = roomId
				end
				if typeof(partData.ExtraAttributes) == "table" then
					for attributeName, attributeValue in partData.ExtraAttributes do
						extraAttributes[attributeName] = attributeValue
					end
				end

				create_build_part(
					partData.Size,
					partData.CFrame,
					color,
					typeof(partData.BuildKind) == "string" and partData.BuildKind or nil,
					nil,
					nil,
					next(extraAttributes) and extraAttributes or nil,
					true,
					roomHasDoors
				)
			end
		end

		return
	end

	if action == "UpdatePart" then
		local part = payload.Part
		if not is_valid_build_part(part) then
			return
		end

		local size = typeof(payload.Size) == "Vector3" and payload.Size or nil
		local cframe = typeof(payload.CFrame) == "CFrame" and payload.CFrame or nil
		local color = typeof(payload.Color) == "Color3" and payload.Color or nil
		local lightRange = typeof(payload.LightRange) == "number" and payload.LightRange or nil
		local lightBrightness = typeof(payload.LightBrightness) == "number" and payload.LightBrightness or nil

		update_build_part(part, size, cframe, color, lightRange, lightBrightness)
		return
	end

	if action == "DeletePart" then
		local part = payload.Part
		if not is_valid_build_part(part) then
			return
		end

		local roomId = part:GetAttribute("RoomId")
		if roomId then
			local folder = get_build_folder()
			if folder then
				for _, child in folder:GetChildren() do
					if child:IsA("BasePart") and child:GetAttribute("RoomId") == roomId then
						delete_build_part(child)
					end
				end
			end
		else
			delete_build_part(part)
		end

		return
	end

	if action == "MoveCharacter" then
		if typeof(payload.Character) ~= "Instance" or not payload.Character:IsA("Model") or typeof(payload.CFrame) ~= "CFrame" then
			return
		end

		local charactersFolder = workspace:FindFirstChild("Characters")
		if not charactersFolder or payload.Character.Parent ~= charactersFolder then
			return
		end

		move_character_to_cframe(payload.Character, payload.CFrame)
	end
end

return MasterBuildManager
