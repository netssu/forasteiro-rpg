------------------//SERVICES
local Players: Players = game:GetService("Players")
local Teams: Teams = game:GetService("Teams")
local RunService: RunService = game:GetService("RunService")

------------------//CONSTANTS
local PLAYER_TEAM_NAME: string = "Jogador"

local BOT_ATTRIBUTE_NAME: string = "StudioAutoBot"
local BOT_ASSIGNED_ATTRIBUTE_NAME: string = "StudioAutoBotAssigned"

local MIN_RADIUS: number = 8
local MAX_RADIUS: number = 20

local MIN_POINTS: number = 8
local MAX_POINTS: number = 14

local MIN_WAIT_BETWEEN_POINTS: number = 0.08
local MAX_WAIT_BETWEEN_POINTS: number = 0.2

local MOVE_TIMEOUT: number = 3
local IDLE_BETWEEN_CIRCLES: number = 0.35

------------------//VARIABLES
local assignedBotUserId: number? = nil

------------------//FUNCTIONS
local function get_team_by_name(teamName: string): Team?
	local team = Teams:FindFirstChild(teamName)

	if team and team:IsA("Team") then
		return team
	end

	return nil
end

local function set_as_player_team(player: Player): ()
	local team = get_team_by_name(PLAYER_TEAM_NAME)

	if not team then
		return
	end

	player.Neutral = false
	player.Team = team
end

local function is_bot_player(player: Player): boolean
	return player:GetAttribute(BOT_ATTRIBUTE_NAME) == true
end

local function move_to(humanoid: Humanoid, targetPosition: Vector3): ()
	local finished: boolean = false

	local connection = humanoid.MoveToFinished:Connect(function()
		finished = true
	end)

	humanoid:MoveTo(targetPosition)

	local startTime = os.clock()

	while humanoid.Parent and not finished and os.clock() - startTime < MOVE_TIMEOUT do
		task.wait()
	end

	connection:Disconnect()
end

local function walk_random_circle(player: Player, character: Model): ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local startPosition = rootPart.Position
	local radius = math.random(MIN_RADIUS, MAX_RADIUS)
	local pointCount = math.random(MIN_POINTS, MAX_POINTS)
	local clockwise = math.random(0, 1) == 1
	local randomAngle = math.rad(math.random(0, 359))

	for pointIndex = 1, pointCount do
		if not player.Parent then
			return
		end

		if not is_bot_player(player) then
			return
		end

		if player.Team == nil or player.Team.Name ~= PLAYER_TEAM_NAME then
			return
		end

		if player.Character ~= character then
			return
		end

		local alpha = (pointIndex / pointCount) * math.pi * 2

		if not clockwise then
			alpha = -alpha
		end

		local angle = randomAngle + alpha

		local targetPosition = Vector3.new(
			startPosition.X + math.cos(angle) * radius,
			startPosition.Y,
			startPosition.Z + math.sin(angle) * radius
		)

		move_to(humanoid, targetPosition)
		task.wait(math.random() * (MAX_WAIT_BETWEEN_POINTS - MIN_WAIT_BETWEEN_POINTS) + MIN_WAIT_BETWEEN_POINTS)
	end
end

local function bot_loop(player: Player, character: Model): ()
	task.spawn(function()
		while player.Parent and player.Character == character and is_bot_player(player) do
			if player.Team and player.Team.Name == PLAYER_TEAM_NAME then
				walk_random_circle(player, character)
			end

			task.wait(IDLE_BETWEEN_CIRCLES)
		end
	end)
end

local function assign_second_player_as_bot(): ()
	if assignedBotUserId ~= nil then
		return
	end

	local playersList = Players:GetPlayers()

	if #playersList < 2 then
		return
	end

	local targetPlayer = playersList[2]

	if not targetPlayer then
		return
	end

	assignedBotUserId = targetPlayer.UserId
	targetPlayer:SetAttribute(BOT_ATTRIBUTE_NAME, true)
	targetPlayer:SetAttribute(BOT_ASSIGNED_ATTRIBUTE_NAME, true)

	set_as_player_team(targetPlayer)

	if targetPlayer.Character then
		bot_loop(targetPlayer, targetPlayer.Character)
	end
end

local function on_character_added(player: Player, character: Model): ()
	task.defer(function()
		if not player.Parent then
			return
		end

		if not is_bot_player(player) then
			return
		end

		set_as_player_team(player)
		bot_loop(player, character)
	end)
end

local function on_player_added(player: Player): ()
	player.CharacterAdded:Connect(function(character: Model)
		on_character_added(player, character)
	end)

	task.defer(function()
		assign_second_player_as_bot()
	end)
end

------------------//INIT
if not RunService:IsStudio() then
	return
end

for _, player in Players:GetPlayers() do
	on_player_added(player)
end

Players.PlayerAdded:Connect(on_player_added)