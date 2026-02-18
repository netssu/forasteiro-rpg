-- // services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- // variables

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local GameRemotes = Remotes:FindFirstChild("Game")

local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui

local Digits = require(ReplicatedStorage.Modules.Utility.Digits)
local TowerData = require(ReplicatedStorage.Modules.StoredData.TowerData)
local EnemyData = require(ReplicatedStorage.Modules.StoredData.EnemyData)

-- // remotes

local RecieveDialogueData = GameRemotes:FindFirstChild("SendDialogueData")
local RecieveSkipWave = GameRemotes:WaitForChild("SkipWave")

-- // ui vars

local MainGui = PlayerGui:WaitForChild("InGame_UI")
local TopUi = MainGui:WaitForChild("CenterTop")
local WavesUi = TopUi:WaitForChild("Wave")
local SkipWaveUi = WavesUi:WaitForChild("Skip")

-- // tables

local Dialogue = {}

-- // functions

local function sendNotification(text : string, type : string)

	local Notification = MainGui:WaitForChild("Notification")
	if not Notification then return end 

	local Template = Notification:WaitForChild("Template"):Clone()
	if not Template then return end 

	local TargetSize = UDim2.new(1, 0, 1.165, 0)
	local StartingSize = UDim2.new(0,0,0,0)

	Template.Text = text

	if type == "Error" then
		Template.TextColor3 = Color3.fromRGB(255, 0, 0)
	elseif type == "Normal" then
		Template.TextColor3 = Color3.fromRGB(255, 255, 255)
	elseif type == "Success" then
		Template.TextColor3 = Color3.fromRGB(0, 255, 0)
	end

	Template.Size = StartingSize

	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back)
	local tweenIn = TweenService:Create(Template, tweenInfo, { Size = TargetSize })
	local tweenOut = TweenService:Create(Template, tweenInfo, { Size = StartingSize })

	Template.Parent = Notification
	Template.Visible = true

	tweenIn:Play()

	task.spawn(function()
		task.wait(5)
		tweenOut:Play()
		tweenOut.Completed:Connect(function()
			Template:Destroy()
		end)
	end)


end

local function getUserData()
	local userData
	repeat
		userData = Player:FindFirstChild("UserData")
		if not userData then
			task.wait(0.1)
		end
	until userData

	return userData

end

local UserData = getUserData()
local StartingCash
local StartingEXP

if UserData then
	StartingCash = UserData:FindFirstChild("Money").Value
	StartingEXP = UserData:FindFirstChild("EXP").Value
end

local function setupButtonTween(Button)
	local Icon = Button:FindFirstChild("Icon")

	local rotationOnEnter = 15
	local rotationOnLeave = 0
	local enterScale = 1.05
	local downScale = 0.9
	local duration = 0.5

	local parent = Button
	local uiScale = parent:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Scale = 1
		uiScale.Parent = parent
	end

	local function tweenScale(toScale)
		TweenService:Create(uiScale, TweenInfo.new(0.1), { Scale = toScale }):Play()
	end

	Button.MouseEnter:Connect(function()
		tweenScale(enterScale)
	end)

	Button.MouseLeave:Connect(function()
		tweenScale(1)
	end)

	Button.MouseButton1Down:Connect(function()
		tweenScale(downScale)
	end)

	Button.MouseButton1Up:Connect(function()
		tweenScale(enterScale)
	end)
end

local function typewriterEffect(label: TextLabel, text: string, delayPerChar: number)
	label.Text = ""
	local fullText = text
	local typing = true
	local skip = false

	local connection
	connection = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 
			or input.UserInputType == Enum.UserInputType.Touch then
			if typing then
				skip = true
			end
		end
	end)

	for i = 1, #fullText do
		if skip then
			label.Text = fullText
			break
		end
		label.Text = string.sub(fullText, 1, i)
		task.wait(delayPerChar)
	end

	typing = false
	connection:Disconnect()
end

local function showDialogue()
	local DialogueContainer = MainGui:WaitForChild("Tutorial")
	DialogueContainer.Visible = true

	local DialogueText = DialogueContainer:WaitForChild("DialogueText")
	local SpeakerName = DialogueContainer:WaitForChild("Speaker")
	local ContinueText = DialogueContainer:FindFirstChild("ContinueText")
	if ContinueText then
		ContinueText.Visible = false
	end

	for categoryName, dialogueSet in pairs(Dialogue) do
		local keys = {}
		for key in pairs(dialogueSet) do
			table.insert(keys, key)
		end
		table.sort(keys, function(a, b)
			return tonumber(a:match("%d+")) < tonumber(b:match("%d+"))
		end)

		for _, key in ipairs(keys) do
			local dialogueData = dialogueSet[key]
			SpeakerName.Text = dialogueData.Speaker
			typewriterEffect(DialogueText, dialogueData.Text, 0.02)

			if ContinueText then
				ContinueText.Visible = true
			end

			local clicked = false
			local connection
			connection = UserInputService.InputBegan:Connect(function(input, gpe)
				if gpe then return end
				if input.UserInputType == Enum.UserInputType.MouseButton1 
					or input.UserInputType == Enum.UserInputType.Touch then
					clicked = true
				end
			end)

			repeat task.wait() until clicked
			connection:Disconnect()
			if ContinueText then
				ContinueText.Visible = false
			end
		end
	end

	DialogueContainer.Visible = false
end

local function updateStats()
	
	local CashText = MainGui:WaitForChild("Bottom"):WaitForChild("CashContainer"):WaitForChild("Frame"):WaitForChild("CashText")
	if not CashText then end
	
	Player:GetAttributeChangedSignal("TempCash"):Connect(function()
		CashText.Text = "$"..Digits.AddCommas(Player:GetAttribute("TempCash"))
	end)
end

local function hideAllFrames()
	
	local Frames = MainGui:WaitForChild("Frames")
	if not Frames then return end
	
	for _, Frame in ipairs(Frames:GetChildren()) do
		if Frame:IsA("Frame") then
			Frame.Visible = false
		end
	end
	
end

