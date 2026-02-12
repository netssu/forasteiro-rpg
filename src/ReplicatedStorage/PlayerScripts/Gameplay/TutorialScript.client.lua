local Tutorial = {}

------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

------------------//CONSTANTS

------------------//VARIABLES
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local tutorialGui = playerGui:WaitForChild("Tutorial")
tutorialGui.IgnoreGuiInset = true 
tutorialGui.Enabled = false

local spotlightContainer = tutorialGui:WaitForChild("SpotlightFrame")
spotlightContainer.Active = false
spotlightContainer.Selectable = false

local textLabel = tutorialGui:WaitForChild("Text")
textLabel.Active = false 

local TutorialConfig = require(ReplicatedStorage.Modules.Datas.TutorialConfig) 
local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local OpenedFrames = require(ReplicatedStorage.Modules.Game.HudManager.OpenedFrames)

local currentStage = 0
local activeBeam = nil
local activeBeamAttachments = {}
local stageConnections = {}

local focusFrame = spotlightContainer:WaitForChild("FocusFrame")
local spotFrames = {
	Top = spotlightContainer:WaitForChild("Top"),
	Bottom = spotlightContainer:WaitForChild("Bottom"),
	Left = spotlightContainer:WaitForChild("Left"),
	Right = spotlightContainer:WaitForChild("Right")
}

------------------//FUNCTIONS
local function disconnectStageConnections()
	for _, connection in pairs(stageConnections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	stageConnections = {}
end

local function destroyBeam()
	if activeBeam then
		activeBeam:Destroy()
		activeBeam = nil
	end

	for _, attachment in pairs(activeBeamAttachments) do
		if attachment and attachment.Parent then
			attachment:Destroy()
		end
	end
	activeBeamAttachments = {}
end

local function createBeam(startPart: BasePart, endPart: BasePart): Beam
	destroyBeam() 

	local attachment0 = Instance.new("Attachment", startPart)
	local attachment1 = Instance.new("Attachment", endPart)

	table.insert(activeBeamAttachments, attachment0)
	table.insert(activeBeamAttachments, attachment1)

	local beam = Instance.new("Beam")
	beam.Attachment0 = attachment0
	beam.Attachment1 = attachment1
	beam.FaceCamera = true
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 100))
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureSpeed = 1
	beam.TextureLength = 2
	beam.Parent = startPart

	activeBeam = beam

	return beam
end

local function getGuiElement(path: string): GuiObject?
	local parts = string.split(path, ".")
	local current = playerGui

	for _, part in ipairs(parts) do
		local child = current:FindFirstChild(part)
		if not child then
			warn("[Tutorial] GUI element not found at path:", path, "- stopped at:", part)
			return nil
		end
		current = child
	end

	return current
end

local function getWorldObject(name: string): BasePart?
	local found = workspace:FindFirstChild(name, true)
	if found then
		if found:IsA("BasePart") then
			return found
		elseif found:IsA("Model") then
			return found.PrimaryPart or found:FindFirstChildWhichIsA("BasePart")
		end
	end

	local parts = string.split(name, ".")
	if #parts > 1 then
		local current = workspace
		for i, part in ipairs(parts) do
			local child = current:FindFirstChild(part)
			if not child then
				warn("[Tutorial] World object not found:", part, "in path:", name)
				return nil
			end
			current = child

			if i == #parts then
				if current:IsA("BasePart") then
					return current
				elseif current:IsA("Model") then
					return current.PrimaryPart or current:FindFirstChildWhichIsA("BasePart")
				end
			end
		end
	end

	return nil
end

