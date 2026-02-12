local NotificationUtility = {}

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Configuração solicitada
local NOTIFICATION_CONFIG = {
	ScreenPosition = UDim2.new(0.5, 0, 0.05, 0),
	Spacing = 10,
	MaxVisible = 4,

	MinWidth = 300,
	MaxWidth = 400,
	Height = 120,

	AnimateIn = 0.5,
	AnimateOut = 0.3,
	DefaultDuration = 4,

	CornerRadius = UDim.new(0, 12),
	StrokeThickness = 2,
	Font = Enum.Font.GothamMedium,

	Sounds = {
		success = "rbxassetid://6026984224",
		error = "rbxassetid://6026984224",
		warning = "rbxassetid://6026984224",
		info = "rbxassetid://6026984224",
		neutral = "rbxassetid://6026984224",
		-- Adicionando fallback para action caso usem o som, mas mantendo a estrutura pedida
		action = "rbxassetid://6026984224" 
	}
}

local NOTIFICATION_TYPES = {
	success = {
		icon = "✔",
		color = Color3.fromRGB(85, 220, 120),
		title = "SUCCESS"
	},
	error = {
		icon = "✖",
		color = Color3.fromRGB(255, 80, 80),
		title = "ERROR"
	},
	warning = {
		icon = "!",
		color = Color3.fromRGB(255, 190, 50),
		title = "WARNING"
	},
	info = {
		icon = "i",
		color = Color3.fromRGB(60, 180, 255),
		title = "INFO"
	},
	neutral = {
		icon = "●",
		color = Color3.fromRGB(150, 150, 150),
		title = "NOTICE"
	},
	action = {
		icon = "★",
		color = Color3.fromRGB(0, 255, 128), -- Verde Action
		title = "ACTION"
	}
}

local NotificationController = {}
NotificationController.__index = NotificationController

local activeNotifications = {}
local notificationQueue = {}
local screenGui = nil
local containerFrame = nil

local function createScreenGui()
	if screenGui then return screenGui end
	local player = Players.LocalPlayer
	if not player then return nil end
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = playerGui:FindFirstChild("NotificationSystem")
	if screenGui then screenGui:Destroy() end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "NotificationSystem"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 100
	screenGui.Parent = playerGui

	containerFrame = Instance.new("Frame")
	containerFrame.Name = "Container"
	containerFrame.Size = UDim2.new(0, NOTIFICATION_CONFIG.MaxWidth, 1, 0)
	containerFrame.Position = NOTIFICATION_CONFIG.ScreenPosition
	containerFrame.AnchorPoint = Vector2.new(0.5, 0)
	containerFrame.BackgroundTransparency = 1
	containerFrame.Parent = screenGui

	local listLayout = Instance.new("UIListLayout")
	listLayout.Name = "Layout"
	listLayout.Padding = UDim.new(0, NOTIFICATION_CONFIG.Spacing)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = containerFrame

	return screenGui
end

local function playSound(soundType)
	local soundId = NOTIFICATION_CONFIG.Sounds[soundType] or NOTIFICATION_CONFIG.Sounds.info
	if not soundId then return end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.5
	sound.Parent = game:GetService("SoundService")
	sound:Play()
	task.delay(2, function()
		if sound then sound:Destroy() end
	end)
end

