local module = {}

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abbreviate = require(ReplicatedStorage.Modules.Math.Abbreviate)

local TEXT_LIFETIME = 0.8
local PLAYER = Players.LocalPlayer
local VFX_FOLDER = ReplicatedStorage.Assets:WaitForChild("VFX")

local function FormatNumber(num: number)
	if type(Abbreviate) == "function" then
		return Abbreviate(num)
	elseif type(Abbreviate) == "table" and Abbreviate.Format then
		return Abbreviate:Format(num)
	elseif type(Abbreviate) == "table" and Abbreviate.abbreviate then
		return Abbreviate.abbreviate(num)
	end
	return tostring(num)
end

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
	textLabel.Text = FormatNumber(amount)
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
	highlight.FillColor = Color3.fromRGB(255, 50, 50)
	highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
	highlight.FillTransparency = 0.2
	highlight.OutlineTransparency = 0.2
	highlight.Parent = model
	
	local tween = TweenService:Create(highlight, TweenInfo.new(0.25), { FillTransparency = 1, OutlineTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		highlight:Destroy()
	end)
end

local function PhysicalShake(model: Model)
	local primary = model.PrimaryPart
	if primary and primary:IsA("BasePart") then
		local force = Vector3.new(
			math.random(-15, 15),
			math.random(10, 25),
			math.random(-15, 15)
		)
		primary:ApplyImpulse(force * primary.AssemblyMass)
	end
end

local function PlayVFX(vfxName: string, targetCFrame: CFrame)
	local template = VFX_FOLDER:FindFirstChild(vfxName)
	if not template then return end

	local vfxPart = template:Clone()
	vfxPart.CFrame = targetCFrame - Vector3.new(0, 3.5 , 0)
	vfxPart.Anchored = true
	vfxPart.CanCollide = false
	vfxPart.Parent = workspace.Terrain

	for _, child in vfxPart:GetDescendants() do
		if child:IsA("ParticleEmitter") then
			local count = child:GetAttribute("EmitCount") or 20 
			child:Emit(count)
		end
	end

	Debris:AddItem(vfxPart, 2)
end

function module:Start(data)
	if not data or not data.Position then return end
	
	local posData = data.Position
	local position = Vector3.new(posData.X, posData.Y, posData.Z)
	local damage = data.Damage or 0
	
	if damage > 0 then
		CreateDamageText(position, damage, false)
		PlayVFX("HitPinata", CFrame.new(position))
	end
	
	local model = GetLocalPinata()
	if model then
		HighlightTarget(model)
		PhysicalShake(model)
	end
end

return module