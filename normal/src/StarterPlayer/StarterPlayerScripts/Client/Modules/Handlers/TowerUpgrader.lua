local Handler = {}

local UnitsAssigned = {}

local Priorities = {
	"First",
	"Last",
	"Closest"
}

local TweenService = game:GetService("TweenService")

local Towers = workspace:WaitForChild("Towers")

local ReplicatedStorage = game.ReplicatedStorage
local Modules = ReplicatedStorage:WaitForChild("Modules")
local StoredData = Modules:WaitForChild("StoredData")
local TowerData = require(StoredData:WaitForChild("TowerData"))

local Players = game.Players
local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local MainUi = PlayerGui:WaitForChild("InGame_UI")
local ButtonFrame = MainUi:WaitForChild("CenterLeft")
local TowersButton = ButtonFrame:WaitForChild("Towers")
local TowersFrame = MainUi:WaitForChild("Towers")
local ExitButton = TowersFrame:WaitForChild("Close")

local TowersHolder = TowersFrame:WaitForChild("Holder")
local ExampleTower = TowersHolder:WaitForChild("Example")

local TowersEnabled = false
local Debounce = false -- this is so that you cant spam the anim / it overlaps lol

local SlideInfo = TweenInfo.new(.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local function GetLevel(tower)
	local level = tower.Name:match("_(%d+)$")
	return level and tonumber(level) or 1
end

local function ActionMenu()
	if Debounce then return end

	Debounce = true

	task.delay(.5, function()
		Debounce = false
	end)

	TowersEnabled = not(TowersEnabled)

	if TowersEnabled then
		TweenService:Create(ButtonFrame, SlideInfo, {Position = UDim2.new(-0.2, 0,0.5, 0)}):Play()
		TowersFrame.Position = UDim2.new(-.5, 0,0.153, 0)
		TowersFrame.Visible = true
		TweenService:Create(TowersFrame, SlideInfo, {Position = UDim2.new(0, 0,0.153, 0)}):Play()
	else
		TweenService:Create(ButtonFrame, SlideInfo, {Position = UDim2.new(0.008, 0,0.5, 0)}):Play()
		TweenService:Create(TowersFrame, SlideInfo, {Position = UDim2.new(-.5, 0,0.153, 0)}):Play()
		task.wait(.35)
		TowersFrame.Visible = false
	end
end

function Handler.Init()
	TowersButton.MouseButton1Click:Connect(ActionMenu)
	ExitButton.MouseButton1Click:Connect(ActionMenu)
	
	Towers.ChildAdded:Connect(function(Model)
		repeat task.wait() until Model:GetAttribute("Owner")
		
		if Model:GetAttribute("Owner") == Player.UserId then
			local NewFrame = ExampleTower:Clone()
			NewFrame.Parent = TowersHolder
			NewFrame.Name = Model.Name
			NewFrame.TowerName.Text = Model.Name:gsub("[%d_]", "")
			NewFrame.Visible = true
			
			local PriorityForwardButton = NewFrame.Priority.Backward
			local PriorityBackwardButton = NewFrame.Priority.Forward
			local PriorityDisplayText = NewFrame.Priority:FindFirstChild("Text")
			
			NewFrame.Name = Model.Name
			
			UnitsAssigned[NewFrame] = Model
			
			NewFrame.Upgrade.UpgradeBtn.MouseButton1Click:Connect(function()
				game.ReplicatedStorage.Remotes.Game.Upgrade:FireServer(Model)
			end)
			
			NewFrame.Upgrade.Sell.MouseButton1Click:Connect(function()
				game.ReplicatedStorage.Remotes.Game.SellTower:FireServer(Model)
			end)
			
			if TowerData[Model.Name] then
				NewFrame.Icon.TowerIcon.Image = "rbxassetid://"..TowerData[Model.Name].ImageId
			end
			
			print(Model)
			
			NewFrame.Upgrade.CurrentLevel.Text = "Lvl "..GetLevel(Model).." >"
			NewFrame.Upgrade.NextLevel.Text = "Lvl "..GetLevel(Model) + 1
			
			local currentPriorityIndex = table.find(Priorities, Model:GetAttribute("Priority")) or 1
			PriorityDisplayText.Text = Priorities[currentPriorityIndex]

			PriorityForwardButton.MouseButton1Click:Connect(function()
				currentPriorityIndex += 1
				if currentPriorityIndex > #Priorities then
					currentPriorityIndex = 1
				end
				local newPriority = Priorities[currentPriorityIndex]
				PriorityDisplayText.Text = newPriority
				Model:SetAttribute("Priority", currentPriorityIndex)

				ReplicatedStorage.Remotes.Building.Target:FireServer(Model, currentPriorityIndex)
			end)

			PriorityBackwardButton.MouseButton1Click:Connect(function()
				currentPriorityIndex -= 1
				if currentPriorityIndex < 1 then
					currentPriorityIndex = #Priorities
				end
				local newPriority = Priorities[currentPriorityIndex]
				PriorityDisplayText.Text = newPriority
				Model:SetAttribute("Priority", currentPriorityIndex)
				
				ReplicatedStorage.Remotes.Building.Target:FireServer(Model, currentPriorityIndex)
			end)
		end
	end)
	
	Towers.ChildRemoved:Connect(function(Model)
		for Key, ModelFound in pairs(UnitsAssigned) do
			if ModelFound == Model then
				Key:Destroy()
				
			end
		end
	end)
end

Handler.Init()

return Handler