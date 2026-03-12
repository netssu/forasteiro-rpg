------------------//VARIABLES
local module = {}

------------------//FUNCTIONS
function module.is_sidebar_visible(self): boolean
	local state = self.state

	return (state.BuildSidebar ~= nil and state.BuildSidebar.Visible)
		or (state.RoomSidebar ~= nil and state.RoomSidebar.Visible)
end

function module.close_gui_object(_self, guiObject: GuiObject?): ()
	if guiObject then
		guiObject.Visible = false
	end
end

function module.close_other_frames(self, exceptName: string?): ()
	local state = self.state
	local frames = {
		EnvironmentWindow = state.EnvironmentWindow,
		PlayersWindow = state.PlayersWindow,
		CombatWindow = state.CombatWindow,
		BuildSidebar = state.BuildSidebar,
		RoomSidebar = state.RoomSidebar,
		NpcSidebar = state.NpcSidebar,
	}

	for name, frame in frames do
		if frame and name ~= exceptName then
			frame.Visible = false
		end
	end
end

function module.update_sidebar_toggle_buttons(self): ()
	local state = self.state
	local constants = self.modules.Constants

	if state.BuildToggleButton then
		state.BuildToggleButton.BackgroundColor3 = (state.BuildSidebar and state.BuildSidebar.Visible) and constants.ACTIVE_BUTTON_COLOR or constants.INACTIVE_BUTTON_COLOR
	end

	if state.RoomToggleButton then
		state.RoomToggleButton.BackgroundColor3 = (state.RoomSidebar and state.RoomSidebar.Visible) and constants.ACTIVE_BUTTON_COLOR or constants.INACTIVE_BUTTON_COLOR
	end
end

function module.open_build_sidebar(self): ()
	local state = self.state

	module.close_other_frames(self, "BuildSidebar")

	if state.RoomSidebar then
		state.RoomSidebar.Visible = false
	end

	if state.BuildSidebar then
		state.BuildSidebar.Visible = true
	end

	module.update_sidebar_toggle_buttons(self)
	self.modules.Preview.refresh_preview(self)
end

function module.open_room_sidebar(self): ()
	local state = self.state

	module.close_other_frames(self, "RoomSidebar")

	if state.BuildSidebar then
		state.BuildSidebar.Visible = false
	end

	if state.RoomSidebar then
		state.RoomSidebar.Visible = true
	end

	module.update_sidebar_toggle_buttons(self)
	self.modules.Preview.refresh_preview(self)
end

function module.close_build_room_sidebars(self): ()
	local state = self.state

	module.close_gui_object(self, state.BuildSidebar)
	module.close_gui_object(self, state.RoomSidebar)
	module.update_sidebar_toggle_buttons(self)
end

