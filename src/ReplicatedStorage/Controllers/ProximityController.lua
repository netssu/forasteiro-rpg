local ProximityController = {}

local MarketplaceService = game:GetService("MarketplaceService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local BuyablesController = require(script.Parent.BuyablesController)
local QueueController = require(script.Parent.QueueController)
local UIController = require(script.Parent.UIController)

local plr = Players.LocalPlayer
local plrGui = plr:WaitForChild("PlayerGui")
local CustomPrompt = ReplicatedStorage.Assets.VFX.Prompt

local activePrompts = {}
local ACTION_NAME = "CustomProximityPromptAction"
local BIND_PRIORITY = 2000

local function getAdorneeFromPrompt(prompt)
	if not prompt then
		return nil
	end

	local parent = prompt.Parent
	if parent and parent:IsA("BasePart") then
		return parent
	end

	if parent and parent:IsA("Attachment") then
		local p = parent.Parent
		if p and p:IsA("BasePart") then
			return p
		end
	end

	local a = parent
	while a do
		if a:IsA("BasePart") then
			return a
		end
		a = a.Parent
	end

	return nil
end

local function getHRP()
	local char = plr.Character
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart")
end

local function getPromptDistance(prompt)
	local hrp = getHRP()
	if not hrp then
		return math.huge
	end

	local adornee = getAdorneeFromPrompt(prompt)
	if not adornee then
		return math.huge
	end

	return (hrp.Position - adornee.Position).Magnitude
end

local function shouldConsiderPrompt(prompt, entry)
	if not prompt or not entry then
		return false
	end
	if not prompt.Parent then
		return false
	end
	if not prompt.Enabled then
		return false
	end
	if not entry.UI or not entry.UI.Parent then
		return false
	end
	return true
end

local function getBestPromptForKeyCode(keyCode)
	local bestPrompt = nil
	local bestDist = math.huge

	for prompt, entry in pairs(activePrompts) do
		if shouldConsiderPrompt(prompt, entry) then
			local ok = false

			if entry.InputType == Enum.ProximityPromptInputType.Keyboard then
				ok = (prompt.KeyboardKeyCode == keyCode)
			elseif entry.InputType == Enum.ProximityPromptInputType.Gamepad then
				ok = (prompt.GamepadKeyCode == keyCode)
			end

			if ok then
				local dist = getPromptDistance(prompt)
				if dist < bestDist then
					bestDist = dist
					bestPrompt = prompt
				end
			end
		end
	end

	return bestPrompt
end

function ProximityController.GetScreenGui()
	local screenGui = plrGui:FindFirstChild("ProximityPrompts")
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "ProximityPrompts"
		screenGui.ResetOnSpawn = false
		screenGui.Parent = plrGui
	end
	return screenGui
end

local function Fade(guiProp, enabled, callback)
	local tweens = {}
	local completedCount = 0

	local function onTweenCompleted()
		completedCount += 1
		if completedCount == #tweens and not enabled then
			guiProp.Enabled = false
			if callback then
				callback()
			end
		end
	end

	guiProp.Enabled = true

	for _, descendant in ipairs(guiProp:GetDescendants()) do
		if descendant:GetAttribute("Fadeable") then
			local props = {}
			if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
				props.TextTransparency = enabled and 0 or 1
			elseif descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
				props.ImageTransparency = enabled and 0 or 1
			elseif descendant:IsA("Frame") then
				props.BackgroundTransparency = enabled and 0 or 1
			end

			if next(props) then
				local tween = TweenService:Create(descendant, TweenInfo.new(enabled and 0.2 or 0.3), props)
				tween.Completed:Connect(onTweenCompleted)
				tween:Play()
				table.insert(tweens, tween)
			end
		end
	end

	if #tweens == 0 and not enabled and callback then
		guiProp.Enabled = false
		callback()
	end
end

local function updateCASBinding()
	local keySet = {}
	local keys = {}

	for prompt, entry in pairs(activePrompts) do
		if shouldConsiderPrompt(prompt, entry) then
			if entry.InputType == Enum.ProximityPromptInputType.Keyboard then
				local kc = prompt.KeyboardKeyCode
				if kc and kc ~= Enum.KeyCode.Unknown and not keySet[kc] then
					keySet[kc] = true
					table.insert(keys, kc)
				end
			elseif entry.InputType == Enum.ProximityPromptInputType.Gamepad then
				local kc = prompt.GamepadKeyCode
				if kc and kc ~= Enum.KeyCode.Unknown and not keySet[kc] then
					keySet[kc] = true
					table.insert(keys, kc)
				end
			end
		end
	end

	if not keySet[Enum.KeyCode.ButtonX] then table.insert(keys, Enum.KeyCode.ButtonX) end
	if not keySet[Enum.KeyCode.E] then table.insert(keys, Enum.KeyCode.E) end
	if not keySet[Enum.KeyCode.F] then table.insert(keys, Enum.KeyCode.F) end

	ContextActionService:UnbindAction(ACTION_NAME)

	ContextActionService:BindActionAtPriority(
		ACTION_NAME,
		function(_, state, inputObject)
			if not inputObject then
				return Enum.ContextActionResult.Pass
			end

			local keyCode = inputObject.KeyCode
			if keyCode == Enum.KeyCode.Unknown then
				return Enum.ContextActionResult.Pass
			end

			local prompt = getBestPromptForKeyCode(keyCode)
			if not prompt then
				return Enum.ContextActionResult.Pass
			end

			if state == Enum.UserInputState.Begin then
				prompt:InputHoldBegin()
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				prompt:InputHoldEnd()
			end

			return Enum.ContextActionResult.Pass
		end,
		false,
		BIND_PRIORITY,
		unpack(keys)
	)
end

function ProximityController.RemovePrompt(prompt)
	local entry = activePrompts[prompt]
	if entry then
		Fade(entry.UI, false, function()
			if entry.UI then
				entry.UI:Destroy()
			end
		end)

		for _, conn in pairs(entry.Connections) do
			if conn and conn.Disconnect then
				conn:Disconnect()
			end
		end

		activePrompts[prompt] = nil
		updateCASBinding()
	end
end

function ProximityController.CreatePrompt(prompt, inputType, gui)
	if activePrompts[prompt] then
		return
	end

	local adornee = getAdorneeFromPrompt(prompt)
	if not adornee then
		return
	end

	local promptUI = CustomPrompt:Clone()
	promptUI.Name = (prompt.Name .. "_" .. tostring(prompt:GetAttribute("type") or "Prompt"))
	promptUI.Adornee = adornee
	promptUI.Parent = gui

	local inputFrame = promptUI.Frame.InputFrame.Frame
	if inputType == Enum.ProximityPromptInputType.Touch then
		inputFrame.ButtonImage.Image = "rbxasset://textures/ui/Controls/TouchTapIcon.png"
		inputFrame.ButtonText.Visible = false
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		inputFrame.ButtonImage.Image = UserInputService:GetImageForKeyCode(prompt.GamepadKeyCode)
		inputFrame.ButtonText.Visible = false
	elseif inputType == Enum.ProximityPromptInputType.Keyboard then
		inputFrame.ButtonText.Text = prompt.KeyboardKeyCode.Name
	end

	promptUI.Frame.TextFrame.ActionText.Text = prompt.ActionText

	local connections = {}

	table.insert(connections, promptUI.TextButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			prompt:InputHoldBegin()
		end
	end))

	table.insert(connections, promptUI.TextButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			prompt:InputHoldEnd()
		end
	end))

	table.insert(connections, prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
		if promptUI and promptUI.Parent then
			promptUI.Frame.TextFrame.ActionText.Text = prompt.ActionText
		end
	end))

	Fade(promptUI, true)

	activePrompts[prompt] = {
		UI = promptUI,
		Connections = connections,
		Debounce = false,
		InputType = inputType,
	}

	updateCASBinding()
