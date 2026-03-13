------------------//VARIABLES
local module = {}

------------------//FUNCTIONS
function module.stop_character_mouse_drag(self): ()
	local state = self.state

	state.CharacterMouseDragActive = false
	state.CharacterMouseDragTarget = nil
	state.CharacterMouseDragPlaneY = 0
	state.CharacterMouseDragOffset = Vector3.zero
	state.LastCharacterMouseDragSend = 0
end

function module.finish_gizmo_drag(self): ()
	local state = self.state

	state.GizmoDragging = false
	state.DragMode = ""
	state.DragFace = nil
	state.DragAxis = nil
	state.DragBasePartCFrame = nil
	state.DragBasePartSize = nil
	state.DragBaseCharacterCFrame = nil
	state.LastDragSend = 0
end

function module.start_character_mouse_drag(self, targetModel: Model): ()
	local state = self.state
	local selection = self.modules.Selection
	local raycast = self.modules.Raycast
	local rootPart = selection.get_root_part_for_character(self, targetModel)

	if not selection.can_drag_character(self, targetModel) then
		return
	end

	if not rootPart then
		return
	end

	local planePoint = raycast.get_mouse_point_on_horizontal_plane(self, rootPart.Position.Y)
	if not planePoint then
		return
	end

	state.CharacterMouseDragActive = true
	state.CharacterMouseDragTarget = targetModel
	state.CharacterMouseDragPlaneY = rootPart.Position.Y
	state.CharacterMouseDragOffset = rootPart.Position - Vector3.new(planePoint.X, rootPart.Position.Y, planePoint.Z)
	state.LastCharacterMouseDragSend = 0
end

function module.update_character_mouse_drag(self): ()
	local state = self.state
	local selection = self.modules.Selection
	local raycast = self.modules.Raycast
	local utility = self.modules.Utility
	local actions = self.modules.Actions

	if not state.CharacterMouseDragActive or not state.CharacterMouseDragTarget then
		return
	end

	if not selection.can_drag_character(self, state.CharacterMouseDragTarget) then
		module.stop_character_mouse_drag(self)
		return
	end

	if not selection.is_valid_selected_character(self, state.CharacterMouseDragTarget) then
		selection.clear_selection(self)
		return
	end

	local rootPart = selection.get_root_part_for_character(self, state.CharacterMouseDragTarget)
	if not rootPart then
		selection.clear_selection(self)
		return
	end

	local planePoint = raycast.get_mouse_point_on_horizontal_plane(self, state.CharacterMouseDragPlaneY)
	if not planePoint then
		return
	end

	local targetPosition = Vector3.new(
		utility.snap_number(planePoint.X + state.CharacterMouseDragOffset.X, state.GridSize),
		state.CharacterMouseDragPlaneY,
		utility.snap_number(planePoint.Z + state.CharacterMouseDragOffset.Z, state.GridSize)
	)

	local newCFrame = CFrame.new(targetPosition) * utility.get_rotation_only_cframe(rootPart.CFrame)
	local nowTime = time()

	rootPart.CFrame = newCFrame

	if nowTime - state.LastCharacterMouseDragSend < self.modules.Constants.DRAG_SEND_INTERVAL then
		return
	end

	state.LastCharacterMouseDragSend = nowTime

	actions.fire_build(self, "MoveCharacter", {
		Character = state.CharacterMouseDragTarget,
		CFrame = newCFrame,
	})
end

function module.begin_drag(self, modeName: string, face: Enum.NormalId): ()
	local state = self.state
	local selection = self.modules.Selection

	state.GizmoDragging = true
	state.DragMode = modeName
	state.DragFace = face
	state.DragAxis = nil
	state.LastDragSend = 0

	if state.SelectedKind == "Part" and state.SelectedPart and selection.is_valid_selected_part(self, state.SelectedPart) then
		state.DragBasePartCFrame = state.SelectedPart.CFrame
		state.DragBasePartSize = state.SelectedPart.Size
		state.DragBaseCharacterCFrame = nil
		return
	end

	if state.SelectedKind == "Character" and state.SelectedCharacter and selection.is_valid_selected_character(self, state.SelectedCharacter) then
		local rootPart = selection.get_root_part_for_character(self, state.SelectedCharacter)

		if rootPart then
			state.DragBaseCharacterCFrame = rootPart.CFrame
		end

		state.DragBasePartCFrame = nil
		state.DragBasePartSize = nil
		module.stop_character_mouse_drag(self)
	end
