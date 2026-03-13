------------------//SERVICES
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//VARIABLES
local module = {}

------------------//FUNCTIONS
function module.ensure_preview_part(self): Part
	local state = self.state
	local constants = self.modules.Constants

	if state.PreviewPart and state.PreviewPart.Parent == workspace then
		return state.PreviewPart
	end

	local partObject = Instance.new("Part")
	partObject.Name = "MasterBuildPreview"
	partObject.Anchored = true
	partObject.CanCollide = false
	partObject.CanTouch = false
	partObject.CanQuery = false
	partObject.Material = Enum.Material.ForceField
	partObject.Color = state.BuildColor
	partObject.Transparency = constants.PREVIEW_TRANSPARENCY
	partObject.TopSurface = Enum.SurfaceType.Smooth
	partObject.BottomSurface = Enum.SurfaceType.Smooth
	partObject.Parent = workspace

	state.PreviewPart = partObject
	return partObject
end

function module.hide_room_preview(self): ()
	local state = self.state

	for _, preview in state.RoomPreviewParts do
		preview.Transparency = 1
	end
end

function module.hide_preview(self): ()
	local partObj = module.ensure_preview_part(self)
	partObj.Transparency = 1
	partObj.CanQuery = false
	module.hide_room_preview(self)
end

function module.show_preview(self, cframe: CFrame, size: Vector3, isLight: boolean?): ()
	local state = self.state
	local constants = self.modules.Constants
	local partObj = module.ensure_preview_part(self)

	partObj.Transparency = constants.PREVIEW_TRANSPARENCY
	partObj.Size = size
	partObj.CFrame = cframe
	partObj.Color = state.BuildColor
	partObj.CanQuery = false
	partObj.Shape = Enum.PartType.Block

	if isLight then
		partObj.Material = Enum.Material.Neon
	else
		partObj.Material = Enum.Material.ForceField
	end
end

function module.show_room_start_preview(self, position: Vector3): ()
	local state = self.state

	local markerSize = Vector3.new(
		math.max(0.5, state.GridSize),
		math.max(0.5, state.GridSize),
		math.max(0.5, state.GridSize)
	)

	local markerCFrame = CFrame.new(position + Vector3.new(0, markerSize.Y / 2, 0))
	module.show_preview(self, markerCFrame, markerSize)
end

function module.get_wall_endpoint_candidates(self): {Vector3}
	local selection = self.modules.Selection
	local utility = self.modules.Utility
	local buildFolder = selection.get_build_folder(self)

	if not buildFolder then
		return {}
	end

	local points = {}

	for _, child in buildFolder:GetChildren() do
		if child:IsA("BasePart") then
			local buildKind = child:GetAttribute("BuildKind")

			if buildKind == "Wall" then
				local center = child.Position
				local lengthAxis = utility.get_flat_wall_unit(child.CFrame.LookVector)
				local halfLength = child.Size.Z * 0.5

				if child.Size.X > child.Size.Z then
					lengthAxis = utility.get_flat_wall_unit(child.CFrame.RightVector)
					halfLength = child.Size.X * 0.5
				end

				local baseY = center.Y - (child.Size.Y * 0.5)
				local pointA = center - (lengthAxis * halfLength)
				local pointB = center + (lengthAxis * halfLength)

				table.insert(points, Vector3.new(pointA.X, baseY, pointA.Z))
				table.insert(points, Vector3.new(pointB.X, baseY, pointB.Z))
			end
		end
	end

	return points
end

function module.snap_wall_point(self, rawPoint: Vector3, anchorPoint: Vector3?): Vector3
	local state = self.state
	local constants = self.modules.Constants
	local utility = self.modules.Utility
	local snappedPoint = utility.snap_vector3(rawPoint, state.GridSize)

	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
		return snappedPoint
	end

	local candidates = module.get_wall_endpoint_candidates(self)
	local bestPoint = snappedPoint
	local bestDistance = constants.WALL_ENDPOINT_SNAP_DISTANCE

	for _, point in candidates do
		local candidatePoint = Vector3.new(point.X, snappedPoint.Y, point.Z)
		local distance = (Vector3.new(candidatePoint.X, 0, candidatePoint.Z) - Vector3.new(snappedPoint.X, 0, snappedPoint.Z)).Magnitude

		if distance <= bestDistance then
			bestDistance = distance
			bestPoint = candidatePoint
		end
	end

	if anchorPoint then
		bestPoint = Vector3.new(bestPoint.X, anchorPoint.Y, bestPoint.Z)
	end

	return utility.snap_vector3(bestPoint, state.GridSize)
end

function module.get_create_preview_cframe_and_size(self): (CFrame?, Vector3?)
	local state = self.state
	local raycast = self.modules.Raycast
	local utility = self.modules.Utility
	local currentPoint = raycast.get_snapped_hit_position(self)

	if not currentPoint then
		return nil, nil
	end

	if not state.CreateAnchor then
		local cframe = CFrame.new(currentPoint + Vector3.new(0, state.GridSize / 2, 0))
		local size = Vector3.new(state.GridSize, state.GridSize, state.GridSize)
		return cframe, size
	end

	return utility.build_box_from_two_points(state.CreateAnchor, currentPoint, state.GridSize)
