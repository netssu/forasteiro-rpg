local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService: UserInputService = game:GetService("UserInputService")
local Workspace: Workspace = game:GetService("Workspace")
local RunService: RunService = game:GetService("RunService")

local REMOTE_NAME: string = "MasterNpcEvent"
local GUI_NAME: string = "MasterGui"

local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")
local camera: Camera = Workspace.CurrentCamera

local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local npcEvent: RemoteEvent = remotesFolder:WaitForChild(REMOTE_NAME)

local charactersFolder = Workspace:WaitForChild("Characters")

local isSpawnModeActive = false
local uiConnected = false
local guiElements = {}
local npcRows = {}
local renderSteppedConnection = nil

local function update_possess_buttons()
	for npc, row in pairs(npcRows) do
		local btn = row:FindFirstChild("PossessBtn")
		if btn and btn:IsA("TextButton") then
			if player.Character == npc then
				btn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
				btn.Text = "Sair"
			else
				btn.BackgroundColor3 = Color3.fromRGB(180, 100, 20)
				btn.Text = "Possuir"
			end
		end
	end
end

local function on_character_changed()
	local char = player.Character
	if renderSteppedConnection then
		renderSteppedConnection:Disconnect()
		renderSteppedConnection = nil
	end

	update_possess_buttons()

	if char then
		local humanoid = char:WaitForChild("Humanoid", 5)
		if humanoid then
			camera.CameraSubject = humanoid

			if char:GetAttribute("IsNPC") then
				humanoid.AutoRotate = false

				renderSteppedConnection = RunService.RenderStepped:Connect(function()
					local rootPart = char:FindFirstChild("HumanoidRootPart")
					if rootPart and humanoid.Health > 0 then
						local camLook = camera.CFrame.LookVector
						local lookAtPos = rootPart.Position + Vector3.new(camLook.X, 0, camLook.Z)
						rootPart.CFrame = CFrame.lookAt(rootPart.Position, lookAtPos)
					end
				end)
			end
		end
	end
end

local function map_ui()
	local sg = playerGui:FindFirstChild(GUI_NAME)
	if not sg then return false end

	local sidebar = sg:FindFirstChild("NpcSidebar")
	if not sidebar then return false end

	local topBar = sg:FindFirstChild("TopBar")
	local toggleBtn = topBar and topBar:FindFirstChild("NpcToggleButton")

	guiElements.MainUI = sg
	guiElements.Sidebar = sidebar
	guiElements.ToggleButton = toggleBtn
	guiElements.SpawnBtn = sidebar:FindFirstChild("SpawnBtn")
	guiElements.UnpossessBtn = sidebar:FindFirstChild("UnpossessBtn")
	guiElements.NpcList = sidebar:FindFirstChild("NpcList")

	return true
end

local function update_canvas_size()
	if not guiElements.NpcList then return end
	local listLayout = guiElements.NpcList:FindFirstChildOfClass("UIListLayout")
	if listLayout then
		guiElements.NpcList.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
	end
end

