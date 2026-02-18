-- services
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

-- references
local Storage = ReplicatedStorage:FindFirstChild("Storage")
local TowerModels = Storage:FindFirstChild("Towers")
local Towers = workspace:FindFirstChild("Towers")
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local Enemies = workspace.Enemies
local ExplosionTemplate = Storage:FindFirstChild("Particles"):FindFirstChild("ExplosionTemplate")

-- path stuff
local Path = workspace.Path
local Waypoints = Path.Waypoints
local collision_Group = "Worms"

-- modules
local ServerStorage = game.ServerStorage
local Managers = ServerStorage:WaitForChild("Modules"):WaitForChild("Managers")
local DataManager = require(Managers:WaitForChild("DataManager"))

local EnemyData = require(ReplicatedStorage.Modules.StoredData.EnemyData)
local QuestData = require(ReplicatedStorage.Modules.StoredData.QuestsData)
local TowerData = require(ReplicatedStorage.Modules.StoredData.TowerData)

-- tracks towers per player
local playerTowers = {}
local MAX_TOWERS_PER_PLAYER = 10

-- gets the current game speed multiplier
local function getGameSpeed()
	return workspace:GetAttribute("GameSpeed") or 1
end

-- increases a stat value anywhere in the players descendants
local function increaseStat(Player : Player, StatName : string, increment : number)
	for _, Value in ipairs(Player:GetDescendants()) do
		if Value.Name == StatName then
			Value.Value = Value.Value + increment
		end
	end
end

-- updates quest progress by finding matching quest attributes
local function updateQuestProgress(player: Player, keyword: string, amount: number)
	if not player or not keyword then return end

	keyword = keyword:lower()

	-- find any attribute that has quest_ and the keyword in it
	for attributeName, value in pairs(player:GetAttributes()) do
		print(attributeName)
		if attributeName:lower():find("quest_") and attributeName:lower():find(keyword) then
			local current = player:GetAttribute(attributeName)
			local newValue = current + amount
			player:SetAttribute(attributeName, newValue)
			print(string.format("[QUEST] %s -> %s increased to %d", player.Name, attributeName, newValue))
		end
	end
end

-- finds a part in a model by checking multiple possible names
local function findPartInModel(model, names)
	if type(names) == "string" then
		names = {names}
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			for _, name in ipairs(names) do
				if descendant.Name == name then
					return descendant
				end
			end
		end
	end
end

-- extracts tower level from name like "Tower_2" returns 2
local function getTowerLevel(Tower)
	if not Tower or not Tower.Name then
		return 1
	end

	local levelStr = Tower.Name:match("_(%d+)$")
	if levelStr then
		return tonumber(levelStr) or 1
	end

	return 1
end

-- finds the closest enemy based on targeting mode
local function getClosestEnemy(Tower : Model, Range : number)
	if not Tower.PrimaryPart then return nil end

	local closestEnemy = nil
	local shortestDistance = math.huge
	local maxRange = Range
	local towerLevel = getTowerLevel(Tower)
	local TargettingMode = Tower:GetAttribute("Priority") or 1
	local highestProgress = -math.huge
	local lowestProgress = math.huge

	for _, enemy in pairs(Enemies:GetChildren()) do
		if enemy:IsA("Model") and enemy.PrimaryPart then
			-- ghosts can only be targeted by level 2+ towers
			if false then --enemy.Name == "Ghost" and towerLevel < 2 then
			else
				local distance = (enemy.PrimaryPart.Position - Tower.PrimaryPart.Position).Magnitude
				if distance <= maxRange then
					-- mode 3 = closest enemy
					if TargettingMode == 3 then
						if distance < shortestDistance then
							shortestDistance = distance
							closestEnemy = enemy
						end
						-- mode 1 = first (furthest along path)
					elseif TargettingMode == 1 then
						local currentWaypoint = enemy:GetAttribute("Current") or 0
						local distanceToNext = enemy:GetAttribute("Distance") or math.huge
						local progress = currentWaypoint * 10000 - distanceToNext
						if progress > highestProgress then
							highestProgress = progress
							closestEnemy = enemy
							shortestDistance = distance
						end
						-- mode 2 = last (least along path)
					elseif TargettingMode == 2 then
						local currentWaypoint = enemy:GetAttribute("Current") or 0
						local distanceToNext = enemy:GetAttribute("Distance") or 0
						local progress = currentWaypoint * 10000 - distanceToNext
						if progress < lowestProgress then
							lowestProgress = progress
							closestEnemy = enemy
							shortestDistance = distance
						end
					end
				end
			end
		end
	end
	return closestEnemy, shortestDistance
