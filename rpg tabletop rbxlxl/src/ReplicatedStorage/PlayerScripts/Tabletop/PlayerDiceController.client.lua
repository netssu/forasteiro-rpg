------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//CONSTANTS
local PLAYER_TEAM_NAME: string = "Jogador"
local GUI_NAME: string = "PlayerHud"
local REMOTE_NAME: string = "DiceEvent"
local DICE_FONT_ID: number = 11726928121

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local modelsFolder: Folder = assetsFolder:WaitForChild("Models")
local diceEvent: RemoteEvent = remotesFolder:WaitForChild(REMOTE_NAME)

local inputFrame: Frame? = nil
local inputBox: TextBox? = nil
local rollButton: TextButton? = nil

local uiConnected: boolean = false

------------------//FUNCTIONS
local function is_player_role(): boolean
	return player.Team ~= nil and player.Team.Name == PLAYER_TEAM_NAME
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
	if not inputBox then return end
	local txt = inputBox.Text

	if txt == "" then return end

	diceEvent:FireServer({
		Action = "Roll",
		Expression = txt,
		Instant = false
	})

	inputBox.Text = ""
end

local function cache_ui(): ()
	local hud = playerGui:FindFirstChild(GUI_NAME)

	if not hud then 
		return 
	end

	local main = hud:FindFirstChild("Main")
	if main then
		inputFrame = main:FindFirstChild("DiceInputFrame")
		if inputFrame then
			inputBox = inputFrame:FindFirstChild("DiceInputBox")
			rollButton = inputFrame:FindFirstChild("RollButton")

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

local function animate_local_physics_dice(total: number, rolls: {number}, expression: string): ()
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

		local offset = Vector3.new(math.random(-4, 4)/10, math.random(0, 8)/10, math.random(-4, 4)/10)
		part.CFrame = CFrame.new(spawnBase + offset) * CFrame.Angles(math.random(), math.random(), math.random())
		part.Parent = workspace

		local forwardPower = math.random(15, 20)
		local upwardPower = math.random(6, 12)
		part.AssemblyLinearVelocity = forwardVector * forwardPower + Vector3.new(math.random(-2, 2), upwardPower, math.random(-2, 2))
		part.AssemblyAngularVelocity = Vector3.new(math.random(-40, 40), math.random(-40, 40), math.random(-40, 40))

		table.insert(localDice, {
			Part = part,
			RollValue = rolls[i] or 0
		})
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
				indLabel.FontFace = Font.fromId(DICE_FONT_ID, Enum.FontWeight.Bold)
				indLabel.TextSize = 0 
				indLabel.Text = tostring(diceObj.RollValue)

				local indStroke = Instance.new("UIStroke")
				indStroke.Color = Color3.fromRGB(0, 0, 0)
				indStroke.Thickness = 2
				indStroke.Parent = indLabel

				indLabel.Parent = indGui
				indGui.Parent = part

				TweenService:Create(indLabel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {TextSize = 32}):Play()
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

			local modStr = string.match(expression, "([+-]%d+)$")
			local totalText = "( " .. tostring(total) .. " )"
			if modStr then
				totalText = "( " .. tostring(total) .. " | " .. modStr .. " )"
			end

			local bgui = Instance.new("BillboardGui")
			bgui.Name = "ResultGui"
			bgui.Size = UDim2.new(0, 150, 0, 80)
			bgui.StudsOffset = Vector3.new(0, 3.5, 0)
			bgui.AlwaysOnTop = true

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = Color3.fromRGB(255, 220, 80)
			label.FontFace = Font.fromId(DICE_FONT_ID, Enum.FontWeight.Bold)
			label.TextSize = 0 
			label.Text = totalText

			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(0, 0, 0)
			stroke.Thickness = 3
			stroke.Parent = label

			label.Parent = bgui
			bgui.Parent = centerAnchor

			TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {TextSize = 46}):Play()
		end

		task.delay(4.5, function()
			for _, diceObj in localDice do
				local part = diceObj.Part
				if part and part.Parent then
					TweenService:Create(part, TweenInfo.new(0.5), {Transparency = 1}):Play()

					for _, child in part:GetChildren() do
						if child:IsA("BillboardGui") then
							local label = child:FindFirstChildOfClass("TextLabel")
							if label then
								TweenService:Create(label, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
								local stroke = label:FindFirstChildOfClass("UIStroke")
								if stroke then
									TweenService:Create(stroke, TweenInfo.new(0.5), {Transparency = 1}):Play()
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
						TweenService:Create(label, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
						local stroke = label:FindFirstChildOfClass("UIStroke")
						if stroke then
							TweenService:Create(stroke, TweenInfo.new(0.5), {Transparency = 1}):Play()
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

local function animate_world_dice(character: Model, total: number): ()
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
				bgui.Size = UDim2.new(0, 100, 0, 100)
				bgui.StudsOffset = Vector3.new(0, 2, 0)
				bgui.AlwaysOnTop = true

				local label = Instance.new("TextLabel")
				label.Size = UDim2.new(1, 0, 1, 0)
				label.BackgroundTransparency = 1
				label.TextColor3 = Color3.fromRGB(255, 255, 255)
				label.FontFace = Font.fromId(DICE_FONT_ID, Enum.FontWeight.Bold)
				label.TextSize = 48
				label.Text = tostring(total)

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
	if typeof(payload) ~= "table" or payload.Action ~= "RollResult" then return end

	if payload.IsInstant then 
		return 
	end

	if payload.Player == player then
		animate_local_physics_dice(payload.Total, payload.Rolls, payload.Expression)
	else
		if payload.Character then
			animate_world_dice(payload.Character, payload.Total)
		end
	end
end

local function on_input_began(input: InputObject, gameProcessed: boolean): ()
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.R then
		if inputBox and is_player_role() then
			task.delay(0.05, function()
				inputBox:CaptureFocus()
				inputBox.Text = ""
			end)
		end
	end
end

------------------//MAIN FUNCTIONS
player:GetPropertyChangedSignal("Team"):Connect(update_visibility)
diceEvent.OnClientEvent:Connect(on_roll_result)
UserInputService.InputBegan:Connect(on_input_began)

playerGui.ChildAdded:Connect(function(child: Instance)
	if child.Name == GUI_NAME then
		update_visibility()
	end
end)

------------------//INIT
update_visibility()