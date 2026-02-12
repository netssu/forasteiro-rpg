------------------//SERVICES
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

------------------//MODULE
local PopupModule = {}

------------------//CONSTANTS
local DEFAULT_INFO = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CRITICAL_INFO = TweenInfo.new(1.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)

------------------//TYPES
type PopupOptions = {
	Duration: number?,
	Direction: Vector3?, -- Direção do movimento (ex: Vector3.new(2, 5, 0))
	IsCritical: boolean?, -- Se true, o texto treme e é maior
	Spread: number?, -- O quanto ele espalha aleatoriamente para os lados
	StartOffset: Vector3?, 
	FontSize: number?
}

------------------//MAIN FUNCTIONS
function PopupModule.Create(target: BasePart, text: string, color: Color3, options: PopupOptions?)
	if not target then return end

	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return end

	options = options or {}

	local duration = options.Duration or 1
	local isCritical = options.IsCritical or false
	local fontSize = options.FontSize or (isCritical and 50 or 35)
	local spread = options.Spread or 0
	local startOffset = options.StartOffset or Vector3.new(0, 3, 0)

	local baseDirection = options.Direction or Vector3.new(0, 5, 0)
	local randomSpread = Vector3.new(
		math.random(-spread, spread) * 10 / 10,
		0,
		math.random(-spread, spread) * 10 / 10
	)
	local finalOffset = startOffset + baseDirection + randomSpread

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "VFX_Popup"
	billboard.Size = UDim2.new(0, 250, 0, 80)
	billboard.StudsOffset = startOffset
	billboard.Adornee = target
	billboard.AlwaysOnTop = true
	billboard.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Parent = billboard
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = false
	label.TextSize = 0 

	local tweenInfo = isCritical and CRITICAL_INFO or DEFAULT_INFO

	-- 1. Movimento e Fade
	local moveTween = TweenService:Create(billboard, tweenInfo, {
		StudsOffset = finalOffset
	})

	local textTween = TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextSize = fontSize
	})

	if isCritical then
		label.Rotation = math.random(-15, 15)
	else
		label.Rotation = math.random(-5, 5)
	end

	moveTween:Play()
	textTween:Play()

	task.delay(duration * 0.7, function()
		if not label or not label.Parent then return end
		local fadeInfo = TweenInfo.new(duration * 0.3, Enum.EasingStyle.Linear)
		TweenService:Create(label, fadeInfo, {
			TextTransparency = 1,
			TextStrokeTransparency = 1
		}):Play()
	end)

	Debris:AddItem(billboard, duration + 0.1)
end

return PopupModule