function module.cache_gui_objects(self): ()
	local state = self.state
	local constants = self.modules.Constants

	local guiObject = state.PlayerGui:FindFirstChild(constants.GUI_NAME)

	if not guiObject or not guiObject:IsA("ScreenGui") then
		state.MasterGui = nil
		state.TopBar = nil

		state.BuildToggleButton = nil
		state.RoomToggleButton = nil

		state.BuildSidebar = nil
		state.RoomSidebar = nil

		state.BuildBody = nil
		state.RoomBody = nil

		state.EnvironmentWindow = nil
		state.PlayersWindow = nil
		state.CombatWindow = nil
		state.NpcSidebar = nil

		state.SelectModeButton = nil
		state.CreateModeButton = nil
		state.WallModeButton = nil
		state.RoomModeButton = nil
		state.LightModeButton = nil
		state.DeleteButton = nil
		state.ApplySizeButton = nil
		state.ApplyColorButton = nil
		state.WallHeightMinusButton = nil
		state.WallHeightPlusButton = nil

		state.BuildStatusLabel = nil
		state.RoomStatusLabel = nil

		state.RoomSettingsFrame = nil
		state.RoomFloorButton = nil
		state.RoomCeilingButton = nil

		state.SizeXBox = nil
		state.SizeYBox = nil
		state.SizeZBox = nil
		state.GridBox = nil
		state.WallHeightBox = nil
		state.WallThicknessBox = nil
		state.RoomHeightBox = nil
		state.ColorRBox = nil
		state.ColorGBox = nil
		state.ColorBBox = nil
		state.LightRangeBox = nil
		state.LightBrightnessBox = nil
		return
	end

	state.MasterGui = guiObject
	state.TopBar = state.MasterGui:FindFirstChild("TopBar")

	state.BuildToggleButton = state.TopBar and state.TopBar:FindFirstChild(constants.BUILD_TOGGLE_BUTTON_NAME) or nil
	state.RoomToggleButton = state.TopBar and state.TopBar:FindFirstChild(constants.ROOM_TOGGLE_BUTTON_NAME) or nil

	state.EnvironmentWindow = state.MasterGui:FindFirstChild("EnvironmentWindow")
	state.PlayersWindow = state.MasterGui:FindFirstChild("PlayersWindow")
	state.CombatWindow = state.MasterGui:FindFirstChild("CombatWindow")
	state.NpcSidebar = state.MasterGui:FindFirstChild("NpcSidebar")

	state.BuildSidebar = state.MasterGui:FindFirstChild(constants.BUILD_SIDEBAR_NAME)
	state.RoomSidebar = state.MasterGui:FindFirstChild(constants.ROOM_SIDEBAR_NAME)

	state.BuildBody = state.BuildSidebar and state.BuildSidebar:FindFirstChild("Body") or nil
	state.RoomBody = state.RoomSidebar and state.RoomSidebar:FindFirstChild("Body") or nil

	state.SelectModeButton = state.BuildBody and state.BuildBody:FindFirstChild("SelectModeButton") or nil
	state.CreateModeButton = state.BuildBody and state.BuildBody:FindFirstChild("CreateModeButton") or nil
	state.DeleteButton = state.BuildBody and state.BuildBody:FindFirstChild("DeleteButton") or nil
	state.ApplySizeButton = state.BuildBody and state.BuildBody:FindFirstChild("ApplySizeButton") or nil
	state.ApplyColorButton = state.BuildBody and state.BuildBody:FindFirstChild("ApplyColorButton") or nil

	state.SizeXBox = state.BuildBody and state.BuildBody:FindFirstChild("SizeXBox") or nil
	state.SizeYBox = state.BuildBody and state.BuildBody:FindFirstChild("SizeYBox") or nil
	state.SizeZBox = state.BuildBody and state.BuildBody:FindFirstChild("SizeZBox") or nil
	state.GridBox = state.BuildBody and state.BuildBody:FindFirstChild("GridBox") or nil
	state.ColorRBox = state.BuildBody and state.BuildBody:FindFirstChild("ColorRBox") or nil
	state.ColorGBox = state.BuildBody and state.BuildBody:FindFirstChild("ColorGBox") or nil
	state.ColorBBox = state.BuildBody and state.BuildBody:FindFirstChild("ColorBBox") or nil

	state.BuildStatusLabel = state.BuildBody and state.BuildBody:FindFirstChild("StatusLabel") or nil

	state.WallModeButton = state.RoomBody and state.RoomBody:FindFirstChild("WallModeButton") or nil
	state.RoomModeButton = state.RoomBody and state.RoomBody:FindFirstChild("RoomModeButton") or nil
	state.LightModeButton = state.RoomBody and state.RoomBody:FindFirstChild("LightModeButton") or nil
	state.WallHeightMinusButton = state.RoomBody and state.RoomBody:FindFirstChild("WallHeightMinusButton") or nil
	state.WallHeightPlusButton = state.RoomBody and state.RoomBody:FindFirstChild("WallHeightPlusButton") or nil

	state.WallHeightBox = state.RoomBody and state.RoomBody:FindFirstChild("WallHeightBox") or nil
	state.WallThicknessBox = state.RoomBody and state.RoomBody:FindFirstChild("WallThicknessBox") or nil
	state.LightRangeBox = state.RoomBody and state.RoomBody:FindFirstChild("LightRangeBox") or nil
	state.LightBrightnessBox = state.RoomBody and state.RoomBody:FindFirstChild("LightBrightnessBox") or nil

	state.RoomSettingsFrame = state.RoomBody and state.RoomBody:FindFirstChild("RoomSettingsFrame") or nil
	state.RoomFloorButton = state.RoomSettingsFrame and state.RoomSettingsFrame:FindFirstChild("RoomFloorButton") or nil
	state.RoomCeilingButton = state.RoomSettingsFrame and state.RoomSettingsFrame:FindFirstChild("RoomCeilingButton") or nil
	state.RoomHeightBox = state.RoomSettingsFrame and state.RoomSettingsFrame:FindFirstChild("RoomHeightBox") or nil

	state.RoomStatusLabel = state.RoomBody and state.RoomBody:FindFirstChild("StatusLabel") or nil

	module.update_sidebar_toggle_buttons(self)
