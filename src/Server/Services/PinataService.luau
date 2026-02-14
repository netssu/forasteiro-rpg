local module = {}

------------------//SERVICES
local HttpService = game:GetService('HttpService')
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')

------------------//DEPENDENCIES
local MetaPlayer = require(ServerScriptService.Modules.Core.MetaPlayer)
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local PinataData = require(ReplicatedStorage.Modules.Constants.PinataData)
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local PlotmeService = require(ServerScriptService.Services.PlotmeService)
local WeaponData = require(ReplicatedStorage.Modules.Constants.WeaponsData)

------------------//CONSTANTS
local RESPAWN_TIME = 3
local DEFAULT_ROPE_LENGTH = 20

------------------//PRIVATE FUNCTIONS
local function get_level_data(level: number)
	if PinataData[level] then return PinataData[level] end

	local maxLevel = 1
	for lvl, _ in pairs(PinataData) do
		if type(lvl) == 'number' and lvl > maxLevel then maxLevel = lvl end
	end

	return PinataData[maxLevel] or PinataData[1]
end

local function clean_pinata(plot: Model)
	local pinataFolder = plot:FindFirstChild('Pinata')
	if pinataFolder then
		local old = pinataFolder:FindFirstChild('Pinata')
			or pinataFolder:FindFirstChild('Model')
		if old then old:Destroy() end
	end
end

local function SendPacket(player: Player, jsonString: string)
	if Packets.Replicator.FireClient then
		Packets.Replicator:FireClient(player, jsonString)
	elseif Packets.Replicator.SendTo then
		Packets.Replicator:SendTo(player, jsonString)
	else
		Packets.Replicator:Fire(player, jsonString)
	end
end

------------------//PUBLIC FUNCTIONS
function module:Init()
	PlotmeService.Signals.AssignPlot:Connect(function(metaPlayer)
		module.CreatePinata(metaPlayer)
	end)

	if Packets.Feed.OnServerEvent then
		Packets.Feed.OnServerEvent:Connect(function(player, jsonString)
			local success, data = pcall(function()
				return HttpService:JSONDecode(jsonString)
			end)
			if success and data and data.ToolName then
				module:Feed(player, data.ToolName)
			end
		end)
	else
		warn(
			'[PinataService] Erro: Não foi possível conectar ao evento Feed.'
		)
	end

	if Packets.Action.OnServerEvent then
		Packets.Action.OnServerEvent:Connect(function(player, jsonString)
			local success, data = pcall(function()
				return HttpService:JSONDecode(jsonString)
			end)
			if success and data and data.Type == 'Hit' and data.ToolName then
				module:ProcessHit(player, data.ToolName)
			end
		end)
	end
end

function module.CreatePinata(metaPlayer)
	local player = metaPlayer.Instance
	local plot = metaPlayer.Cache.Plot
	local pinataFolder = plot and plot:FindFirstChild('Pinata')
	if not pinataFolder then return end

	clean_pinata(plot)

	local currentLevel = PlayerDataManager:Get(player, { 'Pinata', 'Level' })
		or 1
	local levelData = get_level_data(currentLevel)

	if not levelData then
		warn(
			'[PinataService] CRITICAL: Dados do nível '
				.. tostring(currentLevel)
				.. ' não encontrados.'
		)
		return
	end

	local template = ReplicatedStorage.Assets.Pinatas:FindFirstChild(
		levelData.ModelName
	) or ReplicatedStorage.Assets.Pinatas:FindFirstChild('Lhama_Level1')

	if not template then
		warn(
			'[PinataService] Modelo não encontrado: '
				.. tostring(levelData.ModelName)
		)
		return
	end

	local pinata = template:Clone()
	pinata.Name = 'Pinata'
	pinata.Parent = pinataFolder

	local spawnPart = pinataFolder:FindFirstChild('Handle')
		and pinataFolder.Handle:FindFirstChild('End')
	if spawnPart then pinata:PivotTo(spawnPart.CFrame) end

	local maxHealth = levelData.MaxHealth

	pinata:SetAttribute('Type', 'Pinata')
	pinata:SetAttribute('Level', currentLevel)
	pinata:SetAttribute('MaxHealth', maxHealth)
	pinata:SetAttribute('Health', maxHealth)
	pinata:SetAttribute('IsDead', false)
	--[[ 	pinata:SetAttribute('Scale', levelData.Scale or 1)

	if levelData.Scale and levelData.Scale ~= 1 then
		pinata:ScaleTo(levelData.Scale)
	end *]]

	if
		pinataFolder:FindFirstChild('Handle')
		and pinataFolder.Handle:FindFirstChild('RopeConstraint')
	then
		local rope = pinataFolder.Handle.RopeConstraint
		rope.Length = levelData.RopeLength or DEFAULT_ROPE_LENGTH
	end

	local weld = Instance.new('WeldConstraint')
	weld.Part0 = pinata.PrimaryPart or pinata:FindFirstChild('Handle')
	weld.Part1 = pinataFolder.Handle.End
	weld.Parent = pinata

	local rootPart = pinata.PrimaryPart or pinata:FindFirstChild('Handle')

	local promptPart = rootPart:Clone()
	promptPart:ClearAllChildren()
	promptPart.Name = 'PromptPart'
	promptPart.Transparency = 1
	promptPart.CanCollide = false
	promptPart.Massless = true
	promptPart.CFrame = rootPart.CFrame * CFrame.new(0, -5, 0)
	promptPart.Parent = pinata

	local weld = Instance.new('WeldConstraint')
	weld.Part0 = rootPart
	weld.Part1 = promptPart
	weld.Parent = promptPart

	local prompt = Instance.new('ProximityPrompt')
	prompt.Name = 'FeedPrompt'
	prompt.ActionText = 'Feed Candy'
	prompt.ObjectText = 'Pinata'
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 20
	prompt.Enabled = false
	prompt.Parent = promptPart

	local currentXP = PlayerDataManager:Get(player, { 'Pinata', 'XP' }) or 0
	local initPacket = {
		Type = 'pinata_feed',
		XPAdded = 0,
		CurrentXP = currentXP,
		MaxXP = levelData.RequiredXP,
		Level = currentLevel,
	}
	SendPacket(player, HttpService:JSONEncode(initPacket))