local function toggleFrame(FrameName : string)
	
	local Frames = MainGui:WaitForChild("Frames")
	if not Frames then return end
	
	local TargetFrame = Frames:FindFirstChild(FrameName)
	if not TargetFrame then return end
	
	local closeButton : ImageButton = TargetFrame:FindFirstChild("Close")
	if not closeButton then return end
	
	closeButton.MouseButton1Click:Connect(function()
		hideAllFrames()
	end)
	
	hideAllFrames()
	TargetFrame.Visible = not TargetFrame.Visible
	
end

local function setupHotbarKeybinds()
	local UserData = getUserData()
	if not UserData then return end

	local Inventory = UserData:FindFirstChild("Hotbar")
	if not Inventory then return end

	local Hotbar = MainGui:WaitForChild("Bottom"):WaitForChild("Hotbar")
	if not Hotbar then return end

	local keyMap = {
		[Enum.KeyCode.One] = "1",
		[Enum.KeyCode.Two] = "2",
		[Enum.KeyCode.Three] = "3",
		[Enum.KeyCode.Four] = "4",
		[Enum.KeyCode.Five] = "5",
		[Enum.KeyCode.Six] = "6"
	}

	local function tweenButtonScale(button: ImageButton, targetScale: number)
		local uiScale = button:FindFirstChildOfClass("UIScale")
		if not uiScale then
			uiScale = Instance.new("UIScale")
			uiScale.Scale = 1
			uiScale.Parent = button
		end

		TweenService:Create(uiScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = targetScale
		}):Play()
	end

	local lastPressedSlot = nil

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

		local slotName = keyMap[input.KeyCode]
		if not slotName then return end

		if lastPressedSlot == slotName then
			lastPressedSlot = nil
			Remotes.Building.Cancel:Fire()
			return
		end

		lastPressedSlot = slotName

		local Button = Hotbar:FindFirstChild(slotName)
		if Button then
			Remotes.Audio.ClientToClient:Fire("ClickSoundEffect")
			tweenButtonScale(Button, 0.9)
		end

		ReplicatedStorage.Remotes.Building.ClientRequest:Fire(slotName)
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

		local slotName = keyMap[input.KeyCode]
		if not slotName then return end

		local Button = Hotbar:FindFirstChild(slotName)
		if Button then
			tweenButtonScale(Button, 1)
		end
	end)
	
	-- controller support (LB / RB)
	local hotbarSlots = { "1", "2", "3", "4", "5", "6" }

	local function setSlot(slotName)
		if lastPressedSlot == slotName then
			lastPressedSlot = nil
			Remotes.Building.Cancel:Fire()
			return
		end

		lastPressedSlot = slotName

		local Button = Hotbar:FindFirstChild(slotName)
		if Button then
			Remotes.Audio.ClientToClient:Fire("ClickSoundEffect")
			tweenButtonScale(Button, 0.9)
		end

		ReplicatedStorage.Remotes.Building.ClientRequest:Fire(slotName)
	end

	local function getNextSlot(direction)
		local available = {}
		for _, slot in ipairs(hotbarSlots) do
			local btn = Hotbar:FindFirstChild(slot)
			if btn and btn.Visible then
				table.insert(available, slot)
			end
		end

		if #available == 0 then return end

		local currentIndex = table.find(available, lastPressedSlot)
		if not currentIndex then 
			currentIndex = 1 
		else
			currentIndex += direction
			if currentIndex > #available then currentIndex = 1 end
			if currentIndex < 1 then currentIndex = #available end
		end

		return available[currentIndex]
	end

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.ButtonL1 then
			local nextSlot = getNextSlot(-1)
			if nextSlot then setSlot(nextSlot) end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.ButtonR1 then
			local nextSlot = getNextSlot(1)
			if nextSlot then setSlot(nextSlot) end
		end
	end)
end

local function setupHotbar()
	
	local TowerData = require(ReplicatedStorage.Modules.StoredData.TowerData)
	
	local UserData = getUserData()
	if not UserData then return end
	
	local Level = UserData:FindFirstChild("Level")
	if not Level then return end
	
	local InventoryFolder = UserData:FindFirstChild("Hotbar")
	if not InventoryFolder then return end
	
	local HotBar = MainGui:WaitForChild("Bottom"):WaitForChild("Hotbar")
	if not HotBar then return end
	
	if Level.Value >= 15 then
		
		local Level15 = HotBar:WaitForChild("Level15")
		if not Level15 then return end 
		
		local Level9 = HotBar:WaitForChild("Level9")
		if not Level9 then return end 
		
		local Slot5 = HotBar:WaitForChild("5")
		if not Slot5 then return end 
		
		local Slot6 = HotBar:WaitForChild("6")
		if not Slot6 then return end
		
		Level15.Visible = false
		Level9.Visible = false
		
		Slot5.Visible = true
		Slot6.Visible = true
		
	elseif Level.Value >= 10 then
		
		local Level9 = HotBar:WaitForChild("Level9")
		if not Level9 then return end 
		
		local Slot5 = HotBar:WaitForChild("5")
		if not Slot5 then return end 
		
		Level9.Visible = false
		Slot5.Visible = true
		
	end
	
	for _, Slot in ipairs(InventoryFolder:GetChildren()) do
		
		local SlotNumber = Slot.Name
		if not SlotNumber then continue end
		
		local UISlot = HotBar:FindFirstChild(SlotNumber)
		if not UISlot then continue end
		
		if Slot.Value == "" then 
			UISlot.Holder.Visible = false
			continue 
		end
		
		local ImageId = TowerData[Slot.Value].ImageId
		if not ImageId then continue end
		
		local Price = TowerData[Slot.Value].Price
		if not Price then continue end
		
		local UnitIcon : ImageLabel = UISlot:FindFirstChild("UnitIcon")
		if not UnitIcon then continue end
		
		UnitIcon.Image = "rbxassetid://"..ImageId
		UISlot:FindFirstChild("Holder"):FindFirstChild("Price").Text = "$"..Price
		UISlot:FindFirstChild("Holder").Visible = true
	end
	
end

