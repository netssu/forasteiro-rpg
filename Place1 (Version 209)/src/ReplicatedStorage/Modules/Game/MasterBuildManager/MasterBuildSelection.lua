------------------//VARIABLES
local module = {}

------------------//FUNCTIONS
function module.ensure_highlight(self): Highlight
	local state = self.state

	if state.Highlight and state.Highlight.Parent == state.PlayerGui then
		return state.Highlight
	end

	local newHighlight = Instance.new("Highlight")
	newHighlight.Name = "MasterBuildHighlight"
	newHighlight.FillTransparency = 0.75
	newHighlight.OutlineTransparency = 0
	newHighlight.OutlineColor = Color3.fromRGB(255, 220, 80)
	newHighlight.Parent = state.PlayerGui

	state.Highlight = newHighlight
	return newHighlight
end

function module.ensure_hover_highlight(self): Highlight
	local state = self.state

	if state.HoverHighlight and state.HoverHighlight.Parent == state.PlayerGui then
		return state.HoverHighlight
	end

	local newHighlight = Instance.new("Highlight")
	newHighlight.Name = "MasterBuildHoverHighlight"
	newHighlight.FillTransparency = 1
	newHighlight.OutlineTransparency = 0
	newHighlight.OutlineColor = Color3.fromRGB(170, 220, 255)
	newHighlight.Parent = state.PlayerGui

	state.HoverHighlight = newHighlight
	return newHighlight
end

function module.clear_hover_highlight(self): ()
	local currentHoverHighlight = module.ensure_hover_highlight(self)
	currentHoverHighlight.Adornee = nil
end

function module.ensure_handles(self): ()
	local state = self.state

	if not state.MoveHandles or state.MoveHandles.Parent ~= state.PlayerGui then
		state.MoveHandles = Instance.new("Handles")
		state.MoveHandles.Name = "MasterMoveHandles"
		state.MoveHandles.Style = Enum.HandlesStyle.Movement
		state.MoveHandles.Color3 = Color3.fromRGB(120, 220, 255)
		state.MoveHandles.Parent = state.PlayerGui
	end

	if not state.ResizeHandles or state.ResizeHandles.Parent ~= state.PlayerGui then
		state.ResizeHandles = Instance.new("Handles")
		state.ResizeHandles.Name = "MasterResizeHandles"
		state.ResizeHandles.Style = Enum.HandlesStyle.Resize
		state.ResizeHandles.Color3 = Color3.fromRGB(255, 180, 100)
		state.ResizeHandles.Parent = state.PlayerGui
	end

	if not state.RotateHandles or state.RotateHandles.Parent ~= state.PlayerGui then
		state.RotateHandles = Instance.new("ArcHandles")
		state.RotateHandles.Name = "MasterRotateHandles"
		state.RotateHandles.Color3 = Color3.fromRGB(170, 255, 170)
		state.RotateHandles.Parent = state.PlayerGui
	end
end

function module.get_build_folder(self): Folder?
	local constants = self.modules.Constants
	local folder = workspace:FindFirstChild(constants.BUILD_FOLDER_NAME)

	if folder and folder:IsA("Folder") then
		return folder
	end

	return nil
end

function module.is_valid_selected_part(self, inst: BasePart?): boolean
	if not inst then
		return false
	end

	local buildFolder = module.get_build_folder(self)
	if not buildFolder then
		return false
	end

	return inst.Parent == buildFolder and inst:GetAttribute("IsTabletopBuildPart") == true
end

function module.is_valid_selected_character(_self, targetModel: Model?): boolean
	if not targetModel then
		return false
	end

	local charactersFolder = workspace:FindFirstChild("Characters")
	return charactersFolder ~= nil and targetModel.Parent == charactersFolder
end

function module.get_root_part_for_character(_self, targetModel: Model): BasePart?
	local rootPart = targetModel:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end

	return nil
end