end

function module:ProcessHit(player: Player, toolName: string)
	local stats = WeaponData[toolName]
	if not stats then return end

	local character = player.Character
	local equippedTool = character and character:FindFirstChild(toolName)
	if not equippedTool then return end

	local metaPlayer = MetaPlayer.Get(player)
	if metaPlayer and metaPlayer.Cache.Plot then
		local pinataFolder = metaPlayer.Cache.Plot:FindFirstChild('Pinata')
		local pinata = pinataFolder
			and (
				pinataFolder:FindFirstChild('Pinata')
				or pinataFolder:FindFirstChildWhichIsA('Model')
			)

		if pinata then self:ApplyDamage(player, pinata, stats.Damage) end
	end
end

function module:Feed(player: Player, toolName: string)
	local character = player.Character
	local tool = character and character:FindFirstChild(toolName)
	if not tool then return end

	local candyLevel = tool:GetAttribute('XP') or 1
	local currentLevel = PlayerDataManager:Get(player, { 'Pinata', 'Level' })
		or 1
	local currentXP = PlayerDataManager:Get(player, { 'Pinata', 'XP' }) or 0

	local levelData = get_level_data(currentLevel)
	if not levelData then return end

	local xpAmount = candyLevel
	local newTotalXP = currentXP + xpAmount

	tool:Destroy()

	local metaPlayer = MetaPlayer.Get(player)
	if metaPlayer and metaPlayer.Cache.Plot then
		local pinataFolder = metaPlayer.Cache.Plot:FindFirstChild('Pinata')
		local pinata = pinataFolder
			and (
				pinataFolder:FindFirstChild('Pinata')
				or pinataFolder:FindFirstChildWhichIsA('Model')
			)

		if pinata and pinata.PrimaryPart then
			local packetData = {
				Type = 'pinata_feed',
				XPAdded = xpAmount,
				CurrentXP = newTotalXP,
				MaxXP = levelData.RequiredXP,
				Level = currentLevel,
			}
			SendPacket(player, HttpService:JSONEncode(packetData))
		end
	end

	self:AddXP(player, xpAmount, false)
end

function module:ApplyDamage(player: Player, pinataModel: Model, damage: number)
	local currentHealth = pinataModel:GetAttribute('Health') or 0
	local isDead = pinataModel:GetAttribute('IsDead')
	if isDead or currentHealth <= 0 then return end

	local newHealth = math.max(0, currentHealth - damage)
	pinataModel:SetAttribute('Health', newHealth)

	local pos = pinataModel.PrimaryPart and pinataModel.PrimaryPart.Position
		or Vector3.zero
	local packetData = {
		Type = 'pinata_hit',
		Position = { X = pos.X, Y = pos.Y, Z = pos.Z },
		Damage = damage,
	}

	SendPacket(player, HttpService:JSONEncode(packetData))

	--pinata model shake
	pinataModel.PrimaryPart:ApplyImpulse(Vector3.new(
		math.random(-10, 10),
		math.random(5, 15),
		math.random(-10, 10)
	))

	if newHealth <= 0 then self:Break(player, pinataModel) end
end
function module:Break(player: Player, pinataModel: Model)
	pinataModel:SetAttribute('IsDead', true)

	local currentLevel = PlayerDataManager:Get(player, { 'Pinata', 'Level' })
		or 1
	local levelData = get_level_data(currentLevel)

	if levelData and levelData.Drops and levelData.Drops.Coins then
		local coinsMin = levelData.Drops.Coins.Min
		local coinsMax = levelData.Drops.Coins.Max
		local coinsReward = math.random(coinsMin, coinsMax)
		PlayerDataManager:Increment(
			player,
			{ 'Currency', 'Coins' },
			coinsReward
		)
	end

	local pos = pinataModel.PrimaryPart and pinataModel.PrimaryPart.Position
		or Vector3.zero
	local packetData = {
		Type = 'pinata_destroy',
		Position = { X = pos.X, Y = pos.Y, Z = pos.Z },
	}

	SendPacket(player, HttpService:JSONEncode(packetData))

	pinataModel:Destroy()

	task.delay(RESPAWN_TIME, function()
		if player and player.Parent then
			local metaPlayer = MetaPlayer.Get(player)
			if metaPlayer then module.CreatePinata(metaPlayer) end
		end
	end)
end

function module:AddXP(player: Player, amount: number, skipRespawn: boolean)
	local currentLevel = PlayerDataManager:Get(player, { 'Pinata', 'Level' })
		or 1
	local currentXP = PlayerDataManager:Get(player, { 'Pinata', 'XP' }) or 0

	local levelData = get_level_data(currentLevel)
	if not levelData then return end

	local newXP = currentXP + amount

	if newXP >= levelData.RequiredXP then
		local overflow = newXP - levelData.RequiredXP
		PlayerDataManager:Set(player, { 'Pinata', 'Level' }, currentLevel + 1)
		PlayerDataManager:Set(player, { 'Pinata', 'XP' }, overflow)

		if not skipRespawn then
			local metaPlayer = MetaPlayer.Get(player)
			if metaPlayer then module.CreatePinata(metaPlayer) end
		end
	else
		PlayerDataManager:Set(player, { 'Pinata', 'XP' }, newXP)
	end
end

return module