local function createNotificationUI(notifData)
	local typeStyle = NOTIFICATION_TYPES[notifData.type] or NOTIFICATION_TYPES.info

	-- Força estilo Action se tiver callback e for do tipo action
	if notifData.callback and notifData.type == "action" then
		typeStyle = NOTIFICATION_TYPES.action
	end

	local notifFrame = Instance.new("CanvasGroup")
	notifFrame.Name = "Notification_" .. tick()
	notifFrame.Size = UDim2.new(1, 0, 0, NOTIFICATION_CONFIG.Height)
	notifFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	notifFrame.BackgroundTransparency = 0
	notifFrame.BorderSizePixel = 0
	notifFrame.GroupTransparency = 1
	notifFrame.LayoutOrder = notifData.priority or 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = NOTIFICATION_CONFIG.CornerRadius
	corner.Parent = notifFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = typeStyle.color
	stroke.Thickness = NOTIFICATION_CONFIG.StrokeThickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Transparency = 0.5
	stroke.Parent = notifFrame

	-- Ícone posicionado à esquerda
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(0, 40, 0, 40)
	iconContainer.Position = UDim2.new(0, 20, 0.5, 0) -- Margem de 20px da esquerda
	iconContainer.AnchorPoint = Vector2.new(0, 0.5)
	iconContainer.BackgroundColor3 = typeStyle.color
	iconContainer.BorderSizePixel = 0
	iconContainer.Parent = notifFrame

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(1, 0)
	iconCorner.Parent = iconContainer

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Symbol"
	iconLabel.Size = UDim2.new(1, 0, 1, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = notifData.icon or typeStyle.icon
	iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconLabel.Font = Enum.Font.GothamBlack
	iconLabel.TextSize = 24
	iconLabel.Parent = iconContainer

	-- Container do texto
	-- Ocupa o resto do espaço, centralizado verticalmente
	local textContainer = Instance.new("Frame")
	textContainer.Name = "TextContainer"
	textContainer.Size = UDim2.new(1, -80, 1, -20) -- 100% largura - margens (esq+dir)
	textContainer.Position = UDim2.new(0.5, 10, 0.5, 0) -- Levemente deslocado para a direita para compensar visualmente o icone se necessario, ou use 0.5/0.5 puro
	textContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	textContainer.BackgroundTransparency = 1
	textContainer.Parent = notifFrame

	local messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "Message"
	messageLabel.Size = UDim2.new(1, 0, 1, 0)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Text = notifData.message
	messageLabel.TextColor3 = Color3.fromRGB(40, 40, 40)
	messageLabel.Font = NOTIFICATION_CONFIG.Font
	messageLabel.TextWrapped = true
	messageLabel.TextScaled = true
	-- VOLTANDO PARA CENTRALIZADO
	messageLabel.TextXAlignment = Enum.TextXAlignment.Center 
	messageLabel.TextYAlignment = Enum.TextYAlignment.Center
	messageLabel.Parent = textContainer

	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MaxTextSize = 18
	textConstraint.MinTextSize = 14
	textConstraint.Parent = messageLabel

	local progressBar = Instance.new("Frame")
	progressBar.Name = "Timer"
	progressBar.Size = UDim2.new(1, 0, 0, 3)
	progressBar.Position = UDim2.new(0.5, 0, 1, 0)
	progressBar.AnchorPoint = Vector2.new(0.5, 1)
	progressBar.BackgroundColor3 = typeStyle.color
	progressBar.BorderSizePixel = 0
	progressBar.Parent = notifFrame

	return notifFrame, progressBar
end

local function animateIn(notifFrame, onComplete, targetHeight)
	notifFrame.Size = UDim2.new(1, 0, 0, 0)
	notifFrame.GroupTransparency = 1

	targetHeight = targetHeight or NOTIFICATION_CONFIG.Height

	local tweenInfo = TweenInfo.new(
		NOTIFICATION_CONFIG.AnimateIn,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	)

	local sizeTween = TweenService:Create(notifFrame, tweenInfo, {
		Size = UDim2.new(1, 0, 0, targetHeight)
	})

	local fadeTween = TweenService:Create(notifFrame, TweenInfo.new(0.3), {
		GroupTransparency = 0
	})

	sizeTween:Play()
	fadeTween:Play()

	sizeTween.Completed:Connect(function()
		if onComplete then onComplete() end
	end)
end

local function animateOut(notifFrame, onComplete)
	local tweenInfo = TweenInfo.new(
		NOTIFICATION_CONFIG.AnimateOut,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.In
	)

	local sizeTween = TweenService:Create(notifFrame, tweenInfo, {
		Size = UDim2.new(1, 0, 0, 0)
	})

	local fadeTween = TweenService:Create(notifFrame, TweenInfo.new(0.3), {
		GroupTransparency = 1
	})

	sizeTween:Play()
	fadeTween:Play()

	sizeTween.Completed:Connect(function()
		if onComplete then onComplete() end
	end)
end

local function animateProgress(progressBar, duration)
	local tweenInfo = TweenInfo.new(
		duration,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.InOut
	)
	local tween = TweenService:Create(progressBar, tweenInfo, {
		Size = UDim2.new(0, 0, 0, 3)
	})
	tween:Play()
	return tween
end

local function removeNotification(notifId)
	local notif = activeNotifications[notifId]
	if not notif then return end

	if notif.progressTween then notif.progressTween:Cancel() end

	animateOut(notif.frame, function()
		if notif.frame then notif.frame:Destroy() end
		activeNotifications[notifId] = nil
		if #notificationQueue > 0 then
			local nextNotif = table.remove(notificationQueue, 1)
			NotificationController:ShowInternal(nextNotif)
		end
	end)
end

function NotificationController:ShowInternal(notifData)
	local visibleCount = 0
	for _ in pairs(activeNotifications) do
		visibleCount += 1
	end

	if visibleCount >= NOTIFICATION_CONFIG.MaxVisible then
		table.insert(notificationQueue, notifData)
		return
	end

	if not screenGui or not screenGui.Parent then
		createScreenGui()
	end
	if not containerFrame then return end

	local notifFrame, progressBar = createNotificationUI(notifData)
	notifFrame.Parent = containerFrame

	local notifId = "notif_" .. tick()
	activeNotifications[notifId] = {
		frame = notifFrame,
		progressBar = progressBar,
		data = notifData
	}

	if notifData.sound then
		playSound(notifData.type)
	end

	local targetHeight = notifFrame.Size.Y.Offset

	animateIn(notifFrame, function()
		local progressTween = animateProgress(progressBar, notifData.duration)
		if activeNotifications[notifId] then
			activeNotifications[notifId].progressTween = progressTween
		end
		task.delay(notifData.duration, function()
			removeNotification(notifId)
		end)
	end, targetHeight)

	-- Botão invisível em toda a notificação
	local clickDetector = Instance.new("TextButton")
	clickDetector.Size = UDim2.new(1, 0, 1, 0)
	clickDetector.BackgroundTransparency = 1
	clickDetector.Text = ""
	clickDetector.ZIndex = 20
	clickDetector.Parent = notifFrame

	clickDetector.MouseButton1Click:Connect(function()
		if notifData.callback then
			task.spawn(notifData.callback)
		end
		removeNotification(notifId)
	end)
end

function NotificationController:Show(messageOrConfig, notifType, duration)
	local notifData = {}

	if type(messageOrConfig) == "table" then
		notifData = messageOrConfig
		notifData.message = notifData.message or "..."
		notifData.type = notifData.type or "info"
		notifData.duration = notifData.duration or NOTIFICATION_CONFIG.DefaultDuration
		notifData.sound = notifData.sound ~= false
		notifData.priority = notifData.priority or 0
		notifData.callback = notifData.callback
	else
		notifData.message = tostring(messageOrConfig)
		notifData.type = notifType or "info"
		notifData.duration = duration or NOTIFICATION_CONFIG.DefaultDuration
		notifData.sound = true
		notifData.priority = 0
	end

	if not NOTIFICATION_TYPES[notifData.type] then
		notifData.type = "info"
	end

	self:ShowInternal(notifData)
end

function NotificationController:Success(message, duration)
	self:Show(message, "success", duration)
end

function NotificationController:Error(message, duration)
	self:Show(message, "error", duration)
end

function NotificationController:Warning(message, duration)
	self:Show(message, "warning", duration)
end

function NotificationController:Info(message, duration)
	self:Show(message, "info", duration)
end

function NotificationController:Neutral(message, duration)
	self:Show(message, "neutral", duration)
end

function NotificationController:Action(message, callback, duration)
	self:Show({
		message = message,
		type = "action",
		callback = callback,
		duration = duration
	})
end

function NotificationController:ClearAll()
	for notifId in pairs(activeNotifications) do
		removeNotification(notifId)
	end
	notificationQueue = {}
end

task.spawn(function()
	createScreenGui()
end)

return NotificationController