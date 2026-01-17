local UIController = {}

local AvatarEditorService = game:GetService("AvatarEditorService")
local ContentProvider = game:GetService("ContentProvider")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")

local Essentials = require(ReplicatedStorage.KiwiBird.Essentials)
local CameraController = require(script.Parent.CameraController)
local QueueController = require(script.Parent.QueueController)
local PongItemsConfig = require(ReplicatedStorage.Arrays.PongItemsConfig)
-- local PongController = require(script.Parent.PongController)

local BuyablesServiceEvent = ReplicatedStorage.Remotes.Events.BuyablesService

local animConnection = nil

local sounds = ReplicatedStorage.Assets.Sounds

local plr = Players.LocalPlayer

local stocksMenuOpened = false

local launchLock = false



local function Fade(guiProp, enabled, callback)
	local tweens = {}
	local completedCount = 0

	local function onTweenCompleted()
		completedCount += 1
		if completedCount == #tweens and not enabled then
			guiProp.Visible = false
			if callback then
				callback()
			end
		end
	end

	guiProp.Visible = true

	for _, descendant in ipairs(guiProp:GetDescendants()) do
		if descendant:GetAttribute("Fadeable") then
			local props = {}
			if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
				props.TextTransparency = enabled and 0 or 1
			elseif descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
				props.ImageTransparency = enabled and 0 or 1
			elseif descendant:IsA("Frame") then
				props.BackgroundTransparency = enabled and 0 or 1
			elseif descendant:IsA("UIStroke") then
				props.Transparency = enabled and 0 or 1
			end

			if next(props) then
				local tween = TweenService:Create(descendant, TweenInfo.new(enabled and 0.3 or 0.3), props)
				tween.Completed:Connect(onTweenCompleted)
				tween:Play()
				table.insert(tweens, tween)
			end
		end
	end

	if #tweens == 0 and not enabled and callback then
		guiProp.Visible = false
		callback()
	end
end

local a = 1

function UIController.Animation(folder, stop)
	if not stop then
		if animConnection then
			animConnection:Disconnect() -- stop old animation
		end
		a = 1
		animConnection = RunService.Heartbeat:Connect(function(dt)
			if tick() % 0.1 < dt then
				a += 1
				if not folder:FindFirstChild(tostring(a)) then
					a = 1
				end
				for _, v in folder:GetChildren() do
					v.Visible = false
				end
				folder:FindFirstChild(tostring(a)).Visible = true
			end
		end)
	else
		if animConnection then
			animConnection:Disconnect()
			animConnection = nil
		end
		for _, v in folder:GetChildren() do
			v.Visible = false
		end
		if folder:FindFirstChild("1") then
			folder["1"].Visible = true
		end
	end
end

local notifCount = 0
local lastPressTime = 0

function UIController.showNotification(msg: string, color)
	local notifGUI = plr.PlayerGui.Notifications
	local notification = notifGUI.Notification

	notifGUI.Enabled = true
	notification.Visible = false
	local currentTime = tick()
	-- reset counter
	if currentTime - lastPressTime > 1 then
		notifCount = 0
	end

	lastPressTime = currentTime
	notifCount += 1
	local displayMsg = "(x" .. tostring(notifCount) .. ") " .. msg

	local notif = notification:Clone()
	notif.Parent = notifGUI
	notif.Text = displayMsg
	notif.Visible = true

	if color then
		notif.TextColor3 = color
		notif.UIStroke.Color = Color3.fromRGB(0, 0, 0)
	end

	task.spawn(function()
		task.wait(0.2)
		notif:TweenPosition(UDim2.fromScale(0.5, 0.8), "Out", "Sine", 1)
		task.wait(0.5)
		for i = 0, 1, 0.05 do
			notif.TextTransparency = i
			notif.UIStroke.Transparency = i
			task.wait(0.01)
		end
		notif.Visible = false
		notif:Destroy()
	end)
end

function UIController.buttonInteraction(button)
	local gui = plr.PlayerGui:WaitForChild("MainGameUi")

	if button then
		local v = button

		local originalSize = v.Size
		local isHovering = false
		local targetSize = originalSize
		local currentVelocity = { x = 0, y = 0 }
		local currentSize = {
			x = originalSize.X.Scale,
			y = originalSize.Y.Scale,
		}

		local hoverSize = UDim2.new(
			originalSize.X.Scale * 1.05,
			originalSize.X.Offset,
			originalSize.Y.Scale * 1.05,
			originalSize.Y.Offset
		)
		local clickSize = UDim2.new(
			originalSize.X.Scale * 0.9,
			originalSize.X.Offset,
			originalSize.Y.Scale * 0.9,
			originalSize.Y.Offset
		)

		-- Spring physics for BOUNCY effect like a rock in water
		local stiffness = 400 -- How fast it tries to reach target
		local damping = 10 -- Very low = lots of bounces!

		local connection
		connection = RunService.RenderStepped:Connect(function(dt)
			-- CLAMP dt to prevent lag spike issues
			dt = math.min(dt, 0.1)

			-- Calculate distance to target
			local offsetX = targetSize.X.Scale - currentSize.x
			local offsetY = targetSize.Y.Scale - currentSize.y

			-- Spring force (pulls toward target)
			local forceX = offsetX * stiffness
			local forceY = offsetY * stiffness

			-- Damping force (slows down velocity)
			local dampingX = currentVelocity.x * damping
			local dampingY = currentVelocity.y * damping

			-- Update velocity with spring physics
			currentVelocity.x = currentVelocity.x + (forceX - dampingX) * dt
			currentVelocity.y = currentVelocity.y + (forceY - dampingY) * dt

			-- Update position based on velocity
			currentSize.x = currentSize.x + currentVelocity.x * dt
			currentSize.y = currentSize.y + currentVelocity.y * dt

			-- Apply to button
			v.Size = UDim2.new(currentSize.x, originalSize.X.Offset, currentSize.y, originalSize.Y.Offset)

			-- Stop when settled
			local distance = math.sqrt(offsetX ^ 2 + offsetY ^ 2)
			local speed = math.sqrt(currentVelocity.x ^ 2 + currentVelocity.y ^ 2)
			if distance < 0.001 and speed < 0.01 then
				currentSize.x = targetSize.X.Scale
				currentSize.y = targetSize.Y.Scale
				v.Size = targetSize
				currentVelocity.x = 0
				currentVelocity.y = 0
			end
		end)

		v.MouseEnter:Connect(function()
			isHovering = true
			sounds.InGameSounds.UISounds.ButtonHover:Play()
			targetSize = hoverSize
		end)

		v.MouseLeave:Connect(function()
			isHovering = false
			targetSize = originalSize
		end)

		v.MouseButton1Down:Connect(function()
			sounds.InGameSounds.UISounds.ButtonClick:Play()
			targetSize = clickSize
		end)

		v.MouseButton1Up:Connect(function()
			targetSize = originalSize
		end)
	else
		for _, v in pairs(gui:GetDescendants()) do
			if v:IsA("ImageButton") or v:IsA("TextButton") then
				local originalSize = v.Size
				local isHovering = false
				local targetSize = originalSize
				local currentVelocity = { x = 0, y = 0 }
				local currentSize = {
					x = originalSize.X.Scale,
					y = originalSize.Y.Scale,
				}

				local hoverSize = UDim2.new(
					originalSize.X.Scale * 1.05,
					originalSize.X.Offset,
					originalSize.Y.Scale * 1.05,
					originalSize.Y.Offset
				)
				local clickSize = UDim2.new(
					originalSize.X.Scale * 0.9,
					originalSize.X.Offset,
					originalSize.Y.Scale * 0.9,
					originalSize.Y.Offset
				)

				-- Spring physics for BOUNCY effect like a rock in water
				local stiffness = 400 -- How fast it tries to reach target
				local damping = 10 -- Very low = lots of bounces!

				local connection
				connection = RunService.RenderStepped:Connect(function(dt)
					-- CLAMP dt to prevent lag spike issues
					dt = math.min(dt, 0.1)

					-- Calculate distance to target
					local offsetX = targetSize.X.Scale - currentSize.x
					local offsetY = targetSize.Y.Scale - currentSize.y

					-- Spring force (pulls toward target)
					local forceX = offsetX * stiffness
					local forceY = offsetY * stiffness

					-- Damping force (slows down velocity)
					local dampingX = currentVelocity.x * damping
					local dampingY = currentVelocity.y * damping

					-- Update velocity with spring physics
					currentVelocity.x = currentVelocity.x + (forceX - dampingX) * dt
					currentVelocity.y = currentVelocity.y + (forceY - dampingY) * dt

					-- Update position based on velocity
					currentSize.x = currentSize.x + currentVelocity.x * dt
					currentSize.y = currentSize.y + currentVelocity.y * dt

					-- Apply to button
					v.Size = UDim2.new(currentSize.x, originalSize.X.Offset, currentSize.y, originalSize.Y.Offset)

					-- Stop when settled
					local distance = math.sqrt(offsetX ^ 2 + offsetY ^ 2)
					local speed = math.sqrt(currentVelocity.x ^ 2 + currentVelocity.y ^ 2)
					if distance < 0.001 and speed < 0.01 then
						currentSize.x = targetSize.X.Scale
						currentSize.y = targetSize.Y.Scale
						v.Size = targetSize
						currentVelocity.x = 0
						currentVelocity.y = 0
					end
				end)

				v.MouseEnter:Connect(function()
					isHovering = true
					sounds.InGameSounds.UISounds.ButtonHover:Play()
					targetSize = hoverSize
				end)

				v.MouseLeave:Connect(function()
					isHovering = false
					targetSize = originalSize
				end)

				v.MouseButton1Down:Connect(function()
					sounds.InGameSounds.UISounds.ButtonClick:Play()
					targetSize = clickSize
				end)

				v.MouseButton1Up:Connect(function()
					targetSize = originalSize
				end)
			end
		end
	end
