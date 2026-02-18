-- services

local MarketplaceService = game:GetService("MarketplaceService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local ServerStorage = game.ServerStorage
local Modules = ServerStorage:WaitForChild("Modules")
local Manager = Modules:WaitForChild("Managers")
local DataStore = require(Manager:WaitForChild("DataManager"))

local TotalCompleted = 0

-- variables

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local GameRemotes = Remotes:FindFirstChild("Game")

local Path = workspace:FindFirstChild("Path")
local Waypoints = Path:FindFirstChild("Waypoints")

local Units = ServerStorage:FindFirstChild("Units")

local GlobalValues = ReplicatedStorage:FindFirstChild("GlobalValues")

local HealthBillboardTemplate = ReplicatedStorage.Storage.Billboards.Health

-- tables

local EnemyStats = require(ReplicatedStorage.Modules.StoredData.EnemyData)

local TotalWaves = nil

local WaveUnits = nil

local TimeTillNext = nil

-- values

local MaxHealth = GlobalValues:FindFirstChild("Base_Health").Value

-- public

local RoundManager = {}

-- determines cash reward per difficulty
local WaveCash = {
	["Easy"] = 50,
	["Medium"] = 100,
	["Hard"] = 150,
	["Impossible"] = 250,
}

-- server config

local collision_Group = "Worms"
local MAX_ROUNDS = 0
local UNITS_PER_WAVE = 5
local WAVE_DELAY = 3
local MaxTime = 60 * 60

local DatastoreService = game:GetService("DataStoreService")
local ClanStore = DatastoreService:GetDataStore("Clans_v2")

-- difficulty scaling

local SPAWN_TIME_STEP = 0.25   -- controls seconds faster each wave
local HEALTH_MULTIPLIER_STEP = 0.25  -- controls 25% health increase per wave
local BASE_SPAWN_DELAY = 4

local Handler = {}
local CachedData = nil
local PlayerCooldowns = {} -- tracks cooldowns per player

-- local functions

-- picks a random unit from the units folder
local function chooseRandomUnit()
	local unitList = Units:GetChildren()
	local randomUnit = unitList[math.random(1, #unitList)]
	return randomUnit
end

-- fetches clan data from datastore
function GetClanData()
	local success, data = pcall(function()
		return ClanStore:GetAsync("Data")
	end)
	if success then
		if data then
			CachedData = data
		end
		return CachedData
	end
end

-- saves clan data to datastore
function SaveClanData(ClanData)
	local success, err = pcall(function()
		ClanStore:SetAsync("Data", ClanData)

		print("saved!")

		--print(ClanData)
	end)
	if not success then
		warn("Error saving clans:", err)
	end
	return success
end

-- handles when the game ends early (player loses)
local function endGameEarly(currentWave)
	local TimeEnd = tick()
	local TimeTaken = TimeEnd - (workspace:GetAttribute("GameStartTime") or TimeEnd)

	print(workspace:GetAttribute("Difficulty"))

	-- gives players cash based on waves completed
	for _, Plr in ipairs(Players:GetPlayers()) do
		local Multi = 1

		-- checks for gamepass multipliers
		pcall(function()
			if MarketplaceService:UserOwnsGamePassAsync(Plr.UserId, 1529106675) then
				Multi *= 2
			end

			if MarketplaceService:UserOwnsGamePassAsync(Plr.UserId, 1529258503) then
				Multi *= 1.5
			end
		end)

		Plr.UserData.Money.Value += WaveCash[workspace:GetAttribute("Difficulty")] * currentWave
	end

	-- formats the time taken
	local minutes = math.floor(TimeTaken / 60)
	local seconds = math.floor(TimeTaken % 60)
	local formattedTime = string.format("%d:%02d", minutes, seconds)

	-- notifies all clients of the loss
	Remotes.Game.SendNotification:FireAllClients("You lost!", "Error")
	Remotes.Game.ShowResults:FireAllClients(currentWave, formattedTime, "Lost")

	-- updates clan stats after game ends
	local Cache = GetClanData()

	if Cache then
		for _, Player in ipairs(Players:GetPlayers()) do
			local ClanTag = DataStore.Stored[Player.UserId].Data.ClanTag
			if ClanTag then 
				if Cache.Clans[ClanTag] then
					if Player:GetAttribute("WormsKilled") then
						Cache.Clans[ClanTag].Stats.Killed += Player:GetAttribute("WormsKilled")
					end
					if Player:GetAttribute("TowersPlaced") then
						Cache.Clans[ClanTag].Stats.Placed += Player:GetAttribute("TowersPlaced")
					end
				else
					print("no clan")
				end
			else
				print("nope")
			end
		end

		SaveClanData(Cache)
	end
end

-- updates the base health bar ui
local function setBaseHealth()

	local Base = workspace:FindFirstChild("Base")
	if not Base then return end

	local HealthBar = Base:FindFirstChild("UiAttachment"):FindFirstChild("HealthBar")
	if not HealthBar then return end

	local Bar = HealthBar:WaitForChild("GameStats"):WaitForChild("Bar")
	if not Bar then return end

	local HealthText = HealthBar:FindFirstChild("GameStats"):FindFirstChild("HP")
	if not HealthText then return end

	local GlobalHealth = GlobalValues:FindFirstChild("Base_Health")
	if not GlobalHealth then return end

	-- calculates health percentage for the bar
	local Percentage = GlobalHealth.Value / MaxHealth

	Bar.Size = UDim2.new(Percentage, 0, 1, 0)
	HealthText.Text = GlobalHealth.Value.."/"..MaxHealth

end

-- handles damage to the base
local function baseTakeDamage(Damage : number)
	local Base = workspace:FindFirstChild("Base")
	if not Base then return end

	local HealthBar = Base:FindFirstChild("UiAttachment"):FindFirstChild("HealthBar")
	if not HealthBar then return end

	local HealthText = HealthBar:FindFirstChild("GameStats"):FindFirstChild("HP")
	if not HealthText then return end

	local Bar = HealthBar:WaitForChild("GameStats"):WaitForChild("Bar")
	if not Bar then return end

	local GlobalHealth = GlobalValues:FindFirstChild("Base_Health")
	if not GlobalHealth then return end

	local Percentage = GlobalHealth.Value / MaxHealth

	Bar.Size = UDim2.new(Percentage, 0, 1, 0)

	-- subtracts damage and clamps to zero
	GlobalHealth.Value = math.max(GlobalHealth.Value - Damage, 0)
	HealthText.Text = GlobalHealth.Value.."/"..MaxHealth

	-- tells clients to update their health bar display
	Remotes.Game.UpdateHealthbar:FireAllClients(GlobalHealth.Value, MaxHealth)

	-- ends the game if base health hits zero
	if GlobalHealth.Value <= 0 then
		GlobalHealth.Value = 0
		local currentWave = workspace:GetAttribute("CurrentWave") or 1
		endGameEarly(currentWave)
	end
end

-- moves the enemy along the path
local function moveUnit(unit: Model)
	if not unit then return end
	local humanoidRootPart = unit:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	local humanoid = unit:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- plays the walk animation
	local animator = unit:FindFirstChild(unit.Name):FindFirstChild("Humanoid"):FindFirstChild("Animator")
	if animator then
		local walkAnim = Instance.new("Animation")
		walkAnim.AnimationId = "rbxassetid://128646144753424"
		local walkTrack = animator:LoadAnimation(walkAnim)
		walkTrack.Looped = true
		walkTrack:Play()
	end

	-- handles collision with grandma towers
	unit.PrimaryPart.Touched:Connect(function(Hit)
		if Hit.Parent.Name:find("Grandma") then
			if Hit.Parent.Parent.Name:find("Grandma") then
				local Humanoid = Hit.Parent.Parent:FindFirstChildOfClass("Humanoid")
				if not Humanoid then return end
				Humanoid:TakeDamage(unit.Humanoid.Health)
				unit:Destroy()
				
				for _, Plr in ipairs(Players:GetPlayers()) do
					local currentCash = Plr:GetAttribute("TempCash")
					local reward = math.round(EnemyStats[unit.Name].Money / #Players:GetPlayers())
					Plr:SetAttribute("TempCash", currentCash + reward)
				end
				
				return
			else
				--print("None")
			end
		else
			--print("none")
		end
	end)

	-- collects and sorts waypoints by name
	local waypoints = {}
	for _, waypoint in ipairs(Waypoints:GetChildren()) do
		table.insert(waypoints, waypoint)
	end
	table.sort(waypoints, function(a, b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)

	local currentTarget = nil
	local distanceTracker = nil

	-- tracks distance to current waypoint
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

	-- moves the unit toward a target position
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

	-- makes the unit follow the path waypoints
	task.spawn(function()
		for i, waypoint in ipairs(waypoints) do
			if not unit or not unit.Parent then return end
			moveTo(waypoint.Position, i)
			repeat task.wait() until (humanoidRootPart.Position - waypoint.Position).Magnitude < 2 or not unit or not unit.Parent
		end

		-- moves to final target and damages base
		local target = Path:FindFirstChild("Enemy_Target")
		if target and unit and unit.Parent then
			moveTo(target.Position, #waypoints + 1)
			repeat task.wait() until (humanoidRootPart.Position - target.Position).Magnitude < 2 or not unit or not unit.Parent
			if unit and unit.Parent then
				baseTakeDamage(unit.Humanoid.Health)
				unit:Destroy()
			end
		end
	end)
end

-- applies stats to enemies based on type and difficulty
local function applyEnemyStats(unit: Model, enemyType: string, Difficulty)
	if not unit or not EnemyStats[enemyType] then return end

	local humanoid = unit:FindFirstChild("Humanoid")
	if humanoid then
		local baseStats = EnemyStats[enemyType]
		local baseHealth = baseStats.BaseHealth or baseStats.Health
		baseStats.BaseHealth = baseHealth

		-- sets health multiplier based on difficulty
		if workspace:GetAttribute("Difficulty") == "Easy" then
			HEALTH_MULTIPLIER_STEP = .1
		elseif workspace:GetAttribute("Difficulty") == "Medium" then
			HEALTH_MULTIPLIER_STEP = .25
		elseif workspace:GetAttribute("Difficulty") == "Hard" then
			HEALTH_MULTIPLIER_STEP = .35
		elseif workspace:GetAttribute("Difficulty") == "Impossible" then
			HEALTH_MULTIPLIER_STEP = .5
		end

		-- calculates scaled health based on wave number
		local currentWave = workspace:GetAttribute("CurrentWave") or 1
		local healthMultiplier = math.floor((1 + ((currentWave - 1) * HEALTH_MULTIPLIER_STEP)) * 10) / 10
		humanoid.MaxHealth = math.floor(baseHealth * healthMultiplier)

		-- caps easy mode health at 500
		if workspace:GetAttribute("Difficulty") == "Easy" then
			humanoid.MaxHealth = math.min(humanoid.MaxHealth, 500)
		end
		humanoid.Health = humanoid.MaxHealth
		humanoid.WalkSpeed = baseStats.WalkSpeed and baseStats.WalkSpeed * (workspace:GetAttribute("GameSpeed") or 1) or humanoid.WalkSpeed

		-- updates walk speed when game speed changes
		workspace:GetAttributeChangedSignal("GameSpeed"):Connect(function()
			print("changed")
			humanoid.WalkSpeed = baseStats.WalkSpeed and baseStats.WalkSpeed * (workspace:GetAttribute("GameSpeed") or 1) or humanoid.WalkSpeed
		end)	
	end
end

-- creates a tombstone when enemy dies
local function createTomb(CF: CFrame)
	local Tomb = ReplicatedStorage.Storage.GraveStones:FindFirstChild("Default")
	if not Tomb then return end

	local NewTomb = Tomb:Clone()
	local tombSizeY = NewTomb.Size.Y

	-- raycasts to find ground level
	local rayOrigin = CF.Position
	local rayDirection = Vector3.new(0, -50, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {NewTomb, Path}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	local newPos = CF.Position
	if result then
		newPos = Vector3.new(newPos.X, result.Position.Y + (tombSizeY / 2) - 2, newPos.Z)
	end

	-- drops the tombstone from above
	local startPos = newPos + Vector3.new(0, 15, 0)
	local newCF = CFrame.new(newPos, newPos + CF.LookVector)

	NewTomb.CFrame = CFrame.new(startPos, startPos + CF.LookVector)
	NewTomb.Parent = workspace

	local dropTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back)
	local dropTween = TweenService:Create(NewTomb, dropTweenInfo, {CFrame = newCF})
	dropTween:Play()

	-- removes the tombstone after a delay
	task.spawn(function()
		dropTween.Completed:Wait()
		task.wait(4.75)

		local shrinkTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local shrinkTween = TweenService:Create(NewTomb, shrinkTweenInfo, {Size = Vector3.new(0.1, 0.1, 0.1), Position = NewTomb.Position - Vector3.new(0,3,0)})
		shrinkTween:Play()
		shrinkTween.Completed:Wait()

		NewTomb:Destroy()
	end)
end

-- creates a crater effect for tnt enemies
local function createCrater(Position: Vector3, Radius: number, PartCount: number)
	local craterFolder = workspace:FindFirstChild("CraterParts")
	if not craterFolder then return end

	-- creates the crater ring
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

		-- fades out crater parts
		task.delay(3, function()
			local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Linear)
			local tween = TweenService:Create(craterPart, tweenInfo, {Transparency = 1})
			tween:Play()
			tween.Completed:Connect(function()
				craterPart:Destroy()
			end)
		end)
	end

	-- creates flying debris particles
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
			part.CanCollide = false
			part.Parent = craterFolder
			part.Orientation = Vector3.new(math.random(0, 360), math.random(0, 360), math.random(0, 360))

			-- launches debris upward
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

			-- fades out debris
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

-- spawns an enemy unit
local function spawnUnit(unitName: string)
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

	-- sets up the unit in workspace
	HealthBar.Parent = CreatedUnit.PrimaryPart
	CreatedUnit.Parent = workspace.Enemies
	CreatedUnit:PivotTo(SpawnPart.CFrame)
	CreatedUnit:SetAttribute("Current", 0)

	TowerName.Text = CreatedUnit.Name

	-- shows boss health bar for boss enemies
	if CreatedUnit.Name == "Boss" then
		Remotes:FindFirstChild("Game"):FindFirstChild("ShowBossBar"):FireAllClients(CreatedUnit)
	end

	-- sets collision group for all parts
	for _, descendant in ipairs(CreatedUnit:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = collision_Group
		end
	end 

	applyEnemyStats(CreatedUnit, unitName)

	-- updates the health bar display
	local function updateHealth()
		if not humanoid or not Bar or not HPText then return end
		local ratio = humanoid.Health / humanoid.MaxHealth
		Bar.Size = UDim2.new(ratio, 0, 1, 0)
		HPText.Text = string.format("%d / %d", humanoid.Health, humanoid.MaxHealth)
	end

	local ghostSpawned = false

	-- handles health changes and scientist ghost spawn
	humanoid.HealthChanged:Connect(function(newHealth)
		updateHealth()

		-- spawns a ghost when scientist health is low
		if CreatedUnit.Name == "Scientist" and newHealth <= 20 and not ghostSpawned then
			ghostSpawned = true

			task.delay(0.1, function()
				spawnUnit("Ghost")
			end)
		end
	end)

	updateHealth()

	-- handles enemy death
	if humanoid then
		humanoid.Died:Connect(function()

			local PrimaryPart = CreatedUnit.PrimaryPart
			if not PrimaryPart then return end

			-- creates crater for tnt enemies
			if CreatedUnit.Name == "TNT" then
				createCrater(PrimaryPart.Position - Vector3.new(0, 2.7, 0), 1.5, 8)
			end

			local unitCF = CreatedUnit:GetPrimaryPartCFrame()
			createTomb(unitCF)
			CreatedUnit:Destroy()
		end)
	end

	moveUnit(CreatedUnit)
	return CreatedUnit
end

-- functions

-- starts a single wave
function RoundManager.StartWave(WaveNumber, visualwave)
	local waveName = tostring(WaveNumber)
	local unitList = WaveUnits[waveName]

	if not unitList then
		return
	end

	print("Starting", waveName)
	Remotes.Game.SendNotification:FireAllClients("Wave "..visualwave or WaveNumber, "Normal")
	local unitsAlive = #unitList

	-- spawns each unit in the wave
	for _, unitName in ipairs(unitList) do
		local unit 
		unit = spawnUnit(unitName)
		if unit then
			-- tracks when units are destroyed
			unit.AncestryChanged:Connect(function(_, parent)
				if not parent then
					unitsAlive -= 1
				end
			end)
		end
		-- calculates spawn delay that decreases each wave
		local spawnDelay = math.max(0.5, BASE_SPAWN_DELAY - ((WaveNumber - 1) * SPAWN_TIME_STEP))

		task.wait(spawnDelay)
	end

	Remotes.Game.SkipWave:FireAllClients()

	-- waits for wave to complete or timer to expire
	while true do
		task.wait(0.1)

		if WaveNumber ~= MAX_ROUNDS then
			if TimeTillNext <= 0 or workspace:GetAttribute("Skip") or unitsAlive <= 0 then
				workspace:SetAttribute("Skip", nil)
				break
			end
		else
			if unitsAlive <= 0 then
				break
			end
		end
	end

	print(waveName, "completed")

	-- gives players cash after wave completion
	for _, Plr in ipairs(Players:GetPlayers()) do
		Plr:SetAttribute("TempCash", Plr:GetAttribute("TempCash") + ((math.clamp(50 * WaveNumber, 0, 250))/#Players:GetPlayers()))
	end
end

-- awards money to all players based on difficulty
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

-- starts the entire game
function RoundManager.StartGame(TotalWaves, DifficultyPreset, Gamemode, DifficultyName)
	workspace:SetAttribute("GameStartTime", tick())

	MAX_ROUNDS = TotalWaves
	WaveUnits = DifficultyPreset

	workspace:SetAttribute("Difficulty", DifficultyName)

	TotalWaves = MAX_ROUNDS

	-- collects and sorts available waves
	local availableWaves = {}
	for waveName, _ in pairs(WaveUnits) do
		table.insert(availableWaves, waveName)
	end
	table.sort(availableWaves, function(a, b)
		return tonumber(a:match("%d+")) < tonumber(b:match("%d+"))
	end)

	local totalDefinedWaves = #availableWaves

	-- displays round counter
	if Gamemode == "endless" then
		Remotes.Game.DisplayRound:FireAllClients(0, math.huge)
	else
		Remotes.Game.DisplayRound:FireAllClients(0, totalDefinedWaves)
	end
	Remotes.Game.StartTimer:FireAllClients(15)
	task.wait(15)

	local waveIndex = 1
	local cycleCount = 0

	-- loops through all waves
	while true do
		-- handles endless mode cycling
		if waveIndex > totalDefinedWaves then
			if Gamemode == "endless" then
				waveIndex = 1
				cycleCount += 1

				-- scales enemy stats for endless mode
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

		TimeTillNext = 60

		workspace:SetAttribute("Timer", TimeTillNext)

		workspace:SetAttribute("CurrentWave", waveNumber + (totalDefinedWaves * cycleCount))
		if Gamemode == "endless" then
			Remotes.Game.DisplayRound:FireAllClients(waveNumber + (totalDefinedWaves * cycleCount), math.huge)
		else
			Remotes.Game.DisplayRound:FireAllClients(waveNumber, totalDefinedWaves)
		end

		RoundManager.StartWave(waveNumber, waveNumber + (totalDefinedWaves * cycleCount))

		-- checks if game ended early
		if GlobalValues.Base_Health.Value <= 0 then
			print("Game ended early during wave", waveNumber)
			return
		end

		waveIndex += 1
		task.wait(.25)
	end

	-- calculates final time
	local TimeEnd = tick()
	local TimeTaken = TimeEnd - workspace:GetAttribute("GameStartTime")
	local minutes = math.floor(TimeTaken / 60)
	local seconds = math.floor(TimeTaken % 60)
	local formattedTime = string.format("%d:%02d", minutes, seconds)

	awardAllMoney(DifficultyName)

	-- updates player stats on win
	for _, player in ipairs(game.Players:GetPlayers()) do
		local userData = player:FindFirstChild("UserData")
		if userData then
			local tutorialValue = userData:FindFirstChild("CompletedTutorial")
			if tutorialValue and tutorialValue:IsA("BoolValue") then
				tutorialValue.Value = true
			end

			pcall(function()
				userData.Statistics.Wins.Value += 1

				if not(player:GetAttribute("Wins")) then
					player:SetAttribute("Wins", 1)
				else
					player:SetAttribute("Wins", player:GetAttribute("Wins") + 1)
				end
			end)
		end
	end

	-- notifies players of victory
	Remotes.Game.SendNotification:FireAllClients("You won!", "Success")
	Remotes.Game.ShowResults:FireAllClients(MAX_ROUNDS, formattedTime, "Won")

	-- updates clan stats on win
	local Cache = GetClanData()

	if Cache then
		for _, Player in ipairs(Players:GetPlayers()) do
			local ClanTag = DataStore.Stored[Player.UserId].Data.ClanTag
			if ClanTag then 
				if Cache.Clans[ClanTag] then
					if Player:GetAttribute("WormsKilled") then
						Cache.Clans[ClanTag].Stats.Killed += Player:GetAttribute("WormsKilled")
					end
					if Player:GetAttribute("TowersPlaced") then
						Cache.Clans[ClanTag].Stats.Placed += Player:GetAttribute("TowersPlaced")
					end
					Cache.Clans[ClanTag].Stats.Wins += 1	
				else
					print("no clan")
				end
			else
				print("nope")
			end
		end

		SaveClanData(Cache)
	end
end

-- applies slowness effect to enemies
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

-- handles game speed changes from client
GameRemotes:WaitForChild("GameSpeed").OnServerEvent:Connect(function(Plr, Speed)
	local cleanedSpeed = string.gsub(Speed, "x", "")
	local TargetSpeed = tonumber(cleanedSpeed)

	if TargetSpeed then
		workspace:SetAttribute("GameSpeed", TargetSpeed)
	end
end)

-- decreases the wave timer
task.spawn(function()
	while task.wait(.1) do
		if TimeTillNext then
			TimeTillNext -= .1 * (workspace:GetAttribute("GameSpeed") or 1)
			workspace:SetAttribute("Timer", TimeTillNext)
		end
	end
end)

-- handles wave skip requests
Remotes.Game.SkipWave.OnServerEvent:Connect(function()
	workspace:SetAttribute("Skip", true)
end)

return RoundManager