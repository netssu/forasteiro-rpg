------------------//SERVICES
local HttpService: HttpService = game:GetService("HttpService")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//VARIABLES
local module = {}

------------------//FUNCTIONS
function module.fire_build(self, action: string, payload: any?): ()
	local state = self.state
	local request = payload or {}

	request.Action = action
	state.MasterBuildEvent:FireServer(request)
end

function module.reset_build_session(self, preserveCharacterSelection: boolean?): ()
	local state = self.state
	local roomBuilder = self.modules.RoomBuilder
	local preview = self.modules.Preview
	local selection = self.modules.Selection
	local gui = self.modules.Gui

	state.CreateAnchor = nil
	state.WallAnchor = nil
	roomBuilder.reset()

	if preserveCharacterSelection and state.SelectedKind == "Character" then
		preview.hide_preview(self)
		selection.update_handles_for_selection(self)
		gui.update_sidebar_toggle_buttons(self)
		return
	end

	selection.clear_selection(self)
	preview.hide_preview(self)
	gui.update_sidebar_toggle_buttons(self)
end

function module.apply_inputs_to_state(self): ()
	local state = self.state
	local constants = self.modules.Constants
	local utility = self.modules.Utility
	local gui = self.modules.Gui
	local preview = self.modules.Preview

	state.GridSize = utility.sanitize_text_number(state.GridBox and state.GridBox.Text or tostring(constants.DEFAULT_GRID_SIZE), constants.DEFAULT_GRID_SIZE, 0.25)
	state.WallHeight = utility.sanitize_text_number(state.WallHeightBox and state.WallHeightBox.Text or tostring(constants.DEFAULT_WALL_HEIGHT), constants.DEFAULT_WALL_HEIGHT, 1)
	state.WallThickness = utility.sanitize_text_number(state.WallThicknessBox and state.WallThicknessBox.Text or tostring(constants.DEFAULT_WALL_THICKNESS), constants.DEFAULT_WALL_THICKNESS, 0.25)
	state.RoomHeight = utility.sanitize_text_number(state.RoomHeightBox and state.RoomHeightBox.Text or tostring(state.WallHeight), state.WallHeight, 1)

	local sizeX = utility.sanitize_text_number(state.SizeXBox and state.SizeXBox.Text or tostring(constants.DEFAULT_CREATE_SIZE.X), constants.DEFAULT_CREATE_SIZE.X, 1)
	local sizeY = utility.sanitize_text_number(state.SizeYBox and state.SizeYBox.Text or tostring(constants.DEFAULT_CREATE_SIZE.Y), constants.DEFAULT_CREATE_SIZE.Y, 1)
	local sizeZ = utility.sanitize_text_number(state.SizeZBox and state.SizeZBox.Text or tostring(constants.DEFAULT_CREATE_SIZE.Z), constants.DEFAULT_CREATE_SIZE.Z, 1)

	state.LightRange = utility.sanitize_text_number(state.LightRangeBox and state.LightRangeBox.Text or "20", 20, 1)
	state.LightBrightness = utility.sanitize_text_number(state.LightBrightnessBox and state.LightBrightnessBox.Text or "2", 2, 0)

	state.CreateSize = Vector3.new(sizeX, sizeY, sizeZ)
	state.BuildColor = gui.read_color_from_boxes(self)

	gui.sync_boxes_from_state(self)
	preview.refresh_preview(self)
end

