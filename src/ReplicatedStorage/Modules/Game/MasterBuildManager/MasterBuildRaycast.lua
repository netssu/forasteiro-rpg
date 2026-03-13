------------------//SERVICES
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//VARIABLES
local module = {}

------------------//FUNCTIONS
function module.get_current_camera(): Camera
	local currentCamera = workspace.CurrentCamera

	while not currentCamera do
		task.wait()
		currentCamera = workspace.CurrentCamera
	end

	return currentCamera
end

function module.is_pointer_over_gui(self): boolean
	local state = self.state
	local mouseLocation = UserInputService:GetMouseLocation()
	local guiObjects = state.PlayerGui:GetGuiObjectsAtPosition(mouseLocation.X, mouseLocation.Y)

	for _, guiObject in guiObjects do
		if state.MasterGui and guiObject:IsDescendantOf(state.MasterGui) then
			if guiObject.BackgroundTransparency < 1 or guiObject:IsA("TextButton") or guiObject:IsA("TextBox") then
				return true
			end
		end
	end

	return false
end

function module.build_raycast_result(self): RaycastResult?
	local state = self.state
	local currentCamera = module.get_current_camera()
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = currentCamera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local filterList = {}

	if state.Player.Character then
		table.insert(filterList, state.Player.Character)
	end

	if state.PreviewPart then
		table.insert(filterList, state.PreviewPart)
	end

	for _, preview in state.RoomPreviewParts do
		table.insert(filterList, preview)
	end

	local canSelectCharacters = state.ToolMode == "" or state.ToolMode == "Select" or not self.modules.Gui.is_sidebar_visible(self)
	if not canSelectCharacters then
		local hitboxesFolder = workspace:FindFirstChild("MasterHitboxes")
		if hitboxesFolder then
			table.insert(filterList, hitboxesFolder)
		end
	end

	raycastParams.FilterDescendantsInstances = filterList
	return workspace:Raycast(ray.Origin, ray.Direction * 4096, raycastParams)
end

function module.get_snapped_hit_position(self): Vector3?
	local utility = self.modules.Utility
	local state = self.state
	local raycastResult = module.build_raycast_result(self)

	if not raycastResult then
		return nil
	end

	return utility.snap_vector3(raycastResult.Position, state.GridSize)
end

function module.get_mouse_point_on_horizontal_plane(_self, planeY: number): Vector3?
	local currentCamera = module.get_current_camera()
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = currentCamera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	if math.abs(ray.Direction.Y) < 0.0001 then
		return nil
	end

	local t = (planeY - ray.Origin.Y) / ray.Direction.Y
	if t <= 0 then
		return nil
	end

	return ray.Origin + ray.Direction * t
end

return module