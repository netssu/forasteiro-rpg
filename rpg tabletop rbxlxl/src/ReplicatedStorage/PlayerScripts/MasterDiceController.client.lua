------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local MASTER_TEAM_NAME: string = "Mestre"
local GUI_NAME: string = "MasterGui"
local ASSETS_FOLDER_NAME: string = "Assets"
local REMOTES_FOLDER_NAME: string = "Remotes"
local REMOTE_NAME: string = "DiceEvent"

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

local assetsFolder: Folder = ReplicatedStorage:WaitForChild(ASSETS_FOLDER_NAME)
local remotesFolder: Folder = assetsFolder:WaitForChild(REMOTES_FOLDER_NAME)
local diceEvent: RemoteEvent = remotesFolder:WaitForChild(REMOTE_NAME) :: RemoteEvent

local diceFrame: Frame? = nil
local historyContainer: ScrollingFrame? = nil
local instantInputBox: TextBox? = nil
local instantRollButton: TextButton? = nil

local entryCount: number = 0
local uiConnected: boolean = false

------------------//FUNCTIONS
local function is_master_role(): boolean
	return player.Team ~= nil and player.Team.Name == MASTER_TEAM_NAME
end

local function handle_instant_roll(): ()
	if not instantInputBox then return end
	local txt = instantInputBox.Text
	if txt == "" then return end

	diceEvent:FireServer({
		Action = "Roll",
		Expression = txt,
		Instant = true
	})

	instantInputBox.Text = ""
end

local function cache_ui(): ()
	local hud = playerGui:FindFirstChild(GUI_NAME)
	if not hud then return end

	diceFrame = hud:FindFirstChild("MasterDiceFrame")
	if diceFrame then
		historyContainer = diceFrame:FindFirstChild("HistoryContainer")
		local inputFrame = diceFrame:FindFirstChild("InstantInputFrame")
		if inputFrame then
			instantInputBox = inputFrame:FindFirstChild("InstantInputBox")
			instantRollButton = inputFrame:FindFirstChild("InstantRollButton")

			if instantRollButton and not uiConnected then
				instantRollButton.MouseButton1Click:Connect(handle_instant_roll)
				uiConnected = true
			end
		end
	end
end

local function update_visibility(): ()
	cache_ui()
	if diceFrame then
		diceFrame.Visible = is_master_role()
	end
end

local function add_history_entry(playerName: string, expression: string, total: number, isInstant: boolean): ()
	if not historyContainer then return end

	entryCount += 1

	local entry = Instance.new("Frame")
	entry.Size = UDim2.new(1, -8, 0, 46)
	entry.BackgroundColor3 = isInstant and Color3.fromRGB(60, 40, 40) or Color3.fromRGB(34, 36, 44)
	entry.BorderSizePixel = 0
	entry.LayoutOrder = -entryCount

	local corner = Instance.new("UICorner", entry); corner.CornerRadius = UDim.new(0, 6)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -10, 0, 20)
	nameLabel.Position = UDim2.new(0, 8, 0, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(170, 220, 255)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 12
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = playerName .. (isInstant and " [Mestre]" or "")
	nameLabel.Parent = entry

	local detailLabel = Instance.new("TextLabel")
	detailLabel.Size = UDim2.new(1, -10, 0, 20)
	detailLabel.Position = UDim2.new(0, 8, 0, 22)
	detailLabel.BackgroundTransparency = 1
	detailLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	detailLabel.Font = Enum.Font.Jura
	detailLabel.TextSize = 12
	detailLabel.TextXAlignment = Enum.TextXAlignment.Left
	detailLabel.Text = expression .. "  =  " .. tostring(total)
	detailLabel.Parent = entry

	entry.Parent = historyContainer

	if entryCount > 50 then
		for _, child in historyContainer:GetChildren() do
			if child:IsA("Frame") and child.LayoutOrder == -(entryCount - 50) then
				child:Destroy()
			end
		end
	end
end

local function on_roll_result(payload: any): ()
	if typeof(payload) ~= "table" or payload.Action ~= "RollResult" then return end

	local playerName = payload.Player and payload.Player.Name or "Desconhecido"
	add_history_entry(playerName, payload.Expression, payload.Total, payload.IsInstant)
end

------------------//MAIN FUNCTIONS
player:GetPropertyChangedSignal("Team"):Connect(update_visibility)
diceEvent.OnClientEvent:Connect(on_roll_result)
playerGui.ChildAdded:Connect(function(child)
	if child.Name == GUI_NAME then update_visibility() end
end)

------------------//INIT
update_visibility()