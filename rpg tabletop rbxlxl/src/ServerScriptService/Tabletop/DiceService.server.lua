------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//CONSTANTS
local REMOTE_NAME: string = "DiceEvent"
local MASTER_TEAM_NAME: string = "Mestre"

------------------//VARIABLES
local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local diceEvent: RemoteEvent = remotesFolder:WaitForChild(REMOTE_NAME)

local DiceManager = require(ServerStorage.Modules.Game.DiceManager)

------------------//FUNCTIONS
local function on_dice_request(player: Player, payload: any): ()
	if typeof(payload) ~= "table" then
		return
	end

	if payload.Action == "Roll" and typeof(payload.Expression) == "string" then
		local result = DiceManager.parse_and_roll(payload.Expression)

		if result then
			local isMaster = player.Team and player.Team.Name == MASTER_TEAM_NAME or false
			local isInstant = payload.Instant == true

			diceEvent:FireAllClients({
				Action = "RollResult",
				Player = player,
				Character = player.Character,
				Expression = result.Expression,
				Total = result.Total,
				Rolls = result.Rolls,
				DetailString = result.DetailString,
				IsMaster = isMaster,
				IsInstant = isInstant
			})
		end
	end
end

------------------//MAIN FUNCTIONS
diceEvent.OnServerEvent:Connect(on_dice_request)

------------------//INIT