local function setupButtons()
	for _, Button in ipairs(MainGui:GetDescendants()) do
		if Button:IsA("ImageButton") then
			
			setupButtonTween(Button)
			
			Button.MouseButton1Click:Connect(function()
				
				Remotes.Audio.ClientToClient:Fire("ClickSoundEffect")
				
				if Button.Name == "Level9" then
					sendNotification("You must be level 10 to unlock.", "Error")
				elseif Button.Name == "Level15" then
					sendNotification("You must be level 15 to unlock.", "Error")
				end
				
				if Button.Parent.Name == "Hotbar" then
					ReplicatedStorage.Remotes.Building.ClientRequest:Fire(Button.Name)
				else
					local FrameName = Button:GetAttribute("FrameName")
					if not FrameName then return end

					toggleFrame(FrameName)
				end
				
			end)
			
		end
	end
end

local selectedTower = nil
local lastHovered, activeCircle = nil, nil

local function closeTowerInfo()
	
	local TowerInfo = MainGui:WaitForChild("Tower_Info")
	if not TowerInfo then return end
	
	selectedTower = nil
	TowerInfo.Visible = false
	MainGui.CenterLeft.Towers.Visible = true
	
	for _, Circle in ipairs(workspace:GetDescendants()) do
		if Circle:IsA("BasePart") and Circle.Name == "BlueCircle" then
			activeCircle = nil
			Circle:Destroy()
		end
	end
	
end