local function getDynamicFirstPogo(): GuiObject?
	local invFrame = playerGui:FindFirstChild("Inventory", true)
	if not invFrame then return nil end

	local gridScrollingFrame = invFrame:FindFirstChild("GridScrollingFrame", true)
	if not gridScrollingFrame then return nil end

	local pogos = {}
	for _, child in pairs(gridScrollingFrame:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible and child.Name ~= "Template" and child.Name ~= "UIGridLayout" then
			local category = child:GetAttribute("Category")
			if category == "Pogos" then
				table.insert(pogos, child)
			end
		end
	end

	table.sort(pogos, function(a, b)
		return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
	end)

	for _, pogo in ipairs(pogos) do
		local color = pogo:IsA("ImageButton") and pogo.ImageColor3 or pogo.BackgroundColor3
		local isEquipped = (color == Color3.fromRGB(197, 255, 209))

		if not isEquipped then
			return pogo
		end
	end

	if #pogos > 0 then
		return pogos[1]
	end

	return nil
end

local function getDynamicFirstPet(): GuiObject?
	local invFrame = playerGui:FindFirstChild("Inventory", true)
	if not invFrame or not invFrame.Visible then 
		return nil 
	end

	local indexBG = invFrame:FindFirstChild("IndexBG")
	local gridScrollingFrame = nil

	if indexBG then
		gridScrollingFrame = indexBG:FindFirstChild("GridScrollingFrame")
	else
		gridScrollingFrame = invFrame:FindFirstChild("GridScrollingFrame", true)
	end

	if not gridScrollingFrame then 
		return nil 
	end

	task.wait(0.5)

	local pets = {}
	for _, child in pairs(gridScrollingFrame:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible and child.Name ~= "Template" and child.Name ~= "UIGridLayout" then
			local category = child:GetAttribute("Category")
			if category == "Pets" or not category then
				table.insert(pets, child)
			end
		end
	end

	if #pets == 0 then
		return nil
	end

	table.sort(pets, function(a, b)
		return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
	end)

	if #pets > 0 then
		print("[Tutorial] Found first pet target:", pets[1].Name)
		return pets[1]
	end

	return nil
end

local function getSpotlightTarget(guiObject: GuiObject, paddingPx: number): (UDim2, UDim2)
	local absPos = guiObject.AbsolutePosition
	local absSize = guiObject.AbsoluteSize
	local inset = GuiService:GetGuiInset() 

	local centerX = absPos.X + (absSize.X * 0.5)
	local centerY = absPos.Y + (absSize.Y * 0.5) + inset.Y 

	local targetW = absSize.X + (paddingPx * 2)
	local targetH = absSize.Y + (paddingPx * 2)

	return UDim2.fromOffset(centerX, centerY), UDim2.fromOffset(targetW, targetH)
end

local function tweenSpotlight(duration: number, targetPos: UDim2?, targetSize: UDim2?, easingStyle: Enum.EasingStyle?)
	easingStyle = easingStyle or Enum.EasingStyle.Sine

	if targetPos and targetSize then
		TweenService:Create(focusFrame, TweenInfo.new(duration, easingStyle), {
			Position = targetPos,
			Size = targetSize,
			BackgroundTransparency = 1 
		}):Play()

		local leftX = 0
		local rightX = targetPos.X.Offset + (targetSize.X.Offset / 2)
		local bottomY = targetPos.Y.Offset + (targetSize.Y.Offset / 2)

		local holeLeftEdge = targetPos.X.Offset - (targetSize.X.Offset / 2)
		local holeTopEdge = targetPos.Y.Offset - (targetSize.Y.Offset / 2)

		TweenService:Create(spotFrames.Top, TweenInfo.new(duration, easingStyle), {
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 0, holeTopEdge),
			BackgroundTransparency = 0.6
		}):Play()

		TweenService:Create(spotFrames.Bottom, TweenInfo.new(duration, easingStyle), {
			Position = UDim2.new(0, 0, 0, bottomY),
			Size = UDim2.new(1, 0, 1, -bottomY), 
			BackgroundTransparency = 0.6
		}):Play()

		TweenService:Create(spotFrames.Left, TweenInfo.new(duration, easingStyle), {
			Position = UDim2.fromOffset(0, holeTopEdge),
			Size = UDim2.fromOffset(holeLeftEdge, targetSize.Y.Offset),
			BackgroundTransparency = 0.6
		}):Play()

		TweenService:Create(spotFrames.Right, TweenInfo.new(duration, easingStyle), {
			Position = UDim2.fromOffset(rightX, holeTopEdge),
			Size = UDim2.new(1, -rightX, 0, targetSize.Y.Offset),
			BackgroundTransparency = 0.6
		}):Play()

	else
		TweenService:Create(focusFrame, TweenInfo.new(duration, easingStyle), {
			Size = UDim2.fromScale(0, 0),
			Position = UDim2.fromScale(0.5, 0.5)
		}):Play()

		TweenService:Create(spotFrames.Top, TweenInfo.new(duration, easingStyle), {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0, 0),
			BackgroundTransparency = 1 
		}):Play()

		for _, frame in pairs({spotFrames.Bottom, spotFrames.Left, spotFrames.Right}) do
			TweenService:Create(frame, TweenInfo.new(duration, easingStyle), {
				Size = UDim2.fromScale(0, 0),
				BackgroundTransparency = 1
			}):Play()
		end
	end
end