end

function UIController.MenuCameraEffect(enabled)
	local camera = workspace.CurrentCamera

	local fade = plr.PlayerGui.MainGameUi.Fade

	local dof = lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if not dof then
		dof = Instance.new("DepthOfFieldEffect")
		dof.Parent = lighting
	end

	if enabled then
		local cameraTween = TweenService:Create(
			camera,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ FieldOfView = 85 }
		)
		cameraTween:Play()

		local fadeTween = TweenService:Create(
			fade,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ ImageTransparency = 0.65 }
		)

		fadeTween:Play()

		dof.Enabled = true
		local dofTween = TweenService:Create(dof, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FocusDistance = 0,
			InFocusRadius = 0,
			NearIntensity = 1,
			FarIntensity = 1,
		})
		dofTween:Play()
	else
		local cameraTween = TweenService:Create(
			camera,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ FieldOfView = 70 }
		)
		cameraTween:Play()

		local fadeTween = TweenService:Create(
			fade,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ ImageTransparency = 1 }
		)

		fadeTween:Play()

		local dofTween = TweenService:Create(dof, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FocusDistance = 0.05,
			InFocusRadius = 30,
			NearIntensity = 0,
			FarIntensity = 0,
		})
		dofTween:Play()

		dofTween.Completed:Connect(function()
			dof.Enabled = false
		end)
	end
end

local currentOpenMenu = nil
local menuAnimationConnection = nil

function UIController.MenuOpenClose(Frame)
	-- Disconnect any existing animation to prevent interference
	if menuAnimationConnection then
		menuAnimationConnection:Disconnect()
		menuAnimationConnection = nil
	end

	-- If trying to open a menu while another is open, close the previous one first
	if currentOpenMenu and currentOpenMenu ~= Frame and currentOpenMenu.Visible then
		-- Reset size to original before closing
		local originalSize = currentOpenMenu:GetAttribute("OriginalSize")
		if originalSize then
			currentOpenMenu.Size = originalSize
		end
		currentOpenMenu.Visible = false
		UIController.MenuCameraEffect(false)
		ReplicatedStorage.Assets.Sounds.InGameSounds.UISounds.close:Play()
		currentOpenMenu = nil
		task.wait(0.1) -- Small delay for smoother transition
	end

	if Frame.Visible then
		-- Reset size to original before closing
		local originalSize = Frame:GetAttribute("OriginalSize")
		if originalSize then
			Frame.Size = originalSize
		end
		Frame.Visible = false
		ReplicatedStorage.Assets.Sounds.InGameSounds.UISounds.close:Play()
		UIController.MenuCameraEffect(false)
		currentOpenMenu = nil
		return
	end

	-- Store original size as attribute if not already stored
	if not Frame:GetAttribute("OriginalSize") then
		Frame:SetAttribute("OriginalSize", Frame.Size)
	end

	local originalSize = Frame:GetAttribute("OriginalSize")

	Frame.Visible = true
	currentOpenMenu = Frame
	ReplicatedStorage.Assets.Sounds.InGameSounds.UISounds.open:Play()
	UIController.MenuCameraEffect(true)

	local currentVelocity = { x = 0, y = 0 }
	local currentSize = {
		x = 0,
		y = 0,
	}

	Frame.Size = UDim2.fromScale(0, 0)

	local targetSize = originalSize

	local stiffness = 400
	local damping = 15

	menuAnimationConnection = RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 0.1)

		local offsetX = targetSize.X.Scale - currentSize.x
		local offsetY = targetSize.Y.Scale - currentSize.y

		local forceX = offsetX * stiffness
		local forceY = offsetY * stiffness

		local dampingX = currentVelocity.x * damping
		local dampingY = currentVelocity.y * damping

		currentVelocity.x = currentVelocity.x + (forceX - dampingX) * dt
		currentVelocity.y = currentVelocity.y + (forceY - dampingY) * dt

		currentSize.x = currentSize.x + currentVelocity.x * dt
		currentSize.y = currentSize.y + currentVelocity.y * dt

		-- Clamp size to prevent overshooting beyond reasonable bounds
		currentSize.x = math.max(0, math.min(currentSize.x, targetSize.X.Scale * 1.5))
		currentSize.y = math.max(0, math.min(currentSize.y, targetSize.Y.Scale * 1.5))

		Frame.Size = UDim2.new(currentSize.x, originalSize.X.Offset, currentSize.y, originalSize.Y.Offset)

		local distance = math.sqrt(offsetX ^ 2 + offsetY ^ 2)
		local speed = math.sqrt(currentVelocity.x ^ 2 + currentVelocity.y ^ 2)
		if distance < 0.001 and speed < 0.01 then
			currentSize.x = targetSize.X.Scale
			currentSize.y = targetSize.Y.Scale
			Frame.Size = targetSize
			menuAnimationConnection:Disconnect()
			menuAnimationConnection = nil
		end
	end)
end