function module.set_tool_mode(self, newMode: string): ()
	local state = self.state
	local constants = self.modules.Constants
	local roomBuilder = self.modules.RoomBuilder
	local gui = self.modules.Gui
	local selection = self.modules.Selection
	local preview = self.modules.Preview

	state.CreateAnchor = nil
	state.WallAnchor = nil
	roomBuilder.reset()
	selection.clear_selection(self)

	if state.ToolMode == newMode then
		state.ToolMode = constants.TOOL_MODE_NONE
	else
		state.ToolMode = newMode
	end

	if state.ToolMode == constants.TOOL_MODE_WALL or state.ToolMode == constants.TOOL_MODE_ROOM or state.ToolMode == constants.TOOL_MODE_LIGHT then
		gui.open_room_sidebar(self)
	elseif state.ToolMode == constants.TOOL_MODE_SELECT or state.ToolMode == constants.TOOL_MODE_CREATE then
		gui.open_build_sidebar(self)
	end

	if state.RoomSettingsFrame then
		state.RoomSettingsFrame.Visible = state.ToolMode == constants.TOOL_MODE_ROOM
	end

	if state.ToolMode == constants.TOOL_MODE_NONE then
		gui.set_status(self, "Modo livre")
	elseif state.ToolMode == constants.TOOL_MODE_SELECT then
		gui.set_status(self, "Modo seleção")
	elseif state.ToolMode == constants.TOOL_MODE_CREATE then
		gui.set_status(self, "Modo criação 3D")
	elseif state.ToolMode == constants.TOOL_MODE_WALL then
		gui.set_status(self, "Modo parede")
	elseif state.ToolMode == constants.TOOL_MODE_ROOM then
		gui.set_status(self, "Modo sala")
	elseif state.ToolMode == constants.TOOL_MODE_LIGHT then
		gui.set_status(self, "Modo luz")

		if state.ColorRBox then
			state.ColorRBox.Text = tostring(math.floor(constants.DEFAULT_LIGHT_COLOR.R * 255))
		end

		if state.ColorGBox then
			state.ColorGBox.Text = tostring(math.floor(constants.DEFAULT_LIGHT_COLOR.G * 255))
		end

		if state.ColorBBox then
			state.ColorBBox.Text = tostring(math.floor(constants.DEFAULT_LIGHT_COLOR.B * 255))
		end

		module.apply_inputs_to_state(self)
	end

	gui.update_mode_buttons(self)
	selection.update_handles_for_selection(self)
	preview.refresh_preview(self)
end

function module.create_current_preview_part(self): ()
	local state = self.state
	local preview = self.modules.Preview
	local partObj = preview.ensure_preview_part(self)
	local partKind = "Part"

	if partObj.Transparency >= 1 then
		return
	end

	if state.ToolMode == self.modules.Constants.TOOL_MODE_WALL then
		partKind = "Wall"
	end

	if state.ToolMode == self.modules.Constants.TOOL_MODE_LIGHT then
		partKind = "Light"
	end

	module.fire_build(self, "CreatePart", {
		Size = partObj.Size,
		CFrame = partObj.CFrame,
		Color = state.BuildColor,
		BuildKind = partKind,
		LightRange = state.LightRange,
		LightBrightness = state.LightBrightness,
	})
end

function module.delete_selected_target(self): ()
	local state = self.state
	local constants = self.modules.Constants
	local selection = self.modules.Selection

	if state.ToolMode ~= constants.TOOL_MODE_SELECT then
		return
	end

	if state.SelectedKind == "Part" and state.SelectedPart and selection.is_valid_selected_part(self, state.SelectedPart) then
		module.fire_build(self, "DeletePart", {
			Part = state.SelectedPart,
		})
	end

	selection.clear_selection(self)
end

function module.apply_color_to_selected_part(self): ()
	local state = self.state
	local constants = self.modules.Constants
	local selection = self.modules.Selection

	if state.ToolMode ~= constants.TOOL_MODE_SELECT then
		return
	end

	if not state.SelectedPart or not selection.is_valid_selected_part(self, state.SelectedPart) then
		selection.clear_selection(self)
		return
	end

	module.apply_inputs_to_state(self)

	module.fire_build(self, "UpdatePart", {
		Part = state.SelectedPart,
		Color = state.BuildColor,
	})
end

function module.apply_size_to_selected_part(self): ()
	local state = self.state
	local constants = self.modules.Constants
	local selection = self.modules.Selection

	if state.ToolMode ~= constants.TOOL_MODE_SELECT then
		return
	end

	if not state.SelectedPart or not selection.is_valid_selected_part(self, state.SelectedPart) then
		selection.clear_selection(self)
		return
	end

	module.apply_inputs_to_state(self)

	module.fire_build(self, "UpdatePart", {
		Part = state.SelectedPart,
		Size = Vector3.new(state.CreateSize.X, state.CreateSize.Y, state.CreateSize.Z),
		LightRange = state.LightRange,
		LightBrightness = state.LightBrightness,
	})
end

function module.handle_select_click(self, partObj: BasePart?, targetModel: Model?): ()
	local selection = self.modules.Selection
	local gui = self.modules.Gui
	local drag = self.modules.Drag

	if partObj then
		selection.set_selected_part(self, partObj)
		return
	end

	if targetModel then
		selection.set_selected_character(self, targetModel)
		drag.start_character_mouse_drag(self, targetModel)
		return
	end

	selection.clear_selection(self)
	gui.set_status(self, "Nada selecionado")
