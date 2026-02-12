------------------//SERVICES
local Players: Players = game:GetService("Players")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris: Debris = game:GetService("Debris")

------------------//MODULES
local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility)

------------------//CONSTANTS
local STUDS_TO_METERS: number = 0.28
local RNG_MOD: number = 4294967296
local SYNC_FPS: number = 60

local MONEY_CHAR_WIDTH_MULT: number = 0.15
local POPUP_PADDING_X_MONEY: number = 10

-- Configuração de Cores
local COLOR_WHITE = Color3.fromRGB(255, 255, 255)
local COLOR_MONEY_FLASH = Color3.fromRGB(150, 255, 150) -- Verde claro
local COLOR_POWER_FLASH = Color3.fromRGB(90, 200, 255)  -- Azul claro
local COLOR_REBIRTH_FLASH = Color3.fromRGB(200, 160, 255) -- Roxo claro

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")
local hud: ScreenGui = playerGui:WaitForChild("UI"):WaitForChild("GameHUD")

local infosFrame: Frame = hud:WaitForChild("Infos")

-- Money
local moneyLabel: TextLabel = infosFrame:WaitForChild("Money")
local moneyScale: UIScale = moneyLabel:WaitForChild("UIScale")

-- Height
local heightLabel: TextLabel = infosFrame:WaitForChild("Height")

-- Power
local powerLabel: TextLabel = infosFrame:WaitForChild("Power")
local powerScale: UIScale = powerLabel:FindFirstChild("UIScale") :: UIScale
if not powerScale then
	powerScale = Instance.new("UIScale")
	powerScale.Scale = 1
	powerScale.Parent = powerLabel
end
local powerProxy = Instance.new("NumberValue")
powerProxy.Name = "PowerDisplayProxy"
powerProxy.Value = 0

-- Rebirth
local rebirthLabel: TextLabel = infosFrame:WaitForChild("Rebirth")
local rebirthScale: UIScale = rebirthLabel:FindFirstChild("UIScale") :: UIScale
if not rebirthScale then
	rebirthScale = Instance.new("UIScale")
	rebirthScale.Scale = 1
	rebirthScale.Parent = rebirthLabel
end

local character: Model = player.Character or player.CharacterAdded:Wait()
local rootPart: BasePart = character:WaitForChild("HumanoidRootPart")
local humanoid: Humanoid = character:WaitForChild("Humanoid")

local currentCoins: number = 0
local currentPower: number = 0
local currentRebirths: number = 0

local activeMoneyTweens: {[string]: Tween} = {}
local activePowerTweens: {[string]: Tween} = {}
local activeRebirthTweens: {[string]: Tween} = {}

------------------//FUNCTIONS
local function sync_seed(): number
	return math.floor(os.clock() * SYNC_FPS)
end

local function rand01(seed: number, salt: number): number
	local x = (seed * 1103515245 + 12345 + salt * 1013904223) % RNG_MOD
	return x / RNG_MOD
end

local function rand_int(seed: number, salt: number, minV: number, maxV: number): number
	local r = rand01(seed, salt)
	return math.floor(minV + r * (maxV - minV + 1))
end

local function set_money_text(value: number): ()
	moneyLabel.Text = "$ " .. tostring(math.floor(value))
end

local function set_rebirth_text(value: number): ()
	rebirthLabel.Text = "Rebirth : " .. tostring(math.floor(value))
end

local function approx_text_width_px(label: TextLabel, mult: number): number
	local text = label.Text or ""
	return #text * (label.TextSize * mult)
end

local function label_local_xy(label: GuiObject, container: GuiObject): (number, number)
	local p = label.AbsolutePosition
	local c = container.AbsolutePosition
	return (p.X - c.X), (p.Y - c.Y)
end

local function update_height(): ()
	if not rootPart or not humanoid then return end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local hit = workspace:Raycast(rootPart.Position, Vector3.new(0, -10000, 0), params)
	local heightStuds = 0
	if hit then
		local offset = humanoid.HipHeight + (rootPart.Size.Y / 2)
		heightStuds = hit.Distance - offset
	end

	heightStuds = math.max(heightStuds, 0)
	local heightMeters = math.floor(heightStuds * STUDS_TO_METERS)
	heightLabel.Text = tostring(heightMeters) .. " m"
end