end

function module.sync_room_height_default(self): ()
	local state = self.state
	local utility = self.modules.Utility

	if state.RoomHeightBox and state.RoomHeightBox.Text ~= "" then
		state.RoomHeight = utility.sanitize_text_number(state.RoomHeightBox.Text, state.WallHeight, 1)
	else
		state.RoomHeight = state.WallHeight
		if state.RoomHeightBox then
			state.RoomHeightBox.Text = tostring(state.RoomHeight)
		end
	end
end

function module.sync_boxes_from_state(self): ()
	local state = self.state
	local utility = self.modules.Utility
	local constants = self.modules.Constants

	if state.SizeXBox then
		state.SizeXBox.Text = tostring(state.CreateSize.X)
	end

	if state.SizeYBox then
		state.SizeYBox.Text = tostring(state.CreateSize.Y)
	end

	if state.SizeZBox then
		state.SizeZBox.Text = tostring(state.CreateSize.Z)
	end

	if state.GridBox then
		state.GridBox.Text = tostring(state.GridSize)
	end

	if state.WallHeightBox then
		state.WallHeightBox.Text = tostring(state.WallHeight)
	end

	if state.WallThicknessBox then
		state.WallThicknessBox.Text = tostring(state.WallThickness)
	end

	if state.RoomHeightBox then
		state.RoomHeightBox.Text = tostring(state.RoomHeight)
	end

	if state.ColorRBox then
		state.ColorRBox.Text = tostring(utility.clamp_color_channel(state.BuildColor.R * 255))
	end

	if state.ColorGBox then
		state.ColorGBox.Text = tostring(utility.clamp_color_channel(state.BuildColor.G * 255))
	end

	if state.ColorBBox then
		state.ColorBBox.Text = tostring(utility.clamp_color_channel(state.BuildColor.B * 255))
	end

	if state.LightRangeBox then
		state.LightRangeBox.Text = tostring(state.LightRange)
	end

	if state.LightBrightnessBox then
		state.LightBrightnessBox.Text = tostring(state.LightBrightness)
	end

	if state.RoomFloorButton then
		state.RoomFloorButton.Text = state.CreateWithFloor and "Chão: SIM" or "Chão: NÃO"
		state.RoomFloorButton.BackgroundColor3 = state.CreateWithFloor and constants.ACTIVE_BUTTON_COLOR or constants.INACTIVE_BUTTON_COLOR
	end

	if state.RoomCeilingButton then
		state.RoomCeilingButton.Text = state.CreateWithCeiling and "Teto: SIM" or "Teto: NÃO"
		state.RoomCeilingButton.BackgroundColor3 = state.CreateWithCeiling and constants.ACTIVE_BUTTON_COLOR or constants.INACTIVE_BUTTON_COLOR
	end
end

function module.read_color_from_boxes(self): Color3
	local state = self.state
	local utility = self.modules.Utility

	local r = utility.sanitize_text_number(state.ColorRBox and state.ColorRBox.Text or "163", 163, 0)
	local g = utility.sanitize_text_number(state.ColorGBox and state.ColorGBox.Text or "162", 162, 0)
	local b = utility.sanitize_text_number(state.ColorBBox and state.ColorBBox.Text or "165", 165, 0)

	return Color3.fromRGB(
		utility.clamp_color_channel(r),
		utility.clamp_color_channel(g),
		utility.clamp_color_channel(b)
	)