end

function module.handle_create_click(self): ()
	local state = self.state
	local raycast = self.modules.Raycast
	local gui = self.modules.Gui
	local preview = self.modules.Preview
	local currentPoint = raycast.get_snapped_hit_position(self)

	if not currentPoint then
		return
	end

	if not state.CreateAnchor then
		state.CreateAnchor = currentPoint
		gui.set_status(self, "Criar: escolha o segundo ponto")
		preview.refresh_preview(self)
		return
	end

	module.create_current_preview_part(self)
	state.CreateAnchor = nil
	gui.set_status(self, "Peça criada")
	preview.refresh_preview(self)
end

function module.handle_wall_click(self): ()
	local state = self.state
	local raycast = self.modules.Raycast
	local preview = self.modules.Preview
	local gui = self.modules.Gui
	local currentPoint = raycast.get_snapped_hit_position(self)

	if not currentPoint then
		return
	end

	currentPoint = preview.snap_wall_point(self, currentPoint, state.WallAnchor)

	if not state.WallAnchor then
		state.WallAnchor = currentPoint
		gui.set_status(self, "Parede: escolha o ponto final")
		preview.refresh_preview(self)
		return
	end

	module.create_current_preview_part(self)
	state.WallAnchor = nil
	gui.set_status(self, "Parede criada")
	preview.refresh_preview(self)
end

