------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//MODULES
local RoomBuilder = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("RoomBuilder"))

local masterBuildFolder: Folder = script.Parent
local MasterBuildState = require(masterBuildFolder:WaitForChild("MasterBuildState"))
local MasterBuildModuleRegistry = require(masterBuildFolder:WaitForChild("MasterBuildModuleRegistry"))
local MasterBuildRuntime = require(masterBuildFolder:WaitForChild("MasterBuildRuntime"))

------------------//VARIABLES
local module = {}
module.__index = module

------------------//FUNCTIONS
local function warmup_modules(self): ()
	local gui = self.modules.Gui
	local selection = self.modules.Selection
	local preview = self.modules.Preview
	local drag = self.modules.Drag

	gui.cache_gui_objects(self)
	gui.sync_room_height_default(self)
	gui.sync_boxes_from_state(self)

	selection.ensure_highlight(self)
	selection.ensure_hover_highlight(self)
	selection.ensure_handles(self)
	preview.ensure_preview_part(self)

	drag.connect_handles(self)
	gui.connect_buttons(self)

	gui.update_mode_buttons(self)
	preview.hide_preview(self)
	selection.clear_selection(self)
	selection.clear_hover_highlight(self)
	gui.set_status(self, "Modo livre")
end

------------------//MAIN FUNCTIONS
function module.new(player: Player)
	local self = setmetatable({}, module)

	self.state = MasterBuildState.new(player)
	self.modules = MasterBuildModuleRegistry.load()
	self.modules.RoomBuilder = RoomBuilder

	warmup_modules(self)
	MasterBuildRuntime.connect_player_signals(self)
	MasterBuildRuntime.connect_runtime(self)

	return self
end

return module