function module.can_drag_character(self, targetModel: Model?): boolean
	local permissions = self.modules.Permissions
	local state = self.state

	if not targetModel then
		return false
	end

	if permissions.is_master(self) then
		return module.is_valid_selected_character(self, targetModel)
	end

	return permissions.is_player_spectator_drag_enabled(self) and targetModel == state.Player.Character
end

function module.clear_selection(self): ()
	local state = self.state
	local drag = self.modules.Drag
	local currentHighlight = module.ensure_highlight(self)

	state.SelectedKind = ""
	state.SelectedPart = nil
	state.SelectedCharacter = nil

	drag.finish_gizmo_drag(self)
	drag.stop_character_mouse_drag(self)

	currentHighlight.Adornee = nil

	module.ensure_handles(self)

	if state.MoveHandles then
		state.MoveHandles.Adornee = nil
	end

	if state.ResizeHandles then
		state.ResizeHandles.Adornee = nil
	end

	if state.RotateHandles then
		state.RotateHandles.Adornee = nil
	end

	module.clear_hover_highlight(self)
end

function module.validate_selection(self): ()
	local state = self.state

	if state.SelectedKind == "Part" and not module.is_valid_selected_part(self, state.SelectedPart) then
		module.clear_selection(self)
		return
	end

	if state.SelectedKind == "Character" and not module.is_valid_selected_character(self, state.SelectedCharacter) then
		module.clear_selection(self)
	end
end

function module.update_handles_for_selection(self): ()
	local state = self.state
	local gui = self.modules.Gui
	local constants = self.modules.Constants
	local currentHighlight = module.ensure_highlight(self)

	module.ensure_handles(self)

	if state.SelectedKind == "Character" and state.SelectedCharacter then
		local rootPart = module.get_root_part_for_character(self, state.SelectedCharacter)

		currentHighlight.Adornee = state.SelectedCharacter

		if state.MoveHandles then
			state.MoveHandles.Adornee = rootPart
		end

		if state.ResizeHandles then
			state.ResizeHandles.Adornee = nil
		end

		if state.RotateHandles then
			state.RotateHandles.Adornee = rootPart
		end

		gui.set_status(self, "Selecionado: personagem")
		return
	end

	if state.ToolMode ~= constants.TOOL_MODE_SELECT then
		currentHighlight.Adornee = nil
		module.clear_hover_highlight(self)

		if state.MoveHandles then
			state.MoveHandles.Adornee = nil
		end

		if state.ResizeHandles then
			state.ResizeHandles.Adornee = nil
		end

		if state.RotateHandles then
			state.RotateHandles.Adornee = nil
		end

		return
	end

	if state.SelectedKind == "Part" and state.SelectedPart then
		currentHighlight.Adornee = state.SelectedPart

		if state.MoveHandles then
			state.MoveHandles.Adornee = state.SelectedPart
		end

		if state.ResizeHandles then
			state.ResizeHandles.Adornee = state.SelectedPart
		end

		if state.RotateHandles then
			state.RotateHandles.Adornee = state.SelectedPart
		end

		gui.set_status(self, "Selecionado: parte")
		return
	end

	module.clear_selection(self)
end

function module.set_selected_part(self, partObj: BasePart): ()
	local state = self.state
	local gui = self.modules.Gui
	local drag = self.modules.Drag

	state.SelectedKind = "Part"
	state.SelectedPart = partObj
	state.SelectedCharacter = nil

	drag.stop_character_mouse_drag(self)

	if state.SizeXBox then
		state.SizeXBox.Text = tostring(partObj.Size.X)
	end

	if state.SizeYBox then
		state.SizeYBox.Text = tostring(partObj.Size.Y)
	end

	if state.SizeZBox then
		state.SizeZBox.Text = tostring(partObj.Size.Z)
	end

	gui.sync_color_boxes_from_part(self, partObj)
	module.update_handles_for_selection(self)
end