function module.handle_room_click(self): ()
	local state = self.state
	local raycast = self.modules.Raycast
	local preview = self.modules.Preview
	local roomBuilder = self.modules.RoomBuilder
	local gui = self.modules.Gui
	local currentPoint = raycast.get_snapped_hit_position(self)

	if not currentPoint then
		return
	end

	currentPoint = preview.snap_wall_point(self, currentPoint)

	if not roomBuilder.Anchor then
		roomBuilder.Anchor = currentPoint
		gui.set_status(self, "Sala: escolha o ponto final (Segure Shift para portas)")
		preview.refresh_preview(self)
		return
	end

	local raycastResult = raycast.build_raycast_result(self)
	local exactPos = raycastResult and raycastResult.Position or preview.snap_wall_point(self, currentPoint)
	local isShiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

	local _, hoveringDoor = roomBuilder.get_room_data(
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

	if isShiftHeld then
		if not roomBuilder.LockedB then
			roomBuilder.LockedB = currentPoint
		end

		if hoveringDoor then
			roomBuilder.add_door(hoveringDoor.CFrame, hoveringDoor.Size)
			gui.set_status(self, "Sala: porta adicionada (solte Shift para criar)")
		end

		preview.refresh_preview(self)
		return
	end

	local finalParts = roomBuilder.get_room_data(
		exactPos,
		state.GridSize,
		state.RoomHeight,
		state.WallThickness,
		4,
		7.5,
		state.CreateWithFloor,
		state.CreateWithCeiling,
		false
	)

	local roomId = HttpService:GenerateGUID(false)

	module.fire_build(self, "CreateRoomParts", {
		RoomId = roomId,
		Parts = finalParts,
		Doors = roomBuilder.Doors,
		Color = state.BuildColor,
	})

	roomBuilder.reset()
	gui.set_status(self, "Sala criada")
	preview.refresh_preview(self)
end

function module.handle_light_click(self): ()
	local gui = self.modules.Gui
	local preview = self.modules.Preview
	local currentPoint = self.modules.Raycast.get_snapped_hit_position(self)

	if not currentPoint then
		return
	end

	module.create_current_preview_part(self)
	gui.set_status(self, "Luz criada")
	preview.refresh_preview(self)
end

function module.handle_world_left_click(self): ()
	local state = self.state
	local permissions = self.modules.Permissions
	local raycast = self.modules.Raycast
	local gui = self.modules.Gui
	local constants = self.modules.Constants
	local selection = self.modules.Selection
	local drag = self.modules.Drag

	if not permissions.can_use_character_drag(self) and not permissions.is_master(self) then
		return
	end

	if raycast.is_pointer_over_gui(self) then
		return
	end

	if state.GizmoDragging then
		return
	end

	local canSelectCharacters = state.ToolMode == constants.TOOL_MODE_NONE
		or state.ToolMode == constants.TOOL_MODE_SELECT
		or not gui.is_sidebar_visible(self)

	if state.HoverKind == "" then
		selection.clear_selection(self)
	end

	if state.HoverKind == "Character" and state.HoverCharacter and canSelectCharacters and selection.can_drag_character(self, state.HoverCharacter) then
		if state.SelectedCharacter ~= state.HoverCharacter then
			selection.set_selected_character(self, state.HoverCharacter)
		end

		drag.start_character_mouse_drag(self, state.HoverCharacter)
		return
	end

	if not permissions.is_master(self) then
		return
	end

	if not gui.is_sidebar_visible(self) then
		selection.clear_selection(self)
		return
	end

	module.apply_inputs_to_state(self)

	if state.ToolMode == constants.TOOL_MODE_SELECT then
		if state.HoverKind == "Part" and state.HoverPart then
			module.handle_select_click(self, state.HoverPart, nil)
			return
		end
	end

	if state.ToolMode == constants.TOOL_MODE_CREATE then
		module.handle_create_click(self)
		return
	end

	if state.ToolMode == constants.TOOL_MODE_WALL then
		module.handle_wall_click(self)
		return
	end

	if state.ToolMode == constants.TOOL_MODE_ROOM then
		module.handle_room_click(self)
		return
	end

	if state.ToolMode == constants.TOOL_MODE_LIGHT then
		module.handle_light_click(self)
		return
	end

	selection.clear_selection(self)
end

function module.cancel_current_preview(self): ()
	local state = self.state
	local roomBuilder = self.modules.RoomBuilder
	local selection = self.modules.Selection
	local preview = self.modules.Preview
	local gui = self.modules.Gui

	state.CreateAnchor = nil
	state.WallAnchor = nil
	roomBuilder.reset()
	selection.clear_selection(self)
	gui.set_status(self, "Pre-visualização cancelada")
	preview.refresh_preview(self)
end

function module.decrease_wall_height(self): ()
	local state = self.state
	local constants = self.modules.Constants
	local gui = self.modules.Gui
	local preview = self.modules.Preview

	module.apply_inputs_to_state(self)
	state.WallHeight = math.max(1, state.WallHeight - constants.WALL_HEIGHT_STEP)
	gui.sync_boxes_from_state(self)
	preview.refresh_preview(self)
end

function module.increase_wall_height(self): ()
	local state = self.state
	local constants = self.modules.Constants
	local gui = self.modules.Gui
	local preview = self.modules.Preview

	module.apply_inputs_to_state(self)
	state.WallHeight += constants.WALL_HEIGHT_STEP
	gui.sync_boxes_from_state(self)
	preview.refresh_preview(self)
end

function module.handle_shift_began(self): ()
	local state = self.state
	local constants = self.modules.Constants
	local roomBuilder = self.modules.RoomBuilder
	local raycast = self.modules.Raycast
	local preview = self.modules.Preview

	if state.ToolMode == constants.TOOL_MODE_ROOM and roomBuilder.Anchor then
		roomBuilder.LockedB = raycast.get_snapped_hit_position(self)
		preview.refresh_preview(self)
	end
end

function module.handle_shift_ended(self): ()
	local state = self.state
	local constants = self.modules.Constants
	local roomBuilder = self.modules.RoomBuilder
	local gui = self.modules.Gui
	local preview = self.modules.Preview

	if state.ToolMode ~= constants.TOOL_MODE_ROOM then
		return
	end

	if not roomBuilder.Anchor or not roomBuilder.LockedB then
		return
	end

	local finalParts = roomBuilder.get_room_data(
		roomBuilder.LockedB,
		state.GridSize,
		state.RoomHeight,
		state.WallThickness,
		4,
		7.5,
		state.CreateWithFloor,
		state.CreateWithCeiling,
		false
	)

	local roomId = HttpService:GenerateGUID(false)

	module.fire_build(self, "CreateRoomParts", {
		RoomId = roomId,
		Parts = finalParts,
		Doors = roomBuilder.Doors,
		Color = state.BuildColor,
	})

	roomBuilder.reset()
	gui.set_status(self, "Sala criada")
	preview.refresh_preview(self)
end

function module.reset_for_role_change(self): ()
	local state = self.state
	local roomBuilder = self.modules.RoomBuilder
	local selection = self.modules.Selection
	local preview = self.modules.Preview

	state.CreateAnchor = nil
	state.WallAnchor = nil
	roomBuilder.reset()
	selection.clear_selection(self)
	selection.clear_hover_highlight(self)
	preview.hide_preview(self)
end

return module