end

-- creates explosion crater effect with debris
local function createCrater(Position: Vector3, Radius: number, PartCount: number)
	local craterFolder = workspace:FindFirstChild("CraterParts")
	if not craterFolder then return end

	-- create the ring of crater parts
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

		-- tilt parts towards center
		local direction = (Position - partPosition).Unit
		local tilt = CFrame.new(partPosition, partPosition + direction) * CFrame.Angles(math.rad(15), 0, 0)
		craterPart.CFrame = tilt

		craterPart.Parent = craterFolder

		-- fade out after delay
		task.delay(3 / getGameSpeed(), function()
			local tweenInfo = TweenInfo.new(0.25 / getGameSpeed(), Enum.EasingStyle.Linear)
			local tween = TweenService:Create(craterPart, tweenInfo, {Transparency = 1})
			tween:Play()
			tween.Completed:Connect(function()
				craterPart:Destroy()
			end)
		end)
	end

	-- spawn flying debris particles
	task.delay(0.1 / getGameSpeed(), function()
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

			-- launch debris upward
			local debrisForce = Instance.new("BodyVelocity")
			debrisForce.MaxForce = Vector3.new(1e5, 1e5, 1e5)
			debrisForce.Velocity = Vector3.new(
				math.random(-25, 25),
				math.random(25, 55),
				math.random(-25, 25)
			) * getGameSpeed()
			debrisForce.P = 1000
			debrisForce.Parent = part

			game:GetService("Debris"):AddItem(debrisForce, 0.25 / getGameSpeed())

			-- fade out debris after landing
			task.delay(math.random(2, 3) / getGameSpeed(), function()
				local tweenInfo = TweenInfo.new(0.5 / getGameSpeed(), Enum.EasingStyle.Linear)
				local tween = TweenService:Create(part, tweenInfo, {Transparency = 1})
				tween:Play()
				tween.Completed:Connect(function()
					part:Destroy()
				end)
			end)
		end
	end)
end

