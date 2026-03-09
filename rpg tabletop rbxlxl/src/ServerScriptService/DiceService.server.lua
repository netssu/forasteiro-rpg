------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local ASSETS_FOLDER_NAME: string = "Assets"
local REMOTES_FOLDER_NAME: string = "Remotes"
local REMOTE_NAME: string = "DiceEvent"
local MASTER_TEAM_NAME: string = "Mestre"

------------------//VARIABLES
local assetsFolder: Folder = ReplicatedStorage:WaitForChild(ASSETS_FOLDER_NAME)
local remotesFolder: Folder = assetsFolder:WaitForChild(REMOTES_FOLDER_NAME)

local diceEvent: RemoteEvent = remotesFolder:FindFirstChild(REMOTE_NAME) :: RemoteEvent
if not diceEvent then
	diceEvent = Instance.new("RemoteEvent")
	diceEvent.Name = REMOTE_NAME
	diceEvent.Parent = remotesFolder
end

------------------//FUNCTIONS
local function parse_and_roll(expression: string): any
	local countStr, sidesStr, modStr = string.match(string.lower(expression), "(%d*)d(%d+)([+-]?%d*)")

	if not sidesStr then
		return nil
	end

	local count = tonumber(countStr) or 1
	local sides = tonumber(sidesStr)
	local mod = tonumber(modStr) or 0

	if count > 50 then count = 50 end
	if count < 1 then count = 1 end
	if sides < 2 then sides = 2 end

	local total = 0
	local rolls = {}

	for i = 1, count do
		local r = math.random(1, sides)
		table.insert(rolls, r)
		total += r
	end

	total += mod

	local modString = ""
	if mod > 0 then
		modString = "+" .. tostring(mod)
	elseif mod < 0 then
		modString = tostring(mod)
	end

	local formattedExpression = tostring(count) .. "d" .. tostring(sides) .. modString

	return {
		Total = total,
		Rolls = rolls,
		Expression = formattedExpression,
		Mod = mod
	}
end

local function on_dice_request(player: Player, payload: any): ()
	if typeof(payload) ~= "table" then
		return
	end

	if payload.Action == "Roll" and typeof(payload.Expression) == "string" then
		local result = parse_and_roll(payload.Expression)

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
				IsMaster = isMaster,
				IsInstant = isInstant
			})
		end
	end
end

------------------//MAIN FUNCTIONS
diceEvent.OnServerEvent:Connect(on_dice_request)

------------------//INIT