function UIController.shopMenu()
	local gui = plr.PlayerGui.MainGameUi
	local LeftContainer = gui.LeftButtons
	local shopContainer = gui.RobuxShopFrame

	LeftContainer.Shop.MouseButton1Click:Connect(function()
		UIController.MenuOpenClose(shopContainer)
	end)

	shopContainer.X.MouseButton1Click:Connect(function()
		UIController.MenuOpenClose(shopContainer)
	end)

	for _, v in pairs(shopContainer:GetDescendants()) do
		if v.Name == "buyables" then
			local function GetPrice(assetId: number)
				local asset = MarketplaceService:GetProductInfo(assetId, Enum.InfoType.Product)

				return asset.PriceInRobux
			end

			local RobuxPrice = GetPrice(v:GetAttribute("ID"))

			-- v.TextButton.Text = RobuxPrice .. " R$"

			v.MouseButton1Click:Connect(function()
				-- print(v:GetAttribute("ID"))

				if v.Parent.Name == "PotLuck" then
					if plr.PlayerStats.PotLuckMultiplier.Value > 1 then
						UIController.showNotification("Already Owned!")
						return
					end
				end

				if v.Parent.Name == "VIP" then
					if plr.PlayerStats.Vip.Value == true then
						UIController.showNotification("Already Owned!")
						return
					end
				end

				if v.Parent.Name == "StarterPack" then
					if plr.PlayerStats.StarterPack.Value == true then
						UIController.showNotification("Already Owned!")
						return
					end
				end
				
				if v.Parent.Name == "Streak" then
					if plr.PlayerStats.DoubleStreak.Value == true then
						UIController.showNotification("Already Owned!")
						return
					end
				end
				
				if v.Parent.Name == "Wins" then
					if plr.PlayerStats.DoubleWins.Value == true then
						UIController.showNotification("Already Owned!")
						return
					end
				end
				
				local productId = v:GetAttribute("ID")
				MarketplaceService:PromptProductPurchase(plr, productId)

				local purchaseConnection
				purchaseConnection = MarketplaceService.PromptProductPurchaseFinished:Connect(
					function(userId, purchasedProductId, isPurchased)
						if userId == plr.UserId and purchasedProductId == productId then
							purchaseConnection:Disconnect()
							if isPurchased then
								Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.buy, plr.Character, 1)

								UIController.MenuOpenClose(shopContainer)

								UIController.showNotification("Bought " .. v.Parent.Name .. "!")
							end
						end
					end
				)
			end)
		end
	end
end

function UIController.Shockwave(uiElement)
	if not uiElement then
		warn("Shockwave: No UI element provided")
		return
	end

	local gui = plr.PlayerGui:WaitForChild("MainGameUi")

	-- Get the absolute position and size of the UI element
	local absPos = uiElement.AbsolutePosition
	local absSize = uiElement.AbsoluteSize

	-- Calculate center point
	local centerX = absPos.X + (absSize.X / 2)
	local centerY = absPos.Y + (absSize.Y / 2)

	-- Create the shockwave ImageLabel
	local shockwave = Instance.new("ImageLabel")
	shockwave.Name = "Shockwave"
	shockwave.AnchorPoint = Vector2.new(0.5, 0.5)
	shockwave.Position = UDim2.fromOffset(centerX, centerY)
	shockwave.Size = UDim2.fromOffset(0, 0)
	shockwave.BackgroundTransparency = 1
	shockwave.Image = "rbxassetid://2916153928" -- Replace with your shockwave image
	shockwave.ImageTransparency = 0
	shockwave.ZIndex = 1000
	shockwave.Parent = gui

	-- Animate the shockwave
	local maxSize = 500
	local duration = 0.8
	local duration2 = 1.5

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tweenInfo2 = TweenInfo.new(duration2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	-- Tween size and transparency
	local tween = TweenService:Create(shockwave, tweenInfo, {
		Size = UDim2.fromOffset(maxSize, maxSize),
		ImageTransparency = 1,
	})

	local tween2 = TweenService:Create(shockwave, tweenInfo2, {
		ImageTransparency = 1,
	})

	tween:Play()
	tween2:Play()

	tween2.Completed:Connect(function()
		shockwave:Destroy()
	end)
end

local hasFavorited = false

function UIController.ChangeLook()
	local GetDataRemote = game.ReplicatedStorage.Remotes.Functions.GetData
	local playerData = GetDataRemote:InvokeServer()

	print(playerData)

	for _, v in workspace.Buyables.Cups:GetDescendants() do
		if v:IsA("BillboardGui") and v.Name == "OwnedText" then
			print(v.Parent.Name)
			if table.find(playerData["CupsInventory"], v.Parent.Name) then
				print("??")

				if v.Parent.Name == playerData["EquippedCups"] then
					v.TextLabel.Text = "Unequip"
				else
					v.TextLabel.Text = "Equip"
				end
			end
		elseif v:IsA("ProximityPrompt") then
			local parent = v.Parent.Parent

			if table.find(playerData["CupsInventory"], parent.Name) then
				if parent.Name == playerData["EquippedCups"] then
					v.ActionText = "Unequip"
				else
					v.ActionText = "Equip"
				end
			end
		end
	end

	for _, v in workspace.Buyables.Balls:GetDescendants() do
		if v:IsA("BillboardGui") and v.Name == "OwnedText" then
			if table.find(playerData["BallsInventory"], v.Parent.Name) then
				if v.Parent.Name == playerData["EquippedBalls"] then
					v.TextLabel.Text = "Unequip"
				else
					v.TextLabel.Text = "Equip"
				end
			end
		elseif v:IsA("ProximityPrompt") then
			local parent = v.Parent.Parent

			if table.find(playerData["BallsInventory"], parent.Name) then
				if parent.Name == playerData["EquippedBalls"] then
					v.ActionText = "Unequip"
				else
					v.ActionText = "Equip"
				end
			end
		end
	end
end

function UIController.PreloadUIAssets()
	local gui = plr.PlayerGui:WaitForChild("MainGameUi")
	local assetsToPreload = {}

	-- Collect all image assets from the UI
	for _, descendant in pairs(gui:GetDescendants()) do
		if descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
			if descendant.Image ~= "" then
				table.insert(assetsToPreload, descendant.Image)
			end
		elseif descendant:IsA("Decal") then
			if descendant.Texture ~= "" then
				table.insert(assetsToPreload, descendant.Texture)
			end
		end
	end

	-- Preload all collected assets
	if #assetsToPreload > 0 then
		ContentProvider:PreloadAsync(assetsToPreload)
		print("Preloaded " .. #assetsToPreload .. " UI assets")
	end
end

function UIController.MoneyMultiplierUpgrade()
	local guiButton = plr.PlayerGui:WaitForChild("MainGameUi").MMContainer.SpeedBTN

	local id = 3458728466
	local current = 0 

	local function update()
		local value = plr:WaitForChild("PlayerStats"):WaitForChild("MoneyUpgradeMultiplier").Value
		if value == current then return end
		current = value
		
		guiButton.Visible = true
		if value == 1 then
			guiButton.Title.Text = "x3 COINS"
			UIController.showNotification("Upgraded from I > II")
			id = 3463557320
		elseif value == 2 then
			guiButton.Title.Text = "x4 COINS"
			UIController.showNotification("Upgraded from II > III")
			id = 3463557319
		elseif value == 3 then
			guiButton.Title.Text = "x5 COINS"
			UIController.showNotification("Upgraded from III > IV")
			id = 3463557316
		elseif value == 4 then
			--guiButton.Title.Text = "x5 COINS"
			UIController.showNotification("Upgraded from IV > V")
			guiButton.Visible = false
		else
			guiButton.Visible = false
		end

		if id then
			local info = MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Product)
			if info and info.PriceInRobux then
				guiButton.TextLabel.Text = `ONLY {utf8.char(0xE002)}{info.PriceInRobux}`
			end
		end
	end
	
	if id then
		local info = MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Product)
		if info and info.PriceInRobux then
			guiButton.TextLabel.Text = `ONLY {utf8.char(0xE002)}{info.PriceInRobux}`
		end
	end

	guiButton.MouseButton1Click:Connect(function()
		if plr.PlayerStats.MoneyUpgradeMultiplier.Value == 5 then
			UIController.showNotification("Already Reached Max Upgrade!")
		else
			MarketplaceService:PromptProductPurchase(plr, id)
		end
	end)
	
	update()
	plr:WaitForChild("PlayerStats"):WaitForChild("MoneyUpgradeMultiplier"):GetPropertyChangedSignal("Value"):Connect(update)
	-- Listen for when the purchase is completed
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
		if userId == plr.UserId and productId == id then
			if isPurchased then
			
				Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.buy, plr.Character, 1)
				update()
				-- You can add additional UI feedback here, like:
				-- UIController.showNotification("Money Multiplier activated!")
			else
				print("Money Multiplier purchase was cancelled or failed")
			end
		end
	end)