local function handleClientTowers()
	
	local mouse = Player:GetMouse()
	local PlacedTowersFolder = workspace:FindFirstChild("Towers")
	if not PlacedTowersFolder then return end

	local BlueCircleTemplate = ReplicatedStorage.Storage.Circles:FindFirstChild("BlueCircle")
	if not BlueCircleTemplate then return end

	local TweenInfoExpand = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local TweenInfoShrink = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	mouse.Move:Connect(function()
		local target = mouse.Target
		local hoveredTower = nil

		if target then
			for _, tower in ipairs(PlacedTowersFolder:GetChildren()) do
				if tower:IsA("Model") and tower.PrimaryPart == target then
					hoveredTower = tower
					break
				end
			end
		end

		if hoveredTower ~= lastHovered then
			if lastHovered then
				for _, Highlight in ipairs(lastHovered:GetDescendants()) do
					if Highlight:IsA("Highlight") then
						Highlight:Destroy()
					end
				end
				
				MainGui.Tower_Secondary_Info.Visible = false
			end

			if hoveredTower then
				local range = hoveredTower:GetAttribute("Range")
				if range then
					
					local Highlight = Instance.new("Highlight")
					Highlight.Name = "temp"
					Highlight.OutlineColor = Color3.fromRGB(255,255,255)
					Highlight.FillColor = Color3.fromRGB(255,255,255)
					Highlight.FillTransparency = .5
					Highlight.Parent = hoveredTower
					
					Remotes.Audio.ClientToClient:Fire("Hover")

					MainGui.Tower_Secondary_Info.Visible = true
					
					MainGui.Tower_Secondary_Info.Tower_Name.Text = hoveredTower.Name:gsub("[%d_]", "")
					MainGui.Tower_Secondary_Info.Tower_User.Text = "@"..Players:GetPlayerByUserId(hoveredTower:GetAttribute("Owner")).Name
					--[[
					activeCircle = BlueCircleTemplate:Clone()
					activeCircle.Anchored = true
					activeCircle.CanCollide = false
					activeCircle.Parent = workspace
					activeCircle.CFrame = hoveredTower.PrimaryPart.CFrame
						* CFrame.new(0, -hoveredTower.PrimaryPart.Size.Y / 2, 0)
						* CFrame.Angles(0, math.rad(-90), math.rad(90))
					activeCircle.Size = Vector3.new(0.01, 0.01, 0.01)
					local targetSize = Vector3.new(0.375, range * 2, range * 2)
					local tween = TweenService:Create(activeCircle, TweenInfoExpand, { Size = targetSize })
					tween:Play()
					]]
				end
			end

			lastHovered = hoveredTower
		end
	end)
	
	local SellButton = nil
	local UpgradeButton = nil
	local CloseButton = nil
	local TowerInfo = MainGui:WaitForChild("Tower_Info")
	
	local SellButtonConn, UpgradeButtonConn, CloseButtonConn

	local function cleanupUI()
		if activeCircle then
			local shrinkTween = TweenService:Create(activeCircle, TweenInfoShrink, { Size = Vector3.new(0.01, 0.01, 0.01) })
			shrinkTween:Play()
			task.delay(0.15, function()
				if activeCircle then
					activeCircle:Destroy()
					activeCircle = nil
				end
			end)
		end
		TowerInfo.Visible = false
		selectedTower = nil
	end

	mouse.Button1Down:Connect(function()
		local target = mouse.Target
		if not target then return end

		local found = false

		for _, tower in ipairs(PlacedTowersFolder:GetChildren()) do
			if tower:IsA("Model") and target:IsDescendantOf(tower) then --tower.PrimaryPart == target then

				found = true

				if activeCircle then
					activeCircle:Destroy()
					activeCircle = nil
				end
				selectedTower = tower

				local ownerId = tower:GetAttribute("Owner")
				if ownerId ~= Player.UserId then 
					sendNotification("This is not your Tower", "Error")
					return 
				end

				local TowerStat_Damage = tower:GetAttribute("Damage")
				local TowerStat_Rate = tower:GetAttribute("AttackCooldown")
				local TowerStat_Range = tower:GetAttribute("Range")

				local FoundData = TowerData[tower.Name]
				if not FoundData then return end

				local TowerIcon = TowerInfo.Icon.TowerIcon
				local DamageStat = TowerInfo.Stats.Damage.Stat
				local RangeStat = TowerInfo.Stats.Range.Stat
				local RateStat = TowerInfo.Stats.Rate.Stat
				local TowerNameText = TowerInfo.TowerName
				local NextRange = TowerInfo.Stats.Range.Stat2
				local NextRate = TowerInfo.Stats.Rate.Stat2
				local NextDamage = TowerInfo.Stats.Damage.Stat2
				
				local PriortiyContainer = TowerInfo.Priority
				
				local Priorities = {
					"First",
					"Last",
					"Closest"
				}
				
				local PriorityForwardButton = PriortiyContainer.Forward
				local PriorityBackwardButton = PriortiyContainer.Backward
				
				local PriorityDisplayText = PriortiyContainer.Text
				
				local ButtonsContainer = TowerInfo.ButtonHolder
				
				local UpgradeButton = TowerInfo.Upgrade.UpgradeBtn
				local SellButton = ButtonsContainer.Sell
				local CloseButton = ButtonsContainer.CloseBtn

				local PreUpgradeName = tower.Name
				local CurrentUpgrade = 1
				if not tower.Name:match("_") then
					CurrentUpgrade = 2
				elseif tower.Name:match("1") then
					CurrentUpgrade = 2
				elseif tower.Name:match("2") then
					CurrentUpgrade = 3
				elseif tower.Name:match("3") then
					CurrentUpgrade = 4
				end
				
				TowerIcon.Image = "rbxassetid://" .. FoundData.ImageId
				DamageStat.Text = tostring(TowerStat_Damage or 0)
				RangeStat.Text = tostring(TowerStat_Range or 0)
				RateStat.Text = tostring(TowerStat_Rate or 0)
				
				local TargetName
				if not tower.Name:match("_") then
					TargetName = PreUpgradeName .. "_" .. CurrentUpgrade
				else
					TargetName = PreUpgradeName:gsub("%d+$", "") .. CurrentUpgrade
				end
				local NextTower = ReplicatedStorage.Storage.Towers:FindFirstChild(TargetName)
				if NextTower then
					NextDamage.Text = NextTower:GetAttribute("Damage")
					NextRange.Text = NextTower:GetAttribute("Range")
					NextRate.Text = NextTower:GetAttribute("AttackCooldown")
				else
					NextDamage.Text = "Max"
					NextRange.Text = "Max"
					NextRate.Text = "Max"
				end
				
				local PreUpgradeName = tower.Name
				local CurrentUpgrade = 1
				if not tower.Name:match("_") then
					CurrentUpgrade = 2
				elseif tower.Name:match("1") then
					CurrentUpgrade = 2
				elseif tower.Name:match("2") then
					CurrentUpgrade = 3
				elseif tower.Name:match("3") then
					CurrentUpgrade = 4
				end

				local TargetName
				if not tower.Name:match("_") then
					TargetName = PreUpgradeName .. "_" .. CurrentUpgrade
				else
					TargetName = PreUpgradeName:gsub("%d+$", "") .. CurrentUpgrade
				end

				local nextUpgradeData = TowerData[TargetName]
				if nextUpgradeData then
					UpgradeButton.Price.Text = "$" .. (nextUpgradeData.Price or 0)
					UpgradeButton.AutoButtonColor = true
					UpgradeButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				else
					UpgradeButton.Price.Text = "MAX"
					UpgradeButton.AutoButtonColor = false
					UpgradeButton.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
				end

				local baseName, level = string.match(tower.Name, "^(.-)_(%d+)$")
				
				TowerNameText.Text = baseName or tower.Name
				
				TowerInfo.Upgrade.CurrentLevel.Text = `Lvl {level or 1} >`
				
				if NextTower then
					TowerInfo.Upgrade.NextLevel.Text = `Lvl {(level or 1) + 1}`
				else
					TowerInfo.Upgrade.NextLevel.Text = ` MAX`
				end

				activeCircle = BlueCircleTemplate:Clone()
				activeCircle.Anchored = true
				activeCircle.CanCollide = false
				activeCircle.Parent = workspace
				activeCircle.CFrame = tower.PrimaryPart.CFrame
					* CFrame.new(0, -tower.PrimaryPart.Size.Y / 2, 0)
					* CFrame.Angles(0, math.rad(-90), math.rad(90))
				activeCircle.Size = Vector3.new(0.01, 0.01, 0.01)
				activeCircle.CanQuery = false

				local targetSize = Vector3.new(0.375, TowerStat_Range * 2, TowerStat_Range * 2)
				local tween = TweenService:Create(activeCircle, TweenInfoExpand, { Size = targetSize })
				tween:Play()

				TowerInfo.Visible = true
				MainGui.CenterLeft.Towers.Visible = false
				MainGui.Towers.Visible = false
				
				Remotes.Audio.ClientToClient:Fire("ClickSoundEffect")

				if SellButtonConn then SellButtonConn:Disconnect() end
				if UpgradeButtonConn then UpgradeButtonConn:Disconnect() end
				if CloseButtonConn then CloseButtonConn:Disconnect() end

				SellButtonConn = SellButton.MouseButton1Click:Connect(function()
					Remotes.Game.SellTower:FireServer(selectedTower)
					cleanupUI()
				end)

				UpgradeButtonConn = UpgradeButton.MouseButton1Click:Connect(function()
					Remotes.Game.Upgrade:FireServer(selectedTower)
					cleanupUI()
				end)

				CloseButtonConn = CloseButton.MouseButton1Click:Connect(function()
					cleanupUI()
				end)
				
				local currentPriorityIndex = tower:GetAttribute("Priority") or 1
				PriorityDisplayText.Text = Priorities[currentPriorityIndex]

				PriorityForwardButton.MouseButton1Click:Connect(function()
					currentPriorityIndex += 1
					if currentPriorityIndex > #Priorities then
						currentPriorityIndex = 1
					end
					local newPriority = Priorities[currentPriorityIndex]
					PriorityDisplayText.Text = newPriority
					tower:SetAttribute("Priority", currentPriorityIndex)
					Remotes.Building.Target:FireServer(tower, currentPriorityIndex)
				end)

				PriorityBackwardButton.MouseButton1Click:Connect(function()
					currentPriorityIndex -= 1
					if currentPriorityIndex < 1 then
						currentPriorityIndex = #Priorities
					end
					local newPriority = Priorities[currentPriorityIndex]
					PriorityDisplayText.Text = newPriority
					tower:SetAttribute("Priority", currentPriorityIndex)
					Remotes.Building.Target:FireServer(tower, currentPriorityIndex)
				end)

				break
			end
		end
		
		if not(found) then
			if activeCircle then
				activeCircle:Destroy()
				activeCircle = nil
				TowerInfo.Visible = false
			end
		end
	end)
	
	GameRemotes:WaitForChild("ReEnableInfo").OnClientEvent:Connect(function(tower)
		if MainGui.Towers.Visible == true then return end
		if activeCircle then
			activeCircle:Destroy()
			activeCircle = nil
		end
		selectedTower = tower

		local ownerId = tower:GetAttribute("Owner")
		if ownerId ~= Player.UserId then 
			sendNotification("This is not your Tower", "Error")
			return 
		end

		local TowerStat_Damage = tower:GetAttribute("Damage")
		local TowerStat_Rate = tower:GetAttribute("AttackCooldown")
		local TowerStat_Range = tower:GetAttribute("Range")

		local FoundData = TowerData[tower.Name]
		if not FoundData then return end

		local TowerIcon = TowerInfo.Icon.TowerIcon
		local DamageStat = TowerInfo.Stats.Damage.Stat
		local RangeStat = TowerInfo.Stats.Range.Stat
		local RateStat = TowerInfo.Stats.Rate.Stat
		local TowerNameText = TowerInfo.TowerName
		local NextRange = TowerInfo.Stats.Range.Stat2
		local NextRate = TowerInfo.Stats.Rate.Stat2
		local NextDamage = TowerInfo.Stats.Damage.Stat2

		local PriortiyContainer = TowerInfo.Priority

		local Priorities = {
			"First",
			"Last",
			"Closest"
		}

		local PriorityForwardButton = PriortiyContainer.Forward
		local PriorityBackwardButton = PriortiyContainer.Backward

		local PriorityDisplayText = PriortiyContainer.Text

		local ButtonsContainer = TowerInfo.ButtonHolder

		local UpgradeButton = TowerInfo.Upgrade.UpgradeBtn
		local SellButton = ButtonsContainer.Sell
		local CloseButton = ButtonsContainer.CloseBtn

		local PreUpgradeName = tower.Name
		local CurrentUpgrade = 1
		if not tower.Name:match("_") then
			CurrentUpgrade = 2
		elseif tower.Name:match("1") then
			CurrentUpgrade = 2
		elseif tower.Name:match("2") then
			CurrentUpgrade = 3
		elseif tower.Name:match("3") then
			CurrentUpgrade = 4
		end

		TowerIcon.Image = "rbxassetid://" .. FoundData.ImageId
		DamageStat.Text = tostring(TowerStat_Damage or 0)
		RangeStat.Text = tostring(TowerStat_Range or 0)
		RateStat.Text = tostring(TowerStat_Rate or 0)

		local TargetName
		if not tower.Name:match("_") then
			TargetName = PreUpgradeName .. "_" .. CurrentUpgrade
		else
			TargetName = PreUpgradeName:gsub("%d+$", "") .. CurrentUpgrade
		end
		local NextTower = ReplicatedStorage.Storage.Towers:FindFirstChild(TargetName)
		if NextTower then
			NextDamage.Text = NextTower:GetAttribute("Damage")
			NextRange.Text = NextTower:GetAttribute("Range")
			NextRate.Text = NextTower:GetAttribute("AttackCooldown")
		else
			NextDamage.Text = "Max"
			NextRange.Text = "Max"
			NextRate.Text = "Max"
		end

		local PreUpgradeName = tower.Name
		local CurrentUpgrade = 1
		if not tower.Name:match("_") then
			CurrentUpgrade = 2
		elseif tower.Name:match("1") then
			CurrentUpgrade = 2
		elseif tower.Name:match("2") then
			CurrentUpgrade = 3
		elseif tower.Name:match("3") then
			CurrentUpgrade = 4
		end

		local TargetName
		if not tower.Name:match("_") then
			TargetName = PreUpgradeName .. "_" .. CurrentUpgrade
		else
			TargetName = PreUpgradeName:gsub("%d+$", "") .. CurrentUpgrade
		end

		local nextUpgradeData = TowerData[TargetName]
		if nextUpgradeData then
			UpgradeButton.Price.Text = "$" .. (nextUpgradeData.Price or 0)
			UpgradeButton.AutoButtonColor = true
			UpgradeButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		else
			UpgradeButton.Price.Text = "MAX"
			UpgradeButton.AutoButtonColor = false
			UpgradeButton.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
		end

		local baseName, level = string.match(tower.Name, "^(.-)_(%d+)$")

		TowerNameText.Text = baseName or tower.Name

		TowerInfo.Upgrade.CurrentLevel.Text = `Lvl {level or 1} >`
		
		if NextTower then
			TowerInfo.Upgrade.NextLevel.Text = `Lvl {(level or 1) + 1}`
		else
			TowerInfo.Upgrade.NextLevel.Text = ` MAX`
		end

		activeCircle = BlueCircleTemplate:Clone()
		activeCircle.Anchored = true
		activeCircle.CanCollide = false
		activeCircle.CanQuery = false
		activeCircle.Parent = workspace
		activeCircle.CFrame = tower.PrimaryPart.CFrame
			* CFrame.new(0, -tower.PrimaryPart.Size.Y / 2, 0)
			* CFrame.Angles(0, math.rad(-90), math.rad(90))
		activeCircle.Size = Vector3.new(0.01, 0.01, 0.01)

		local targetSize = Vector3.new(0.375, TowerStat_Range * 2, TowerStat_Range * 2)
		local tween = TweenService:Create(activeCircle, TweenInfoExpand, { Size = targetSize })
		tween:Play()

		TowerInfo.Visible = true
		MainGui.CenterLeft.Towers.Visible = false
		MainGui.Towers.Visible = false
		Remotes.Audio.ClientToClient:Fire("ClickSoundEffect")

		if SellButtonConn then SellButtonConn:Disconnect() end
		if UpgradeButtonConn then UpgradeButtonConn:Disconnect() end
		if CloseButtonConn then CloseButtonConn:Disconnect() end

		SellButtonConn = SellButton.MouseButton1Click:Connect(function()
			Remotes.Game.SellTower:FireServer(selectedTower)
			cleanupUI()
		end)

		UpgradeButtonConn = UpgradeButton.MouseButton1Click:Connect(function()
			Remotes.Game.Upgrade:FireServer(selectedTower)
			cleanupUI()
		end)

		CloseButtonConn = CloseButton.MouseButton1Click:Connect(function()
			cleanupUI()
		end)

		local currentPriorityIndex = tower:GetAttribute("Priority") or 1
		PriorityDisplayText.Text = Priorities[currentPriorityIndex]

		PriorityForwardButton.MouseButton1Click:Connect(function()
			currentPriorityIndex += 1
			if currentPriorityIndex > #Priorities then
				currentPriorityIndex = 1
			end
			local newPriority = Priorities[currentPriorityIndex]
			PriorityDisplayText.Text = newPriority

			tower:SetAttribute("Priority", currentPriorityIndex)
			Remotes.Building.Target:FireServer(tower, currentPriorityIndex)
		end)

		PriorityBackwardButton.MouseButton1Click:Connect(function()
			currentPriorityIndex -= 1
			if currentPriorityIndex < 1 then
				currentPriorityIndex = #Priorities
			end
			local newPriority = Priorities[currentPriorityIndex]
			PriorityDisplayText.Text = newPriority
			tower:SetAttribute("Priority", currentPriorityIndex)
			Remotes.Building.Target:FireServer(tower, currentPriorityIndex)
		end)
	end)

	TowerInfo:GetPropertyChangedSignal("Visible"):Connect(function()
		if not SellButton then return end 
		
		SellButton.MouseButton1Click:Connect(function()
			local shrinkTween = TweenService:Create(activeCircle, TweenInfoShrink, { Size = Vector3.new(0.01, 0.01, 0.01) })
			shrinkTween:Play()
			task.delay(0.15, function()
				if activeCircle then
					activeCircle:Destroy()
					activeCircle = nil
				end
			end)
			Remotes.Game.SellTower:FireServer(selectedTower)
			TowerInfo.Visible = false
			selectedTower = nil
		end)

		UpgradeButton.MouseButton1Click:Connect(function()
			local shrinkTween = TweenService:Create(activeCircle, TweenInfoShrink, { Size = Vector3.new(0.01, 0.01, 0.01) })
			shrinkTween:Play()
			task.delay(0.15, function()
				if activeCircle then
					activeCircle:Destroy()
					activeCircle = nil
				end
			end)
			Remotes.Game.Upgrade:FireServer(selectedTower)
			TowerInfo.Visible = false
			selectedTower = nil
		end)
		
		CloseButton.MouseButton1Click:Connect(function()
			TowerInfo.Visible = false
			selectedTower = nil
			local shrinkTween = TweenService:Create(activeCircle, TweenInfoShrink, { Size = Vector3.new(0.01, 0.01, 0.01) })
			shrinkTween:Play()
			task.delay(0.15, function()
				if activeCircle then
					activeCircle:Destroy()
					activeCircle = nil
				end
			end)
		end)
	end)
	
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.X then
			local TowerInfo = MainGui:FindFirstChild("Tower_Info")
			if TowerInfo and TowerInfo.Visible and selectedTower then
				local shrinkTween = TweenService:Create(activeCircle, TweenInfoShrink, { Size = Vector3.new(0.01, 0.01, 0.01) })
				shrinkTween:Play()
				task.delay(0.15, function()
					if activeCircle then
						activeCircle:Destroy()
						activeCircle = nil
					end
				end)
				Remotes.Game.SellTower:FireServer(selectedTower)
				TowerInfo.Visible = false
				selectedTower = nil
			end
		elseif input.KeyCode == Enum.KeyCode.E then
			Remotes.Game.Upgrade:FireServer(selectedTower)
			TowerInfo.Visible = false
			selectedTower = nil
		end
	end)
	
	TowerInfo:GetPropertyChangedSignal("Visible"):Connect(function()
		MainGui.CenterLeft.Towers.Visible = not(TowerInfo.Visible)
		MainGui.CenterLeft.Position = UDim2.new(0.008, 0,0.5, 0)
		
		if MainGui.Towers.Visible == true then
			MainGui.Towers.Visible = not(TowerInfo.Visible)
		end
	end)
	