function module.set_selected_character(self, targetModel: Model): ()
	local state = self.state

	state.SelectedKind = "Character"
	state.SelectedPart = nil
	state.SelectedCharacter = targetModel

	module.update_handles_for_selection(self)
end

function module.resolve_click_target(self): (string, BasePart?, Model?)
	local state = self.state
	local mouse = state.Player:GetMouse()
	local instance = mouse.Target

	if not instance then
		return "", nil, nil
	end

	if instance:IsA("BasePart") then
		local targetVal = instance:FindFirstChild("TargetCharacter")
		if targetVal and targetVal:IsA("ObjectValue") and targetVal.Value and targetVal.Value:IsA("Model") then
			return "Character", nil, targetVal.Value
		end

		local buildFolder = module.get_build_folder(self)
		if buildFolder and instance.Parent == buildFolder and instance:GetAttribute("IsTabletopBuildPart") == true then
			return "Part", instance, nil
		end

		local model = instance:FindFirstAncestorOfClass("Model")
		if model then
			local charactersFolder = workspace:FindFirstChild("Characters")
			if charactersFolder and model.Parent == charactersFolder then
				return "Character", nil, model
			end
		end
	end

	return "", nil, nil
end

function module.update_hover_highlight(self): ()
	local state = self.state
	local permissions = self.modules.Permissions
	local gui = self.modules.Gui
	local raycast = self.modules.Raycast
	local constants = self.modules.Constants
	local currentHoverHighlight = module.ensure_hover_highlight(self)
	local hitboxesFolder = workspace:FindFirstChild("MasterHitboxes")

	if hitboxesFolder then
		for _, hb in hitboxesFolder:GetChildren() do
			if hb:IsA("BasePart") then
				hb.Transparency = 1
			end
		end
	end

	if not permissions.can_use_character_drag(self) then
		currentHoverHighlight.Adornee = nil
		state.HoverKind = ""
		state.HoverPart = nil
		state.HoverCharacter = nil
		return
	end

	if raycast.is_pointer_over_gui(self) or state.GizmoDragging then
		currentHoverHighlight.Adornee = nil
		state.HoverKind = ""
		state.HoverPart = nil
		state.HoverCharacter = nil
		return
	end

	local canHoverParts = gui.is_sidebar_visible(self) and state.ToolMode == constants.TOOL_MODE_SELECT
	local canHoverCharacters = state.ToolMode == constants.TOOL_MODE_NONE
		or state.ToolMode == constants.TOOL_MODE_SELECT
		or not gui.is_sidebar_visible(self)

	local targetKind, targetPart, foundCharacter = module.resolve_click_target(self)

	state.HoverKind = targetKind
	state.HoverPart = targetPart
	state.HoverCharacter = foundCharacter

	if targetKind == "Part" and targetPart and canHoverParts then
		if state.SelectedKind == "Part" and state.SelectedPart == targetPart then
			currentHoverHighlight.Adornee = nil
			return
		end

		currentHoverHighlight.Adornee = targetPart
		return
	end

	if targetKind == "Character" and foundCharacter and canHoverCharacters then
		if not module.can_drag_character(self, foundCharacter) then
			currentHoverHighlight.Adornee = nil
			return
		end

		if hitboxesFolder then
			for _, hb in hitboxesFolder:GetChildren() do
				local targetVal = hb:FindFirstChild("TargetCharacter")
				if targetVal and targetVal:IsA("ObjectValue") and targetVal.Value == foundCharacter then
					hb.Transparency = 0.8
					hb.Color = Color3.fromRGB(120, 200, 255)
					hb.Material = Enum.Material.ForceField
					break
				end
			end
		end

		if state.SelectedKind == "Character" and state.SelectedCharacter == foundCharacter then
			currentHoverHighlight.Adornee = nil
			return
		end

		currentHoverHighlight.Adornee = foundCharacter
		return
	end

	currentHoverHighlight.Adornee = nil
end

return module