end

local function isTaken(seat: BasePart)
	local v = seat:GetAttribute("taken")
	return v ~= nil and v ~= ""
end

local Forbidden = {"QueueTable12", "QueueTable13", "QueueTable14", "QueueTable15"}
local function isForbidden(name: string)
	for _, forbiddenName in ipairs(Forbidden) do
		if forbiddenName == name then
			return true
		end
	end
	return false
end

function UIController.PressedEvent()
	local SocialService = game:GetService("SocialService")
	local Players = game:GetService("Players")
	local Player = Players.LocalPlayer
	
	local UI = Player.PlayerGui.MainGameUi.MMContainer.Event
	local Going = false
	
	if SocialService:GetEventRsvpStatusAsync("1310104350386553411") == Enum.RsvpStatus.Going then 
		Going = true
		return 
	end
	
	UI.Activated:Connect(function()
		if Going then return end
		
		SocialService:PromptRsvpToEventAsync("1310104350386553411")
		
		if SocialService:GetEventRsvpStatusAsync("1310104350386553411") == Enum.RsvpStatus.Going then 
			Going = true
			return 
		end
	end)
end

function UIController.ChristmasEventUI()
	local Players = game:GetService("Players")
	local Player = Players.LocalPlayer

	local UI = Player.PlayerGui:WaitForChild("MainGameUi"):WaitForChild("ChristmasFrame")
	local remote = ReplicatedStorage.Remotes.Events.ChristmasQuest

	local function Load()
		local PlayerData = ReplicatedStorage.Remotes.Functions.GetData:InvokeServer()
		local ChristmasTable = require(ReplicatedStorage.Arrays.ChristmasEventTable)
		local ScrollingFrame = UI.ScrollingFrame
		local Temp = ReplicatedStorage.Assets.UI.Task

		for i, v in ScrollingFrame:GetChildren() do
			if v:IsA("Frame") then
				v:Destroy()
			end
		end

		for i, v in ipairs(ChristmasTable) do
			local clone = Temp:Clone()
			local ProgressBarPer1 = 1 / v.AmountRequired

			local AmountStat
			if PlayerData.ChristmasWins >= v.AmountRequired then
				AmountStat = v.AmountRequired
			else
				AmountStat = PlayerData.ChristmasWins
			end

			clone.Name = "Task" .. i
			clone.Title.Text = `Quest #{i}`
			clone.Desc.Text = v.Desc
			clone.Progress.Text.Text = `{AmountStat}/{v.AmountRequired}`
			clone.Progress.Bar.Size = UDim2.new(ProgressBarPer1 * AmountStat, 0, 1, 0)
			
			clone.Reward.Icon.Image = v.RewardIcon
			clone.Reward.Title.Text = v.RewardName
			
			if PlayerData.ChristmasTasks[i] == true then
				clone.Skip.Visible = false
				clone.Claim.Visible = true
				clone.Claim.Title.Text = "Claimed"
				clone.Claim.Active = false
				clone.Progress.Bar.Size = UDim2.new(1, 0, 1, 0)
				clone.Progress.Text.Text = `{v.AmountRequired}/{v.AmountRequired}`
			elseif not PlayerData.ChristmasTasks[i] and PlayerData.ChristmasWins >= v.AmountRequired then
				clone.Skip.Visible = false
				clone.Claim.Visible = true
				clone.Claim.Activated:Connect(function()
					remote:FireServer(i)
				end)
			else
				clone.Skip.Visible = true
				clone.Claim.Visible = false
				clone.Skip.Activated:Connect(function()
					MarketplaceService:PromptProductPurchase(plr, v.ProductID)
				end)
			end
			
			clone.Parent = ScrollingFrame
		end
	end

	remote.OnClientEvent:Connect(function(method)
		if not UI.Visible then
			Load()
			UIController.MenuOpenClose(UI)
		end
		
		if method == "Load" then
			Load()
		end
	end)

	Load()

	UI.X.Activated:Connect(function()
		UIController.MenuOpenClose(UI)
	end)
end

function UIController.PressedPlay()
	local QueueController = require(script.Parent.QueueController)
	local queueTables = workspace.QueueTables

	local chosenSeat: BasePart? = nil

	for _, tableModel in ipairs(queueTables:GetChildren()) do
		if not isForbidden(tableModel.Name) then
			local seat1 = tableModel["1"] :: BasePart
			local seat2 = tableModel["2"] :: BasePart

			local s1 = isTaken(seat1)
			local s2 = isTaken(seat2)

			if s1 and not s2 then
				chosenSeat = seat2
				break
			elseif s2 and not s1 then
				chosenSeat = seat1
				break
			end
		end
	end

	if not chosenSeat then
		for _, tableModel in ipairs(queueTables:GetChildren()) do
			if not isForbidden(tableModel.Name) then
				local seat1 = tableModel["1"] :: BasePart
				local seat2 = tableModel["2"] :: BasePart

				if (not isTaken(seat1)) and (not isTaken(seat2)) then
					chosenSeat = seat1
					break
				end
			end
		end
	end

	if chosenSeat then
		QueueController.Enter(chosenSeat)
	else
		warn("No available seats found")
	end
end