end

function module.get_wall_preview_cframe_and_size(self): (CFrame?, Vector3?)
	local state = self.state
	local raycast = self.modules.Raycast
	local utility = self.modules.Utility
	local currentPoint = raycast.get_snapped_hit_position(self)

	if not currentPoint then
		return nil, nil
	end

	currentPoint = module.snap_wall_point(self, currentPoint, state.WallAnchor)

	local height = math.max(1, state.WallHeight)
	local thickness = math.max(0.25, state.WallThickness)

	if not state.WallAnchor then
		local size = Vector3.new(thickness, height, state.GridSize)
		local cframe = CFrame.lookAt(
			currentPoint + Vector3.new(0, height / 2, 0),
			currentPoint + Vector3.new(0, height / 2, -1)
		)
		return cframe, size
	end

	return utility.build_wall_from_points(state.WallAnchor, currentPoint, height, thickness, state.GridSize)
end

function module.get_light_preview_cframe_and_size(self): (CFrame?, Vector3?)
	local state = self.state
	local raycast = self.modules.Raycast
	local currentPoint = raycast.get_snapped_hit_position(self)

	if not currentPoint then
		return nil, nil
	end

	local cframe = CFrame.new(currentPoint + Vector3.new(0, state.CreateSize.Y / 2, 0))
	return cframe, state.CreateSize
end

function module.refresh_room_preview(self): ()
	local state = self.state
	local raycast = self.modules.Raycast
	local roomBuilder = self.modules.RoomBuilder
	local currentPoint = raycast.get_snapped_hit_position(self)

	if not currentPoint then
		module.ensure_preview_part(self).Transparency = 1
		module.hide_room_preview(self)
		return
	end

	if not roomBuilder.Anchor then
		module.hide_room_preview(self)
		module.show_room_start_preview(self, currentPoint)
		return
	end

	module.show_room_start_preview(self, roomBuilder.Anchor)

	local raycastResult = raycast.build_raycast_result(self)
	local exactPos = raycastResult and raycastResult.Position or module.snap_wall_point(self, currentPoint)
	local isShiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

	local partsData = roomBuilder.get_room_data(
		exactPos,
		state.GridSize,
		state.RoomHeight,
		state.WallThickness,
		4,
		7.5,
		state.CreateWithFloor,
		state.CreateWithCeiling,
		isShiftHeld
	)

	if #partsData == 0 then
		module.hide_room_preview(self)
		return
	end

	while #state.RoomPreviewParts < #partsData do
		local preview = Instance.new("Part")
		preview.Name = "MasterBuildRoomPreview"
		preview.Anchored = true
		preview.CanCollide = false
		preview.CanQuery = false
		preview.Material = Enum.Material.ForceField
		preview.TopSurface = Enum.SurfaceType.Smooth
		preview.BottomSurface = Enum.SurfaceType.Smooth
		preview.Parent = workspace
		table.insert(state.RoomPreviewParts, preview)
	end

	local index = 1
	while state.RoomPreviewParts[index] do
		local preview = state.RoomPreviewParts[index]
		local data = partsData[index]

		if data then
			preview.Size = data.Size
			preview.CFrame = data.CFrame
			preview.Color = state.BuildColor
			preview.Transparency = self.modules.Constants.PREVIEW_TRANSPARENCY
		else
			preview.Transparency = 1
		end

		index += 1
	end
end

function module.refresh_preview(self): ()
	local state = self.state
	local permissions = self.modules.Permissions
	local gui = self.modules.Gui
	local constants = self.modules.Constants

	if not permissions.is_master(self) or not gui.is_sidebar_visible(self) then
		module.hide_preview(self)
		return
	end

	if state.ToolMode == constants.TOOL_MODE_NONE or state.ToolMode == constants.TOOL_MODE_SELECT then
		module.hide_preview(self)
		return
	end

	if state.ToolMode == constants.TOOL_MODE_CREATE then
		module.hide_room_preview(self)

		local cframe, size = module.get_create_preview_cframe_and_size(self)
		if cframe and size then
			module.show_preview(self, cframe, size)
			return
		end
	end

	if state.ToolMode == constants.TOOL_MODE_WALL then
		module.hide_room_preview(self)

		local cframe, size = module.get_wall_preview_cframe_and_size(self)
		if cframe and size then
			module.show_preview(self, cframe, size)
			return
		end
	end

	if state.ToolMode == constants.TOOL_MODE_ROOM then
		module.refresh_room_preview(self)
		return
	end

	if state.ToolMode == constants.TOOL_MODE_LIGHT then
		module.hide_room_preview(self)

		local cframe, size = module.get_light_preview_cframe_and_size(self)
		if cframe and size then
			module.show_preview(self, cframe, size, true)
			return
		end
	end

	module.hide_preview(self)
end

return module