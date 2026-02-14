local module = {}

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Short = require(ReplicatedStorage.Modules.Core.Short)

local PLAYER = Players.LocalPlayer
local VFX_FOLDER = ReplicatedStorage.Assets:WaitForChild("VFX")

local function FormatNumber(num: number)
	if type(Short) == "table" and Short.Abbreviate then
		return Short:Abbreviate(num, 1000, 2)
	end
	return tostring(num)
end

local function PlayVFX(vfxName: string, targetCFrame: CFrame)
	local template = VFX_FOLDER:FindFirstChild(vfxName)
	if not template then return end

	local vfxPart = template:Clone()
	vfxPart.CFrame = targetCFrame
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

local function GetLocalPinata()
	local map = workspace:FindFirstChild("Map")
	if not map then return nil end

	local plotsFolder = map:FindFirstChild("Plots")
	if not plotsFolder then return nil end

	for _, p in plotsFolder:GetChildren() do
		if p:GetAttribute("Owner") == PLAYER.UserId then
			local pinataFolder = p:FindFirstChild("Pinata")
			if pinataFolder then
				return pinataFolder:FindFirstChild("Pinata") or pinataFolder:FindFirstChildWhichIsA("Model")
			end
		end
	end
	return nil
end

local function CreateFloatingXP(position: Vector3, amountText: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "XPIndicator"
	billboard.Size = UDim2.fromScale(3, 3)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
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
	textLabel.Text = "+" .. amountText .. " XP"
	textLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
	textLabel.TextStrokeTransparency = 0
	textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	textLabel.TextScaled = true
	textLabel.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Parent = textLabel

	billboard.Parent = workspace.Terrain

	local targetPos = position + Vector3.new(0, 4, 0)
	TweenService:Create(part, TweenInfo.new(1), { Position = targetPos }):Play()
	TweenService:Create(textLabel, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

	Debris:AddItem(part, 1)
	Debris:AddItem(billboard, 1)
end

local function UpdateXPBar(model: Model, currentXP: number, requiredXP: number, level: number)
	local head = model.PrimaryPart or model:FindFirstChild("Handle")
	if not head then return end

	local billboard = model:FindFirstChild("XPBarGui") or model:FindFirstChild("LevelBar")
	local levelBar = nil

	if not billboard then
		local playerGui = PLAYER:FindFirstChild("PlayerGui")
		local template = playerGui and playerGui:FindFirstChild("Main") and playerGui.Main:FindFirstChild("LevelBar")

		if template then
			levelBar = template:Clone()
			levelBar.Name = "LevelBar"

			if levelBar:IsA("GuiObject") then
				levelBar.Size = UDim2.fromScale(1, 1)
				levelBar.Position = UDim2.fromScale(0, 0)
				levelBar.Visible = true
				
				billboard = Instance.new("BillboardGui")
				billboard.Name = "XPBarGui"
				billboard.Size = UDim2.fromScale(6, 1.5)
				billboard.StudsOffset = Vector3.new(0, 7.5, 0)
				billboard.AlwaysOnTop = true
				levelBar.Parent = billboard
				billboard.Parent = model
			elseif levelBar:IsA("BillboardGui") then
				billboard = levelBar
				billboard.AlwaysOnTop = true
				billboard.Parent = model
			end
		end
	else
		if billboard:IsA("BillboardGui") and billboard.Name == "LevelBar" then
			levelBar = billboard
		else
			levelBar = billboard:FindFirstChild("LevelBar")
		end
	end

	if not levelBar then return end

	local levelText = levelBar:FindFirstChild("Level", true)
	local xpText = levelBar:FindFirstChild("XP", true)
	local barFrame = levelBar:FindFirstChild("BarFrame", true)

	if levelText and levelText:IsA("TextLabel") then
		levelText.Text = "Level " .. FormatNumber(level)
	end

	if xpText and xpText:IsA("TextLabel") then
		local formattedCurrent = FormatNumber(currentXP)
		local formattedMax = FormatNumber(requiredXP)
		xpText.RichText = true
		xpText.Text = string.format('%s <font size="10" color="rgb(50,150,255)">XP</font> / %s <font size="10" color="rgb(50,150,255)">XP</font>', formattedCurrent, formattedMax)
	end

	if barFrame and barFrame:IsA("GuiObject") then
		local percent = math.clamp(currentXP / requiredXP, 0, 1)
		TweenService:Create(barFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(percent, 1)
		}):Play()
	end

	if billboard then
		billboard.Enabled = true
	end
end

function module:Start(data)
	if not data then return end
	
	local xpAdded = tonumber(data.XPAdded) or 0
	local currentXP = data.CurrentXP or 0
	local maxXP = data.MaxXP or 100
	local level = data.Level or 1
	
	local model = GetLocalPinata()
	if model then
		UpdateXPBar(model, currentXP, maxXP, level)
		
		if xpAdded > 0 then
			local pos = model.PrimaryPart and model.PrimaryPart.Position or model:GetPivot().Position
			
			local character = PLAYER.Character
			if character then
				local targetCFrame = nil
				
				local tool = character:FindFirstChildWhichIsA("Tool")
				if tool then
					local handle = tool.PrimaryPart or tool:FindFirstChild("Handle")
					if handle then
						targetCFrame = handle.CFrame
					end
				end
				
				if not targetCFrame then
					local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
					if hand then
						targetCFrame = hand.CFrame
					end
				end
				
				if targetCFrame then
					PlayVFX("CandyDisappear", targetCFrame)
				end
			end

			CreateFloatingXP(pos, FormatNumber(xpAdded))
		end
	end
end

return module