local function create_npc_row(npc: Model)
	if npcRows[npc] then return end

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 130)
	row.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	local corner = Instance.new("UICorner", row) corner.CornerRadius = UDim.new(0, 8)
	local stroke = Instance.new("UIStroke", row) stroke.Color = Color3.fromRGB(60, 60, 60) stroke.Thickness = 1
	row.Parent = guiElements.NpcList

	local nameLabel = Instance.new("TextLabel", row)
	nameLabel.Size = UDim2.new(0, 150, 0, 20)
	nameLabel.Position = UDim2.new(0, 8, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = npc.Name .. " (NPC)"
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left

	local possessBtn = Instance.new("TextButton", row)
	possessBtn.Name = "PossessBtn"
	possessBtn.Size = UDim2.new(0, 80, 0, 25)
	possessBtn.Position = UDim2.new(1, -115, 0, 5)
	possessBtn.BackgroundColor3 = Color3.fromRGB(180, 100, 20)
	possessBtn.Text = "Possuir"
	possessBtn.TextColor3 = Color3.fromRGB(255,255,255)
	possessBtn.Font = Enum.Font.GothamBold
	Instance.new("UICorner", possessBtn).CornerRadius = UDim.new(0, 4)

	local deleteBtn = Instance.new("TextButton", row)
	deleteBtn.Size = UDim2.new(0, 25, 0, 25)
	deleteBtn.Position = UDim2.new(1, -30, 0, 5)
	deleteBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
	deleteBtn.Text = "X"
	deleteBtn.TextColor3 = Color3.fromRGB(255,255,255)
	deleteBtn.Font = Enum.Font.GothamBold
	Instance.new("UICorner", deleteBtn).CornerRadius = UDim.new(0, 4)

	local function makeInput(name, x, y, w, placeholder, text)
		local box = Instance.new("TextBox", row)
		box.Size = UDim2.new(0, w, 0, 25)
		box.Position = UDim2.new(0, x, 0, y)
		box.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
		box.TextColor3 = Color3.fromRGB(255,255,255)
		box.PlaceholderText = placeholder
		box.Text = tostring(text)
		box.Font = Enum.Font.GothamMedium
		box.TextSize = 11
		Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
		return box
	end

	local hum = npc:FindFirstChild("Humanoid")
	local imageBox = makeInput("ImageId", 8, 35, 120, "ID Imagem", npc:GetAttribute("RoleImageId") or "")
	local speedBox = makeInput("Speed", 135, 35, 60, "Vel", hum and hum.WalkSpeed or 16)
	local scaleBox = makeInput("Scale", 202, 35, 60, "Escala", npc:GetAttribute("TokenScale") or 1)

	local function sendTextBoxUpdate()
		npcEvent:FireServer({
			Action = "UpdateNpc",
			NPC = npc,
			ImageId = imageBox.Text,
			WalkSpeed = tonumber(speedBox.Text) or 16,
			Scale = tonumber(scaleBox.Text) or 1
		})
	end
	imageBox.FocusLost:Connect(sendTextBoxUpdate)
	speedBox.FocusLost:Connect(sendTextBoxUpdate)
	scaleBox.FocusLost:Connect(sendTextBoxUpdate)

	local rotLabel = Instance.new("TextLabel", row)
	rotLabel.Size = UDim2.new(0, 40, 0, 20)
	rotLabel.Position = UDim2.new(0, 8, 0, 68)
	rotLabel.BackgroundTransparency = 1
	rotLabel.TextColor3 = Color3.fromRGB(255,255,255)
	rotLabel.Font = Enum.Font.GothamBold

	local sliderBg = Instance.new("Frame", row)
	sliderBg.Size = UDim2.new(0, 200, 0, 10)
	sliderBg.Position = UDim2.new(0, 60, 0, 73)
	sliderBg.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)

	local sliderFill = Instance.new("Frame", sliderBg)
	sliderFill.BackgroundColor3 = Color3.fromRGB(46, 125, 50)
	Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

	local sliderBtn = Instance.new("TextButton", sliderBg)
	sliderBtn.Size = UDim2.new(0, 14, 0, 14)
	sliderBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sliderBtn.Text = ""
	Instance.new("UICorner", sliderBtn).CornerRadius = UDim.new(1, 0)

	local currentRot = npc.PrimaryPart and npc.PrimaryPart.Orientation.Y or 0
	if currentRot < 0 then currentRot = currentRot + 360 end
	local initialPercent = currentRot / 360
	sliderFill.Size = UDim2.new(initialPercent, 0, 1, 0)
	sliderBtn.Position = UDim2.new(initialPercent, -7, 0.5, -7)
	rotLabel.Text = math.floor(currentRot) .. "°"

	local isDragging = false

	sliderBtn.MouseButton1Down:Connect(function() isDragging = true end)
	sliderBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDragging = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local relativeX = input.Position.X - sliderBg.AbsolutePosition.X
			local percent = math.clamp(relativeX / sliderBg.AbsoluteSize.X, 0, 1)

			sliderFill.Size = UDim2.new(percent, 0, 1, 0)
			sliderBtn.Position = UDim2.new(percent, -7, 0.5, -7)

			local degrees = math.floor(percent * 360)
			rotLabel.Text = degrees .. "°"

			npcEvent:FireServer({
				Action = "UpdateNpc",
				NPC = npc,
				RotationY = degrees
			})
		end
	end)

	local healthAnnotationBox = makeInput("HealthAnnotation", 8, 95, 60, "Vida", npc:GetAttribute("NpcHealthAnnotation") or "")
	healthAnnotationBox.FocusLost:Connect(function()
		npcEvent:FireServer({
			Action = "UpdateNpc",
			NPC = npc,
			HealthAnnotation = healthAnnotationBox.Text
		})
	end)

	possessBtn.MouseButton1Click:Connect(function()
		if isSpawnModeActive then
			isSpawnModeActive = false
			if guiElements.SpawnBtn then
				guiElements.SpawnBtn.Text = "Spawn: OFF"
				guiElements.SpawnBtn.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
			end
		end

		if player.Character == npc then
			npcEvent:FireServer({ Action = "Unpossess" })
		else
			npcEvent:FireServer({ Action = "Possess", NPC = npc })
		end
	end)

	deleteBtn.MouseButton1Click:Connect(function()
		npcEvent:FireServer({ Action = "DeleteNpc", NPC = npc })
	end)

	npcRows[npc] = row
	update_canvas_size()
	update_possess_buttons()
