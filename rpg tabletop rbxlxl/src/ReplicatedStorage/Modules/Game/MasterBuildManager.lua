------------------//SERVICES

------------------//CONSTANTS
local MASTER_TEAM_NAME: string = "Mestre"
local BUILD_FOLDER_NAME: string = "TabletopBuildParts"
local MIN_PART_SIZE: number = 1
local MAX_PART_SIZE: number = 512
local DEFAULT_COLOR: Color3 = Color3.fromRGB(163, 162, 165)

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

local function create_build_part(size: Vector3, cframe: CFrame, color: Color3?, buildKind: string?, lightRange: number?, lightBrightness: number?): BasePart?
	local folder = get_build_folder()
	if not folder then return nil end

	local kind = buildKind or "Part"
	local part = Instance.new("Part")
	part.Name = "BuildPart"
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = true
	part.CanQuery = true
	part.Color = sanitize_color(color)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = sanitize_size(size)
	part.CFrame = cframe
	part:SetAttribute("IsTabletopBuildPart", true)
	part:SetAttribute("BuildKind", kind)
	part.Shape = Enum.PartType.Block

	if kind == "Light" then
		part.Material = Enum.Material.Neon
		local pointLight = Instance.new("PointLight")
		pointLight.Color = part.Color
		pointLight.Range = typeof(lightRange) == "number" and lightRange or 20
		pointLight.Brightness = typeof(lightBrightness) == "number" and lightBrightness or 2
		pointLight.Shadows = true
		pointLight.Parent = part
	else
		part.Material = Enum.Material.SmoothPlastic
	end

	part.Parent = folder
	return part
end

local function update_build_part(part: BasePart, size: Vector3?, cframe: CFrame?, color: Color3?, lightRange: number?, lightBrightness: number?): ()
	if size then part.Size = sanitize_size(size) end
	if cframe then part.CFrame = cframe end

	if color then
		part.Color = color
		local light = part:FindFirstChildOfClass("PointLight")
		if light then light.Color = color end
	end

	if lightRange or lightBrightness then
		local light = part:FindFirstChildOfClass("PointLight")
		if light then
			if lightRange then light.Range = lightRange end
			if lightBrightness then light.Brightness = lightBrightness end
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

local function slice_wall(wallCFrame, wallSize, doorCFrame, doorSize)
	local localDoor = wallCFrame:ToObjectSpace(doorCFrame)

	local extX = math.abs(localDoor.RightVector.X) * doorSize.X/2 + math.abs(localDoor.UpVector.X) * doorSize.Y/2 + math.abs(localDoor.LookVector.X) * doorSize.Z/2
	local extY = math.abs(localDoor.RightVector.Y) * doorSize.X/2 + math.abs(localDoor.UpVector.Y) * doorSize.Y/2 + math.abs(localDoor.LookVector.Y) * doorSize.Z/2
	local extZ = math.abs(localDoor.RightVector.Z) * doorSize.X/2 + math.abs(localDoor.UpVector.Z) * doorSize.Y/2 + math.abs(localDoor.LookVector.Z) * doorSize.Z/2

	if math.abs(localDoor.Position.X) > wallSize.X/2 + extX then return {{CFrame = wallCFrame, Size = wallSize}} end
	if math.abs(localDoor.Position.Y) > wallSize.Y/2 + extY then return {{CFrame = wallCFrame, Size = wallSize}} end
	if math.abs(localDoor.Position.Z) > wallSize.Z/2 + extZ then return {{CFrame = wallCFrame, Size = wallSize}} end

	local dMin = localDoor.Position.Z - extZ
	local dMax = localDoor.Position.Z + extZ
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

	local holeTopY = localDoor.Position.Y + extY
	local holeBottomY = localDoor.Position.Y - extY
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

		create_build_part(payload.Size, payload.CFrame, color, buildKind, lightRange, lightBrightness)
		return
	end

	if action == "CreateRoomParts" then
		if typeof(payload.Parts) ~= "table" then return end
		local color = typeof(payload.Color) == "Color3" and payload.Color or nil
		local roomId = typeof(payload.RoomId) == "string" and payload.RoomId or nil

		for _, partData in payload.Parts do
			local p = create_build_part(
				partData.Size, 
				partData.CFrame, 
				color, 
				partData.BuildKind, 
				nil, 
				nil
			)
			if p and roomId then p:SetAttribute("RoomId", roomId) end
		end

		if typeof(payload.Doors) == "table" then
			local folder = get_build_folder()
			if folder then
				local raycastParams = RaycastParams.new()
				raycastParams.FilterType = Enum.RaycastFilterType.Include
				raycastParams.FilterDescendantsInstances = {folder}

				for _, door in payload.Doors do
					local hitParts = {}

					-- Lança 4 Raycasts a partir do centro da porta para os lados e frente/tras procurando paredes velhas
					local dirs = { door.CFrame.RightVector, -door.CFrame.RightVector, door.CFrame.LookVector, -door.CFrame.LookVector }
					for _, dir in dirs do
						local result = workspace:Raycast(door.CFrame.Position, dir * 4, raycastParams)
						if result and result.Instance and result.Instance:GetAttribute("BuildKind") == "Wall" and result.Instance:GetAttribute("RoomId") ~= roomId then
							hitParts[result.Instance] = true
						end
					end

					for existingPart, _ in hitParts do
						-- Projeta perfeitamente a porta no espaço local da parede pra forçar o corte
						local localPos = existingPart.CFrame:ToObjectSpace(door.CFrame).Position
						local projectedDoorCFrame = existingPart.CFrame * CFrame.new(0, localPos.Y, localPos.Z) * (existingPart.CFrame:Inverse() * door.CFrame).Rotation

						local sliced = slice_wall(existingPart.CFrame, existingPart.Size, projectedDoorCFrame, door.Size)

						if #sliced ~= 1 or sliced[1].Size ~= existingPart.Size then
							local oldRoomId = existingPart:GetAttribute("RoomId")
							for _, s in sliced do
								local p = create_build_part(s.Size, s.CFrame, existingPart.Color, "Wall", nil, nil)
								if p and oldRoomId then p:SetAttribute("RoomId", oldRoomId) end
							end
							existingPart:Destroy()
						end
					end
				end
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
					if child:GetAttribute("RoomId") == roomId then
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