local SettingsController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local SoundController = require(ReplicatedStorage.Controllers.SoundController)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local SWITCH_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BAR_TWEEN_INFO = TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

local COLOR_ON = Color3.fromRGB(100, 220, 100)
local COLOR_OFF = Color3.fromRGB(220, 80, 80)

local SWITCH_POS_ON = UDim2.new(1, -2, 0.5, 0)
local SWITCH_POS_OFF = UDim2.new(0, 2, 0.5, 0)

local SETTINGS_CONFIG = {
	{ Type = "Bool", Key = "MuteMusic", LabelTop = "Mute Music", LabelBottom = "Mute the background music" },
	{ Type = "Bool", Key = "MuteSFX", LabelTop = "Mute SFX", LabelBottom = "Mute sound effects" },
	{ Type = "Bool", Key = "Shadows", LabelTop = "Shadows", LabelBottom = "Enable or disable game shadows" },
	{ Type = "Bar", Key = "MusicVolume", LabelTop = "Music Volume", LabelBottom = "Adjust the background music volume" },
	{ Type = "Bar", Key = "SFXVolume", LabelTop = "SFX Volume", LabelBottom = "Adjust the sound effects volume" },
}

local settingsFR = nil
local listFrame = nil
local currentSettings = {}
local boolItems = {}
local barItems = {}

local function getTemplate(templateName)
	return settingsFR.SettingsBG.ListScrollingFrame:FindFirstChild(templateName)
end

local function applySettingLocally(key, value)
	if key == "MuteMusic" then
		SoundController.MuteMusic(value)
	elseif key == "MuteSFX" then
		SoundController.MuteSFX(value)
	elseif key == "MusicVolume" then
		SoundController.SetMusicVolume(value)
	elseif key == "SFXVolume" then
		SoundController.SetSFXVolume(value)
	elseif key == "Shadows" then
		Lighting.GlobalShadows = value
	end
end

local function setSwitchState(switchBG, switchBT, state, animate)
	local targetColor = state and COLOR_ON or COLOR_OFF
	local targetPos = state and SWITCH_POS_ON or SWITCH_POS_OFF

	switchBT.AnchorPoint = Vector2.new(state and 1 or 0, 0.5)

	if animate then
		TweenService:Create(switchBG, SWITCH_TWEEN_INFO, { BackgroundColor3 = targetColor }):Play()
		TweenService:Create(switchBT, SWITCH_TWEEN_INFO, { Position = targetPos }):Play()
	else
		switchBG.BackgroundColor3 = targetColor
		switchBT.Position = targetPos
	end
end

local function setBarValue(barBG, barBT, value, animate)
	local safeValue = math.clamp(value, 0, 1)
	
	local visualSize = math.max(safeValue, 0.02)
	local targetSize = UDim2.new(visualSize, 0, 1, 0)

	if animate then
		TweenService:Create(barBT, BAR_TWEEN_INFO, { Size = targetSize }):Play()
	else
		barBT.Size = targetSize
	end
end

local function createBoolItem(config)
	local template = getTemplate("SettingsBGBool")
	if not template then return nil end
	
	local item = template:Clone()
	item.Name = "Bool_" .. config.Key
	item.Visible = true
	item.Parent = listFrame
	
	local labelTop = item:FindFirstChild("SettingsTX")
	local labelBottom = item:FindFirstChild("SettingsTXDesc")
	local switchBG = item:FindFirstChild("SwitchBG")
	local switchBT = switchBG and switchBG:FindFirstChild("SwitchBT")

	if labelTop then labelTop.Text = config.LabelTop end
	if labelBottom then labelBottom.Text = config.LabelBottom end

	local state = currentSettings[config.Key]
	if state == nil then state = false end

	setSwitchState(switchBG, switchBT, state, false)

	local function toggleSwitch()
		local newState = not currentSettings[config.Key]
		currentSettings[config.Key] = newState
		
		setSwitchState(switchBG, switchBT, newState, true)
		applySettingLocally(config.Key, newState)
		
		Packets.Action:Fire("ChangeSetting", { config.Key, newState })
	end

	switchBG.Active = true
	switchBG.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			toggleSwitch()
		end
	end)

	if switchBT then
		switchBT.Active = true
		switchBT.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				toggleSwitch()
			end
		end)
	end

	return item
end