-- main tower logic - handles attacking and abilities
local function enableTower(Player : Player, Tower : Model)
	-- get all required attributes
	local AnimationId = Tower:GetAttribute("AnimationId")
	if not AnimationId then
		warn("[" .. Tower.Name .. "] : Error no animation id")
		return
	end

	local AttackAnim = "rbxassetid://" .. Tower:GetAttribute("AnimationId")
	local Damage = Tower:GetAttribute("Damage")
	if not Damage then return end

	local Range = Tower:GetAttribute("Range")
	if not Range then return end

	local TowerDataEntry = TowerData[Tower.Name]
	if not TowerDataEntry then
		warn("[" .. Tower.Name .. "] : Error no tower data")
		return
	end

	local CustomAbility = TowerDataEntry.Ability
	if not CustomAbility then
		warn("[" .. Tower.Name .. "] : Error no ability found")
		return
	end

	local AttackCooldown = Tower:GetAttribute("AttackCooldown")
	if not AttackCooldown then return end

	-- get model references
	local PrimaryPart = Tower.PrimaryPart
	if not PrimaryPart then
		warn("[" .. Tower.Name .. "] : Error no PrimaryPart")
		return
	end

	local Model = PrimaryPart:FindFirstChild(Tower.Name)
	if not Model then
		warn("[" .. Tower.Name .. "] : Error missing prefab model inside PrimaryPart")
		return
	end

	local Torso = Model:FindFirstChild("Torso")
	if not Torso then
		warn("[" .. Tower.Name .. "] : Error missing Torso")
		return
	end

	local Humanoid = Model:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		warn("[" .. Tower.Name .. "] : Error missing Humanoid")
		return
	end

	-- setup animator
	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then
		Animator = Instance.new("Animator")
		Animator.Parent = Humanoid
	end

	local PrimaryPartAgain = Tower.PrimaryPart
	if not PrimaryPartAgain then return end

	-- lock y position so tower doesnt float
	local FixedYAxis = PrimaryPartAgain.Position.Y

	-- load attack animation
	local Animation = Instance.new("Animation")
	Animation.AnimationId = AttackAnim

	local AnimationTrack = Animator:LoadAnimation(Animation)

	-- cooldowns for sound effects
	local lastAbilitySoundTime = 0
	local lastGrenadeSoundTime = 0
	local magicianActive = false

	-- update animation speed when game speed changes
	local function updateAnimationSpeed()
		AnimationTrack:AdjustSpeed(getGameSpeed())
	end

	workspace:GetAttributeChangedSignal("GameSpeed"):Connect(updateAnimationSpeed)

	-- airport has looping animation
	if Tower.Name == "Airport" then
		AnimationTrack:AdjustSpeed(getGameSpeed())
		AnimationTrack.Looped = true
		AnimationTrack:Play()
	end

	warn(CustomAbility)

	-- main attack loop
	task.spawn(function()
		task.wait(1 / getGameSpeed())
		while Tower.Parent == workspace:FindFirstChild("Towers") do
			Torso.CanCollide = false
			local closestEnemy, distance = getClosestEnemy(Tower, Range)

			if closestEnemy and closestEnemy.PrimaryPart then
				local enemyHumanoid = closestEnemy:FindFirstChildOfClass("Humanoid")
				if not enemyHumanoid then
					task.wait(0.1 / getGameSpeed())
					continue
				end

				-- rotate tower to face enemy
				local towerPos = PrimaryPart.Position
				local enemyPos = closestEnemy.PrimaryPart.Position
				local flatTowerPos = Vector3.new(towerPos.X, FixedYAxis, towerPos.Z)
				local flatEnemyPos = Vector3.new(enemyPos.X, FixedYAxis, enemyPos.Z)
				local lookCFrame = CFrame.lookAt(flatTowerPos, flatEnemyPos)
				local pos = PrimaryPart.Position

				-- airport doesnt rotate
				if not Tower.Name:find("Airport") then
					PrimaryPart.CFrame = CFrame.new(pos) * CFrame.Angles(0, select(2, lookCFrame:ToEulerAnglesYXZ()), 0)
				end

				if AnimationTrack.IsPlaying then
					if Tower.Name ~= "Airport" then
						AnimationTrack:Stop()
					end
				end

				if Tower.Name ~= "Airport" then
					AnimationTrack:AdjustSpeed(getGameSpeed())
					AnimationTrack:Play()
				end

				-- handle different tower abilities
				if CustomAbility == "Deformation" then
					-- grenade/explosion ability
					local names = {"Dynamite", "Grenade"}
					local partToHide = findPartInModel(Tower, names)

					-- hide projectile then show it again
					if partToHide then
						task.spawn(function()
							partToHide.Transparency = 1
							task.wait((AttackCooldown - .5) / getGameSpeed())
							local tweenInfo = TweenInfo.new(0.25 / getGameSpeed(), Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
							local goal = { Transparency = 0 }

							local tween = TweenService:Create(partToHide, tweenInfo, goal)
							tween:Play()
							tween.Completed:Wait()
						end)
					end

					-- spawn explosion effect
					local ExplosionPart = ExplosionTemplate:Clone()
					ExplosionPart.Position = enemyPos - Vector3.new(0, 2.5, 0)
					ExplosionPart.Parent = workspace

					-- play sound with cooldown
					if os.clock() - lastGrenadeSoundTime > 0.1 then
						Remotes.Audio.ServerToClient:FireAllClients("Grenader")
						lastGrenadeSoundTime = os.clock()
					end

					-- emit particles
					task.spawn(function()
						task.wait(0.05 / getGameSpeed())
						for _, Particle in ipairs(ExplosionPart:GetDescendants()) do
							if Particle:IsA("ParticleEmitter") then
								Particle:Emit(4)
							end
						end
					end)

					-- cleanup explosion
					task.spawn(function()
						task.wait(3 / getGameSpeed())
						if ExplosionPart and ExplosionPart.Parent then
							ExplosionPart:Destroy()
						end
					end)

					createCrater(enemyPos - Vector3.new(0, 2.5, 0), 2, 12)

				elseif CustomAbility == "Slowness" then
					-- slowing ability
					if os.clock() - lastAbilitySoundTime > 0.1 then
						Remotes.Audio.ServerToClient:FireClient(Player, Tower.Name)
						lastAbilitySoundTime = os.clock()
					end

					local ApplySlowness = Remotes.Game:FindFirstChild("ApplySlowness")
					if not ApplySlowness then return end

					ApplySlowness:Fire(enemyHumanoid, .5, 3)

				elseif CustomAbility == "Magician" then
					-- beam attack ability
					local Scepter = Model:FindFirstChild("Scepter")
					if not Scepter then return end

					local Beam1Attachment = Scepter:FindFirstChild("Beam1")
					local BeamTargetAttachment = Scepter:FindFirstChild("BeamTarget")
					if not Beam1Attachment or not BeamTargetAttachment then return end

					if not magicianActive then
						magicianActive = true

						-- enable beams
						for _, Beam in ipairs(Beam1Attachment:GetChildren()) do
							if Beam:IsA("Beam") then
								Beam.Enabled = true
							end
						end

						-- track enemy with beam
						task.spawn(function()
							while Tower.Parent == Towers do
								local newTarget, distance = getClosestEnemy(Tower, Range)
								if newTarget and newTarget.PrimaryPart and distance <= Range then
									BeamTargetAttachment.WorldPosition = newTarget.PrimaryPart.Position + Vector3.new(0, -0.5, 0)
								else
									-- disable beams when no target
									for _, Beam in ipairs(Beam1Attachment:GetChildren()) do
										if Beam:IsA("Beam") then
											Beam.Enabled = false
										end
									end
									break
								end
								task.wait(0.03 / getGameSpeed())
							end

							for _, Beam in ipairs(Beam1Attachment:GetChildren()) do
								if Beam:IsA("Beam") then
									Beam.Enabled = false
								end
							end
						end)
						task.wait(.03 / getGameSpeed())

						magicianActive = false
					else
						print("active")
					end

				elseif CustomAbility == "Wizard" then
					-- wizard attack with projectile hiding
					if os.clock() - lastAbilitySoundTime > 0.1 then
						Remotes.Audio.ServerToClient:FireClient(Player, Tower.Name)
						lastAbilitySoundTime = os.clock()
					end

					local names = {"Dynamite", "Grenade"}
					local partToHide = findPartInModel(Tower, names)

					if partToHide then
						task.spawn(function()
							partToHide.Transparency = 1
							task.wait((AttackCooldown - .5) / getGameSpeed())
							local tweenInfo = TweenInfo.new(0.25 / getGameSpeed(), Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
							local goal = { Transparency = 0 }

							local tween = TweenService:Create(partToHide, tweenInfo, goal)
							tween:Play()
							tween.Completed:Wait()
						end)
					end

				elseif CustomAbility == "None" then
					-- basic attack with sound
					local baseName = Tower.Name:gsub("_%d+$", "")

					if os.clock() - lastAbilitySoundTime > 0.1 then
						Remotes.Audio.ServerToClient:FireClient(Player, baseName)
						lastAbilitySoundTime = os.clock()
					end
				end

				-- emit fist particles if tower has them
				local FistR = Model:FindFirstChild("FistR")
				if FistR then
					for _, Child in ipairs(FistR:GetDescendants()) do
						if Child:IsA("ParticleEmitter") then
							Child:Emit(2)
						end
					end
				end

				-- deal damage to enemy
				local success, response = pcall(function()
					enemyHumanoid:TakeDamage(Damage)

					-- show damage numbers
					if enemyHumanoid.Health > 0 then
						Remotes.Game.VisualDamage:FireAllClients(enemyHumanoid.Parent,Damage)
					end

					-- handle enemy death
					if enemyHumanoid.Health <= 0 then
						local MoneyTemplate = ReplicatedStorage.Storage.Billboards.Money:Clone()
						if not MoneyTemplate then return end

						local UserData = Player:FindFirstChild("UserData")
						if not UserData then return end

						local EXP = UserData:FindFirstChild("EXP")
						if not EXP then return end

						local Money = UserData:FindFirstChild("Money")
						if not Money then return end

						local enemyName = enemyHumanoid.Parent.Name
						local reward = 0

						if enemyName and EnemyData[enemyName] then
							local BaseCash = EnemyData[enemyName].Money
							local EXPperKill = math.random(10, 20)
							local CashPerKill = BaseCash

							Remotes.Audio.ServerToClient:FireClient(Player, "EnemyDying")

							-- calculate multiplier from gamepasses
							local Multi = 1

							pcall(function()
								if MarketplaceService:UserOwnsGamePassAsync(Player.UserId, 1529352425) then
									Multi *= 2
								end

								if MarketplaceService:UserOwnsGamePassAsync(Player.UserId, 1529258503) then
									Multi *= 1.5
								end
							end)

							EXP.Value = EXP.Value + EXPperKill * Multi

							-- split cash between all players
							for _, Plr in ipairs(Players:GetPlayers()) do
								local currentCash = Plr:GetAttribute("TempCash")
								reward = math.round(CashPerKill / #Players:GetPlayers())
								Plr:SetAttribute("TempCash", currentCash + reward)
							end
						end

						-- update stats
						increaseStat(Player, "WormsKilled", 1)
						updateQuestProgress(Player, enemyName, 1)

						if not(Player:GetAttribute("WormsKilled")) then
							Player:SetAttribute("WormsKilled", 1)
						else
							Player:SetAttribute("WormsKilled", Player:GetAttribute("WormsKilled") + 1)
						end

						-- show money earned billboard
						MoneyTemplate.Worm_Money.Worm_income.Text = "+$"..reward / #Players:GetPlayers()
						local deathPos = closestEnemy.PrimaryPart and closestEnemy.PrimaryPart.Position or Tower.PrimaryPart.Position
						MoneyTemplate.Parent = workspace

						local adorneePart

						if MoneyTemplate:IsA("BillboardGui") then
							MoneyTemplate.StudsOffset = Vector3.new(0, 3, 0)
							local part = Instance.new("Part")
							part.Anchored = true
							part.CanCollide = false
							part.Transparency = 1
							part.Size = Vector3.new(1, 1, 1)
							part.Position = deathPos + Vector3.new(0, .25, 0)
							part.Parent = workspace
							MoneyTemplate.Adornee = part
							adorneePart = part
						else
							MoneyTemplate:SetPrimaryPartCFrame(CFrame.new(deathPos + Vector3.new(0, 3, 0)))
						end

						-- cleanup money billboard
						task.spawn(function()
							task.wait(1 / getGameSpeed())
							if MoneyTemplate then
								MoneyTemplate:Destroy()
							end
							if adorneePart and adorneePart.Parent then
								adorneePart:Destroy()
							end
						end)

					elseif CustomAbility == "Thrower" then
						-- thrower projectile hiding
						local names = {"Dynamite", "Grenade", "Sheep"}
						local partToHide = findPartInModel(Tower, names)

						if partToHide then
							task.spawn(function()
								partToHide.Transparency = 1
								task.wait((AttackCooldown - .5) / getGameSpeed())
								local tweenInfo = TweenInfo.new(0.25 / getGameSpeed(), Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
								local goal = { Transparency = 0 }

								local tween = TweenService:Create(partToHide, tweenInfo, goal)
								tween:Play()
								tween.Completed:Wait()
							end)
						end
					end
				end)

				if not(success) then 
					warn(response)
				end

				task.wait(AttackCooldown / getGameSpeed())
			else
				-- no enemy in range, wait and check again
				task.wait(0.1 / getGameSpeed())
			end
		end
	end)
end

-- drops tower from above with bounce effect
local function dropAnimation(Tower : Model, TargetCFrame : CFrame)
	if not Tower.PrimaryPart then return end
	local startCFrame = TargetCFrame + Vector3.new(0, 3, 0)

	Tower:SetPrimaryPartCFrame(startCFrame)

	local tweenInfo = TweenInfo.new(0.25 / getGameSpeed(), Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tween = TweenService:Create(Tower.PrimaryPart, tweenInfo, {CFrame = TargetCFrame})

	tween:Play()
end

-- moves grandma unit backwards along the path
local function moveGrandmaBackwards(unit: Model, TOwer)
	if not unit then return end

	-- setup health bar
	local Health = ReplicatedStorage.Storage.Billboards.Health:Clone()
	if not Health then return end

	local hrp = unit:FindFirstChild("HumanoidRootPart")
	local humanoid = unit:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end

	-- play walk animation
	local animator = unit:FindFirstChild(unit.Name):FindFirstChild("Humanoid"):FindFirstChildOfClass("Animator")
	if animator then
		local walkAnim = Instance.new("Animation")
		walkAnim.AnimationId = "rbxassetid://75891183321464"
		local walkTrack = animator:LoadAnimation(walkAnim)
		walkTrack.Looped = true
		walkTrack:Play()
	end

	local Bar = Health.Worm_Health.Bar
	local HPText = Health.Worm_Health.HP

	task.spawn(function()
		-- scale health based on tower upgrade level
		if TOwer.Name:find("_2") then
			humanoid.MaxHealth = 250
			humanoid.Health = 250
		elseif TOwer.Name:find("_3") then
			humanoid.MaxHealth = 500
			humanoid.Health = 500
		end

		Health.Worm_Health.Tower_Name.Text = "Grandma"
		Health.Worm_Health.HP.Text = humanoid.Health.."/"..humanoid.MaxHealth
		Health.Parent = hrp

		-- updates health bar ui
		local function updateHealth()
			print(humanoid.Health)
			local ratio = humanoid.Health / humanoid.MaxHealth
			Bar.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
			HPText.Text = string.format("%d / %d", humanoid.Health, humanoid.MaxHealth)
		end

		updateHealth()

		humanoid:GetPropertyChangedSignal("Health"):Connect(updateHealth)

		humanoid.Died:Connect(function()
			unit:Destroy()
		end)
	end)

	-- sort waypoints in reverse order
	local waypoints = {}
	for _, wp in ipairs(Waypoints:GetChildren()) do
		local n = tonumber(wp.Name)
		if n then
			table.insert(waypoints, {index = n, part = wp})
		end
	end

	table.sort(waypoints, function(a, b)
		return a.index > b.index
	end)

	-- tweens unit to a position
	local function tweenToPosition(targetPos)
		if not unit or not hrp or not hrp.Parent then return false end
		local startPos = hrp.Position
		local distance = (targetPos - startPos).Magnitude
		local duration = distance / humanoid.WalkSpeed
		local direction = (targetPos - startPos).Unit
		local targetCFrame = CFrame.new(targetPos, targetPos + direction)

		local info = TweenInfo.new(duration, Enum.EasingStyle.Linear)
		local tween = TweenService:Create(hrp, info, {CFrame = targetCFrame})

		tween:Play()
		tween.Completed:Wait()

		return unit and unit.Parent ~= nil
	end

	-- walk backwards through all waypoints
	task.spawn(function()
		for _, w in ipairs(waypoints) do
			if not tweenToPosition(w.part.Position) then 
				print("Tween failed or Grandma deleted")
				return 
			end
		end

		-- reach spawn and despawn
		local target = Path:FindFirstChild("Enemy_Spawn")
		if target and unit and unit.Parent then
			tweenToPosition(target.Position)
			if unit and unit.Parent then
				unit:Destroy()
			end
		end
	end)
end

-- creates a grandma unit for grandma towers
function createGrandma(ParentModel : Model)
	local GrandmaModel = ServerStorage.Units.Grandma:Clone()
	if not GrandmaModel then return end 

	local Path = workspace.Path

	-- setup collision
	for _, descendant in ipairs(GrandmaModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CollisionGroup = collision_Group
		end
	end 

	-- spawn at end of path facing backwards
	local targetCFrame = Path.Enemy_Target.CFrame
	local flippedCFrame = targetCFrame * CFrame.Angles(0, math.rad(180), 0)

	local spawnPosition = flippedCFrame.Position + Vector3.new(0, GrandmaModel.PrimaryPart.Size.Y / 2, 0)
	GrandmaModel.Parent = workspace

	-- handle cleanup and respawning
	task.spawn(function()
		-- destroy grandma if tower is destroyed
		ParentModel.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				if GrandmaModel and GrandmaModel.Parent then
					GrandmaModel:Destroy()
				end
			end
		end)

		-- respawn grandma if it dies while tower exists
		GrandmaModel.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				if not ParentModel or ParentModel.Parent == nil then
					return
				end

				task.wait(0.1)
				createGrandma(ParentModel)
			end
		end)
	end)

	GrandmaModel:MoveTo(spawnPosition)

	task.wait(0.1)
	moveGrandmaBackwards(GrandmaModel, ParentModel)
end

-- spawns a tower for a player
local function spawnUnit(Player : Player, TowerName : string, CFrame, isUpgrade)
	-- init player tower table
	if not playerTowers[Player] then
		playerTowers[Player] = {}
	end

	-- check tower limit
	if not isUpgrade and #playerTowers[Player] >= MAX_TOWERS_PER_PLAYER then
		Remotes.Game.SendNotification:FireClient(Player, "Max tower limit ("..MAX_TOWERS_PER_PLAYER..") reached!", "Error")
		return
	end

	-- validate tower exists
	local TowerInfo = TowerModels:FindFirstChild(TowerName)
	if not TowerInfo then return end

	local Data = TowerData[TowerName]
	if not Data then return end

	local TowerPrice = Data.Price
	if not TowerPrice then return end

	local PlayerCash = Player:GetAttribute("TempCash")
	if not PlayerCash then return end

	local PlayerTagTemplate = ReplicatedStorage.Storage.Billboards.Player
	if not PlayerTagTemplate then return end

	-- check and deduct money
	if not isUpgrade then
		if PlayerCash < TowerPrice then
			local NeededCash = TowerPrice - PlayerCash
			Remotes.Game.SendNotification:FireClient(Player, "You need $"..NeededCash, "Error")
			return
		end
		Player:SetAttribute("TempCash", PlayerCash - TowerPrice)
	end

	-- clone and setup tower
	local Tower = TowerInfo:Clone()
	Tower:SetAttribute("Owner", Player.UserId)

	-- disable collision on all parts
	for _, BasePart in ipairs(Tower:GetDescendants()) do
		if BasePart:IsA("BasePart") then
			BasePart.CanCollide = false
		end
	end

	-- add player name tag
	local PlayerTag = PlayerTagTemplate:Clone()
	local towerBaseName = Tower.Name:gsub("_%d+$", "")
	PlayerTag.Tower_Level.Player.Text = "@"..Player.Name.."'s "..towerBaseName
	PlayerTag.Parent = Tower

	Tower.Parent = Towers

	print(Tower.Name.."_Voice")

	Remotes.Audio.ServerToClient:FireClient(Player, Tower.Name.."_Voice")

	dropAnimation(Tower, CFrame)
	enableTower(Player, Tower)

	-- special handling for grandma tower
	if Tower.Name:match("Grandma") then
		local InnerModel = Tower.Tower:FindFirstChildOfClass("Model")
		print(InnerModel.Name)

		-- make grandma tower semi-transparent
		InnerModel.Torso.Transparency = .5

		for _, BasePart in ipairs(InnerModel.Torso:GetChildren()) do
			if BasePart:IsA("BasePart") then
				BasePart.Transparency = .5
			end
		end

		task.spawn(createGrandma, Tower)
	end

	-- spawn placement particles
	if not isUpgrade then
		table.insert(playerTowers[Player], Tower)

		local new_particle = Storage.Particles.PlaceTemplate:Clone()
		new_particle.Parent = workspace
		new_particle.CFrame = Tower.PrimaryPart.CFrame

		task.delay(.5 / getGameSpeed(), function()
			for _, particle in ipairs(new_particle:GetDescendants()) do
				if particle:IsA("ParticleEmitter") then
					particle.Enabled = false
				end
			end

			task.wait(1 / getGameSpeed())

			new_particle:Destroy()
		end)
	end

	return Tower
end

-- place tower remote
Remotes:FindFirstChild("Building"):FindFirstChild("PlaceTower").OnServerEvent:Connect(function(Player: Player, TowerName: string, CFrame: CFrame)
	spawnUnit(Player, TowerName, CFrame)

	local data = DataManager.Stored[Player.UserId]
	data.Data.Statistics.TowersPlaced += 1

	-- update towers placed stat
	if not(Player:GetAttribute("TowersPlaced")) then
		Player:SetAttribute("TowersPlaced", 1)
	else
		Player:SetAttribute("TowersPlaced", Player:GetAttribute("TowersPlaced") + 1)
	end
end)

-- sell tower remote
Remotes:FindFirstChild("Game"):FindFirstChild("SellTower").OnServerEvent:Connect(function(Player : Player, Tower : Model)
	if not Tower then return end

	-- verify ownership
	local ownerId = Tower:GetAttribute("Owner")
	if ownerId ~= Player.UserId then
		Remotes.Game.SendNotification:FireClient(Player, "You do not own this tower!", "Error")
		return
	end

	local Cash = Player:GetAttribute("TempCash")
	if not Cash then return end

	local TowerName = Tower.Name
	if not TowerName then return end

	local TowerInfo = TowerData[TowerName]
	if not TowerInfo or not TowerInfo.Price then return end

	-- give 75% of value back
	local SellValue = math.floor(TowerInfo.Price * 0.75)

	local NewCash = Cash + SellValue
	Player:SetAttribute("TempCash", NewCash)

	-- remove from player tower list
	if playerTowers[Player] then
		for i, t in ipairs(playerTowers[Player]) do
			if t == Tower then
				table.remove(playerTowers[Player], i)
				break
			end
		end
	end

	Tower:Destroy()
end)

-- upgrade tower remote
Remotes.Game.Upgrade.OnServerEvent:Connect(function(Player : Player, Tower : Model)
	if not Tower then return end

	-- verify ownership
	local ownerId = Tower:GetAttribute("Owner")
	if ownerId ~= Player.UserId then
		Remotes.Game.ReEnableInfo:FireClient(Player, Tower)
		Remotes.Game.SendNotification:FireClient(Player, "You do not own this tower!", "Error")
		return
	end

	local PrimaryPart = Tower.PrimaryPart
	if not PrimaryPart then return end

	local PreUpgradePos = PrimaryPart.Position
	if not PreUpgradePos then return end

	local PreUpgradeName = Tower.Name
	if not PreUpgradeName then return end

	-- figure out current upgrade level
	local CurrentUpgrade = 1

	if not Tower.Name:match("_") then
		CurrentUpgrade = 2
	elseif Tower.Name:match("1") then
		CurrentUpgrade = 2
	elseif Tower.Name:match("2") then
		CurrentUpgrade = 3
	elseif Tower.Name:match("3") then
		CurrentUpgrade = 4
	end

	-- build target tower name
	local TargetName
	if not Tower.Name:match("_") then
		TargetName = PreUpgradeName.."_"..CurrentUpgrade
	else
		TargetName = PreUpgradeName:gsub("%d+$", "") .. CurrentUpgrade
	end

	if not TowerData then warn("No TowerData for", TargetName) return end

	local PriceData = TowerData[TargetName].Price
	if not PriceData then return end

	local PlayerCash = Player:GetAttribute("TempCash")
	if not PlayerCash then return end

	-- check if player can afford
	if PlayerCash < PriceData then
		local NeededCash = PriceData - PlayerCash
		Remotes.Game.SendNotification:FireClient(Player, "You need $"..NeededCash, "Error")
		return
	end

	Player:SetAttribute("TempCash", PlayerCash - PriceData)
	increaseStat(Player, "TowersPlaced", 1)

	-- replace old tower with upgraded one
	if playerTowers[Player] then
		for i, oldTower in ipairs(playerTowers[Player]) do
			if oldTower == Tower then
				-- spawn upgrade particles
				local new_particle = Storage.Particles.UpgradeTemplate:Clone()
				new_particle.Parent = workspace
				new_particle.CFrame = Tower.PrimaryPart.CFrame
				local SaveCFrame = Tower.PrimaryPart.CFrame

				task.delay(.5 / getGameSpeed(), function()
					for _, particle in ipairs(new_particle:GetDescendants()) do
						if particle:IsA("ParticleEmitter") then
							particle.Enabled = false
						end
					end

					task.wait(1 / getGameSpeed())

					new_particle:Destroy()
				end)

				Tower:Destroy()
				Remotes.Audio.ServerToClient:FireClient(Player, "TowerUpgrade")
				task.wait(0.1 / getGameSpeed())

				-- spawn new upgraded tower
				local newTower = spawnUnit(Player, TargetName, SaveCFrame, true)
				if newTower then
					playerTowers[Player][i] = newTower
				end

				Remotes.Game.ReEnableInfo:FireClient(Player, newTower)

				updateQuestProgress(Player, "TowerUpgrades", 1)

				break
			end
		end
	end
end)

-- change tower targeting priority
Remotes.Building.Target.OnServerEvent:Connect(function(Plr, Model, Target)
	if not(Model) then return end
	Model:SetAttribute("Priority", Target)
end)

-- cleanup when player leaves
Players.PlayerRemoving:Connect(function(player)
	playerTowers[player] = nil
end)

return {}