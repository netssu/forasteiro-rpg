local module = {}

------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

------------------//DEPENDENCIES
local MetaPlayer = require(ServerScriptService.Modules.Core.MetaPlayer)
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local PlotmeService = require(ServerScriptService.Services.PlotmeService)
local PinataData = require(ReplicatedStorage.Modules.Constants.PinataData)

------------------//CONSTANTS
local RESPAWN_TIME = 3
local DEFAULT_ROPE_LENGTH = 10

-- Tabela de Níveis Integrada
local PINATA_LEVELS = {
	[1] = {
		required_xp = 100,
		model_name = "Pocket Pinata",
		scale = 1.0,
		hp_multiplier = 1.0
	},
	[2] = {
		required_xp = 250,
		model_name = "Lhama_Level2", -- Certifique-se que esse modelo existe em Assets ou mude para Level1
		scale = 1.2,
		hp_multiplier = 1.5
	},
	[3] = {
		required_xp = 500,
		model_name = "Lhama_Level3",
		scale = 1.5,
		hp_multiplier = 2.5
	},
}

------------------//PRIVATE FUNCTIONS

local function get_level_data(level: number)
	-- Retorna o nível específico ou o último nível definido (cap)
	return PINATA_LEVELS[level] or PINATA_LEVELS[#PINATA_LEVELS]
end

local function clean_pinata(plot: Model)
	local pinataFolder = plot:FindFirstChild("Pinata")
	if pinataFolder then
		local old = pinataFolder:FindFirstChild("Pinata") or pinataFolder:FindFirstChild("Model")
		if old then old:Destroy() end
	end
end

------------------//PUBLIC FUNCTIONS

function module:Init()
	PlotmeService.Signals.AssignPlot:Connect(function(metaPlayer)
		module.CreatePinata(metaPlayer)
	end)
end

function module.CreatePinata(metaPlayer)
	local player = metaPlayer.Instance
	local plot = metaPlayer.Cache.Plot
	local pinataFolder = plot and plot:FindFirstChild("Pinata")
	
	if not pinataFolder then return end
	
	clean_pinata(plot)
	
	local currentLevel = PlayerDataManager:Get(player, {"Pinata", "Level"}) or 1
	local levelData = get_level_data(currentLevel)
	
	local template = ReplicatedStorage.Assets.Pinatas:FindFirstChild(levelData.model_name) 
		or ReplicatedStorage.Assets.Pinatas:FindFirstChild("Lhama_Level1")
	
	if not template then 
		warn("Nenhum modelo de Pinata encontrado em Assets.")
		return 
	end
	
	local pinata = template:Clone()
	pinata.Name = "Pinata"
	pinata.Parent = pinataFolder
	
	local spawnPart = pinataFolder:FindFirstChild("Handle") and pinataFolder.Handle:FindFirstChild("End")
	if spawnPart then
		pinata:PivotTo(spawnPart.CFrame)
	end
	
	-- 4. Atributos
	local maxHealth = 100 * (levelData.hp_multiplier or 1)
	
	pinata:SetAttribute("Type", "Pinata")
	pinata:SetAttribute("Level", currentLevel)
	pinata:SetAttribute("MaxHealth", maxHealth)
	pinata:SetAttribute("Health", maxHealth)
	pinata:SetAttribute("IsDead", false)
	
	-- 5. Corda (Constraint)
	if pinataFolder:FindFirstChild("Handle") and pinataFolder.Handle:FindFirstChild("RopeConstraint") then
		local rope = pinataFolder.Handle.RopeConstraint
		-- Tenta pegar do PinataData externo ou usa o default local
		local staticData = PinataData[levelData.model_name]
		rope.Length = staticData and staticData.RopeLength or DEFAULT_ROPE_LENGTH
	end

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = pinata.PrimaryPart or pinata:FindFirstChild("Handle")
	weld.Part1 = pinataFolder.Handle.End
	weld.Parent = pinata
end

function module:ApplyDamage(player: Player, pinataModel: Model, damage: number)
	local currentHealth = pinataModel:GetAttribute("Health") or 0
	local isDead = pinataModel:GetAttribute("IsDead")
	
	if isDead or currentHealth <= 0 then return end
	
	local newHealth = math.max(0, currentHealth - damage)
	pinataModel:SetAttribute("Health", newHealth)
	
	-- Feedback
	Packets.Replicator:Fire(player, "pinata_hit", { 
		Pinata = pinataModel,
		Damage = damage 
	})
	
	-- Recompensa (Hit)
	local coins = math.floor(damage * 0.5)
	if coins > 0 then
		PlayerDataManager:Increment(player, {"Currency", "Coins"}, coins)
	end
	
	-- Morte
	if newHealth <= 0 then
		self:Break(player, pinataModel)
	end
end

function module:Break(player: Player, pinataModel: Model)
	pinataModel:SetAttribute("IsDead", true)
	
	-- Bônus (Destruição)
	local level = pinataModel:GetAttribute("Level") or 1
	local bonus = level * 50
	PlayerDataManager:Increment(player, {"Currency", "Coins"}, bonus)
	
	Packets.Replicator:Fire(player, "pinata_destroy", { Pinata = pinataModel })
	
	pinataModel:Destroy()
	
	task.delay(RESPAWN_TIME, function()
		if player and player.Parent then
			local metaPlayer = MetaPlayer.Get(player)
			if metaPlayer then
				module.CreatePinata(metaPlayer)
			end
		end
	end)
end

function module:AddXP(player: Player, amount: number)
	local currentLevel = PlayerDataManager:Get(player, {"Pinata", "Level"}) or 1
	local currentXP = PlayerDataManager:Get(player, {"Pinata", "XP"}) or 0
	
	local levelData = get_level_data(currentLevel)
	local newXP = currentXP + amount
	
	if newXP >= levelData.required_xp then
		local overflow = newXP - levelData.required_xp
		
		PlayerDataManager:Set(player, {"Pinata", "Level"}, currentLevel + 1)
		PlayerDataManager:Set(player, {"Pinata", "XP"}, overflow)
		
		-- Atualiza o modelo (Evolução visual)
		local metaPlayer = MetaPlayer.Get(player)
		if metaPlayer then
			module.CreatePinata(metaPlayer)
		end
	else
		PlayerDataManager:Set(player, {"Pinata", "XP"}, newXP)
	end
end

return module