function UIController.BottomLeftListener()
	local gui = plr.PlayerGui:WaitForChild("MainGameUi").BottomLeftContainer
	local TweenService = game:GetService("TweenService")
	local Players = game:GetService("Players")
	local QueueController = require(script.Parent.QueueController)

	-- Counter animation for coins
	local currentDisplayedCoins = plr:WaitForChild("leaderstats").Coins.Value
	local targetCoins = currentDisplayedCoins
	local isCounting = false

	local function updateCoinDisplay()
		if isCounting then
			return
		end
		isCounting = true

		local difference = targetCoins - currentDisplayedCoins
		local duration = math.min(math.abs(difference) / 1000, 1.5) -- Max 1 second animation
		local startTime = tick()
		local startValue = currentDisplayedCoins

		while tick() - startTime < duration do
			local alpha = (tick() - startTime) / duration
			currentDisplayedCoins = math.floor(startValue + (difference * alpha))
			plr.PlayerGui.MainGameUi.LeftButtons.Coin.Title.Text = "$" .. currentDisplayedCoins
			Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.tick, workspace, 1)
			task.wait()
		end

		currentDisplayedCoins = targetCoins
		plr.PlayerGui.MainGameUi.LeftButtons.Coin.Title.Text = "$" .. currentDisplayedCoins
		isCounting = false
	end

	plr:WaitForChild("leaderstats").Coins.Changed:Connect(function()
		targetCoins = plr.leaderstats.Coins.Value
		updateCoinDisplay()
	end)

	-- Initialize coin display
	plr.PlayerGui.MainGameUi.LeftButtons.Coin.Title.Text = "$" .. plr.leaderstats.Coins.Value

	-- Friend boost system
	local function countFriendsInServer()
		local friendCount = 0
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= plr and plr:IsFriendsWith(player.UserId) then
				friendCount = friendCount + 1
			end
		end
		return friendCount
	end

	local function updateFriendBoost()
		local friendsOnline = countFriendsInServer()
		local friendBoost = friendsOnline * 0.1 -- 10% per friend

		-- Update multiplier display
		local baseMultiplier = plr.PlayerStats.Multiplier.Value + plr.PlayerStats.MoneyUpgradeMultiplier.Value
		local totalMultiplier = baseMultiplier

		local LuckMultiplier = plr.PlayerStats.PotLuckMultiplier.Value + plr.PlayerStats.Stakes.Value

		gui.CurrentMultiplier.TextLabel.Text = "Coin Multiplier: " .. totalMultiplier .. "x"

		gui.PotLuckMultiplier.TextLabel.Text = "Pot Luck Multiplier: " .. LuckMultiplier .. "x"

		plr.PlayerGui.MainGameUi.LeftButtons.Win.Title.Text = plr.leaderstats.Wins.Value

		UIController.ChangeLook()

		-- Optional: Show friend boost separately if you have a GUI element for it
		if gui:FindFirstChild("FriendBoost") then
			gui.FriendBoost.TextLabel.Text = string.format("+%.0f%% Friend Boost", friendBoost * 100)
		end

		if plr.leaderstats.Wins.Value >= 10 then
			workspace.lock.SurfaceGui.Frame.Visible = false
		end
	end

	plr.PlayerGui.MainGameUi.LeftButtons.Coin["+"].MouseButton1Click:Connect(function()
		UIController.MenuOpenClose(plr.PlayerGui.MainGameUi.RobuxShopFrame)
	end)
	
	plr.PlayerGui.MainGameUi.TopButtons.Play.Activated:Connect(function()
		UIController.PressedPlay()
	end)
	
	-- Listen for multiplier changes
	plr:WaitForChild("PlayerStats").MoneyUpgradeMultiplier.Changed:Connect(updateFriendBoost)
	plr:WaitForChild("PlayerStats").Multiplier.Changed:Connect(updateFriendBoost)
	plr:WaitForChild("PlayerStats").PotLuckMultiplier.Changed:Connect(updateFriendBoost)
	plr:WaitForChild("leaderstats").Wins.Changed:Connect(updateFriendBoost)

	-- Listen for players joining/leaving to update friend boost
	Players.PlayerAdded:Connect(function(player)
		task.wait(0.1) -- Small delay to ensure friendship data loads
		if plr:IsFriendsWith(player.UserId) then
			updateFriendBoost()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		if plr:IsFriendsWith(player.UserId) then
			updateFriendBoost()
		end
	end)

	-- Initial friend boost calculation
	updateFriendBoost()
end

function UIController.WinMenu()
	local gui = plr.PlayerGui:WaitForChild("MainGameUi").WinScreen

	gui.X.MouseButton1Click:Connect(function()
		UIController.MenuOpenClose(gui)
	end)
	gui.double.MouseButton1Click:Connect(function()
		MarketplaceService:PromptProductPurchase(plr, 3459557640)

		local purchaseConnection
		purchaseConnection = MarketplaceService.PromptProductPurchaseFinished:Connect(
			function(userId, purchasedProductId, isPurchased)
				if userId == plr.UserId and purchasedProductId == 3459557640 then
					purchaseConnection:Disconnect()
					if isPurchased then
						Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.buy, plr.Character, 1)

						UIController.showNotification("2x Money!")

						UIController.MenuOpenClose(gui)
					end
				end
			end
		)
	end)
end

function UIController.LoseMenu()
	local gui = plr.PlayerGui:WaitForChild("MainGameUi").LoseScreen

	gui.X.MouseButton1Click:Connect(function()
		UIController.MenuOpenClose(gui)
	end)
	gui.Restore.MouseButton1Click:Connect(function()
		MarketplaceService:PromptProductPurchase(plr, 3459557641)

		local purchaseConnection
		purchaseConnection = MarketplaceService.PromptProductPurchaseFinished:Connect(
			function(userId, purchasedProductId, isPurchased)
				if userId == plr.UserId and purchasedProductId == 3459557641 then
					purchaseConnection:Disconnect()
					if isPurchased then
						Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.buy, plr.Character, 1)
						UIController.showNotification("Streak reverted!")

						UIController.MenuOpenClose(gui)
					end
				end
			end
		)
	end)
end

function UIController.InkButton()
	local inkButton = plr.PlayerGui:WaitForChild("MainGameUi").Ink

	inkButton.MouseButton1Click:Connect(function()
		MarketplaceService:PromptProductPurchase(plr, 3461644699)

		local purchaseConnection
		purchaseConnection = MarketplaceService.PromptProductPurchaseFinished:Connect(
			function(userId, purchasedProductId, isPurchased)
				if userId == plr.UserId and purchasedProductId == 3461644699 then
					purchaseConnection:Disconnect()
					if isPurchased then
						inkButton.Visible = false
						Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.buy, plr.Character, 1)
					end
				end
			end
		)
	end)
end

function UIController.PlusCupButton()
	local PlusCup = plr.PlayerGui:WaitForChild("MainGameUi").PlusCup

	PlusCup.MouseButton1Click:Connect(function()
		MarketplaceService:PromptProductPurchase(plr, 3466651970)

		local purchaseConnection
		purchaseConnection = MarketplaceService.PromptProductPurchaseFinished:Connect(
			function(userId, purchasedProductId, isPurchased)
				if userId == plr.UserId and purchasedProductId == 3466651970 then
					purchaseConnection:Disconnect()
					if isPurchased then
						PlusCup.Visible = false
						Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.buy, plr.Character, 1)
					end
				end
			end
		)
	end)
end

function UIController.LikeReward()
	local menu = plr.PlayerGui:WaitForChild("MainGameUi"):WaitForChild("LikeReward")
	local close = menu.LikeRewardFrame.X
	local remote = ReplicatedStorage.Remotes.Events.LikeReward

	local GetDataRemote = game.ReplicatedStorage.Remotes.Functions.GetData
	local playerData = GetDataRemote:InvokeServer()

	if playerData.ClaimedLikeReward then
		local likeRewardModel = workspace:FindFirstChild("LikeReward")
		if likeRewardModel then
			likeRewardModel:Destroy()
		end
		if menu.Visible then
			UIController.MenuOpenClose(menu)
		end
	end

	close.MouseButton1Click:Connect(function()
		UIController.MenuOpenClose(menu)
	end)

	menu.LikeRewardFrame.Purchase.MouseButton1Click:Connect(function()
		remote:FireServer("Claim")
	end)

	menu:GetPropertyChangedSignal("Visible"):Connect(function()
		remote:FireServer("Visible")
	end)

	UIS.WindowFocusReleased:Connect(function()
		remote:FireServer("Tabbed")
	end)

	remote.OnClientEvent:Connect(function(update, val)
		if update == "notif" then
			UIController.showNotification(val)
			return
		end
		if update then
			if val then
				local likeRewardModel = workspace:FindFirstChild("LikeReward")
				if likeRewardModel then
					likeRewardModel:Destroy()
				end
				if menu.Visible then
					UIController.MenuOpenClose(menu)
				end
			else
				UIController.showNotification("You didn't like the game!", Color3.fromRGB(255, 60, 63))
			end
			return
		end

		if not menu.Visible then
			UIController.MenuOpenClose(menu)
		end
	end)
