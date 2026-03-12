------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//MODULES
local modulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules")
local dictionaryFolder: Folder = modulesFolder:WaitForChild("Dictionary")
local utilityFolder: Folder = modulesFolder:WaitForChild("Utility")
local DiceDictionary = require(dictionaryFolder:WaitForChild("DiceDictionary"))
local DiceRemoteUtility = require(utilityFolder:WaitForChild("DiceRemoteUtility"))

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")
local assetsFolder: Folder = ReplicatedStorage:WaitForChild(DiceDictionary.ASSETS_FOLDER_NAME)
local modelsFolder: Folder = assetsFolder:WaitForChild(DiceDictionary.MODELS_FOLDER_NAME)
local diceEvent: RemoteEvent

local inputFrame: Frame? = nil
local inputBox: TextBox? = nil
local rollButton: TextButton? = nil
local uiConnected = false

------------------//FUNCTIONS
local function is_player_role(): boolean
	return player.Team ~= nil and player.Team.Name == DiceDictionary.PLAYER_TEAM_NAME
end

local function get_base_dice_part(): BasePart
	local found = modelsFolder:FindFirstChild("Dado") or modelsFolder:FindFirstChild("Dice") or modelsFolder:FindFirstChildWhichIsA("BasePart")
	if found and found:IsA("BasePart") then
		return found:Clone()
	end

	local fallback = Instance.new("Part")
	fallback.Size = Vector3.new(1, 1, 1)
	fallback.Color = Color3.fromRGB(220, 220, 220)
	fallback.Material = Enum.Material.SmoothPlastic
	return fallback
end

local function handle_roll_click(): ()
	if not inputBox then
		return
	end

	local txt = inputBox.Text
	if txt == "" then
		return
	end

	diceEvent:FireServer({
		Action = DiceDictionary.ROLL_ACTION,
		Expression = txt,
		Instant = false,
	})

	inputBox.Text = ""
end

local function cache_ui(): ()
	local hud = playerGui:FindFirstChild(DiceDictionary.GUI_NAME)
	if not hud then
		return
	end

	local main = hud:FindFirstChild(DiceDictionary.MAIN_FRAME_NAME)
	if main then
		inputFrame = main:FindFirstChild(DiceDictionary.DICE_INPUT_FRAME_NAME) :: Frame?
		if inputFrame then
			inputBox = inputFrame:FindFirstChild(DiceDictionary.DICE_INPUT_BOX_NAME) :: TextBox?
			rollButton = inputFrame:FindFirstChild(DiceDictionary.ROLL_BUTTON_NAME) :: TextButton?

			if not uiConnected then
				if rollButton then
					rollButton.MouseButton1Click:Connect(handle_roll_click)
				end

				if inputBox then
					inputBox.FocusLost:Connect(function(enterPressed: boolean)
						if enterPressed then
							handle_roll_click()
						end
					end)
				end

				uiConnected = true
			end
		end
	end

	local viewportFrame = hud:FindFirstChild("DiceViewport")
	if viewportFrame then
		viewportFrame.Visible = false
	end
end

local function update_visibility(): ()
	cache_ui()
	if inputFrame then
		inputFrame.Visible = is_player_role()
	end
end

local function animate_local_physics_dice(rolls: {number}, detailString: string): ()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera

	local spawnCFrame
	if rootPart then
		spawnCFrame = rootPart.CFrame + Vector3.new(0, 3, 0)
	else
		spawnCFrame = cam.CFrame
	end

	local forwardVector = spawnCFrame.LookVector
	local spawnBase = spawnCFrame.Position + forwardVector * 2.5
	local count = math.clamp(#rolls, 1, 15)
	local localDice = {}

	for i = 1, count do
		local part = get_base_dice_part()
		part.Anchored = false
		part.CanCollide = true
		part.CanQuery = false

		local offset = Vector3.new(math.random(-4, 4) / 10, math.random(0, 8) / 10, math.random(-4, 4) / 10)
		part.CFrame = CFrame.new(spawnBase + offset) * CFrame.Angles(math.random(), math.random(), math.random())
		part.Parent = workspace

		local forwardPower = math.random(15, 20)
		local upwardPower = math.random(6, 12)
		part.AssemblyLinearVelocity = forwardVector * forwardPower + Vector3.new(math.random(-2, 2), upwardPower, math.random(-2, 2))
		part.AssemblyAngularVelocity = Vector3.new(math.random(-40, 40), math.random(-40, 40), math.random(-40, 40))

		table.insert(localDice, { Part = part, RollValue = rolls[i] or 0 })
	end

	task.delay(1.8, function()
		local centerPosition = Vector3.zero
		local validDiceCount = 0

		for _, diceObj in localDice do
			local part = diceObj.Part
			if part and part.Parent then
				centerPosition += part.Position
				validDiceCount += 1

				local indGui = Instance.new("BillboardGui")
				indGui.Name = "IndividualGui"
				indGui.Size = UDim2.new(0, 50, 0, 50)
				indGui.StudsOffset = Vector3.new(0, 1.5, 0)
				indGui.AlwaysOnTop = true

				local indLabel = Instance.new("TextLabel")
				indLabel.Size = UDim2.new(1, 0, 1, 0)
				indLabel.BackgroundTransparency = 1
				indLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
				indLabel.FontFace = Font.fromId(DiceDictionary.DICE_FONT_ID, Enum.FontWeight.Bold)
				indLabel.TextSize = 0
				indLabel.Text = tostring(diceObj.RollValue)

				local indStroke = Instance.new("UIStroke")
				indStroke.Color = Color3.fromRGB(0, 0, 0)
				indStroke.Thickness = 2
				indStroke.Parent = indLabel

				indLabel.Parent = indGui
				indGui.Parent = part

				TweenService:Create(indLabel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextSize = 32 }):Play()
			end
		end

		local centerAnchor: Part? = nil
		if validDiceCount > 0 then
			centerPosition /= validDiceCount

			centerAnchor = Instance.new("Part")
			centerAnchor.Name = "DiceCenterAnchor"
			centerAnchor.Anchored = true
			centerAnchor.CanCollide = false
			centerAnchor.CanQuery = false
			centerAnchor.Transparency = 1
			centerAnchor.Size = Vector3.new(1, 1, 1)
			centerAnchor.Position = centerPosition
			centerAnchor.Parent = workspace

			local bgui = Instance.new("BillboardGui")
			bgui.Name = "ResultGui"
			bgui.Size = UDim2.new(0, 300, 0, 80)
			bgui.StudsOffset = Vector3.new(0, 3.5, 0)
			bgui.AlwaysOnTop = true

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = Color3.fromRGB(255, 220, 80)
			label.FontFace = Font.fromId(DiceDictionary.DICE_FONT_ID, Enum.FontWeight.Bold)
			label.TextSize = 0
			label.Text = detailString

			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(0, 0, 0)
			stroke.Thickness = 3
			stroke.Parent = label

			label.Parent = bgui
			bgui.Parent = centerAnchor
			TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextSize = 46 }):Play()
		end

		task.delay(4.5, function()
			for _, diceObj in localDice do
				local part = diceObj.Part
				if part and part.Parent then
					TweenService:Create(part, TweenInfo.new(0.5), { Transparency = 1 }):Play()
					for _, child in part:GetChildren() do
						if child:IsA("BillboardGui") then
							local label = child:FindFirstChildOfClass("TextLabel")
							if label then
								TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
								local stroke = label:FindFirstChildOfClass("UIStroke")
								if stroke then
									TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
								end
							end
						end
					end

					task.delay(0.5, function()
						part:Destroy()
					end)
				end
			end

			if centerAnchor and centerAnchor.Parent then
				local bgui = centerAnchor:FindFirstChild("ResultGui")
				if bgui then
					local label = bgui:FindFirstChildOfClass("TextLabel")
					if label then
						TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
						local stroke = label:FindFirstChildOfClass("UIStroke")
						if stroke then
							TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
						end
					end
				end

				task.delay(0.5, function()
					centerAnchor:Destroy()
				end)
			end
		end)
	end)