end

local function init()
	updateStats()
	setupButtons()
	setupHotbar()
	handleClientTowers()
	setupHotbarKeybinds()
end

-- // code

if Player then
	init()
end

RecieveDialogueData.OnClientEvent:Connect(function(Data)
	Dialogue = Data
	task.wait()
	showDialogue()
end)

Remotes.Game.DisplayRound.OnClientEvent:Connect(function(CurrentRound : number, MaxRound : number)
	
	local CenterTop = MainGui:WaitForChild("CenterTop")
	if not CenterTop then return end
	
	local StatsFrame = CenterTop:WaitForChild("Stats")
	if not StatsFrame then return end
	
	local WaveStat = StatsFrame:WaitForChild("Wave")
	if not WaveStat then return end
	
	local RoundText = WaveStat:WaitForChild("Round") 
	if not RoundText then return end
	
	RoundText.Text = CurrentRound.."/"..MaxRound
	
end)

Remotes.Game.SendNotification.OnClientEvent:Connect(function(Text, Type)
	sendNotification(Text, Type)
end)

local activeTimerId = 0

Remotes.Game.StartTimer.OnClientEvent:Connect(function(maxTime : number)

	local CenterTop = MainGui:WaitForChild("CenterTop")
	if not CenterTop then return end

	local StatsFrame = CenterTop:WaitForChild("Stats")
	if not StatsFrame then return end

	local TimeStat = StatsFrame:WaitForChild("Time")
	if not TimeStat then return end

	local Timer = TimeStat:WaitForChild("Timer") 
	if not Timer then return end
	
	activeTimerId += 1
	local thisTimerId = activeTimerId

	task.spawn(function()
		local remaining = maxTime
		while remaining >= 0 do
			if thisTimerId ~= activeTimerId then
				return
			end

			local minutes = math.floor(remaining / 60)
			local seconds = remaining % 60
			Timer.Text = string.format("%02d:%02d", minutes, seconds)

			task.wait(1)
			remaining -= 1
		end
	end)

end)

