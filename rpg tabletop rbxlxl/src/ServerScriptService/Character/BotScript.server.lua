------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")

------------------//CONSTANTS
local MIN_RADIUS: number = 8
local MAX_RADIUS: number = 20

local MIN_POINTS: number = 8
local MAX_POINTS: number = 14

local MIN_WAIT_BETWEEN_POINTS: number = 0.08
local MAX_WAIT_BETWEEN_POINTS: number = 0.2

local MOVE_TIMEOUT: number = 3
local IDLE_BETWEEN_CIRCLES: number = 0.35

------------------//VARIABLES
local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local remotesFolder: Folder = assetsFolder:WaitForChild("Remotes")
local diceEvent: RemoteEvent = remotesFolder:WaitForChild("DiceEvent") :: RemoteEvent

------------------//FUNCTIONS
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

local function walk_random_circle(character: Model): ()
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
		if not character.Parent then
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

local function bot_roll_loop(character: Model): ()
	task.spawn(function()
		while character.Parent do
			task.wait(10)

			local roll = math.random(1, 20)

			-- Finge uma rolagem de 1d20 para todos os clientes verem
			diceEvent:FireAllClients({
				Action = "RollResult",
				Player = nil, -- Bot não é um Player real
				Character = character,
				Expression = "1d20",
				Total = roll,
				Rolls = {roll},
				IsMaster = false,
				IsInstant = false
			})
		end
	end)
end

local function bot_loop(character: Model): ()
	bot_roll_loop(character)

	task.spawn(function()
		while character.Parent do
			walk_random_circle(character)
			task.wait(IDLE_BETWEEN_CIRCLES)
		end
	end)
end

------------------//INIT

-- Procura o TestBot na pasta Characters (onde movemos ele antes) ou direto no workspace
local charactersFolder = workspace:FindFirstChild("Characters")
local testBot = charactersFolder and charactersFolder:FindFirstChild("TestBot") or workspace:FindFirstChild("TestBot")

if not RunService:IsStudio()  then
	testBot:Destroy()
	return
end

if testBot then
	bot_loop(testBot)
end