end

local function animate_world_dice(character: Model, detailString: string): ()
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local dice = get_base_dice_part()
	dice.Anchored = true
	dice.CanCollide = false
	dice.CanQuery = false
	dice.Parent = workspace

	local startTime = time()
	local spinDuration = 1.0
	local showDuration = 5.0

	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not character.Parent or not head.Parent then
			dice:Destroy()
			connection:Disconnect()
			return
		end

		local elapsed = time() - startTime
		local targetPos = head.Position + Vector3.new(0, 3.5, 0)

		if elapsed < spinDuration then
			dice.CFrame = CFrame.new(targetPos) * CFrame.Angles(elapsed * 20, elapsed * 15, elapsed * 10)
		elseif elapsed < spinDuration + showDuration then
			dice.CFrame = CFrame.new(targetPos)
			if not dice:FindFirstChild("ResultGui") then
				local bgui = Instance.new("BillboardGui")
				bgui.Name = "ResultGui"
				bgui.Size = UDim2.new(0, 300, 0, 100)
				bgui.StudsOffset = Vector3.new(0, 2, 0)
				bgui.AlwaysOnTop = true

				local label = Instance.new("TextLabel")
				label.Size = UDim2.new(1, 0, 1, 0)
				label.BackgroundTransparency = 1
				label.TextColor3 = Color3.fromRGB(255, 255, 255)
				label.FontFace = Font.fromId(DiceDictionary.DICE_FONT_ID, Enum.FontWeight.Bold)
				label.TextSize = 48
				label.Text = detailString

				local stroke = Instance.new("UIStroke")
				stroke.Color = Color3.fromRGB(0, 0, 0)
				stroke.Thickness = 2
				stroke.Parent = label

				label.Parent = bgui
				bgui.Parent = dice
			end
		else
			dice:Destroy()
			connection:Disconnect()
		end
	end)
end

local function on_roll_result(payload: any): ()
	if typeof(payload) ~= "table" or payload.Action ~= DiceDictionary.ROLL_RESULT_ACTION then
		return
	end

	if payload.IsInstant then
		return
	end

	if payload.Player == player then
		animate_local_physics_dice(payload.Rolls, payload.DetailString)
		return
	end

	if payload.Character then
		animate_world_dice(payload.Character, payload.DetailString)
	end
end

local function on_input_began(input: InputObject, gameProcessed: boolean): ()
	if gameProcessed then
		return
	end

	if input.KeyCode == DiceDictionary.ROLL_KEYCODE then
		if inputBox and is_player_role() then
			task.delay(0.05, function()
				inputBox:CaptureFocus()
				inputBox.Text = ""
			end)
		end
	end
end

local function on_gui_added(child: Instance): ()
	if child.Name == DiceDictionary.GUI_NAME then
		update_visibility()
	end
end

------------------//MAIN FUNCTIONS
local DiceController = {}

function DiceController.run(): ()
	diceEvent = DiceRemoteUtility.get_dice_event()
	player:GetPropertyChangedSignal("Team"):Connect(update_visibility)
	diceEvent.OnClientEvent:Connect(on_roll_result)
	UserInputService.InputBegan:Connect(on_input_began)
	playerGui.ChildAdded:Connect(on_gui_added)
	update_visibility()
end

return DiceController