--[[Remotes:FindFirstChild("Game"):FindFirstChild("ShowBossBar").OnClientEvent:Connect(function(BossModel : Model)
	
	local Humanoid = BossModel:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end
	
	local Boss_HP = MainGui:WaitForChild("Boss_HP")
	if not Boss_HP then return end 
	
	local BossNameText = Boss_HP:WaitForChild("Tower_Name")
	if not BossNameText then return end
	
	local HPText = Boss_HP:WaitForChild("HP")
	if not HPText then return end
	
	local BarFrame = Boss_HP:WaitForChild("Bar")
	
	Boss_HP.Visible = true
	BossNameText.Text = BossModel.Name
	
	local function UpdateHealth()
		local currentHealth = math.clamp(Humanoid.Health, 0, Humanoid.MaxHealth)
		local ratio = currentHealth / Humanoid.MaxHealth

		HPText.Text = math.floor(currentHealth) .. "/" .. math.floor(Humanoid.MaxHealth)
		BarFrame.Size = UDim2.new(ratio, 0, 1, 0)
		Humanoid.Died:Connect(function()
			Boss_HP.Visible = false
		end)
	end
	
	UpdateHealth()
	Humanoid.HealthChanged:Connect(UpdateHealth)
	
	Humanoid.Died:Connect(function()
		Boss_HP.Visible = false
	end)
	
	BossModel.AncestryChanged:Connect(function(_, parent)
		if not parent then
			Boss_HP.Visible = false
		end
	end)
	
end)--]]

