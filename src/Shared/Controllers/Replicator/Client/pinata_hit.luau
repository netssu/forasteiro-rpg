local module = {}

-- // SERVICES
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

-- // CONSTANTS
local TEXT_LIFETIME = 0.8
local PLAYER = Players.LocalPlayer

-- // PRIVATE FUNCTIONS
local function GetLocalPinata()
	local map = workspace:FindFirstChild("Map")
	if not map then return nil end

	local plotsFolder = map:FindFirstChild("Plots")
	if not plotsFolder then return nil end

	local plot = nil
	
	for _, p in plotsFolder:GetChildren() do
		if p:GetAttribute("Owner") == PLAYER.UserId then
			plot = p
			break
		end
	end

	if plot then
		local pinataFolder = plot:FindFirstChild("Pinata")
		if pinataFolder then
			return pinataFolder:FindFirstChild("Pinata") or pinataFolder:FindFirstChildWhichIsA("Model")
		end
	end
	
	return nil
end

local function CreateDamageText(position: Vector3, amount: number, isCrit: boolean)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageIndicator"
	billboard.Size = UDim2.fromScale(2.5, 2.5)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position
	part.Parent = workspace.Terrain
	billboard.Adornee = part
	
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.Text = amount
	textLabel.TextColor3 = isCrit and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 255, 255)
	textLabel.TextStrokeTransparency = 0
	textLabel.TextStrokeColor3 = Color3.new(0,0,0)
	textLabel.TextScaled = true
	textLabel.Parent = billboard
	
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0
	uiScale.Parent = textLabel
	
	billboard.Parent = workspace.Terrain
	
	local targetPos = position + Vector3.new(math.random(-1,1), 4.5, math.random(-1,1))
	
	TweenService:Create(uiScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.2 }):Play()
	TweenService:Create(part, TweenInfo.new(TEXT_LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = targetPos }):Play()
	
	task.delay(TEXT_LIFETIME * 0.5, function()
		TweenService:Create(textLabel, TweenInfo.new(TEXT_LIFETIME * 0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	
	Debris:AddItem(part, TEXT_LIFETIME)
	Debris:AddItem(billboard, TEXT_LIFETIME)
end

local function HighlightTarget(model: Model)
	local oldHighlight = model:FindFirstChild("HitHighlight")
	if oldHighlight then oldHighlight:Destroy() end

	local highlight = Instance.new("Highlight")
	highlight.Name = "HitHighlight"
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.2
	highlight.OutlineTransparency = 0.5
	highlight.Parent = model
	
	local tween = TweenService:Create(highlight, TweenInfo.new(0.25), { FillTransparency = 1, OutlineTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		highlight:Destroy()
	end)
end

local function BumpTarget(model: Model)
	if model:GetAttribute("Tweening") then return end
	model:SetAttribute("Tweening", true)

	local baseScale = model:GetAttribute("Scale") or 1
	local targetScale = baseScale * 1.15
	
	model:ScaleTo(targetScale)
	
	task.delay(0.08, function()
		if model and model.Parent then
			model:ScaleTo(baseScale)
			model:SetAttribute("Tweening", false)
		end
	end)
end

local function SpawnParticles(position: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxassetid://14111878332"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 200))
	emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0)})
	emitter.Lifetime = NumberRange.new(0.3, 0.5)
	emitter.Speed = NumberRange.new(15, 25)
	emitter.SpreadAngle = Vector2.new(360, 360)
	emitter.Drag = 5
	emitter.Parent = attachment
	
	emitter:Emit(8)
	Debris:AddItem(attachment, 1)
end

-- // MAIN FUNCTION
function module:Start(data)
	if not data or not data.Position then return end
	
	local position = data.Position
	local damage = data.Damage or 0
	CreateDamageText(position, damage, damage > 10)
	SpawnParticles(position)
	
	local model = GetLocalPinata()
	if model then
		HighlightTarget(model)
		BumpTarget(model)
	end
end

return module