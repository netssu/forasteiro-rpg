local module = {}

-- // SERVICES
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

-- // CONSTANTS
local BAR_LIFETIME = 3
local PLAYER = Players.LocalPlayer
local HIDE_TWEENS = {}

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

	-- UIStroke para deixar o texto gordinho
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

	local billboard = model:FindFirstChild("XPBarGui")
	local isNew = false

	if not billboard then
		isNew = true
		billboard = Instance.new("BillboardGui")
		billboard.Name = "XPBarGui"
		billboard.Size = UDim2.fromScale(7, 1.4) -- Bem maior
		billboard.StudsOffset = Vector3.new(0, 7.5, 0) -- Mais alto
		billboard.AlwaysOnTop = true
		
		-- Container Principal (Borda Branca)
		local container = Instance.new("Frame")
		container.Name = "Container"
		container.Size = UDim2.fromScale(1, 0.5) -- A barra ocupa metade do billboard
		container.Position = UDim2.fromScale(0, 0.5)
		container.BackgroundColor3 = Color3.fromRGB(30, 30, 45) -- Fundo escuro
		container.BorderSizePixel = 0
		container.Parent = billboard
		
		local containerCorner = Instance.new("UICorner")
		containerCorner.CornerRadius = UDim.new(1, 0) -- Pílula
		containerCorner.Parent = container
		
		local containerStroke = Instance.new("UIStroke")
		containerStroke.Color = Color3.fromRGB(255, 255, 255)
		containerStroke.Thickness = 4
		containerStroke.Parent = container

		-- Barra de Preenchimento
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = Color3.fromRGB(0, 200, 255) -- Azul Neon
		fill.BorderSizePixel = 0
		fill.Parent = container
		
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill
		
		-- Brilho interno (Opcional)
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 200, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 240, 255))
		}
		gradient.Rotation = 90
		gradient.Parent = fill

		-- Texto de Level
		local text = Instance.new("TextLabel")
		text.Name = "InfoText"
		text.Size = UDim2.fromScale(1, 0.8) -- Texto grande
		text.Position = UDim2.fromScale(0, -0.9) -- Acima da barra
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.TextScaled = true
		text.Parent = billboard
		
		local textStroke = Instance.new("UIStroke")
		textStroke.Thickness = 3
		textStroke.Parent = text

		billboard.Parent = model
		
		-- Animação de Entrada (Pop)
		billboard.Size = UDim2.fromScale(0, 0)
		TweenService:Create(billboard, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(7, 1.4)
		}):Play()
	end

	local percent = math.clamp(currentXP / requiredXP, 0, 1)
	local container = billboard:FindFirstChild("Container")
	local fill = container and container:FindFirstChild("Fill")
	local text = billboard:FindFirstChild("InfoText")

	if text then
		text.Text = string.format("LEVEL %d  [%d/%d]", level, math.floor(currentXP), math.floor(requiredXP))
	end
	
	if fill then
		TweenService:Create(fill, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(percent, 1)
		}):Play()
	end

	billboard.Enabled = true
	
	if HIDE_TWEENS[model] then
		task.cancel(HIDE_TWEENS[model])
	end

	HIDE_TWEENS[model] = task.delay(BAR_LIFETIME, function()
		if billboard and billboard.Parent then
			-- Animação de Saída
			local tween = TweenService:Create(billboard, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Size = UDim2.fromScale(0, 0)
			})
			tween:Play()
			tween.Completed:Connect(function()
				billboard.Enabled = false
				billboard.Size = UDim2.fromScale(7, 1.4) -- Reseta tamanho para a próxima
			end)
		end
		HIDE_TWEENS[model] = nil
	end)
end

-- // MAIN FUNCTION
function module:Start(data)
	if not data then return end
	
	local xpAdded = data.XPAdded or "0"
	local currentXP = data.CurrentXP or 0
	local maxXP = data.MaxXP or 100
	local level = data.Level or 1
	
	local model = GetLocalPinata()
	if model then
		local pos = model.PrimaryPart.Position
		CreateFloatingXP(pos, xpAdded)
		UpdateXPBar(model, currentXP, maxXP, level)
	end
end

return module