local function createBarItem(config)
	local template = getTemplate("SettingsBGBar")
	if not template then return nil end
	
	local item = template:Clone()
	item.Name = "Bar_" .. config.Key
	item.Visible = true
	item.Parent = listFrame

	local barBG = item:FindFirstChild("BarBG")
	local barBT = barBG and barBG:FindFirstChild("BarBT")
	local labelTop = item:FindFirstChild("SettingsTX")
	local labelBottom = item:FindFirstChild("SettingsTXDesc")

	if barBT then
		barBT.AnchorPoint = Vector2.new(0, 0.5)
		barBT.Position = UDim2.new(0, 0, 0.5, 0)
	end

	if labelTop then labelTop.Text = config.LabelTop end
	if labelBottom then labelBottom.Text = config.LabelBottom end

	local value = currentSettings[config.Key] or 0.5
	setBarValue(barBG, barBT, value, false)

	local function updateInput(inputObject)
		if not barBG then return end
		
		local barAbsPos = barBG.AbsolutePosition.X
		local barAbsSize = barBG.AbsoluteSize.X
		local mouseX = inputObject.Position.X
		
		local newValue = math.clamp((mouseX - barAbsPos) / barAbsSize, 0, 1)
		
		if currentSettings[config.Key] ~= newValue then
			currentSettings[config.Key] = newValue
			setBarValue(barBG, barBT, newValue, false)
			applySettingLocally(config.Key, newValue)
			Packets.Action:Fire("ChangeSetting", { config.Key, newValue })
		end
	end

	local function startDragging(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			updateInput(input)

			local moveConn, upConn
			moveConn = UserInputService.InputChanged:Connect(function(moveInput)
				if moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch then
					updateInput(moveInput)
				end
			end)

			upConn = UserInputService.InputEnded:Connect(function(upInput)
				if upInput.UserInputType == Enum.UserInputType.MouseButton1 or upInput.UserInputType == Enum.UserInputType.Touch then
					moveConn:Disconnect()
					upConn:Disconnect()
				end
			end)
		end
	end

	barBG.Active = true
	barBG.InputBegan:Connect(startDragging)
	
	if barBT then
		barBT.Active = true
		barBT.InputBegan:Connect(startDragging)
	end

	return item
end

local function buildSettingsUI()
	local children = listFrame:GetChildren()
	for _, child in ipairs(children) do
		if child:IsA("Frame") and child.Name ~= "SettingsBGBool" and child.Name ~= "SettingsBGBar" then
			child:Destroy()
		end
	end

	boolItems = {}
	barItems = {}

	for _, config in ipairs(SETTINGS_CONFIG) do
		if config.Type == "Bool" then
			boolItems[config.Key] = createBoolItem(config)
		elseif config.Type == "Bar" then
			barItems[config.Key] = createBarItem(config)
		end
	end
end

local function refreshUIItem(key, value)
	if boolItems[key] then
		local switchBG = boolItems[key]:FindFirstChild("SwitchBG")
		local switchBT = switchBG and switchBG:FindFirstChild("SwitchBT")
		if switchBG and switchBT then setSwitchState(switchBG, switchBT, value, true) end
	end
	if barItems[key] then
		local barBG = barItems[key]:FindFirstChild("BarBG")
		local barBT = barBG and barBG:FindFirstChild("BarBT")
		if barBG and barBT then setBarValue(barBG, barBT, value, true) end
	end
end

local function onApplySettings(args)
	local settings = args[1] or {}
	for key, value in pairs(settings) do
		currentSettings[key] = value
		applySettingLocally(key, value)
	end
	buildSettingsUI()
end

local function onSettingChanged(args)
	local key = args[1]
	local value = args[2]
	
	if currentSettings[key] ~= value then
		currentSettings[key] = value
		applySettingLocally(key, value)
		refreshUIItem(key, value)
	end
end

function SettingsController.Init()
	local screenGui = PlayerGui:WaitForChild("Main")
	settingsFR = screenGui:WaitForChild("SettingsFR")
	listFrame = settingsFR.SettingsBG.ListScrollingFrame

	local boolTemplate = getTemplate("SettingsBGBool")
	local barTemplate = getTemplate("SettingsBGBar")
	if boolTemplate then boolTemplate.Visible = false end
	if barTemplate then barTemplate.Visible = false end
	
	Packets.Action.OnClientEvent:Connect(function(action, args)
		if action == "ApplySettings" then
			onApplySettings(args)
		elseif action == "SettingChanged" then
			onSettingChanged(args)
		end
	end)

	Packets.Action:Fire("RequestSettings", {})
end

function SettingsController.GetSetting(key)
	return currentSettings[key]
end

return SettingsController