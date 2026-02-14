local module = {}

------------------//SERVICES
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')

------------------//DEPENDENCIES
local DataTemplate = require(ServerScriptService.Modules.Core.DataTemplate)
local MetaPlayer = require(ServerScriptService.Modules.Core.MetaPlayer)
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local PinataService = require(ServerScriptService.Services.PinataService)
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local PlotmeService = require(ServerScriptService.Services.PlotmeService)

------------------//CONSTANTS
local BASE_LEVEL_REQ = 10
local LEVEL_SCALING = 5
local TOKEN_REWARD = 1

------------------//FUNCTIONS

local function get_requirement(rebirth_count: number): number
	return BASE_LEVEL_REQ + (rebirth_count * LEVEL_SCALING)
end

local function wipe_data(player: Player)
	PlayerDataManager:Set(player, 'Pinata', DataTemplate.Pinata)
	PlayerDataManager:Set(player, 'Inventory', DataTemplate.Inventory)
	PlayerDataManager:Set(
		player,
		{ 'Plot', 'Droppers' },
		DataTemplate.Plot.Droppers
	)
	PlayerDataManager:Set(
		player,
		{ 'Currency', 'Coins' },
		DataTemplate.Currency.Coins
	)
end

local function refresh_visuals(player: Player)
	local meta_player = MetaPlayer.Get(player)
	if meta_player then
		PinataService.CreatePinata(meta_player)

		-- DropperService:ClearDroppers(meta_player)
	end
end

------------------//MAIN FUNCTIONS

function module:Rebirth(player: Player): boolean
	local rebirth_count = PlayerDataManager:Get(
		player,
		{ 'Currency', 'RebirthCount' }
	) or 0
	local current_level = PlayerDataManager:Get(player, { 'Pinata', 'Level' })
		or 1

	local required_level = get_requirement(rebirth_count)

	if current_level >= required_level then
		PlayerDataManager:Increment(player, { 'Currency', 'RebirthCount' }, 1)
		PlayerDataManager:Increment(
			player,
			{ 'Currency', 'RebirthTokens' },
			TOKEN_REWARD
		)

		wipe_data(player)
		refresh_visuals(player)
		local map = workspace:FindFirstChild("Map")
		if map then
			local plots = map:FindFirstChild("Plots")
			if plots then
				for _, plot in plots:GetChildren() do
					if plot:IsA("Model") and plot:GetAttribute("Owner") == player.UserId then
						PlotmeService:ApplyMachineOwnership(plot, player)
						break
					end
				end
			end
		end

		print(
			`[Rebirth] Sucesso! Jogador {player.Name} agora tem {rebirth_count + 1} Rebirths.`
		)
		return true
	else
		warn(
			`[Rebirth] Falha. Nível necessário: {required_level}. Nível atual: {current_level}`
		)
		return false
	end
end

------------------//INIT

function module:Start()
	Packets.Rebirth.OnServerEvent:Connect(function(player)
		module:Rebirth(player)
	end)
end

return module