end

function module.sync_color_boxes_from_part(self, partObj: BasePart): ()
	local state = self.state

	state.BuildColor = partObj.Color

	local light = partObj:FindFirstChildOfClass("PointLight")
	if light then
		state.LightRange = light.Range
		state.LightBrightness = light.Brightness
	end

	module.sync_boxes_from_state(self)
end

function module.set_status(self, text: string): ()
	local state = self.state

	if state.BuildStatusLabel then
		state.BuildStatusLabel.Text = text
	end

	if state.RoomStatusLabel then
		state.RoomStatusLabel.Text = text
	end
end

function module.get_ordered_modes(self): {string}
	local state = self.state
	local constants = self.modules.Constants
	local activeModes = {}

	if state.BuildSidebar and state.BuildSidebar.Visible then
		if state.SelectModeButton then
			table.insert(activeModes, {btn = state.SelectModeButton, mode = constants.TOOL_MODE_SELECT})
		end

		if state.CreateModeButton then
			table.insert(activeModes, {btn = state.CreateModeButton, mode = constants.TOOL_MODE_CREATE})
		end
	end

	if state.RoomSidebar and state.RoomSidebar.Visible then
		if state.WallModeButton then
			table.insert(activeModes, {btn = state.WallModeButton, mode = constants.TOOL_MODE_WALL})
		end

		if state.RoomModeButton then
			table.insert(activeModes, {btn = state.RoomModeButton, mode = constants.TOOL_MODE_ROOM})
		end

		if state.LightModeButton then
			table.insert(activeModes, {btn = state.LightModeButton, mode = constants.TOOL_MODE_LIGHT})
		end
	end

	table.sort(activeModes, function(a, b)
		return a.btn.AbsolutePosition.Y < b.btn.AbsolutePosition.Y
	end)

	local ordered = {}

	for _, item in activeModes do
		table.insert(ordered, item.mode)
	end

	return ordered
end

function module.update_mode_buttons(self): ()
	local state = self.state
	local constants = self.modules.Constants

	if state.SelectModeButton then
		state.SelectModeButton.BackgroundColor3 = state.ToolMode == constants.TOOL_MODE_SELECT and constants.ACTIVE_BUTTON_COLOR or constants.INACTIVE_BUTTON_COLOR
	end

	if state.CreateModeButton then
		state.CreateModeButton.BackgroundColor3 = state.ToolMode == constants.TOOL_MODE_CREATE and constants.ACTIVE_BUTTON_COLOR or constants.INACTIVE_BUTTON_COLOR
	end

	if state.WallModeButton then
		state.WallModeButton.BackgroundColor3 = state.ToolMode == constants.TOOL_MODE_WALL and constants.ACTIVE_BUTTON_COLOR or constants.INACTIVE_BUTTON_COLOR
	end

	if state.RoomModeButton then
		state.RoomModeButton.BackgroundColor3 = state.ToolMode == constants.TOOL_MODE_ROOM and constants.ACTIVE_BUTTON_COLOR or constants.INACTIVE_BUTTON_COLOR
	end

	if state.LightModeButton then
		state.LightModeButton.BackgroundColor3 = state.ToolMode == constants.TOOL_MODE_LIGHT and constants.ACTIVE_BUTTON_COLOR or constants.INACTIVE_BUTTON_COLOR
	end

	module.update_sidebar_toggle_buttons(self)
end