end

function ProximityController.Interaction(prompt)
	local entry = activePrompts[prompt]
	if not entry or entry.Debounce then
		return
	end

	entry.Debounce = true

	local promptUI = entry.UI
	if not promptUI then
		entry.Debounce = false
		return
	end

	local originalSize = promptUI.Frame.Size
	local clickSize = UDim2.new(
		originalSize.X.Scale * 0.95,
		originalSize.X.Offset,
		originalSize.Y.Scale * 0.95,
		originalSize.Y.Offset
	)

	local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tweenShrink = TweenService:Create(promptUI.Frame, tweenInfo, { Size = clickSize })
	local tweenExpand = TweenService:Create(promptUI.Frame, tweenInfo, { Size = originalSize })

	tweenShrink:Play()
	tweenShrink.Completed:Connect(function()
		tweenExpand:Play()
		tweenExpand.Completed:Connect(function()
			local e = activePrompts[prompt]
			if e then
				e.Debounce = false
			end
		end)
	end)
end

local function handlePromptTriggered(prompt)
	ProximityController.Interaction(prompt)

	local t = prompt:GetAttribute("type")
	if not t then
		return
	end

	if t == "VIP" then
		if plr.PlayerStats.Vip.Value then
			UIController.showNotification("VIP Already Owned!")
		else
			MarketplaceService:PromptProductPurchase(plr, 3457958846)
		end
	elseif t == "itemInteract" then
		local text = prompt.Parent.Parent.OwnedText.TextLabel.Text
		local itemname = prompt.Parent.Parent.Name
		local itemType = prompt.Parent.Parent.Parent.Name
		if text == "Equip" then
			BuyablesController.Equip(itemname, itemType)
		elseif text == "Unequip" then
			BuyablesController.Unequip(itemname, itemType)
		else
			BuyablesController.Buy(itemname, itemType)
		end
	elseif t == "queue" then
		if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then
			return
		end
		if plr.Character.Humanoid.Health < 1 then
			return
		end
		local podium = getAdorneeFromPrompt(prompt)
		if podium then
			QueueController.Enter(podium)
		end
	end
end

function ProximityController.Handler()
	updateCASBinding()

	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end

		local gui = ProximityController.GetScreenGui()
		ProximityController.CreatePrompt(prompt, inputType, gui)
	end)

	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end

		ProximityController.RemovePrompt(prompt)
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		handlePromptTriggered(prompt)
	end)

	plr.CharacterAdded:Connect(function()
		for prompt in pairs(activePrompts) do
			ProximityController.RemovePrompt(prompt)
		end
	end)
end

return ProximityController
