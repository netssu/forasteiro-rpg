-- // services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

-- // variables

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local GameRemotes = Remotes:FindFirstChild("Game")

local PathA = workspace:FindFirstChild("PathA")
local A_Waypoints = PathA:FindFirstChild("Waypoints")

local PathB = workspace:FindFirstChild("PathB")
local B_Waypoints = PathB:FindFirstChild("Waypoints")

local Units = ServerStorage:FindFirstChild("Units")

local GlobalValues = ReplicatedStorage:FindFirstChild("GlobalValues")

local HealthBillboardTemplate = ReplicatedStorage.Storage.Billboards.Health

-- // tables

local EnemyStats = require(ReplicatedStorage.Modules.StoredData.EnemyStats)

local WaveUnits = nil

-- // values

local MaxHealth = GlobalValues:FindFirstChild("Base_Health_A").Value

-- // public

local RoundManager = {}

local Bases = {
	A = workspace:FindFirstChild("BaseA"),
	B = workspace:FindFirstChild("BaseB")
}

local BaseHealthValues = {
	A = GlobalValues:FindFirstChild("Base_Health_A"),
	B = GlobalValues:FindFirstChild("Base_Health_B")
}

-- // server config

local collision_Group = "Worms"
local MAX_ROUNDS = 0
local UNITS_PER_WAVE = 5
local WAVE_DELAY = 3
local MaxTime = 60 * 60

-- // local functions

