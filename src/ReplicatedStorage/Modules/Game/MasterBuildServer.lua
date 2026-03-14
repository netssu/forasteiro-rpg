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
local BASEPLATE_NAME: string = "Baseplate"
local TERRAIN_STEP_SIZE: number = 4

------------------//VARIABLES
local MasterBuildManager = {}
local cachedBaseplate: BasePart? = nil
local cachedBaseplateParent: Instance? = nil
local terrainStateByUserId: {[number]: {Center: Vector3, Width: number, MinY: number, MaxY: number}} = {}

local TERRAIN_BIOMES = {
	Arctic = {Top = Enum.Material.Snow, Under = Enum.Material.Snow, BaseHeight = 24, Amplitude = 12, NoiseScale = 0.02, Ridge = 8, WaterLevel = nil, TopThickness = 6},
	Dunes = {Top = Enum.Material.Sand, Under = Enum.Material.Sand, BaseHeight = 20, Amplitude = 9, NoiseScale = 0.024, Ridge = 9, WaterLevel = nil, TopThickness = 5},
	Canyons = {Top = Enum.Material.Slate, Under = Enum.Material.Rock, BaseHeight = 30, Amplitude = 18, NoiseScale = 0.012, Ridge = 16, WaterLevel = nil, TopThickness = 4},
	Lavascape = {Top = Enum.Material.Basalt, Under = Enum.Material.Basalt, BaseHeight = 32, Amplitude = 24, NoiseScale = 0.012, Ridge = 26, WaterLevel = nil, TopThickness = 6, LavaLevel = 21},
	Water = {Top = Enum.Material.Sand, Under = Enum.Material.Rock, BaseHeight = 8, Amplitude = 5, NoiseScale = 0.03, Ridge = 2, WaterLevel = 18, TopThickness = 4},
	Mountains = {Top = Enum.Material.Rock, Under = Enum.Material.Slate, BaseHeight = 34, Amplitude = 20, NoiseScale = 0.013, Ridge = 16, WaterLevel = nil, TopThickness = 4},
	Hills = {Top = Enum.Material.Ground, Under = Enum.Material.Ground, BaseHeight = 18, Amplitude = 8, NoiseScale = 0.021, Ridge = 5, WaterLevel = nil, TopThickness = 5},
	Plains = {Top = Enum.Material.Grass, Under = Enum.Material.Grass, BaseHeight = 16, Amplitude = 4, NoiseScale = 0.026, Ridge = 2, WaterLevel = nil, TopThickness = 6},
	Marsh = {Top = Enum.Material.Grass, Under = Enum.Material.Mud, BaseHeight = 12, Amplitude = 5, NoiseScale = 0.024, Ridge = 3, WaterLevel = 17, TopThickness = 5},
}

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

local function apply_part_visuals(part: BasePart, color: Color3?, buildKind: string, lightRange: number?, lightBrightness: number?, materialOverride: Enum.Material?): ()
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
		part.Material = materialOverride or Enum.Material.SmoothPlastic

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

local function get_baseplate(): BasePart?
	if cachedBaseplate then
		return cachedBaseplate
	end

	local baseplate = workspace:FindFirstChild(BASEPLATE_NAME)
	if baseplate and baseplate:IsA("BasePart") then
		cachedBaseplate = baseplate
		cachedBaseplateParent = baseplate.Parent
		return baseplate
	end

	return nil
end

local function set_baseplate_enabled(enabled: boolean): ()
	local baseplate = get_baseplate()
	if not baseplate then
		return
	end

	if enabled then
		baseplate.Parent = cachedBaseplateParent or workspace
		cachedBaseplateParent = baseplate.Parent
		return
	end

	cachedBaseplateParent = baseplate.Parent
	baseplate.Parent = nil
end

local function create_build_part(size: Vector3, cframe: CFrame, color: Color3?, buildKind: string?, lightRange: number?, lightBrightness: number?, extraAttributes: {[string]: any}?, allowRoomReplacement: boolean?, preferNewWall: boolean?, materialOverride: Enum.Material?): BasePart?
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
							apply_part_visuals(replacementPart, sourceColor, sourceKind, nil, nil, materialOverride)
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

		apply_part_visuals(part, color, finalKind, lightRange, lightBrightness, materialOverride)
		apply_extra_attributes(part, extraAttributes)

		part.Parent = folder
		if firstPart == nil then
			firstPart = part
		end
	end

	return firstPart
end

