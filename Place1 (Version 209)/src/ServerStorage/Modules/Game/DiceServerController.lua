------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//MODULES
local replicatedModulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules")
local dictionaryFolder: Folder = replicatedModulesFolder:WaitForChild("Dictionary")
local utilityFolder: Folder = replicatedModulesFolder:WaitForChild("Utility")
local DiceDictionary = require(dictionaryFolder:WaitForChild("DiceDictionary"))
local DiceRemoteUtility = require(utilityFolder:WaitForChild("DiceRemoteUtility"))

local serverModulesFolder: Folder = ServerStorage:WaitForChild("Modules")
local gameFolder: Folder = serverModulesFolder:WaitForChild("Game")
local DiceManager = require(gameFolder:WaitForChild("DiceManager"))

------------------//FUNCTIONS
local function on_dice_request(player: Player, payload: any): ()
	if typeof(payload) ~= "table" then
		return
	end

	if payload.Action ~= DiceDictionary.ROLL_ACTION or typeof(payload.Expression) ~= "string" then
		return
	end

	local result = DiceManager.parse_and_roll(payload.Expression)
	if not result then
		return
	end

	local teamName = player.Team and player.Team.Name or ""
	local isMaster = teamName == DiceDictionary.MASTER_TEAM_NAME
	local isInstant = payload.Instant == true
	local diceEvent = DiceRemoteUtility.get_dice_event()

	diceEvent:FireAllClients({
		Action = DiceDictionary.ROLL_RESULT_ACTION,
		Player = player,
		Character = player.Character,
		Expression = result.Expression,
		Total = result.Total,
		Rolls = result.Rolls,
		DetailString = result.DetailString,
		IsMaster = isMaster,
		IsInstant = isInstant,
	})
end

------------------//MAIN FUNCTIONS
local DiceServerController = {}

function DiceServerController.connect(): ()
	local diceEvent = DiceRemoteUtility.get_dice_event()
	diceEvent.OnServerEvent:Connect(on_dice_request)
end

return DiceServerController