local function updateTextLabel(stageData: any)
	textLabel.Text = stageData.Text.Text or ""
	textLabel.Position = stageData.Text.Position or UDim2.fromScale(0.5, 0.15)
	textLabel.Size = stageData.Text.Size or UDim2.fromScale(0.7, 0.15)
	textLabel.TextSize = stageData.Text.TextSize or 20

	textLabel.TextTransparency = 1
	local textStroke = textLabel:FindFirstChildWhichIsA("UIStroke")
	if textStroke then
		textStroke.Transparency = 1
	end

	TweenService:Create(textLabel, TweenInfo.new(0.3), {
		TextTransparency = 0
	}):Play()

	if textStroke then
		TweenService:Create(textStroke, TweenInfo.new(0.3), {
			Transparency = 0
		}):Play()
	end
end

local function executeStage(stageNumber: number)
	disconnectStageConnections()
	destroyBeam()

	print("[Tutorial] Executing Stage:", stageNumber)

	local stageData = TutorialConfig.getStage(stageNumber)
	if not stageData or not stageData.Enabled then
		print("[Tutorial] Stage finished or disabled, ending tutorial")
		Tutorial.finishTutorial()
		return
	end

	updateTextLabel(stageData)

	local foundButton = nil

	if stageData.Spotlight.Enabled then
		task.spawn(function()
			if stageData.Spotlight.GuiPath == "DYNAMIC_FIRST_POGO" or stageData.Spotlight.GuiPath == "DYNAMIC_FIRST_PET" then
				task.wait(0.5) 
				if stageData.Spotlight.GuiPath == "DYNAMIC_FIRST_POGO" then
					foundButton = getDynamicFirstPogo()
					if not foundButton then task.wait(0.5) foundButton = getDynamicFirstPogo() end
				elseif stageData.Spotlight.GuiPath == "DYNAMIC_FIRST_PET" then
					foundButton = getDynamicFirstPet()
					if not foundButton then task.wait(0.5) foundButton = getDynamicFirstPet() end
				end
			else
				task.wait(0.1)
				foundButton = getGuiElement(stageData.Spotlight.GuiPath)
			end

			if foundButton then
				print("[Tutorial] Element found:", foundButton.Name)
				local pos, size = getSpotlightTarget(foundButton, stageData.Spotlight.Padding or 10)
				tweenSpotlight(0.3, pos, size, Enum.EasingStyle.Quad)
			else
				if stageData.Spotlight.GuiPath then warn("[Tutorial] Element not found:", stageData.Spotlight.GuiPath) end
				if stageData.Spotlight.Position and stageData.Spotlight.Size then
					tweenSpotlight(0.3, stageData.Spotlight.Position, stageData.Spotlight.Size)
				else
					tweenSpotlight(0.3)
				end
			end
		end)
	else
		tweenSpotlight(0.3)
	end

	if stageData.Trail and stageData.Trail.Enabled then
		task.spawn(function()
			local character = player.Character or player.CharacterAdded:Wait()
			local hrp = character:WaitForChild("HumanoidRootPart", 5)

			if hrp and stageData.Trail.TargetPath then
				if stageData.Trail.TargetType == "World" then
					local targetPart = getWorldObject(stageData.Trail.TargetPath)
					if targetPart then createBeam(hrp, targetPart) end
				end
			end
		end)
	end

	local condition = stageData.WaitForCondition

	if condition == "Wait" then
		task.wait(stageData.ConditionValue or 2)
		player:SetAttribute("TutorialStage", stageNumber + 1)

	elseif condition == "CoinsReached" then
		local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
		local targetCoins = stageData.ConditionValue or 400
		local startJumps = player:GetAttribute("Jumps") or 0

		local jumpConn = player:GetAttributeChangedSignal("Jumps"):Connect(function()
			local currentJumps = player:GetAttribute("Jumps") or 0
			if currentJumps > startJumps then
				tweenSpotlight(0.5)
			end
		end)
		table.insert(stageConnections, jumpConn)
		local function checkCoins(val)
			if val and val >= targetCoins then
				task.wait(0.5)
				tweenSpotlight(0.5)
				player:SetAttribute("TutorialStage", stageNumber + 1)
			end
		end

		local currentCoins = DataUtility.client.get("Coins")
		if currentCoins and currentCoins >= targetCoins then
			checkCoins(currentCoins)
		else
			local bindConn = DataUtility.client.bind("Coins", function(coins)
				checkCoins(coins)
			end)
			table.insert(stageConnections, bindConn)
		end

	elseif condition == "Jumps" then
		local requiredJumps = stageData.ConditionValue or 1
		local startJumps = player:GetAttribute("Jumps") or 0
		local jumpsCounted = 0

		local conn = player:GetAttributeChangedSignal("Jumps"):Connect(function()
			local current = player:GetAttribute("Jumps") or 0
			if current > startJumps then
				local diff = current - startJumps
				jumpsCounted = jumpsCounted + diff
				startJumps = current

				if jumpsCounted >= 1 then tweenSpotlight(0.5) end

				if jumpsCounted >= requiredJumps then
					player:SetAttribute("TutorialStage", stageNumber + 1)
				end
			end
		end)
		table.insert(stageConnections, conn)

	elseif condition == "ButtonClick" then
		task.spawn(function()
			local attempts = 0
			while not foundButton and attempts < 10 do task.wait(0.2) attempts += 1 end
			local targetBtn = foundButton or (stageData.Spotlight.GuiPath and getGuiElement(stageData.Spotlight.GuiPath))

			if targetBtn and targetBtn:IsA("GuiObject") then
				local triggered = false
				local function triggerNextStage()
					if triggered then return end
					triggered = true
					player:SetAttribute("TutorialStage", stageNumber + 1)
				end

				if targetBtn:IsA("GuiButton") or targetBtn:IsA("ImageButton") or targetBtn:IsA("TextButton") then
					table.insert(stageConnections, targetBtn.Activated:Connect(triggerNextStage))
					table.insert(stageConnections, targetBtn.MouseButton1Click:Connect(triggerNextStage))
				else
					table.insert(stageConnections, targetBtn.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							triggerNextStage()
						end
					end))
				end
			end
		end)

	elseif condition == "Purchase" then
		local conn = player:GetAttributeChangedSignal("LastPurchase"):Connect(function()
			if player:GetAttribute("LastPurchase") == stageData.ConditionValue then
				player:SetAttribute("TutorialStage", stageNumber + 1)
			end
		end)
		table.insert(stageConnections, conn)

	elseif condition == "ShopClosed" or condition == "InventoryClosed" then
		local targetFrameName = condition == "ShopClosed" and "Shop" or "Inventory"
		local frame = playerGui:FindFirstChild(targetFrameName, true)

		if frame then
			local conn = frame:GetPropertyChangedSignal("Visible"):Connect(function()
				if not frame.Visible then
					task.wait(0.2)
					player:SetAttribute("TutorialStage", stageNumber + 1)
				end
			end)
			table.insert(stageConnections, conn)
			if not frame.Visible then task.wait(0.5) player:SetAttribute("TutorialStage", stageNumber + 1) end
		end

		local conn = OpenedFrames.FrameClosed.Event:Connect(function(fName)
			if fName == targetFrameName then
				task.wait(0.5)
				player:SetAttribute("TutorialStage", stageNumber + 1)
			end
		end)
		table.insert(stageConnections, conn)

	elseif condition == "EggPurchase" then
		print("[Tutorial] Waiting for egg hatch...")
		if player:GetAttribute("EggAnimationFinished") == true then
			player:SetAttribute("EggAnimationFinished", false)
		end

		local conn = player:GetAttributeChangedSignal("EggAnimationFinished"):Connect(function()
			if player:GetAttribute("EggAnimationFinished") == true then
				local lastEgg = player:GetAttribute("LastEggPurchase")
				local expectedEgg = stageData.ConditionValue

				print("[Tutorial] Egg Hatched! Got:", lastEgg, "Expected:", expectedEgg)

				local isMatch = (lastEgg == expectedEgg)

				if not isMatch then
					warn("[Tutorial] Egg name mismatch! proceeding anyway to avoid stuck state.")
					isMatch = true 
				end

				if isMatch then
					task.wait(0.5)
					player:SetAttribute("TutorialStage", stageNumber + 1)
				end
			end
		end)
		table.insert(stageConnections, conn)

	elseif condition == "PetEquipped" then
		local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))

		local function checkPetEquipped()
			local equippedPets = DataUtility.client.get("EquippedPets")
			if equippedPets then
				for _, petId in pairs(equippedPets) do
					if petId and petId ~= "" then
						return true
					end
				end
			end
			return false
		end

		if checkPetEquipped() then
			task.wait(0.5)
			player:SetAttribute("TutorialStage", stageNumber + 1)
		else
			local bindConn = DataUtility.client.bind("EquippedPets", function(val)
				if val then
					for _, petId in pairs(val) do
						if petId and petId ~= "" then
							task.wait(0.5)
							player:SetAttribute("TutorialStage", stageNumber + 1)
							return
						end
					end
				end
			end)
			table.insert(stageConnections, bindConn)
		end
	end