local function chooseRandomUnit()
	local unitList = Units:GetChildren()
	local randomUnit = unitList[math.random(1, #unitList)]
	return randomUnit
end

local function endGameEarly(currentWave)
	local TimeEnd = tick()
	local TimeTaken = TimeEnd - (workspace:GetAttribute("GameStartTime") or TimeEnd)

	local minutes = math.floor(TimeTaken / 60)
	local seconds = math.floor(TimeTaken % 60)
	local formattedTime = string.format("%d:%02d", minutes, seconds)

	if BaseHealthValues.A.Value > 0 then
		for _, Plr in ipairs(Players:GetPlayers()) do
			if Plr:GetAttribute("PathSide") == "A" then
				Plr.UserData.Money.Value += 100 * (currentWave or 1)
				Remotes.Game.SendNotification:FireClient(Plr, "You Won!", "Success")
				Remotes.Game.ShowResults:FireClient(Plr ,currentWave, formattedTime, "Won")		
			else
				Remotes.Game.SendNotification:FireClient(Plr, "You lost!", "Error")
				Remotes.Game.ShowResults:FireClient(Plr, currentWave, formattedTime, "Lost")
			end
		end
	else
		for _, Plr in ipairs(Players:GetPlayers()) do
			if Plr:GetAttribute("PathSide") == "B" then
				Plr.UserData.Money.Value += 100 * (currentWave or 1)
				Remotes.Game.SendNotification:FireClient(Plr, "You Won!", "Success")
				Remotes.Game.ShowResults:FireClient(Plr, currentWave, formattedTime, "Won")		
			else
				Remotes.Game.SendNotification:FireClient(Plr, "You lost!", "Error")
				Remotes.Game.ShowResults:FireClient(Plr, currentWave, formattedTime, "Lost")
			end
		end
	end
end

local function setBaseHealth(baseKey)
	local Base = Bases[baseKey]
	if not Base then return end

	local HealthBar = Base:FindFirstChild("UiAttachment"):FindFirstChild("HealthBar")
	if not HealthBar then return end

	local Bar = HealthBar:WaitForChild("GameStats"):WaitForChild("Bar")
	local HealthText = HealthBar:FindFirstChild("GameStats"):FindFirstChild("HP")

	local GlobalHealth = BaseHealthValues[baseKey]
	if not GlobalHealth then return end

	local Percentage = GlobalHealth.Value / MaxHealth

	Bar.Size = UDim2.new(Percentage, 0, 1, 0)
	HealthText.Text = GlobalHealth.Value.."/"..MaxHealth
end

local function baseTakeDamage(baseKey, Damage : number)
	local Base = Bases[baseKey]
	if not Base then return end

	local HealthBar = Base:FindFirstChild("UiAttachment"):FindFirstChild("HealthBar")
	if not HealthBar then return end

	local HealthText = HealthBar:FindFirstChild("GameStats"):FindFirstChild("HP")
	if not HealthText then return end

	local Bar = HealthBar:FindFirstChild("GameStats"):FindFirstChild("Bar")
	if not Bar then return end

	local GlobalHealth = BaseHealthValues[baseKey]
	if not GlobalHealth then return end
	
	print("Base : "..Base.Name.. " Global Health Value : "..GlobalHealth.Name)

	GlobalHealth.Value = math.max(GlobalHealth.Value - Damage, 0)
	local Percentage = GlobalHealth.Value / MaxHealth

	Bar.Size = UDim2.new(Percentage, 0, 1, 0)
	HealthText.Text = GlobalHealth.Value.."/"..MaxHealth

	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("PathSide") == baseKey then
			Remotes.Game.UpdateHealthbar:FireClient(player, GlobalHealth.Value, MaxHealth)
			break
		end
	end

	if GlobalHealth.Value <= 0 then
		GlobalHealth.Value = 0
		local currentWave = workspace:GetAttribute("CurrentWave") or 1
		endGameEarly(currentWave)
	end
end

local function moveUnit(unit: Model, Path, Waypoints)
	if not unit or not Path or not Waypoints then return end
	local humanoidRootPart = unit:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	local humanoid = unit:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local animator = unit:FindFirstChild(unit.Name):FindFirstChild("Humanoid"):FindFirstChild("Animator")
	if animator then
		local walkAnim = Instance.new("Animation")
		walkAnim.AnimationId = "rbxassetid://128646144753424"
		local walkTrack = animator:LoadAnimation(walkAnim)
		walkTrack.Looped = true
		walkTrack:Play()
	end

	local waypoints = {}
	for _, waypoint in ipairs(Waypoints:GetChildren()) do
		table.insert(waypoints, waypoint)
	end
	table.sort(waypoints, function(a, b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)

	local currentTarget = nil
	local distanceTracker = nil

	local function startDistanceTracker()
		if distanceTracker then
			task.cancel(distanceTracker)
		end
		distanceTracker = task.spawn(function()
			while unit and unit.Parent and currentTarget do
				local dist = (humanoidRootPart.Position - currentTarget).Magnitude
				unit:SetAttribute("Distance", dist)
				task.wait(0.2)
			end
		end)
	end

	local function moveTo(targetPos, waypointIndex)
		currentTarget = targetPos
		unit:SetAttribute("Current", waypointIndex)
		startDistanceTracker()

		return task.spawn(function()
			while unit and unit.Parent do
				humanoidRootPart.Anchored = true
				local pos = humanoidRootPart.Position
				local diff = targetPos - pos
				local dist = diff.Magnitude
				if dist < 1 then break end
				local dir = diff.Unit
				local step = dir * humanoid.WalkSpeed * task.wait()
				humanoidRootPart.CFrame = CFrame.new(pos + step, pos + step + dir)
			end
		end)
	end

	task.spawn(function()
		for i, waypoint in ipairs(waypoints) do
			if not unit or not unit.Parent then return end
			moveTo(waypoint.Position, i)
			repeat task.wait() until (humanoidRootPart.Position - waypoint.Position).Magnitude < 2 or not unit or not unit.Parent
		end

		local target = Path:FindFirstChild("Enemy_Target")
		if target and unit and unit.Parent then
			moveTo(target.Position, #waypoints + 1)
			repeat task.wait() until (humanoidRootPart.Position - target.Position).Magnitude < 2 or not unit or not unit.Parent
			if unit and unit.Parent then
				if Path == PathA then
					print("A")
					baseTakeDamage("A", unit.Humanoid.Health)
				elseif Path == PathB then
					print("B")
					baseTakeDamage("B", unit.Humanoid.Health)
				end
				unit:Destroy()
			end
		end
	end)
end

local function applyEnemyStats(unit: Model, enemyType: string)
	if not unit or not EnemyStats[enemyType] then return end

	local humanoid = unit:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = EnemyStats[enemyType]["WalkSpeed"] or humanoid.WalkSpeed
		humanoid.MaxHealth = EnemyStats[enemyType]["Health"] or humanoid.MaxHealth
		humanoid.Health = humanoid.MaxHealth
	end
end

local function createTomb(CF: CFrame)
	local Tomb = ReplicatedStorage.Storage.GraveStones:FindFirstChild("Default")
	if not Tomb then return end

	local NewTomb = Tomb:Clone()
	local tombSizeY = NewTomb.Size.Y

	local rayOrigin = CF.Position
	local rayDirection = Vector3.new(0, -50, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {NewTomb}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	local newPos = CF.Position
	if result then
		newPos = Vector3.new(newPos.X, result.Position.Y + (tombSizeY / 2) - 2, newPos.Z)
	end

	local startPos = newPos + Vector3.new(0, 5, 0)
	local newCF = CFrame.new(newPos, newPos + CF.LookVector)

	NewTomb.CFrame = CFrame.new(startPos, startPos + CF.LookVector)
	NewTomb.Parent = workspace

	local TweenService = game:GetService("TweenService")

	local dropTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back)
	local dropTween = TweenService:Create(NewTomb, dropTweenInfo, {CFrame = newCF})
	dropTween:Play()

	task.spawn(function()
		dropTween.Completed:Wait()
		task.wait(4.75)

		local shrinkTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local shrinkTween = TweenService:Create(NewTomb, shrinkTweenInfo, {Size = Vector3.new(0.1, 0.1, 0.1)})
		shrinkTween:Play()
		shrinkTween.Completed:Wait()

		NewTomb:Destroy()
	end)
end

local function createCrater(Position: Vector3, Radius: number, PartCount: number)
	local craterFolder = workspace:FindFirstChild("CraterParts")
	if not craterFolder then return end

	local angleIncrement = 2 * math.pi / PartCount
	for i = 0, PartCount - 1 do
		local angle = i * angleIncrement
		local x = Position.X + Radius * math.cos(angle)
		local z = Position.Z + Radius * math.sin(angle)
		local partPosition = Vector3.new(x, Position.Y, z)

		local craterPart = Instance.new("Part")
		craterPart.Size = Vector3.new(1.5, 1, 1.5)
		craterPart.Material = Enum.Material.Ground
		craterPart.Color = Color3.fromRGB(86, 66, 54)
		craterPart.Position = partPosition
		craterPart.Anchored = true
		craterPart.CanCollide = false

		local direction = (Position - partPosition).Unit
		local tilt = CFrame.new(partPosition, partPosition + direction) * CFrame.Angles(math.rad(15), 0, 0)
		craterPart.CFrame = tilt

		craterPart.Parent = craterFolder

		task.delay(3, function()
			local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Linear)
			local tween = TweenService:Create(craterPart, tweenInfo, {Transparency = 1})
			tween:Play()
			tween.Completed:Connect(function()
				craterPart:Destroy()
			end)
		end)
	end

	task.delay(0.1, function()
		for i = 1, PartCount do
			local randomSize = math.random(25, 60) / 100
			local part = Instance.new("Part")
			part.Size = Vector3.new(randomSize, randomSize, randomSize)
			part.Material = Enum.Material.Slate
			part.Color = Color3.fromRGB(86, 66, 54)
			part.Position = Position + Vector3.new(
				math.random(-Radius, Radius),
				math.random(0, 3),
				math.random(-Radius, Radius)
			)
			part.Anchored = false
			part.CanCollide = true
			part.Parent = craterFolder
			part.Orientation = Vector3.new(math.random(0, 360), math.random(0, 360), math.random(0, 360))

			local debrisForce = Instance.new("BodyVelocity")
			debrisForce.MaxForce = Vector3.new(1e5, 1e5, 1e5)
			debrisForce.Velocity = Vector3.new(
				math.random(-25, 25),
				math.random(25, 55),
				math.random(-25, 25)
			)
			debrisForce.P = 1000
			debrisForce.Parent = part

			game:GetService("Debris"):AddItem(debrisForce, 0.25)

			task.delay(math.random(2, 3), function()
				local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
				local tween = TweenService:Create(part, tweenInfo, {Transparency = 1})
				tween:Play()
				tween.Completed:Connect(function()
					part:Destroy()
				end)
			end)
		end
	end)
end

local function spawnUnit(unitName: string, Path, Waypoints)
	local selectedUnit = Units:FindFirstChild(unitName)
	if not selectedUnit then
		warn("Unit not found:", unitName, " using random fallback")
		selectedUnit = chooseRandomUnit()
	end
	if not selectedUnit then return end

	local CreatedUnit: Model = selectedUnit:Clone()
	if not CreatedUnit then return end

	local SpawnPart = Path:FindFirstChild("Enemy_Spawn")
	if not SpawnPart then return end
	
	local HealthBar = HealthBillboardTemplate:Clone()
	if not HealthBar then return end
	
	local humanoid = CreatedUnit:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	local Container = HealthBar:FindFirstChild("Worm_Health")
	if not Container then return end
	
	local Bar = Container:FindFirstChild("Bar")
	local TowerName = Container:FindFirstChild("Tower_Name")
	local HPText = Container:FindFirstChild("HP")
	
	HealthBar.Parent = CreatedUnit.PrimaryPart
	CreatedUnit.Parent = workspace.Enemies
	CreatedUnit:MoveTo(SpawnPart.Position)
	
	TowerName.Text = CreatedUnit.Name
	
	if CreatedUnit.Name == "Boss" then
		Remotes:FindFirstChild("Game"):FindFirstChild("ShowBossBar"):FireAllClients(CreatedUnit)
	end

	for _, descendant in ipairs(CreatedUnit:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = collision_Group
		end
	end 

	applyEnemyStats(CreatedUnit, unitName)
	
	local function updateHealth()
		if not humanoid or not Bar or not HPText then return end
		local ratio = humanoid.Health / humanoid.MaxHealth
		Bar.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
		HPText.Text = string.format("%d / %d", humanoid.Health, humanoid.MaxHealth)
	end
	
	humanoid.HealthChanged:Connect(function()
		updateHealth()
	end)
	
	updateHealth()

	if humanoid then
		humanoid.Died:Connect(function()
			
			local PrimaryPart = CreatedUnit.PrimaryPart
			if not PrimaryPart then return end

			if CreatedUnit.Name == "TNT" then
				createCrater(PrimaryPart.Position - Vector3.new(0, 2.7, 0), 1.5, 8)
			end
			
			local unitCF = CreatedUnit:GetPrimaryPartCFrame()
			createTomb(unitCF)
			CreatedUnit:Destroy()
		end)
	end

	moveUnit(CreatedUnit, Path, Waypoints)
	return CreatedUnit
end

-- // functions

function RoundManager.StartWave(WaveNumber)
	local waveName = "Wave" .. tostring(WaveNumber)
	local unitList = WaveUnits[waveName]

	if not unitList then
		return
	end

	print("Starting", waveName)
	Remotes.Game.SendNotification:FireAllClients("Wave "..WaveNumber, "Normal")
	local unitsAlive = #unitList * 2

	local function spawnWaveOnPath(Path, Waypoints)
		for _, unitName in ipairs(unitList) do
			local unit = spawnUnit(unitName, Path, Waypoints)
			if unit then
				unit.AncestryChanged:Connect(function(_, parent)
					if not parent then
						unitsAlive -= 1
					end
				end)
			end
			task.wait(4)
		end
	end

	task.spawn(function()
		spawnWaveOnPath(PathA, A_Waypoints)
	end)
	task.spawn(function()
		spawnWaveOnPath(PathB, B_Waypoints)
	end)

	while unitsAlive > 0 do
		task.wait(0.5)
	end

	print(waveName, "completed")
end


local function awardAllMoney(DifficultyName)
	
	local AmountToGive = 0
	
	if DifficultyName == "Easy" then
		AmountToGive = 500
	elseif DifficultyName == "Medium" then
		AmountToGive = 1500
	elseif DifficultyName == "Hard" then
		AmountToGive = 4500
	elseif DifficultyName == "Impossible" then
		AmountToGive = 7500
	end
	
	if AmountToGive > 0 then
		
		for _, Player in ipairs(Players:GetPlayers()) do
			
			local UserData = Player:FindFirstChild("UserData")
			if not UserData then return end 
			
			local Money = UserData:FindFirstChild("Money")
			if not Money then return end 
			
			Money.Value = Money.Value + AmountToGive

		end
		
	end
	
end

function RoundManager.StartGame(TotalWaves, DifficultyPreset, Gamemode, DifficultyName)
	workspace:SetAttribute("GameStartTime", tick())

	MAX_ROUNDS = TotalWaves
	WaveUnits = DifficultyPreset

	local availableWaves = {}
	for waveName, _ in pairs(WaveUnits) do
		table.insert(availableWaves, waveName)
	end
	table.sort(availableWaves, function(a, b)
		return tonumber(a:match("%d+")) < tonumber(b:match("%d+"))
	end)

	local totalDefinedWaves = #availableWaves

	Remotes.Game.DisplayRound:FireAllClients(0, totalDefinedWaves)
	Remotes.Game.StartTimer:FireAllClients(15)
	task.wait(15)

	local waveIndex = 1
	local cycleCount = 0

	while true do
		if waveIndex > totalDefinedWaves then
			if Gamemode == "Endless" then
				waveIndex = 1
				cycleCount += 1

				local multiplier = 1 + (cycleCount * 0.1)
				for enemyType, stats in pairs(EnemyStats) do
					stats.Health = math.floor(stats.Health * multiplier)
					stats.WalkSpeed = stats.WalkSpeed * (1 + (cycleCount * 0.02))
				end

				print(string.format("[Endless] Cycle %d: Enemies now x%.1f HP", cycleCount, multiplier))
			else
				break
			end
		end

		local waveName = availableWaves[waveIndex]
		local waveNumber = tonumber(waveName:match("%d+")) or waveIndex

		Remotes.Game.StartTimer:FireAllClients(200)
		workspace:SetAttribute("CurrentWave", waveNumber)
		Remotes.Game.DisplayRound:FireAllClients(waveNumber, totalDefinedWaves)

		RoundManager.StartWave(waveNumber)

		if BaseHealthValues.A.Value <= 0 or BaseHealthValues.B.Value <= 0 then
			print("Game ended early during wave", waveNumber)
			return
		end

		waveIndex += 1
		task.wait(WAVE_DELAY)
	end

	local TimeEnd = tick()
	local TimeTaken = TimeEnd - workspace:GetAttribute("GameStartTime")
	local minutes = math.floor(TimeTaken / 60)
	local seconds = math.floor(TimeTaken % 60)
	local formattedTime = string.format("%d:%02d", minutes, seconds)

	awardAllMoney(DifficultyName)

	Remotes.Game.SendNotification:FireAllClients("You won!", "Success")
	Remotes.Game.ShowResults:FireAllClients(MAX_ROUNDS, formattedTime, "Won")
end


GameRemotes:FindFirstChild("ApplySlowness").Event:Connect(function(humanoid, slowFactor, duration)
	if not humanoid then return end

	local originalSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = math.max(1, originalSpeed * slowFactor)

	task.delay(duration, function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = originalSpeed
		end
	end)
end)

Remotes.PVP.SpawnUnit.OnServerEvent:Connect(function(player: Player, enemyName: string)
	
	local EnemyData = require(game.ReplicatedStorage.Modules.StoredData.EnemyStats)
	local enemyInfo = EnemyData[enemyName]
	
	if not enemyInfo then
		warn("Invalid enemy: " .. tostring(enemyName))
		return
	end

	local price = enemyInfo.PriceToSpawn or 0
	local playerCash = player:GetAttribute("TempCash")
	local pathSide = player:GetAttribute("PathSide")

	if not playerCash then
		warn("Player missing TempCash attribute")
		return
	end

	if playerCash < price then
		Remotes.Game.SendNotification:FireClient(player, "You don't have enough cash to spawn this unit!", "Error")
		return
	else
		Remotes.Game.SendNotification:FireClient(player, `Spawned {enemyName}!`, "Success")
	end

	player:SetAttribute("TempCash", playerCash - price)

	local path, waypoints
	if pathSide == "A" then
		path = PathB
		waypoints = B_Waypoints
	elseif pathSide == "B" then
		path = PathA
		waypoints = A_Waypoints
	end

	if not path or not waypoints then
		warn("Could not determine path for " .. player.Name)
		return
	end

	local spawnedUnit = spawnUnit(enemyName, path, waypoints)
	
end)

return RoundManager