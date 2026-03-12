------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService: UserInputService = game:GetService("UserInputService")
local RunService: RunService = game:GetService("RunService")

------------------//MODULES
local RoomBuilder = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("RoomBuilder"))

local masterBuildFolder: Folder = script

local MasterBuildState = require(masterBuildFolder:WaitForChild("MasterBuildState"))
local MasterBuildConstants = require(masterBuildFolder:WaitForChild("MasterBuildConstants"))
local MasterBuildUtility = require(masterBuildFolder:WaitForChild("MasterBuildUtility"))
local MasterBuildPermissions = require(masterBuildFolder:WaitForChild("MasterBuildPermissions"))
local MasterBuildRaycast = require(masterBuildFolder:WaitForChild("MasterBuildRaycast"))
local MasterBuildGui = require(masterBuildFolder:WaitForChild("MasterBuildGui"))
local MasterBuildSelection = require(masterBuildFolder:WaitForChild("MasterBuildSelection"))
local MasterBuildPreview = require(masterBuildFolder:WaitForChild("MasterBuildPreview"))
local MasterBuildDrag = require(masterBuildFolder:WaitForChild("MasterBuildDrag"))
local MasterBuildActions = require(masterBuildFolder:WaitForChild("MasterBuildActions"))
local MasterBuildHitbox = require(masterBuildFolder:WaitForChild("MasterBuildHitbox"))

------------------//VARIABLES
local module = {}
module.__index = module

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

local function connect_player_signals(self): ()
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

local function connect_runtime(self): ()
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

------------------//MAIN FUNCTIONS
function module.new(player: Player)
	local self = setmetatable({}, module)

	self.state = MasterBuildState.new(player)

	self.modules = {
		Constants = MasterBuildConstants,
		Utility = MasterBuildUtility,
		Permissions = MasterBuildPermissions,
		Raycast = MasterBuildRaycast,
		Gui = MasterBuildGui,
		Selection = MasterBuildSelection,
		Preview = MasterBuildPreview,
		Drag = MasterBuildDrag,
		Actions = MasterBuildActions,
		Hitbox = MasterBuildHitbox,
		RoomBuilder = RoomBuilder,
	}

	MasterBuildGui.cache_gui_objects(self)
	MasterBuildGui.sync_room_height_default(self)
	MasterBuildGui.sync_boxes_from_state(self)

	MasterBuildSelection.ensure_highlight(self)
	MasterBuildSelection.ensure_hover_highlight(self)
	MasterBuildSelection.ensure_handles(self)
	MasterBuildPreview.ensure_preview_part(self)

	MasterBuildDrag.connect_handles(self)
	MasterBuildGui.connect_buttons(self)

	MasterBuildGui.update_mode_buttons(self)
	MasterBuildPreview.hide_preview(self)
	MasterBuildSelection.clear_selection(self)
	MasterBuildSelection.clear_hover_highlight(self)
	MasterBuildGui.set_status(self, "Modo livre")

	connect_player_signals(self)
	connect_runtime(self)

	return self
end

return module