end

function UIController.StarterPack()
	local guiButton = plr.PlayerGui.MainGameUi.MMContainer.SP
	local menu = plr.PlayerGui.MainGameUi.StarterPack
	local close = menu.StarterPackFrame.X

	if plr:WaitForChild("PlayerStats", 1.5).StarterPack.Value == true then
		guiButton.Visible = false
		return
	end

	close.MouseButton1Click:Connect(function()
		UIController.MenuOpenClose(menu)
	end)

	guiButton.MouseButton1Click:Connect(function()
		UIController.MenuOpenClose(menu)
	end)

	menu.StarterPackFrame.Purchase.MouseButton1Click:Connect(function()
		MarketplaceService:PromptProductPurchase(plr, 3459672778)

		local purchaseConnection
		purchaseConnection = MarketplaceService.PromptProductPurchaseFinished:Connect(
			function(userId, purchasedProductId, isPurchased)
				if userId == plr.UserId and purchasedProductId == 3459672778 then
					purchaseConnection:Disconnect()
					if isPurchased then
						task.delay(0.5, function()
							UIController.ChangeLook()
						end)

						guiButton.Visible = false
						Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.buy, plr.Character, 1)

						UIController.MenuOpenClose(menu)

						UIController.showNotification("Got $1000!")

						task.delay(0.8, function()
							UIController.showNotification("Got Glass Cup!")
						end)

						task.delay(1.6, function()
							UIController.showNotification("Got Football!")
						end)
					end
				end
			end
		)
	end)
end

function UIController.Leave()
	local gui = plr.PlayerGui:WaitForChild("MainGameUi").Leave

	gui.MouseButton1Click:Connect(function()
		QueueController.Leave()
	end)
end

function UIController.Invite()
	local SocialService = game:GetService("SocialService")
	local PongItemsConfig = require(ReplicatedStorage.Arrays.PongItemsConfig)
	local button = plr.PlayerGui:WaitForChild("MainGameUi").Invite

	button.MouseButton1Click:Connect(function()
		local success, errorMessage = pcall(function()
			SocialService:PromptGameInvite(plr)
		end)

		if not success then
			warn("Failed to open invite menu: " .. errorMessage)
		end
	end)
end