end

local function remove_npc_row(npc)
	if npcRows[npc] then
		npcRows[npc]:Destroy()
		npcRows[npc] = nil
		update_canvas_size()
	end
end

local function on_click()
	if player.Team == nil or player.Team.Name ~= "Mestre" then return end
	if not isSpawnModeActive then return end

	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	local params = RaycastParams.new()
	if player.Character then
		params.FilterDescendantsInstances = {player.Character}
		params.FilterType = Enum.RaycastFilterType.Exclude
	end

	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)

	if result then
		local hit = result.Instance

		-- Lógica nova para garantir que lê o modelo se você clicar pela Hitbox invisível!
		local npcModel = hit:FindFirstAncestorOfClass("Model")

		if hit.Name == "MasterHitbox" then
			local targetVal = hit:FindFirstChild("TargetCharacter")
			if targetVal and targetVal.Value then
				npcModel = targetVal.Value
			end
		end

		if npcModel and npcModel:GetAttribute("IsNPC") then
			-- A lógica antiga sua de select_npc caso você queira fazer algo ao clicar
			return
		end

		npcEvent:FireServer({ Action = "SpawnNpc", Position = result.Position })
	end
end

local function connect_ui()
	if not map_ui() then return end
	if uiConnected then return end
	uiConnected = true

	if guiElements.ToggleButton then
		guiElements.ToggleButton.MouseButton1Click:Connect(function()
			guiElements.Sidebar.Visible = not guiElements.Sidebar.Visible
		end)
	end

	if guiElements.SpawnBtn then
		guiElements.SpawnBtn.MouseButton1Click:Connect(function()
			isSpawnModeActive = not isSpawnModeActive
			guiElements.SpawnBtn.Text = isSpawnModeActive and "Spawn: ON" or "Spawn: OFF"
			guiElements.SpawnBtn.BackgroundColor3 = isSpawnModeActive and Color3.fromRGB(80, 150, 80) or Color3.fromRGB(34, 36, 44)
		end)
	end

	if guiElements.UnpossessBtn then
		guiElements.UnpossessBtn.MouseButton1Click:Connect(function()
			npcEvent:FireServer({ Action = "Unpossess" })
		end)
	end

	for _, child in charactersFolder:GetChildren() do
		if child:GetAttribute("IsNPC") then
			create_npc_row(child)
		end
	end

	charactersFolder.ChildAdded:Connect(function(child)
		task.wait(0.1)
		if child:GetAttribute("IsNPC") then
			create_npc_row(child)
		end
	end)

	charactersFolder.ChildRemoved:Connect(function(child)
		remove_npc_row(child)
	end)
end

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		on_click()
	end
end)

player:GetPropertyChangedSignal("Team"):Connect(function()
	if guiElements.MainUI then
		guiElements.MainUI.Enabled = player.Team ~= nil and player.Team.Name == "Mestre"
	end
end)

player:GetPropertyChangedSignal("Character"):Connect(on_character_changed)

playerGui.ChildAdded:Connect(function(child)
	if child.Name == GUI_NAME then
		task.defer(connect_ui)
	end
end)

connect_ui()

if player.Character then
	task.spawn(on_character_changed)
end