workspace:WaitForChild("Enemies").ChildAdded:Connect(function(Model)
	if EnemyData[Model.Name] and EnemyData[Model.Name].Boss then
		local NewExample = MainGui.Boss_HP.Example:Clone()
		NewExample.Parent = MainGui.Boss_HP
		NewExample.Visible = true
		NewExample.ImageLabel.Image = EnemyData[Model.Name].ImageId
		NewExample.Tower_Name.Text = Model.Name

		local Humanoid = Model:WaitForChild("Humanoid", 5)
		if not Humanoid then
			NewExample:Destroy()
			return
		end

		local MaxHealth = Humanoid.MaxHealth
		local OriginalBarColor = NewExample.Bar.BackgroundColor3

		NewExample.HP.Text = Humanoid.Health.. "/".. MaxHealth
		NewExample.Bar.Size = UDim2.new(0, 0, 1, 0)

		TweenService:Create(NewExample.Bar, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 1, 0)
		}):Play()

		local function pulseBar()
			local scaleY = NewExample.Bar:FindFirstChildOfClass("UIScale")
			if not scaleY then
				scaleY = Instance.new("UIScale")
				scaleY.Parent = NewExample.Bar
			end

			TweenService:Create(NewExample.Bar, TweenInfo.new(0.05), {
				BackgroundColor3 = Color3.new(1, 1, 1)
			}):Play()

			TweenService:Create(scaleY, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1.15
			}):Play()

			task.delay(0.08, function()
				TweenService:Create(scaleY, TweenInfo.new(0.15, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
					Scale = 1
				}):Play()

				TweenService:Create(NewExample.Bar, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
					BackgroundColor3 = OriginalBarColor
				}):Play()
			end)
		end

		local previousHealth = Humanoid.Health

		Humanoid:GetPropertyChangedSignal("Health"):Connect(function()
			local currentHealth = Humanoid.Health
			local healthPercent = math.clamp(currentHealth / MaxHealth, 0, 1)

			NewExample.HP.Text = math.floor(currentHealth).. "/".. MaxHealth

			TweenService:Create(NewExample.Bar, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Size = UDim2.new(healthPercent, 0, 1, 0)
			}):Play()

			if currentHealth < previousHealth then
				pulseBar()
			end

			previousHealth = currentHealth
		end)

		Humanoid.Died:Connect(function()
			NewExample.HP.Text = "0/".. MaxHealth

			TweenService:Create(NewExample.Bar, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 0, 1, 0)
			}):Play()

			task.wait(0.5)

			TweenService:Create(NewExample, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = UDim2.new(0, 0, 0, 0)
			}):Play()

			task.wait(0.3)
			NewExample:Destroy()
		end)

		Model.AncestryChanged:Connect(function()
			if not Model:IsDescendantOf(workspace) then
				NewExample.HP.Text = "0/".. MaxHealth

				TweenService:Create(NewExample.Bar, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
					Size = UDim2.new(0, 0, 1, 0)
				}):Play()

				task.wait(0.5)

				TweenService:Create(NewExample, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Size = UDim2.new(0, 0, 0, 0)
				}):Play()

				task.wait(0.3)
				NewExample:Destroy()
			end
		end)
	end
end)

local function hideAll()
	for _, Frame in ipairs(MainGui:GetChildren()) do
		if Frame:IsA("Frame") then
			Frame.Visible = false
		end
	end
end

local statsShown = false