function UIController.Loading()
	local loading = plr.PlayerGui:WaitForChild("MainGameUi").LoadingContainer
	local loadingText = loading:FindFirstChild("TextLabel")
	local skipButton = loading:FindFirstChild("Skip")
	local studs = loading:FindFirstChild("Studs")

	loading.Visible = true

	-- Diagonal scrolling animation for studs background
	local studsConnection
	if studs and studs:IsA("ImageLabel") then
		-- Store original values
		local originalAnchorPoint = studs.AnchorPoint
		local originalPosition = studs.Position
		local originalSize = studs.Size

		-- Make studs larger to allow seamless scrolling
		studs.AnchorPoint = Vector2.new(0.5, 0.5)
		studs.Position = UDim2.new(0.5, 0, 0.5, 0)
		studs.Size = UDim2.new(10, 0, 10, 0)

		local scrollSpeed = 20
		local wrapDistance = 2000 -- Match to your texture tile size
		local offset = 0

		studsConnection = RunService.RenderStepped:Connect(function(dt)
			if not loading.Visible then
				if studsConnection then
					studsConnection:Disconnect()
					studsConnection = nil
				end
				return
			end

			-- Use modulo for smooth continuous loop (no snapping)
			offset = (offset + scrollSpeed * dt) % wrapDistance

			-- Apply offset
			
			studs.Position = UDim2.new(0.5, -offset, 0.5, -offset)
		end)
	end

	local skipped = false

	-- Fade out function
	local function fadeOutLoading(callback)
		if studsConnection then
			studsConnection:Disconnect()
			studsConnection = nil
		end

		local fadeTime = 0.5
		local tweenInfo = TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tweens = {}

		if loading.BackgroundTransparency < 1 then
			local tween = TweenService:Create(loading, tweenInfo, { BackgroundTransparency = 1 })
			table.insert(tweens, tween)
		end

		for _, descendant in loading:GetDescendants() do
			local props = {}
			if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
				if descendant.TextTransparency < 1 then props.TextTransparency = 1 end
				if descendant.BackgroundTransparency < 1 then props.BackgroundTransparency = 1 end
			end
			if descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
				if descendant.ImageTransparency < 1 then props.ImageTransparency = 1 end
				if descendant.BackgroundTransparency < 1 then props.BackgroundTransparency = 1 end
			end
			if descendant:IsA("Frame") then
				if descendant.BackgroundTransparency < 1 then props.BackgroundTransparency = 1 end
			end
			if descendant:IsA("UIStroke") then
				if descendant.Transparency < 1 then props.Transparency = 1 end
			end
			if next(props) then
				local tween = TweenService:Create(descendant, tweenInfo, props)
				table.insert(tweens, tween)
			end
		end

		for _, tween in tweens do
			tween:Play()
		end

		task.delay(fadeTime, function()
			loading.Visible = false
			if callback then callback() end
		end)
	end

	if skipButton then
		skipButton.Visible = false
		skipButton.MouseButton1Click:Connect(function()
			skipped = true
			fadeOutLoading()
		end)
	end

	TweenService:Create(loading.ball, TweenInfo.new(15), { Rotation = 6000 }):Play()

	local startTime = tick()

	local essentialAssets = {}
	local secondaryAssets = {}

	local essentialSoundNames = {
		"ButtonHover", "ButtonClick", "open", "close", "buy", "equip", "Deny"
	}

	for _, sound in pairs(ReplicatedStorage.Assets.Sounds:GetDescendants()) do
		if sound:IsA("Sound") then
			local isEssential = false
			for _, name in ipairs(essentialSoundNames) do
				if sound.Name == name then
					isEssential = true
					break
				end
			end
			if isEssential then
				table.insert(essentialAssets, sound)
			else
				table.insert(secondaryAssets, sound)
			end
		end
	end

	local mainGui = plr.PlayerGui:WaitForChild("MainGameUi")
	local essentialContainers = {
		mainGui:FindFirstChild("LeftButtons"),
		mainGui:FindFirstChild("BottomLeftContainer"),
		mainGui:FindFirstChild("MMContainer"),
	}

	for _, descendant in pairs(mainGui:GetDescendants()) do
		if descendant:IsA("ImageButton") or descendant:IsA("TextButton") then
			if descendant:IsA("ImageButton") and descendant.Image ~= "" then
				table.insert(essentialAssets, descendant)
			end
			for _, child in descendant:GetDescendants() do
				if (child:IsA("ImageLabel") or child:IsA("ImageButton")) and child.Image ~= "" then
					table.insert(essentialAssets, child)
				end
			end
		end
	end

	for _, container in ipairs(essentialContainers) do
		if container then
			for _, desc in container:GetDescendants() do
				if (desc:IsA("ImageLabel") or desc:IsA("ImageButton")) and desc.Image ~= "" then
					if not table.find(essentialAssets, desc) then
						table.insert(essentialAssets, desc)
					end
				end
			end
		end
	end

	for _, descendant in pairs(plr.PlayerGui:GetDescendants()) do
		if descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
			if descendant.Image ~= "" and not table.find(essentialAssets, descendant) then
				table.insert(secondaryAssets, descendant)
			end
		end
	end

	for _, folder in pairs(ReplicatedStorage.Assets.Models:GetChildren()) do
		for _, model in pairs(folder:GetDescendants()) do
			if model:IsA("MeshPart") or model:IsA("Decal") or model:IsA("Texture") then
				table.insert(secondaryAssets, model)
			end
		end
	end

	for _, descendant in pairs(workspace:GetDescendants()) do
		if descendant:IsA("MeshPart") or descendant:IsA("Decal") or descendant:IsA("Texture") then
			table.insert(secondaryAssets, descendant)
		end
	end

	for _, anim in pairs(ReplicatedStorage:GetDescendants()) do
		if anim:IsA("Animation") then
			table.insert(secondaryAssets, anim)
		end
	end

	local totalAssets = #essentialAssets + #secondaryAssets
	local loadedAssets = 0

	print("Essential assets: " .. #essentialAssets .. ", Secondary assets: " .. #secondaryAssets)

	local function updateProgress(phase)
		local percentage = math.floor((loadedAssets / totalAssets) * 100)
		percentage = math.min(percentage, 100)

		if loadingText then
			if phase == 1 then
				loadingText.Text = "Loading UI... " .. percentage .. "%"
			else
				loadingText.Text = "Loading assets... " .. percentage .. "%"
			end
		end

		if loading:FindFirstChild("LoadingBar") then
			local bar = loading.LoadingBar
			if bar:FindFirstChild("Fill") then
				local fillAmount = math.min(loadedAssets / totalAssets, 1)
				bar.Fill.Size = UDim2.new(fillAmount, 0, 1, 0)
			end
		end

		if skipButton and not skipButton.Visible then
			if percentage >= 30 or (tick() - startTime) >= 2 then
				skipButton.Visible = true
			end
		end
	end

	local function preloadBatch(assets, phase, batchSize)
		batchSize = batchSize or 10
		for i = 1, #assets, batchSize do
			if skipped then return end

			local batch = {}
			for j = i, math.min(i + batchSize - 1, #assets) do
				table.insert(batch, assets[j])
			end

			ContentProvider:PreloadAsync(batch)
			loadedAssets = loadedAssets + #batch
			updateProgress(phase)
			task.wait()
		end
	end

	print("Loading essential assets...")
	preloadBatch(essentialAssets, 1, 5)

	if skipped then return end

	if loadingText then
		loadingText.Text = "Loading player data..."
	end

	if not plr:WaitForChild("PlayerStats", 10) then
		warn("PlayerStats took too long to load")
	end

	if not plr:WaitForChild("leaderstats", 10) then
		warn("leaderstats took too long to load")
	end

	if skipped then return end

	print("Loading secondary assets...")
	preloadBatch(secondaryAssets, 2, 15)

	if skipped then return end

	local minLoadTime = 1.5
	local elapsed = tick() - startTime

	if elapsed < minLoadTime and not skipped then
		if loadingText then
			loadingText.Text = "Loading... 100%"
		end
		local remainingTime = minLoadTime - elapsed
		local waitStart = tick()
		while (tick() - waitStart) < remainingTime and not skipped do
			task.wait(0.1)
		end
	end

	if skipped then return end

	print("Preloading complete! Loaded " .. totalAssets .. " assets")
	fadeOutLoading()
end

function UIController.Store()
	local StoreGui = plr.PlayerGui.MainGameUi.StoreContainer
	local StoreButton = plr.PlayerGui.MainGameUi.LeftButtons.Store
	local GetDataRemote = game.ReplicatedStorage.Remotes.Functions.GetData

	local function UpdateEquippedVisuals(ItemType)
		local plrData = GetDataRemote:InvokeServer()
		local equippedItem = plrData["Equipped" .. ItemType]

		for _, frame in StoreGui.Frame.ScrollingFrame:GetChildren() do
			if frame:IsA("ImageButton") and frame.Name ~= "+" then
				if frame.Name == equippedItem then
					frame.ImageColor3 = Color3.fromRGB(0, 255, 0)
				else
					frame.ImageColor3 = Color3.fromRGB(255, 255, 255)
				end
			end
		end
	end

	local function getModelBounds(model)
		local minPos = Vector3.new(math.huge, math.huge, math.huge)
		local maxPos = Vector3.new(-math.huge, -math.huge, -math.huge)

		local function processInstance(instance)
			if instance:IsA("BasePart") then
				local pos = instance.Position
				local halfSize = instance.Size / 2

				minPos = Vector3.new(
					math.min(minPos.X, pos.X - halfSize.X),
					math.min(minPos.Y, pos.Y - halfSize.Y),
					math.min(minPos.Z, pos.Z - halfSize.Z)
				)
				maxPos = Vector3.new(
					math.max(maxPos.X, pos.X + halfSize.X),
					math.max(maxPos.Y, pos.Y + halfSize.Y),
					math.max(maxPos.Z, pos.Z + halfSize.Z)
				)
			end
		end

		if model:IsA("BasePart") then
			processInstance(model)
		else
			for _, descendant in model:GetDescendants() do
				processInstance(descendant)
			end
			-- Also check the model itself if it's a BasePart
			if model:IsA("BasePart") then
				processInstance(model)
			end
		end

		local size = maxPos - minPos
		local center = (minPos + maxPos) / 2

		return size, center
	end

	-- Helper function to setup viewport camera for an item
	local function setupViewportCamera(viewportFrame, itemModel, itemType)
		local camera = Instance.new("Camera")
		viewportFrame.CurrentCamera = camera
		camera.Parent = viewportFrame

		local size, center = getModelBounds(itemModel)
		local maxDimension = math.max(size.X, size.Y, size.Z)
		local fov = 50
		-- Calculate camera distance based on FOV and model size
		if itemType == "Balls" then
			fov = 30
		end
		-- Field of view in degrees
		camera.FieldOfView = fov
		local fovRad = math.rad(fov / 2)
		local distance = (maxDimension / 2) / math.tan(fovRad) * 1.5 -- 1.5 multiplier for padding

		-- Ensure minimum distance
		distance = math.max(distance, 2)

		-- Position camera at an angle for better 3D visualization
		local cameraAngleX = math.rad(15) -- Slight downward angle
		local cameraAngleY = math.rad(25) -- Slight side angle

		-- Calculate camera offset from center
		local cameraOffset = Vector3.new(
			math.sin(cameraAngleY) * math.cos(cameraAngleX) * distance,
			math.sin(cameraAngleX) * distance,
			math.cos(cameraAngleY) * math.cos(cameraAngleX) * distance
		)

		local cameraPosition = center + cameraOffset
		camera.CFrame = CFrame.new(cameraPosition, center)

		return camera
	end

	local function CreateItems(ItemType)
		StoreGui.Frame.buy.Visible = false
		StoreGui.Frame.Title.Text = ItemType

		-- Clear existing items
		for _, e in StoreGui.Frame.ScrollingFrame:GetChildren() do
			if not e:IsA("UIListLayout") and e.Name ~= "+" then
				e:Destroy()
			end
		end

		local playerData = GetDataRemote:InvokeServer()

		for _, v in ReplicatedStorage.Assets.Models:FindFirstChild(ItemType):GetChildren() do
			if table.find(playerData[ItemType .. "Inventory"], v.Name) then
				local clone = ReplicatedStorage.Assets.UI.ItemFrame:Clone()

				clone.Title.Text = v.Name
				clone.Parent = StoreGui.Frame.ScrollingFrame
				clone.Name = v.Name

				-- Clone the item model
				local itemClone = v:Clone()

				-- Position the item at origin for the viewport
				if itemClone:IsA("Model") then
					itemClone:PivotTo(CFrame.new(0, 0, 0))
				elseif itemClone:IsA("BasePart") then
					itemClone.CFrame = CFrame.new(0, 0, 0)
				end

				itemClone.Parent = clone.ViewportFrame

				-- Setup the camera to properly view the item
				setupViewportCamera(clone.ViewportFrame, itemClone, ItemType)

				UIController.buttonInteraction(clone)

				clone.MouseButton1Click:Connect(function()
					StoreGui.Frame.buy.Visible = true
					local plrData = GetDataRemote:InvokeServer()

					if table.find(plrData[ItemType .. "Inventory"], clone.Name) then
						if v.Name == plrData["Equipped" .. ItemType] then
							StoreGui.Frame.buy.TextLabel.Text = "Unequip"
						else
							StoreGui.Frame.buy.TextLabel.Text = "Equip"
						end
					end

					StoreGui.Frame.buy:SetAttribute("item", clone.Name)
					StoreGui.Frame.buy:SetAttribute("itemType", ItemType)
				end)
			end
		end

		-- Update visuals after creating items
		UpdateEquippedVisuals(ItemType)
	end

	CreateItems("Balls")

	StoreButton.MouseButton1Click:Connect(function()
		CreateItems("Balls")
		UIController.MenuOpenClose(StoreGui)
	end)

	StoreGui.Frame.X.MouseButton1Click:Connect(function()
		UIController.MenuOpenClose(StoreGui)
	end)

	StoreGui.Frame.Balls.MouseButton1Click:Connect(function()
		CreateItems("Balls")
	end)

	StoreGui.Frame.Cups.MouseButton1Click:Connect(function()
		CreateItems("Cups")
	end)

	StoreGui.Frame.buy.MouseButton1Click:Connect(function()
		local currentItemType = StoreGui.Frame.buy:GetAttribute("itemType")

		if StoreGui.Frame.buy.TextLabel.Text == "Equip" then
			BuyablesServiceEvent:FireServer({
				["Action"] = "Equip",
				["ItemName"] = StoreGui.Frame.buy:GetAttribute("item"),
				["ItemType"] = currentItemType,
			})
			Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.equip, workspace, 1)
			task.delay(0.05, function()
				UIController.ChangeLook()
				UpdateEquippedVisuals(currentItemType)
			end)
			StoreGui.Frame.buy.TextLabel.Text = "Unequip"
		elseif StoreGui.Frame.buy.TextLabel.Text == "Unequip" then
			BuyablesServiceEvent:FireServer({
				["Action"] = "Unequip",
				["ItemName"] = StoreGui.Frame.buy:GetAttribute("item"),
				["ItemType"] = currentItemType,
			})
			Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.equip, workspace, 1)
			task.delay(0.05, function()
				UIController.ChangeLook()
				UpdateEquippedVisuals(currentItemType)
			end)
			StoreGui.Frame.buy.TextLabel.Text = "Equip"
		else
			if plr.leaderstats.Coins.Value >= PongItemsConfig[StoreGui.Frame.buy:GetAttribute("item")].Price then
				BuyablesServiceEvent:FireServer({
					["Action"] = "Buy",
					["ItemName"] = StoreGui.Frame.buy:GetAttribute("item"),
					["ItemType"] = currentItemType,
				})
				Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.buy, workspace, 1)
				task.delay(0.05, function()
					UIController.ChangeLook()
					UpdateEquippedVisuals(currentItemType)
				end)
			else
				UIController.MenuOpenClose(plr.PlayerGui.MainGameUi.RobuxShopFrame)
				Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.Deny, workspace, 1)
			end
		end
	end)

	StoreGui.Frame.ScrollingFrame["+"].MouseButton1Click:Connect(function()
		UIController.MenuOpenClose(StoreGui)
		BuyablesServiceEvent:FireServer({
			["Action"] = "Teleport",
			["Type"] = StoreGui.Frame.Title.Text,
		})
	end)