local function update_build_part(part: BasePart, size: Vector3?, cframe: CFrame?, color: Color3?, lightRange: number?, lightBrightness: number?, materialOverride: Enum.Material?): ()
	local finalSize = size and sanitize_size(size) or part.Size
	local finalCFrame = cframe or part.CFrame
	local buildKind = get_build_kind(part)

	part.Size = finalSize
	part.CFrame = finalCFrame

	if color or buildKind == "Light" then
		apply_part_visuals(part, color or part.Color, buildKind, lightRange, lightBrightness, materialOverride)
	elseif materialOverride and buildKind ~= "Light" then
		part.Material = materialOverride
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

local function clear_terrain_region(center: Vector3, width: number, minY: number, maxY: number): ()
	local terrain = workspace.Terrain
	local height = math.max(4, maxY - minY)
	local cframe = CFrame.new(center.X, minY + (height / 2), center.Z)
	terrain:FillBlock(cframe, Vector3.new(width, height, width), Enum.Material.Air)
end

local function move_all_characters_above(yLevel: number): ()
	local charactersFolder = workspace:FindFirstChild("Characters")
	if not charactersFolder or not charactersFolder:IsA("Folder") then
		return
	end

	for _, character in charactersFolder:GetChildren() do
		if character:IsA("Model") then
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart and rootPart:IsA("BasePart") and rootPart.Position.Y < yLevel then
				local pos = Vector3.new(rootPart.Position.X, yLevel, rootPart.Position.Z)
				local forward = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
				if forward.Magnitude < 0.001 then
					forward = Vector3.new(0, 0, -1)
				else
					forward = forward.Unit
				end
				move_character_to_cframe(character, CFrame.new(pos, pos + forward))
			end
		end
	end
end

local function generate_biome_terrain(userId: number, center: Vector3, width: number, biomeName: string, hideBaseplate: boolean, topMaterialOverride: Enum.Material?, relief: number): ()
	local biome = TERRAIN_BIOMES[biomeName] or TERRAIN_BIOMES.Marsh
	local topMaterial = topMaterialOverride or biome.Top
	local reliefFactor = math.clamp(relief, 0.6, 1.8)
	local terrain = workspace.Terrain
	local seed = (userId % 997) * 0.11
	local half = width / 2
	local step = TERRAIN_STEP_SIZE
	local minY = center.Y - 64
	local maxY = center.Y + biome.BaseHeight + (biome.Amplitude * reliefFactor) + (biome.Ridge * reliefFactor) + 36

	local oldState = terrainStateByUserId[userId]
	if oldState then
		clear_terrain_region(oldState.Center, oldState.Width, oldState.MinY, oldState.MaxY)
	end

	clear_terrain_region(center, width, minY, maxY)

	for x = -half, half - step, step do
		for z = -half, half - step, step do
			local worldX = center.X + x + (step / 2)
			local worldZ = center.Z + z + (step / 2)

			local n1 = math.noise((worldX * biome.NoiseScale) + seed, (worldZ * biome.NoiseScale) - seed)
			local n2 = math.noise((worldX * biome.NoiseScale * 2) - seed, (worldZ * biome.NoiseScale * 2) + seed)
			local n3 = math.noise((worldX * biome.NoiseScale * 0.5) + (seed * 0.7), (worldZ * biome.NoiseScale * 0.5) - (seed * 0.4))
			local ridge = math.abs(math.noise((worldX * biome.NoiseScale * 0.65) + seed, (worldZ * biome.NoiseScale * 0.65) + seed))
			local smooth = (n1 * 0.55) + (n2 * 0.2) + (n3 * 0.25)
			local height = center.Y + biome.BaseHeight + (smooth * biome.Amplitude * reliefFactor) + (ridge * biome.Ridge * reliefFactor)

			local underMinY = minY
			local underHeight = math.max(6, height - underMinY)
			terrain:FillBlock(CFrame.new(worldX, underMinY + (underHeight / 2), worldZ), Vector3.new(step, underHeight, step), biome.Under)

			local topThickness = math.clamp((biome.TopThickness or 4) + (math.abs(n2) * 2), 3, 8)
			local localTopMaterial = topMaterial

			if biomeName == "Marsh" then
				if biome.WaterLevel and height < (biome.WaterLevel + 1.5) then
					localTopMaterial = Enum.Material.Grass
				else
					localTopMaterial = (n2 > 0.35) and Enum.Material.Grass or Enum.Material.Mud
				end
			elseif biomeName == "Plains" then
				if math.abs(n2) > 0.62 and math.abs(n3) > 0.45 then
					localTopMaterial = Enum.Material.Rock
				else
					localTopMaterial = Enum.Material.Grass
				end
			elseif biomeName == "Hills" then
				if n1 > 0.45 and n3 > 0.35 then
					localTopMaterial = Enum.Material.Mud
				elseif n2 < -0.5 then
					localTopMaterial = Enum.Material.Rock
				else
					localTopMaterial = Enum.Material.Ground
				end
			elseif biomeName == "Lavascape" then
				if ridge > 0.76 then
					localTopMaterial = Enum.Material.Basalt
				elseif n2 > 0.35 then
					localTopMaterial = Enum.Material.Rock
				else
					localTopMaterial = Enum.Material.Slate
				end
			elseif biomeName == "Arctic" then
				localTopMaterial = Enum.Material.Snow
			end

			terrain:FillBlock(CFrame.new(worldX, height - (topThickness / 2), worldZ), Vector3.new(step, topThickness, step), localTopMaterial)

			if biome.WaterLevel and height < biome.WaterLevel then
				local waterHeight = biome.WaterLevel - height
				if waterHeight > 1 then
					terrain:FillBlock(CFrame.new(worldX, height + (waterHeight / 2), worldZ), Vector3.new(step, waterHeight, step), Enum.Material.Water)
				end
			end

			if biome.LavaLevel and height < biome.LavaLevel then
				local lavaHeight = biome.LavaLevel - height
				if lavaHeight > 1 then
					terrain:FillBlock(CFrame.new(worldX, height + (lavaHeight / 2), worldZ), Vector3.new(step, lavaHeight, step), Enum.Material.Lava)
				end
			end

			if biomeName == "Canyons" and ridge > 0.7 then
				local pillarHeight = 4 + (ridge * 10)
				terrain:FillBlock(CFrame.new(worldX, height + (pillarHeight / 2), worldZ), Vector3.new(step, pillarHeight, step), Enum.Material.Slate)
			end
		end
	end

	terrainStateByUserId[userId] = {
		Center = center,
		Width = width,
		MinY = minY,
		MaxY = maxY,
	}

	set_baseplate_enabled(not hideBaseplate)
	move_all_characters_above(maxY + 8)