function module.connect_buttons(self): ()
	local state = self.state
	local constants = self.modules.Constants
	local actions = self.modules.Actions
	local preview = self.modules.Preview

	if state.ButtonsConnected then
		return
	end

	if not state.BuildToggleButton or not state.RoomToggleButton or not state.BuildSidebar or not state.RoomSidebar then
		return
	end

	state.ButtonsConnected = true

	state.BuildToggleButton.MouseButton1Click:Connect(function()
		local willOpen = not state.BuildSidebar.Visible

		if willOpen then
			module.open_build_sidebar(self)
		else
			module.close_build_room_sidebars(self)
			actions.reset_build_session(self, state.SelectedKind == "Character")
		end
	end)

	state.RoomToggleButton.MouseButton1Click:Connect(function()
		local willOpen = not state.RoomSidebar.Visible

		if willOpen then
			module.open_room_sidebar(self)
		else
			module.close_build_room_sidebars(self)
			actions.reset_build_session(self, state.SelectedKind == "Character")
		end
	end)

	if state.SelectModeButton then
		state.SelectModeButton.MouseButton1Click:Connect(function()
			actions.set_tool_mode(self, constants.TOOL_MODE_SELECT)
		end)
	end

	if state.CreateModeButton then
		state.CreateModeButton.MouseButton1Click:Connect(function()
			actions.set_tool_mode(self, constants.TOOL_MODE_CREATE)
		end)
	end

	if state.WallModeButton then
		state.WallModeButton.MouseButton1Click:Connect(function()
			actions.set_tool_mode(self, constants.TOOL_MODE_WALL)
		end)
	end

	if state.RoomModeButton then
		state.RoomModeButton.MouseButton1Click:Connect(function()
			actions.set_tool_mode(self, constants.TOOL_MODE_ROOM)
		end)
	end

	if state.LightModeButton then
		state.LightModeButton.MouseButton1Click:Connect(function()
			actions.set_tool_mode(self, constants.TOOL_MODE_LIGHT)
		end)
	end

	if state.DeleteButton then
		state.DeleteButton.MouseButton1Click:Connect(function()
			actions.delete_selected_target(self)
		end)
	end

	if state.RoomFloorButton then
		state.RoomFloorButton.MouseButton1Click:Connect(function()
			state.CreateWithFloor = not state.CreateWithFloor
			module.sync_boxes_from_state(self)
			preview.refresh_preview(self)
		end)
	end

	if state.RoomCeilingButton then
		state.RoomCeilingButton.MouseButton1Click:Connect(function()
			state.CreateWithCeiling = not state.CreateWithCeiling
			module.sync_boxes_from_state(self)
			preview.refresh_preview(self)
		end)
	end

	if state.ApplySizeButton then
		state.ApplySizeButton.MouseButton1Click:Connect(function()
			actions.apply_inputs_to_state(self)

			if state.ToolMode == constants.TOOL_MODE_SELECT and state.SelectedKind == "Part" then
				actions.apply_size_to_selected_part(self)
				return
			end

			module.set_status(self, "Valores atualizados")
		end)
	end

	if state.ApplyColorButton then
		state.ApplyColorButton.MouseButton1Click:Connect(function()
			actions.apply_inputs_to_state(self)

			if state.ToolMode == constants.TOOL_MODE_SELECT and state.SelectedKind == "Part" then
				actions.apply_color_to_selected_part(self)
				return
			end

			preview.refresh_preview(self)
			module.set_status(self, "Cor atualizada")
		end)
	end

	if state.WallHeightMinusButton then
		state.WallHeightMinusButton.MouseButton1Click:Connect(function()
			actions.apply_inputs_to_state(self)
			state.WallHeight = math.max(1, state.WallHeight - constants.WALL_HEIGHT_STEP)
			module.sync_boxes_from_state(self)
			preview.refresh_preview(self)
		end)
	end

	if state.WallHeightPlusButton then
		state.WallHeightPlusButton.MouseButton1Click:Connect(function()
			actions.apply_inputs_to_state(self)
			state.WallHeight += constants.WALL_HEIGHT_STEP
			module.sync_boxes_from_state(self)
			preview.refresh_preview(self)
		end)
	end
end

function module.on_gui_added(self, child: Instance): ()
	local constants = self.modules.Constants

	if child.Name ~= constants.GUI_NAME then
		return
	end

	self.state.ButtonsConnected = false

	task.defer(function()
		module.cache_gui_objects(self)
		module.sync_room_height_default(self)
		module.sync_boxes_from_state(self)
		module.update_mode_buttons(self)
		module.connect_buttons(self)
		self.modules.Preview.refresh_preview(self)
	end)
end

return module