end

function UIController.NotificationListener()
	ReplicatedStorage.Remotes.Events.Notification.OnClientEvent:Connect(function(message)
		UIController.showNotification(message, Color3.fromRGB(0, 255, 21))
	end)
end

function UIController.ServerLuck()
	local CurrentLuck = ReplicatedStorage.Server.LuckBoost
	
	local IDs = {3488135968, 3488136128, 3488136272}
	local Prices = {}
	
	local Current = 1
	
	for i, v in pairs(IDs) do
		local productInfo = MarketplaceService:GetProductInfo(v, Enum.InfoType.Product)
		Prices[i] = productInfo.PriceInRobux
	end
	
	local UI = plr.PlayerGui.MainGameUi.RobuxShopFrame.ScrollingFrame.ServerLuck
	
	local function Update()
		if CurrentLuck.Value == 1 then
			UI.Prev.Text = "1x"
			UI.New.Text = "2x"
			Current = 1
		elseif CurrentLuck.Value == 2 then
			UI.Prev.Text = "2x"
			UI.New.Text = "4x"
			Current = 2
		elseif CurrentLuck.Value == 4 then
			UI.Prev.Text = "4x"
			UI.New.Text = "8x"
			Current = 3
		elseif CurrentLuck.Value == 8 then
			UI.Prev.Text = "8x"
			UI.New.Text = "Max"
			Current = 3
		end
		
		UI.Buy.Title.Text = `R$ {Prices[Current]}`
	end
	
	task.spawn(function()
		while task.wait(1) do
			if CurrentLuck:GetAttribute("EndTime") - os.time() > 0 then
				UI.Timer.Text = `{CurrentLuck:GetAttribute("EndTime") - os.time()}s`
			else
				UI.Timer.Text = "0s"
			end
		end
	end)
	
	UI.Buy.Activated:Connect(function()
		MarketplaceService:PromptProductPurchase(plr, IDs[Current])
	end)
	
	Update()
	
	CurrentLuck.Changed:Connect(function()
		Update()
	end)
end

function UIController.Lock()
	if plr.leaderstats.Wins.Value >= 10 then
		workspace.lock.SurfaceGui.Frame.Visible = false
	end
end

function UIController.Handler()
	local character = plr.Character or plr.CharacterAdded:Wait()
	if not character:IsDescendantOf(workspace) then
		character.AncestryChanged:Wait()
	end

	task.spawn(function()
		pcall(function()
			UIController.Loading()
		end)
	end)

	pcall(function() UIController.PreloadUIAssets() end)
	pcall(function() UIController.buttonInteraction() end)
	pcall(function() UIController.BottomLeftListener() end)
	pcall(function() UIController.shopMenu() end)
	pcall(function() UIController.WinMenu() end)
	pcall(function() UIController.LoseMenu() end)
	pcall(function() UIController.StarterPack() end)
	pcall(function() UIController.LikeReward() end)
	pcall(function() UIController.InkButton() end)
	pcall(function() UIController.Leave() end)
	pcall(function() UIController.Invite() end)
	pcall(function() UIController.NotificationListener() end)
	pcall(function() UIController.PlusCupButton() end)
	pcall(function() UIController.PressedEvent() end)
	pcall(function() UIController.ServerLuck() end)

	task.delay(1, function()
		pcall(function() UIController.MoneyMultiplierUpgrade() end)
		pcall(function() UIController.Store() end)
		pcall(function() UIController.Lock() end)
	end)
end


return UIController