Remotes.Game.ShowResults.OnClientEvent:Connect(function(roundsPlayed, formattedTime, Type)

	local radius = 35
	local heightoffset = 0
	local speed = .2
	
	if statsShown == true then return end
	statsShown = true

	local Camera = workspace.Camera
	if not Camera then return end

	local CenterPart = workspace:FindFirstChild("CenterPart")
	if not CenterPart then return end 

	local UserData = getUserData()
	if not UserData then return end

	local CurrentCash = UserData:FindFirstChild("Money")
	if not CurrentCash then return end

	local CurrentXP = UserData:FindFirstChild("EXP")
	if not CurrentXP then return end

	local ResultsFrame = MainGui:WaitForChild("End_Result")
	if not ResultsFrame then return end 
	
	local Title = ResultsFrame:FindFirstChild("End_Result"):FindFirstChild("Title")
	if not Title then return end

	local TimeText = ResultsFrame:WaitForChild("End_Result"):WaitForChild("ButtonHolder"):WaitForChild("Time"):WaitForChild("Amount")
	if not TimeText then return end

	local Rounds = ResultsFrame:WaitForChild("End_Result"):WaitForChild("ButtonHolder"):WaitForChild("Rounds"):WaitForChild("Amount")
	if not Rounds then return end

	local Rewards = ResultsFrame:WaitForChild("End_Result"):WaitForChild("ButtonHolder"):WaitForChild("Reward")
	if not Rewards then return end
	
	local ReturnButton = ResultsFrame:WaitForChild("End_Result"):WaitForChild("ButtonHolder2"):WaitForChild("Return")
	if not ReturnButton then return end

	local CashAmount = Rewards:WaitForChild("CashAmount")
	local XPAmount = Rewards:WaitForChild("XPAmount")

	local CashGained = CurrentCash.Value - StartingCash
	local EXPGained = CurrentXP.Value - StartingEXP

	for _, Frame in ipairs(MainGui:GetChildren()) do
		if Frame:IsA("Frame") then
			Frame.Visible = false
		end
	end
	
	if Type == "Won" then
		Title.Text = "You Won!"
		Remotes.Audio.ClientToClient:Fire("WinRound")
		Title.TextColor3 = Color3.fromRGB(0, 255, 0)
	elseif Type == "Lost" then
		Title.Text = "You Lost!"
		Remotes.Audio.ClientToClient:Fire("EndDefeat")
		Title.TextColor3 = Color3.fromRGB(255, 0, 0)
	end

	TimeText.Text = formattedTime
	Rounds.Text = roundsPlayed

	CashAmount.Text = "+$"..CashGained
	XPAmount.Text = "+"..EXPGained
	
	ReturnButton.MouseButton1Click:Connect(function()
		ReturnButton.MainText.Text = "Teleporting"
		Remotes.Game.ReturnToLobby:FireServer()
	end)
	
	hideAll()

	ResultsFrame.Visible = true

	local originalCameraType = Camera.CameraType
	Camera.CameraType = Enum.CameraType.Scriptable

	local angle = 0
	local isOrbiting = true

	local orbitConnection
	orbitConnection = game:GetService("RunService").RenderStepped:Connect(function(delta)
		if not isOrbiting or not CenterPart then
			orbitConnection:Disconnect()
			Camera.CameraType = originalCameraType
			return
		end

		angle = angle + speed * delta

		local x = CenterPart.Position.X + radius * math.cos(angle)
		local z = CenterPart.Position.Z + radius * math.sin(angle)
		local y = CenterPart.Position.Y + heightoffset

		local newPosition = Vector3.new(x, y, z)
		Camera.CFrame = CFrame.new(newPosition, CenterPart.Position + Vector3.new(0, heightoffset, 0))
	end)
	
	
end)

Remotes.Game.UpdateHealthbar.OnClientEvent:Connect(function(currentHealth, maxHealth)
	local HealthBar = MainGui:WaitForChild("CenterTop"):WaitForChild("GameStats")
	if not HealthBar then return end

	local Bar = HealthBar:WaitForChild("Bar")
	if not Bar then return end

	local HPText = HealthBar:WaitForChild("HP")
	if not HPText then return end

	local Percentage = math.clamp(currentHealth / maxHealth, 0, 1)
	local newSize = UDim2.new(Percentage, 0, 1, 0)

	local TweenService = game:GetService("TweenService")
	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	TweenService:Create(Bar, tweenInfo, {Size = newSize}):Play()

	HPText.Text = currentHealth .. "/" .. maxHealth

	local originalSize = HealthBar.Size
	local biggerSize = UDim2.new(originalSize.X.Scale * 1.05, 0, originalSize.Y.Scale * 1.05, 0)

	local popTweenOut = TweenService:Create(HealthBar, TweenInfo.new(0.125, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = biggerSize
	})

	local popTweenIn = TweenService:Create(HealthBar, TweenInfo.new(0.125, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = originalSize
	})

	popTweenOut:Play()
	popTweenOut.Completed:Connect(function()
		popTweenIn:Play()
	end)
end)

Remotes.Building.CloseTowerInfo.Event:Connect(function()
	closeTowerInfo()
end)

local TopRight = MainGui:WaitForChild("TopRight")
local HolderRight = TopRight:WaitForChild("Holder")

workspace:GetAttributeChangedSignal("GameSpeed"):Connect(function()
	for _, Frame in ipairs(HolderRight:GetChildren()) do
		if Frame:IsA("ImageButton") then
			if Frame.Name == "x"..workspace:GetAttribute("GameSpeed") then
				Frame.Multiplier.TextColor3 = Color3.new(0,1,0)
			else
				Frame.Multiplier.TextColor3 = Color3.new(1,1,1)
			end
		end
	end
end)

for _, Frame in ipairs(HolderRight:GetChildren()) do
	if Frame:IsA("ImageButton") then
		Frame.MouseButton1Click:Connect(function()
			if Frame.Name == "x3" then
				if not(game:GetService("MarketplaceService"):UserOwnsGamePassAsync(Player.UserId, 1616584704)) then
					game:GetService("MarketplaceService"):PromptGamePassPurchase(Player, 1616584704)
					return
				end
			end
			GameRemotes.GameSpeed:FireServer(Frame.Name)
		end)
	end
end

local Timer = 5

RecieveSkipWave.OnClientEvent:Connect(function()
	SkipWaveUi.Visible = true
	Timer = 5
	
	while Timer > 0 do
		SkipWaveUi.Timer.Text = Timer.."s"
		task.wait(1) 
		Timer -= 1
	end
	
	if Timer <= 0 then
		SkipWaveUi.Visible = false
	end
end)

SkipWaveUi.MouseButton1Click:Connect(function()
	SkipWaveUi.Visible = false
	RecieveSkipWave:FireServer()
end)

return {}