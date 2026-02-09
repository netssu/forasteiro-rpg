local module = {}

-- // SERVICES
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

-- // CONSTANTS
local PLAYER = Players.LocalPlayer
local BAR_LIFETIME = 3 -- Tempo que a barra fica visível após alimentar
local BAR_SIZE = UDim2.fromScale(4, 0.6)
local BAR_OFFSET = Vector3.new(0, 4, 0) -- Altura acima da Pinata

-- // VARIABLES
local activeBar = nil -- Guarda a referência da barra ativa para não criar várias
local hideTask = nil -- Guarda a tarefa de esconder para resetar o timer

-- // PRIVATE FUNCTIONS
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

local function CreateFloatingText(position: Vector3, text: string)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position
	part.Parent = workspace.Terrain
	
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(2, 2)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = part
	billboard.Parent = workspace.Terrain
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(100, 200, 255) -- Azul Claro
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Parent = billboard
	
	-- Animação Subindo
	local targetPos = position + Vector3.new(0, 3, 0)
	TweenService:Create(part, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = targetPos }):Play()
	TweenService:Create(label, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	
	Debris:AddItem(part, 1)
	Debris:AddItem(billboard, 1)
end

local function UpdateXPBar(pinata: Model, currentXP: number, maxXP: number)
	-- Se já existe uma barra ativa na pinata certa, usa ela
	if activeBar and activeBar.Adornee == pinata.PrimaryPart then
		-- Apenas reinicia o timer de esconder
	else
		-- Se não existe ou é de outra pinata, destrói a antiga e cria nova
		if activeBar then activeBar:Destroy() end
		
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "XPBar"
		billboard.Size = BAR_SIZE
		billboard.StudsOffset = BAR_OFFSET
		billboard.AlwaysOnTop = true
		billboard.Adornee = pinata.PrimaryPart
		
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 0.3)
		bg.Position = UDim2.fromScale(0, 0.35)
		bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		bg.BorderSizePixel = 0
		bg.Parent = billboard
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = bg
		
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(0, 1) -- Começa vazio
		fill.BackgroundColor3 = Color3.fromRGB(50, 150, 255) -- Azul XP
		fill.BorderSizePixel = 0
		fill.Parent = bg
		
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill
		
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1.5)
		text.Position = UDim2.fromScale(0, -1.6)
		text.BackgroundTransparency = 1
		text.Text = "Level Up Progress"
		text.TextColor3 = Color3.new(1,1,1)
		text.TextStrokeTransparency = 0
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.Parent = billboard
		
		billboard.Parent = Players.LocalPlayer.PlayerGui
		activeBar = billboard
		
		-- Animação de Entrada (Scale)
		billboard.Size = UDim2.fromScale(0, 0)
		TweenService:Create(billboard, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = BAR_SIZE }):Play()
	end
	
	-- Atualiza o Preenchimento
	local percent = math.clamp(currentXP / maxXP, 0, 1)
	local fillFrame = activeBar:FindFirstChild("Frame"):FindFirstChild("Fill")
	
	TweenService:Create(fillFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { 
		Size = UDim2.fromScale(percent, 1) 
	}):Play()
	
	-- Gerencia o desaparecimento
	if hideTask then task.cancel(hideTask) end
	hideTask = task.delay(BAR_LIFETIME, function()
		if activeBar then
			local tween = TweenService:Create(activeBar, TweenInfo.new(0.5), { Size = UDim2.fromScale(0, 0) })
			tween:Play()
			tween.Completed:Connect(function()
				if activeBar then activeBar:Destroy() end
				activeBar = nil
			end)
		end
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

-- // MAIN FUNCTION
function module:Start(data)
	-- data espera: { ToolName="Candy", XPAdded=15, CurrentXP=50, MaxXP=100, Position=Vector3 }
	if not data then return end
	
	local pinata = GetLocalPinata()
	if not pinata then return end
	
	local pos = pinata.PrimaryPart.Position
	
	-- 1. Texto Flutuante "+15 XP"
	if data.XPAdded then
		CreateFloatingText(pos, "+" .. data.XPAdded .. " XP")
	end
	
	-- 2. Barra de XP
	if data.CurrentXP and data.MaxXP then
		UpdateXPBar(pinata, data.CurrentXP, data.MaxXP)
	end
	
	-- 3. Efeito físico (Bump)
	BumpTarget(pinata)
end

return module