local function spawn_money_popup(label: TextLabel, amount: number)
	local seed = sync_seed()
	local textColor = Color3.fromRGB(100, 255, 120)
	local strokeColor = Color3.fromRGB(0, 50, 0)

	local popup = Instance.new("TextLabel")
	popup.Name = "MoneyFx"
	popup.Text = "+" .. tostring(math.floor(amount))
	popup.Size = UDim2.new(0, 120, 0, 30)
	popup.BackgroundTransparency = 1
	popup.TextColor3 = textColor
	popup.Font = Enum.Font.FredokaOne
	popup.TextSize = 28
	popup.ZIndex = 10

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = strokeColor
	stroke.Parent = popup

	local baseX, baseY = label_local_xy(label, infosFrame)
	local textWidth = approx_text_width_px(label, MONEY_CHAR_WIDTH_MULT)

	local posX = baseX + textWidth + POPUP_PADDING_X_MONEY + rand_int(seed, 1, 0, 14)
	local posY = baseY + rand_int(seed, 2, -2, 6)
	local rot0 = rand_int(seed, 3, -20, 20)

	popup.Position = UDim2.new(0, posX, 0, posY)
	popup.Rotation = rot0
	popup.Parent = infosFrame

	local pScale = Instance.new("UIScale")
	pScale.Scale = 0
	pScale.Parent = popup

	TweenService:Create(pScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1.2 }):Play()

	local driftX = rand_int(seed, 4, -30, 50)
	local driftY = -rand_int(seed, 5, 40, 60)
	local rot1 = rand_int(seed, 6, -10, 10)

	TweenService:Create(popup, TweenInfo.new(1, Enum.EasingStyle.Quad), {
		Position = popup.Position + UDim2.new(0, driftX, 0, driftY),
		Rotation = popup.Rotation + rot1,
		TextTransparency = 1,
	}):Play()

	TweenService:Create(stroke, TweenInfo.new(1), { Transparency = 1 }):Play()

	Debris:AddItem(popup, 1.1)
end

-- Função genérica para animar qualquer label
local function animate_element(label: TextLabel, scaleObj: UIScale, store: {[string]: Tween}, flashColor: Color3)
	if store["scale"] then store["scale"]:Cancel() end
	if store["rotate"] then store["rotate"]:Cancel() end
	if store["color"] then store["color"]:Cancel() end

	-- 1. Pulo (Scale)
	scaleObj.Scale = 1.25
	local tScale = TweenService:Create(scaleObj, TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 })
	store["scale"] = tScale
	tScale:Play()

	-- 2. Rotação (Tilt)
	label.Rotation = -3
	local tRot = TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Rotation = 0 })
	store["rotate"] = tRot
	tRot:Play()

	-- 3. Cor (Flash)
	label.TextColor3 = flashColor
	local tColor = TweenService:Create(label, TweenInfo.new(0.6), { TextColor3 = COLOR_WHITE })
	store["color"] = tColor
	tColor:Play()
end

-- Função que dispara a animação em TODOS os labels ao mesmo tempo
local function trigger_global_animation()
	animate_element(moneyLabel, moneyScale, activeMoneyTweens, COLOR_MONEY_FLASH)
	animate_element(powerLabel, powerScale, activePowerTweens, COLOR_POWER_FLASH)
	animate_element(rebirthLabel, rebirthScale, activeRebirthTweens, COLOR_REBIRTH_FLASH)
end

local function update_power_visuals(newPower: number)
	if newPower == currentPower then return end

	-- Tween no número
	local numTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local numTween = TweenService:Create(powerProxy, numTweenInfo, { Value = newPower })
	numTween:Play()

	if newPower > currentPower and currentPower > 0 then
		trigger_global_animation() -- Anima os três
	end

	currentPower = newPower
end

powerProxy:GetPropertyChangedSignal("Value"):Connect(function()
	powerLabel.Text = "Jump Power : " .. math.floor(powerProxy.Value)
end)

local function update_money_visuals(newAmount: number)
	local diff = newAmount - currentCoins
	if diff > 0 and currentCoins > 0 then
		spawn_money_popup(moneyLabel, diff)
		trigger_global_animation() -- Anima os três
	end
	currentCoins = newAmount
	set_money_text(newAmount)
end

local function update_rebirth_visuals(newVal: number)
	if newVal == currentRebirths then return end

	if newVal > currentRebirths then
		trigger_global_animation() -- Anima os três
	end

	currentRebirths = newVal
	set_rebirth_text(newVal)
end

------------------//INIT
DataUtility.client.ensure_remotes()

moneyLabel.TextWrapped = false
moneyLabel.TextXAlignment = Enum.TextXAlignment.Left

powerLabel.TextWrapped = false
powerLabel.TextXAlignment = Enum.TextXAlignment.Left
powerLabel.RichText = false
powerLabel.TextColor3 = COLOR_WHITE

rebirthLabel.TextWrapped = false
rebirthLabel.TextXAlignment = Enum.TextXAlignment.Left
rebirthLabel.TextColor3 = COLOR_WHITE

player.CharacterAdded:Connect(function(newChar)
	character = newChar
	rootPart = newChar:WaitForChild("HumanoidRootPart")
	humanoid = newChar:WaitForChild("Humanoid")
end)

RunService.RenderStepped:Connect(update_height)

-- Init Coins
local initialCoins = DataUtility.client.get("Coins") or 0
currentCoins = initialCoins
set_money_text(currentCoins)

-- Init Power
local initialPower = DataUtility.client.get("PogoSettings.base_jump_power") or 0
currentPower = initialPower
powerProxy.Value = initialPower
powerLabel.Text = "Jump Power : " .. math.floor(initialPower)

-- Init Rebirths
local initialRebirths = DataUtility.client.get("Rebirths") or 0
currentRebirths = initialRebirths
set_rebirth_text(currentRebirths)

-- Binds
DataUtility.client.bind("Coins", update_money_visuals)
DataUtility.client.bind("PogoSettings.base_jump_power", update_power_visuals)
DataUtility.client.bind("Rebirths", update_rebirth_visuals)