end

local function reset_generated_terrain(userId: number): ()
	local state = terrainStateByUserId[userId]
	if not state then
		set_baseplate_enabled(true)
		return
	end

	clear_terrain_region(state.Center, state.Width, state.MinY, state.MaxY)
	terrainStateByUserId[userId] = nil
	set_baseplate_enabled(true)
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

		local materialOverride = typeof(payload.Material) == "EnumItem" and payload.Material.EnumType == Enum.Material and payload.Material or nil
		local extraAttributes = typeof(payload.ExtraAttributes) == "table" and payload.ExtraAttributes or nil

		create_build_part(payload.Size, payload.CFrame, color, buildKind, lightRange, lightBrightness, extraAttributes, false, false, materialOverride)
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
					roomHasDoors,
					nil
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

		local materialOverride = typeof(payload.Material) == "EnumItem" and payload.Material.EnumType == Enum.Material and payload.Material or nil
		update_build_part(part, size, cframe, color, lightRange, lightBrightness, materialOverride)
		return
	end

	if action == "SetBaseplateEnabled" then
		if typeof(payload.Enabled) ~= "boolean" then
			return
		end

		set_baseplate_enabled(payload.Enabled)
		return
	end

	if action == "GenerateBiomeTerrain" then
		if typeof(payload.Center) ~= "Vector3" then
			return
		end

		if typeof(payload.Width) ~= "number" then
			return
		end

		local width = math.clamp(math.floor(payload.Width + 0.5), 96, 512)
		local biomeName = typeof(payload.Biome) == "string" and payload.Biome or "Marsh"
		local hideBaseplate = payload.HideBaseplate == true
		local topMaterialOverride = typeof(payload.TopMaterial) == "EnumItem" and payload.TopMaterial.EnumType == Enum.Material and payload.TopMaterial or nil
		local relief = typeof(payload.Relief) == "number" and payload.Relief or 1
		generate_biome_terrain(player.UserId, payload.Center, width, biomeName, hideBaseplate, topMaterialOverride, relief)
		return
	end

	if action == "ResetGeneratedTerrain" then
		reset_generated_terrain(player.UserId)
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
