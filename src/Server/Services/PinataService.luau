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

------------------//CONSTANTS
local RESPAWN_TIME = 3
local DEFAULT_ROPE_LENGTH = 10
local BASE_XP_PER_CANDY = 15

local PINATA_LEVELS = {
	[1] = {
		required_xp = 100,
		model_name = 'Pocket Pinata',
		scale = 1.0,
		hp_multiplier = 1.0,
	},
	[2] = {
		required_xp = 250,
		model_name = 'Lhama_Level2',
		scale = 1.2,
		hp_multiplier = 1.5,
	},
	[3] = {
		required_xp = 500,
		model_name = 'Lhama_Level3',
		scale = 1.5,
		hp_multiplier = 2.5,
	},
}

------------------//PRIVATE FUNCTIONS
local function get_level_data(level: number)
	return PINATA_LEVELS[level] or PINATA_LEVELS[#PINATA_LEVELS]
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

	-- CORREÇÃO AQUI: Trocamos :Listen por .OnServerEvent:Connect
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
		-- Fallback caso a biblioteca use outro nome (ex: .Event)
		warn(
			'[PinataService] Erro: Não foi possível conectar ao evento Feed.'
		)
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

	local template = ReplicatedStorage.Assets.Pinatas:FindFirstChild(
		levelData.model_name
	) or ReplicatedStorage.Assets.Pinatas:FindFirstChild('Lhama_Level1')
	if not template then return end

	local pinata = template:Clone()
	pinata.Name = 'Pinata'
	pinata.Parent = pinataFolder

	local spawnPart = pinataFolder:FindFirstChild('Handle')
		and pinataFolder.Handle:FindFirstChild('End')
	if spawnPart then pinata:PivotTo(spawnPart.CFrame) end

	local maxHealth = 100 * (levelData.hp_multiplier or 1)

	pinata:SetAttribute('Type', 'Pinata')
	pinata:SetAttribute('Level', currentLevel)
	pinata:SetAttribute('MaxHealth', maxHealth)
	pinata:SetAttribute('Health', maxHealth)
	pinata:SetAttribute('IsDead', false)
	pinata:SetAttribute('Scale', levelData.scale or 1)

	if levelData.scale and levelData.scale ~= 1 then
		pinata:ScaleTo(levelData.scale)
	end

	if
		pinataFolder:FindFirstChild('Handle')
		and pinataFolder.Handle:FindFirstChild('RopeConstraint')
	then
		local rope = pinataFolder.Handle.RopeConstraint
		local staticData = PinataData[levelData.model_name]
		rope.Length = staticData and staticData.RopeLength
			or DEFAULT_ROPE_LENGTH
	end

	local weld = Instance.new('WeldConstraint')
	weld.Part0 = pinata.PrimaryPart or pinata:FindFirstChild('Handle')
	weld.Part1 = pinataFolder.Handle.End
	weld.Parent = pinata

	-- Cria o Prompt (Desligado por padrão)
	local prompt = Instance.new('ProximityPrompt')
	prompt.Name = 'FeedPrompt'
	prompt.ActionText = 'Feed Candy'
	prompt.ObjectText = 'Pinata'
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 20
	prompt.Enabled = false
	prompt.Parent = pinata.PrimaryPart or pinata:FindFirstChild('Handle')
end

function module:Feed(player: Player, toolName: string)
    local character = player.Character
    local tool = character and character:FindFirstChild(toolName)

    if not tool then return end

    local candyLevel = tool:GetAttribute('Level') or 1
    local currentLevel = PlayerDataManager:Get(player, { 'Pinata', 'Level' }) or 1
    local currentXP = PlayerDataManager:Get(player, { 'Pinata', 'XP' }) or 0
    local levelData = get_level_data(currentLevel)

    local xpAmount = BASE_XP_PER_CANDY * candyLevel
    local newTotalXP = currentXP + xpAmount

    tool:Destroy()

    local metaPlayer = MetaPlayer.Get(player)
    if metaPlayer and metaPlayer.Cache.Plot then
        local pinataFolder = metaPlayer.Cache.Plot:FindFirstChild('Pinata')
        local pinata = pinataFolder and (
            pinataFolder:FindFirstChild('Pinata') or pinataFolder:FindFirstChildWhichIsA('Model')
        )

        if pinata and pinata.PrimaryPart then
            local packetData = {
                Type = 'pinata_feed',
                XPAdded = xpAmount,
                CurrentXP = newTotalXP,
                MaxXP = levelData.required_xp,
                Level = currentLevel
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

	local coins = math.floor(damage * 0.5)
	if coins > 0 then
		PlayerDataManager:Increment(player, { 'Currency', 'Coins' }, coins)
	end

	if newHealth <= 0 then self:Break(player, pinataModel) end
end

function module:Break(player: Player, pinataModel: Model)
	pinataModel:SetAttribute('IsDead', true)
	local level = pinataModel:GetAttribute('Level') or 1
	local bonus = level * 50

	PlayerDataManager:Increment(player, { 'Currency', 'Coins' }, bonus)

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
	local newXP = currentXP + amount

	if newXP >= levelData.required_xp then
		local overflow = newXP - levelData.required_xp
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