end

function Tutorial.startTutorial()
	print("[Tutorial] Starting tutorial...")

	local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
	local tutorialCompleted = DataUtility.client.get("TutorialCompleted")

	if tutorialCompleted then
		print("[Tutorial] Already completed, skipping...")
		return
	end

	tutorialGui.Enabled = true

	focusFrame.Size = UDim2.fromScale(0, 0)
	focusFrame.Position = UDim2.fromScale(0.5, 0.5)

	spotFrames.Top.Size = UDim2.fromScale(1, 1)
	spotFrames.Top.Position = UDim2.fromScale(0, 0)
	spotFrames.Bottom.Size = UDim2.fromScale(0, 0)
	spotFrames.Bottom.Position = UDim2.fromScale(0, 1)
	spotFrames.Left.Size = UDim2.fromScale(0, 0)
	spotFrames.Right.Size = UDim2.fromScale(0, 0)

	for _, frame in pairs(spotFrames) do
		frame.BackgroundTransparency = 0.6
	end
	focusFrame.BackgroundTransparency = 1

	if not focusFrame:FindFirstChildWhichIsA("UIStroke") then
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Thickness = 4
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = focusFrame
	end

	if not focusFrame:FindFirstChildWhichIsA("UICorner") then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = focusFrame
	end

	focusFrame.BackgroundTransparency = 1
	focusFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	focusFrame.ZIndex = 10
	focusFrame.Active = false 
	focusFrame.Selectable = false

	spotlightContainer.BackgroundTransparency = 1
	spotlightContainer.BorderSizePixel = 0
	spotlightContainer.AnchorPoint = Vector2.new(0, 0)
	spotlightContainer.Position = UDim2.fromScale(0, 0)
	spotlightContainer.Size = UDim2.fromScale(1, 1)
	spotlightContainer.ZIndex = 5

	for _, frame in pairs(spotFrames) do
		frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		frame.BackgroundTransparency = 0.6
		frame.BorderSizePixel = 0
		frame.ZIndex = 6
		frame.Active = false 
		frame.Selectable = false
	end

	textLabel.ZIndex = 15
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextWrapped = true
	textLabel.TextXAlignment = Enum.TextXAlignment.Center
	textLabel.TextYAlignment = Enum.TextYAlignment.Center
	textLabel.Font = Enum.Font.GothamBold

	if not textLabel:FindFirstChildWhichIsA("UIStroke") then
		local textStroke = Instance.new("UIStroke")
		textStroke.Color = Color3.fromRGB(0, 0, 0)
		textStroke.Thickness = 3
		textStroke.Parent = textLabel
	end

	local stroke = focusFrame:FindFirstChildWhichIsA("UIStroke")
	if stroke then
		stroke.Enabled = true
		stroke.Transparency = 0
	end

	player:SetAttribute("TutorialStage", 0)
	player:SetAttribute("Tutorial", true)
	player:SetAttribute("Jumps", 0) 

	executeStage(0)