end

function module.begin_rotate(self, axis: Enum.Axis): ()
	local state = self.state
	local selection = self.modules.Selection

	state.GizmoDragging = true
	state.DragMode = "Rotate"
	state.DragAxis = axis
	state.DragFace = nil
	state.LastDragSend = 0

	if state.SelectedKind == "Part" and state.SelectedPart and selection.is_valid_selected_part(self, state.SelectedPart) then
		state.DragBasePartCFrame = state.SelectedPart.CFrame
	elseif state.SelectedKind == "Character" and state.SelectedCharacter and selection.is_valid_selected_character(self, state.SelectedCharacter) then
		local rootPart = selection.get_root_part_for_character(self, state.SelectedCharacter)

		if rootPart then
			state.DragBasePartCFrame = rootPart.CFrame
		end
	end
end

function module.maybe_send_drag_update(self, nowTime: number, callback: () -> ()): ()
	local state = self.state
	local constants = self.modules.Constants

	if nowTime - state.LastDragSend < constants.DRAG_SEND_INTERVAL then
		return
	end

	state.LastDragSend = nowTime
	callback()
end

function module.update_selected_part_from_drag(self, distance: number): ()
	local state = self.state
	local selection = self.modules.Selection
	local utility = self.modules.Utility
	local actions = self.modules.Actions

	if not state.SelectedPart
		or not selection.is_valid_selected_part(self, state.SelectedPart)
		or not state.DragBasePartCFrame
		or not state.DragBasePartSize
		or not state.DragFace then
		selection.clear_selection(self)
		return
	end

	local snappedDistance = utility.snap_number(distance, state.GridSize)
	local axisVector = utility.vector_from_normal_id(state.DragFace, state.DragBasePartCFrame)

	if state.DragMode == "Move" then
		local newCFrame = state.DragBasePartCFrame + axisVector * snappedDistance

		module.maybe_send_drag_update(self, time(), function()
			actions.fire_build(self, "UpdatePart", {
				Part = state.SelectedPart,
				CFrame = newCFrame,
			})
		end)

		return
	end

	if state.DragMode == "Resize" then
		local axisName = utility.local_axis_name_from_normal(state.DragFace)
		local newSize = state.DragBasePartSize
		local centerShift = axisVector * (snappedDistance / 2)

		if axisName == "X" then
			newSize = Vector3.new(math.max(1, state.DragBasePartSize.X + snappedDistance), state.DragBasePartSize.Y, state.DragBasePartSize.Z)
		elseif axisName == "Y" then
			newSize = Vector3.new(state.DragBasePartSize.X, math.max(1, state.DragBasePartSize.Y + snappedDistance), state.DragBasePartSize.Z)
		else
			newSize = Vector3.new(state.DragBasePartSize.X, state.DragBasePartSize.Y, math.max(1, state.DragBasePartSize.Z + snappedDistance))
		end

		local newCFrame = state.DragBasePartCFrame + centerShift

		module.maybe_send_drag_update(self, time(), function()
			actions.fire_build(self, "UpdatePart", {
				Part = state.SelectedPart,
				Size = newSize,
				CFrame = newCFrame,
			})
		end)
	end
end

