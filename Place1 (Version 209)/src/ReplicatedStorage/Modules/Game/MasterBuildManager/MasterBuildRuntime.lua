------------------//SERVICES
local UserInputService: UserInputService = game:GetService("UserInputService")
local RunService: RunService = game:GetService("RunService")

------------------//FUNCTIONS
local function on_input_began(self, input: InputObject, gameProcessed: boolean): ()
	local constants = self.modules.Constants
	local gui = self.modules.Gui
	local actions = self.modules.Actions
	local permissions = self.modules.Permissions

	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		actions.handle_shift_began(self)
	end

	local keyIndex = constants.KEY_MAP[input.KeyCode]
	if keyIndex and permissions.is_master(self) and gui.is_sidebar_visible(self) then
		local orderedModes = gui.get_ordered_modes(self)
		local selectedMode = orderedModes[keyIndex]

		if selectedMode then
			actions.set_tool_mode(self, selectedMode)
		end

		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		actions.handle_world_left_click(self)
		return
	end

	if input.KeyCode == Enum.KeyCode.Delete or input.KeyCode == Enum.KeyCode.Backspace then
		actions.delete_selected_target(self)
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape then
		actions.cancel_current_preview(self)
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftBracket then
		actions.decrease_wall_height(self)
		return
	end

	if input.KeyCode == Enum.KeyCode.RightBracket then
		actions.increase_wall_height(self)
	end
end

local function on_input_ended(self, input: InputObject): ()
	local drag = self.modules.Drag
	local actions = self.modules.Actions

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		drag.stop_character_mouse_drag(self)
	end

	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		actions.handle_shift_ended(self)
	end
end

------------------//MAIN FUNCTIONS
local MasterBuildRuntime = {}

function MasterBuildRuntime.connect_player_signals(self): ()
	local state = self.state
	local actions = self.modules.Actions
	local gui = self.modules.Gui
	local preview = self.modules.Preview

	state.Player:GetAttributeChangedSignal(state.PLAYER_SPECTATOR_ATTRIBUTE_NAME):Connect(function()
		actions.reset_for_role_change(self)
	end)

	state.Player:GetPropertyChangedSignal("Team"):Connect(function()
		actions.reset_for_role_change(self)
		gui.cache_gui_objects(self)
		gui.connect_buttons(self)
		gui.update_mode_buttons(self)
		preview.refresh_preview(self)
	end)

	state.PlayerGui.ChildAdded:Connect(function(child: Instance)
		gui.on_gui_added(self, child)
	end)
end

function MasterBuildRuntime.connect_runtime(self): ()
	local hitbox = self.modules.Hitbox
	local selection = self.modules.Selection
	local drag = self.modules.Drag
	local preview = self.modules.Preview
	local gui = self.modules.Gui

	RunService.RenderStepped:Connect(function()
		hitbox.sync_master_hitboxes(self)
		selection.validate_selection(self)
		drag.update_character_mouse_drag(self)
		selection.update_hover_highlight(self)
		preview.refresh_preview(self)
		gui.update_sidebar_toggle_buttons(self)
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		on_input_began(self, input, gameProcessed)
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		on_input_ended(self, input)
	end)
end

return MasterBuildRuntime