end

function Tutorial.finishTutorial()
	print("[Tutorial] Finishing tutorial...")

	disconnectStageConnections()
	destroyBeam()

	for _, frame in pairs(spotFrames) do
		TweenService:Create(frame, TweenInfo.new(1), {BackgroundTransparency = 1}):Play()
	end

	TweenService:Create(textLabel, TweenInfo.new(1), {TextTransparency = 1}):Play()
	local textStroke = textLabel:FindFirstChildWhichIsA("UIStroke")
	if textStroke then
		TweenService:Create(textStroke, TweenInfo.new(1), {Transparency = 1}):Play()
	end

	local focusStroke = focusFrame:FindFirstChildWhichIsA("UIStroke")
	if focusStroke then
		focusStroke.Enabled = false
	end

	task.wait(1)
	tutorialGui.Enabled = false

	player:SetAttribute("Tutorial", nil)
	player:SetAttribute("TutorialStage", nil)

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets then
		local remotes = assets:FindFirstChild("Remotes")
		if remotes then
			local finishEvent = remotes:FindFirstChild("FinishTutorial")
			if finishEvent then
				finishEvent:FireServer()
				print("[Tutorial] Finish event sent to server")
			end
		end
	end
end

------------------//INIT
player:GetAttributeChangedSignal("TutorialStage"):Connect(function()
	if not player:GetAttribute("Tutorial") then return end

	local newStage = player:GetAttribute("TutorialStage")
	if newStage and newStage > currentStage then
		print("[Tutorial] Stage changed:", currentStage, "→", newStage)
		currentStage = newStage
		executeStage(currentStage)
	end
end)

task.spawn(function()
	if not player.Character then player.CharacterAdded:Wait() end

	local tutorialCompleted = DataUtility.client.get("TutorialCompleted")

	if tutorialCompleted then
		return
	end

	if not player.Name:find("2") then
		return
	end

	Tutorial.startTutorial()
end)

return Tutorial