function module.update_selected_character_from_drag(self, distance: number): ()
	local state = self.state
	local selection = self.modules.Selection
	local utility = self.modules.Utility
	local actions = self.modules.Actions

	if not state.SelectedCharacter
		or not selection.is_valid_selected_character(self, state.SelectedCharacter)
		or not state.DragBaseCharacterCFrame
		or not state.DragFace then
		selection.clear_selection(self)
		return
	end

	local snappedDistance = utility.snap_number(distance, state.GridSize)
	local axisVector = utility.vector_from_character_normal_id(state.DragFace, state.DragBaseCharacterCFrame)
	local newCFrame = state.DragBaseCharacterCFrame + axisVector * snappedDistance

	local rootPart = selection.get_root_part_for_character(self, state.SelectedCharacter)
	if rootPart then
		rootPart.CFrame = newCFrame
	end

	module.maybe_send_drag_update(self, time(), function()
		actions.fire_build(self, "MoveCharacter", {
			Character = state.SelectedCharacter,
			CFrame = newCFrame,
		})
	end)
end

function module.update_selected_part_rotation(self, relativeAngle: number): ()
	local state = self.state
	local selection = self.modules.Selection
	local utility = self.modules.Utility
	local actions = self.modules.Actions

	if not state.DragBasePartCFrame or not state.DragAxis then
		selection.clear_selection(self)
		return
	end

	local snappedDegrees = utility.snap_number(math.deg(relativeAngle), self.modules.Constants.ROTATION_STEP_DEGREES)
	local snappedAngle = math.rad(snappedDegrees)
	local rotation = utility.rotation_cframe_from_axis(state.DragAxis, snappedAngle)
	local newCFrame = state.DragBasePartCFrame * rotation

	if state.SelectedKind == "Part" and state.SelectedPart and selection.is_valid_selected_part(self, state.SelectedPart) then
		module.maybe_send_drag_update(self, time(), function()
			actions.fire_build(self, "UpdatePart", {
				Part = state.SelectedPart,
				CFrame = newCFrame,
			})
		end)
	elseif state.SelectedKind == "Character" and state.SelectedCharacter and selection.is_valid_selected_character(self, state.SelectedCharacter) then
		local rootPart = selection.get_root_part_for_character(self, state.SelectedCharacter)

		if rootPart then
			rootPart.CFrame = newCFrame
		end

		module.maybe_send_drag_update(self, time(), function()
			actions.fire_build(self, "MoveCharacter", {
				Character = state.SelectedCharacter,
				CFrame = newCFrame,
			})
		end)
	end
end

function module.connect_handles(self): ()
	local state = self.state
	local selection = self.modules.Selection

	if state.HandlesConnected then
		return
	end

	selection.ensure_handles(self)
	state.HandlesConnected = true

	if state.MoveHandles then
		state.MoveHandles.MouseButton1Down:Connect(function(face: Enum.NormalId)
			module.begin_drag(self, "Move", face)
		end)

		state.MoveHandles.MouseButton1Up:Connect(function()
			module.finish_gizmo_drag(self)
		end)

		state.MoveHandles.MouseDrag:Connect(function(face: Enum.NormalId, distance: number)
			if state.SelectedKind == "Part" then
				module.update_selected_part_from_drag(self, distance)
				return
			end

			if state.SelectedKind == "Character" then
				module.update_selected_character_from_drag(self, distance)
			end
		end)
	end

	if state.ResizeHandles then
		state.ResizeHandles.MouseButton1Down:Connect(function(face: Enum.NormalId)
			module.begin_drag(self, "Resize", face)
		end)

		state.ResizeHandles.MouseButton1Up:Connect(function()
			module.finish_gizmo_drag(self)
		end)

		state.ResizeHandles.MouseDrag:Connect(function(face: Enum.NormalId, distance: number)
			if state.SelectedKind == "Part" then
				module.update_selected_part_from_drag(self, distance)
			end
		end)
	end

	if state.RotateHandles then
		state.RotateHandles.MouseButton1Down:Connect(function(axis: Enum.Axis)
			module.begin_rotate(self, axis)
		end)

		state.RotateHandles.MouseButton1Up:Connect(function()
			module.finish_gizmo_drag(self)
		end)

		state.RotateHandles.MouseDrag:Connect(function(axis: Enum.Axis, relativeAngle: number)
			state.DragAxis = axis
			module.update_selected_part_rotation(self, relativeAngle)
		end)
	end
end

return module