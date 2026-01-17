local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Essentials = require(ReplicatedStorage.KiwiBird.Essentials)
local vfxPlayer = require(ReplicatedStorage["A-Packages"].VFXPlayer)
local sharedModules = ReplicatedStorage.Modules
local Maid = require(sharedModules.Nevermore.Maid)
local safeCharacterAdded = require(sharedModules.Utils.safeCharacterAdded)
local safePlayerAdded = require(sharedModules.Utils.safePlayerAdded)
local characterMaid = Maid.new()

local PongService = {}
local PongServiceEvent = ReplicatedStorage.Remotes.Events.PongService

local activePowerConnections = {}
local activeGames = {}
local activeTables = {}
local activeBallChecks = {}
local playerPowerSpeeds = {}

local roundState = {}

-- Enhanced redemption tracking
local redemptionState = {}
local redemptionRounds = {}

-- Helper function to get cup count for a player side
local function GetCupCount(tableModel, playerSide)
	local cupsFolder = tableModel.Main["cups" .. playerSide]

	return #cupsFolder:GetChildren()
end

-- Helper function to get which side a player is on (1 or 2)
local function GetPlayerSide(tableModel, player)
	if tableModel["1"]:GetAttribute("taken") == player.Name then
		return 1
	else
		return 2
	end
end

-- Spawn a single cup for a player during redemption
local function SpawnRedemptionCup(tableModel, player)
	local playerSide = GetPlayerSide(tableModel, player)
	local cupsFolder = tableModel.Main["cups" .. playerSide]
	local cupPositions = tableModel.Main[tostring(playerSide)]

	print("SpawnRedemptionCup called for", player.Name, "on side", playerSide)
	print("Current cup count:", #cupsFolder:GetChildren())

	local spawnPosition = cupPositions["1"]

	if spawnPosition then
		local cupTemplate = ReplicatedStorage.Assets.Models.Cups:FindFirstChild(player.PlayerStats.EquippedCups.Value)
		if not cupTemplate then
			warn("Cup template not found for", player.PlayerStats.EquippedCups.Value)
			return false
		end

		local cupClone = cupTemplate:Clone()
		cupClone.Parent = cupsFolder
		cupClone:PivotTo(spawnPosition.WorldCFrame)
		cupClone.Name = spawnPosition.Name

		print("SUCCESS: Spawned redemption cup for", player.Name, "at position", spawnPosition.Name)
		print("New cup count:", #cupsFolder:GetChildren())

		return true
	else
		warn("No available position to spawn cup for", player.Name)

		return false
	end
end

local function IsGameActive(player1, player2)
	if not player1 or not player1.Parent then
		return false
	end
	if not player2 or not player2.Parent then
		return false
	end
	if not activeGames[player1] or not activeGames[player2] then
		return false
	end
	if not activeTables[player1] or not activeTables[player2] then
		return false
	end

	return true
end

local function IsPlayerGameActive(player)
	if not player or not player.Parent then
		return false
	end
	if not activeGames[player] then
		return false
	end
	if not activeTables[player] then
		return false
	end

	return true
end

local function CleanupPlayerGame(player: Player)
	print("Cleaning up game for player:", player.Name)

	local ball = PongService.FindBall(player)

	if ball then
		PongService.StopPowerMeter(ball)

		if activeBallChecks[ball] then
			task.cancel(activeBallChecks[ball])
			activeBallChecks[ball] = nil
		end

		ball:Destroy()
	end

	local tableModel = activeTables[player]

	if tableModel and roundState[tableModel] then
		roundState[tableModel] = nil
	end

	if tableModel and redemptionRounds[tableModel] then
		redemptionRounds[tableModel] = nil
	end

	activeGames[player] = nil
	activeTables[player] = nil
	playerPowerSpeeds[player] = nil
	redemptionState[player] = nil

	-- Lazy. Could error if the player is leaving and `PlayerGui` doesn't exist.
	pcall(function()
		local playButton = player.PlayerGui.MainGameUi.TopButtons.Play
		playButton.Visible = true
		playButton.Active = true
	end)
end

local function InstaLose(player, opponent)
	local Table = activeTables[player] or activeTables[opponent]

	if not Table then
		warn("Table not found in activeTables for InstaLose")

		return
	end

	if redemptionRounds[Table] then
		redemptionRounds[Table] = nil
	end

	local multiplier = opponent.PlayerStats.Multiplier.Value + opponent.PlayerStats.MoneyUpgradeMultiplier.Value
	local money = Table:GetAttribute("money") * multiplier

	if opponent.PlayerStats.Vip.Value then
		opponent.leaderstats.Coins.Value += math.floor(money * 2)
	else
		opponent.leaderstats.Coins.Value += money
	end

	opponent.leaderstats.Wins.Value += 1
	opponent.leaderstats.Streak.Value += 1
	opponent.PlayerStats.PastStreak.Value = opponent.leaderstats.Streak.Value

	if player and player.Character and player.Character:FindFirstChild("InGame") then
		player.Character.InGame.Value = false
	end
	if opponent and opponent.Character and opponent.Character:FindFirstChild("InGame") then
		opponent.Character.InGame.Value = false
	end

	player.leaderstats.Streak.Value = 0
	opponent.PlayerStats.EarnedMoney.Value = money

	local leaderstats = opponent:FindFirstChild("leaderstats")
	assert(leaderstats, "Invalid leaderstats.")

	if leaderstats.Streak and leaderstats.Streak.Value > 0 then
		if
			opponent
			and opponent.Character
			and opponent.Character:FindFirstChild("Head")
			and opponent.Character.Head:FindFirstChild("Streak")
		then
			local billboard = opponent.Character.Head.Streak
			billboard.TextLabel.Text = opponent.leaderstats.Streak.Value
		else
			local billboard = ReplicatedStorage.Assets.VFX.Streak:Clone()
			billboard.Parent = opponent.Character.Head
			billboard.TextLabel.Text = opponent.leaderstats.Streak.Value
		end
	end

	if
		player.Character
		and player.Character:FindFirstChild("Head")
		and player.Character.Head:FindFirstChild("Streak")
	then
		local billboard = player.Character.Head.Streak
		billboard:Destroy()
	end

	PongServiceEvent:FireClient(opponent, { ["Action"] = "Win" })
	PongServiceEvent:FireClient(player, { ["Action"] = "Lose" })
end

function OnPongServiceEvent(plr, argtable)
	if argtable["Action"] == "Throw" then
		if not IsPlayerGameActive(plr) then
			warn("Game no longer active, ignoring throw action")

			return
		end

		local ball = PongService.FindBall(plr)
		if not ball then
			return warn("Ball not found for player:", plr.Name)
		end

		PongService.StopPowerMeter(ball)

		local power = argtable["Power"] or 50
		local direction = argtable["Direction"] or Vector3.new(0, 0, -1)
		local startPos = ball.Position

		local params = PongService.CalculateTrajectoryParams(power)

		print(plr.Name, "threw ball with power:", power, "duration:", params.duration)

		local tableModel = ball.Parent.Parent
		local player1 = Players:FindFirstChild(tableModel["1"]:GetAttribute("taken"))
		local player2 = Players:FindFirstChild(tableModel["2"]:GetAttribute("taken"))

		if not player1 or not player2 then
			return warn("Could not find both players for table")
		end

		if not IsGameActive(player1, player2) then
			return warn("Game no longer active before throw animation")
		end

		ball.Transparency = 1
		ball.CanCollide = false
		ball.Anchored = true

		local trajectoryData = {
			["Action"] = "AnimateBall",
			["StartPos"] = startPos,
			["Direction"] = direction,
			["Power"] = power,
			["Duration"] = params.duration,
			["BallName"] = ball.Name,
		}

		PongServiceEvent:FireClient(player1, trajectoryData)
		PongServiceEvent:FireClient(player2, trajectoryData)

		PongService.CheckBallCollision(ball, power, direction, startPos, tableModel)
	end
end

function PongService.FindTable(player1, player2)
	for _, v in workspace.QueueTables:GetChildren() do
		local podium1 = v:FindFirstChild("1")
		local podium2 = v:FindFirstChild("2")
		if
			(podium1:GetAttribute("taken") == player1.Name and podium2:GetAttribute("taken") == player2.Name)
			or (podium1:GetAttribute("taken") == player2.Name and podium2:GetAttribute("taken") == player1.Name)
		then
			return v
		end
	end

	return nil
end

function PongService.FindBall(plr)
	for _, v in workspace.QueueTables:GetDescendants() do
		if v.Name == plr.Name .. "_Ball" then
			return v
		end
	end

	return nil
end

function PongService.CalculateTrajectoryParams(power)
	local minDistance = 3
	local maxDistance = 12
	local distance = minDistance + ((power / 100) * (maxDistance - minDistance))
	local peakHeight = 0.8 + (power / 100) * 1.2
	local peakPosition = 0.4
	local dropSteepness = 1.8
	local duration = 0.8 + (distance / maxDistance) * 0.7

	return {
		distance = distance,
		peakHeight = peakHeight,
		peakPosition = peakPosition,
		dropSteepness = dropSteepness,
		duration = duration,
	}
end

function PongService.CalculatePositionAtTime(t, startPos, direction, params)
	local segmentDistance = params.distance * t
	local position = startPos + (direction * segmentDistance)

	local verticalOffset
	if t < params.peakPosition then
		local riseT = t / params.peakPosition
		local easeOut = 1 - math.pow(1 - riseT, 2.5)
		verticalOffset = params.peakHeight * easeOut
	else
		local fallT = (t - params.peakPosition) / (1 - params.peakPosition)
		local peakToEnd = 1 - math.pow(fallT, params.dropSteepness)
		verticalOffset = params.peakHeight * peakToEnd - (fallT * fallT * 1)
	end

	return position + Vector3.new(0, verticalOffset, 0)
end

function PongService.AutoThrowBall(ball, plr)
	if not ball or not ball.Parent then
		return
	end

	if not IsPlayerGameActive(plr) then
		print("Game no longer active, cancelling auto-throw")

		return
	end

	print(plr.Name, "auto-throwing ball due to countdown expiration")

	local power = ball.Power.Value or 50
	local tableModel = ball.Parent.Parent
	local direction

	if tableModel:GetAttribute("side") == 1 then
		direction = Vector3.new(0, 0, -1)
	else
		direction = Vector3.new(0, 0, 1)
	end

	local startPos = ball.Position
	PongService.StopPowerMeter(ball)

	local params = PongService.CalculateTrajectoryParams(power)
	print(plr.Name, "auto-threw ball with power:", power, "duration:", params.duration)

	local player1 = Players:FindFirstChild(tableModel["1"]:GetAttribute("taken"))
	local player2 = Players:FindFirstChild(tableModel["2"]:GetAttribute("taken"))

	if not player1 or not player2 then
		warn("Could not find both players for table")

		return
	end

	if not IsGameActive(player1, player2) then
		print("Game no longer active before auto-throw animation")

		return
	end

	ball.Transparency = 1
	ball.CanCollide = false
	ball.Anchored = true

	local trajectoryData = {
		["Action"] = "AnimateBall",
		["StartPos"] = startPos,
		["Direction"] = direction,
		["Power"] = power,
		["Duration"] = params.duration,
		["BallName"] = ball.Name,
	}

	PongServiceEvent:FireClient(player1, trajectoryData)
	PongServiceEvent:FireClient(player2, trajectoryData)

	PongService.CheckBallCollision(ball, power, direction, startPos, tableModel)
end

function PongService.EvaluateRedemptionRound(tableModel, player1, player2)
	local roundData = redemptionRounds[tableModel]

	if not roundData then
		warn("No redemption round data found!")

		return
	end

	print(roundData)

	local firstResult = roundData.firstShooterResult
	local secondResult = roundData.secondShooterResult
	local firstShooter = roundData.firstShooter
	local secondShooter = roundData.secondShooter

	print(
		"Evaluating redemption round",
		roundData.round,
		"- First:",
		firstShooter.Name,
		"=",
		firstResult,
		", Second:",
		secondShooter.Name,
		"=",
		secondResult
	)

	local cam = tableModel.Cams.cam3

	-- Case 1: First shooter missed, Second shooter hit -> Second shooter wins
	if firstResult == "miss" and secondResult == "hit" then
		print(secondShooter.Name, "WINS! (opponent missed, they hit)")
		redemptionRounds[tableModel] = nil
		PongService.FinalizeWin(tableModel, secondShooter, firstShooter, cam, false)

		return
	end

	-- Case 2: First shooter hit, Second shooter missed -> First shooter wins
	if firstResult == "hit" and secondResult == "miss" then
		print(firstShooter.Name, "WINS! (they hit, opponent missed)")
		redemptionRounds[tableModel] = nil
		PongService.FinalizeWin(tableModel, firstShooter, secondShooter, cam, false)

		return
	end

	-- Case 3: Both hit OR both missed -> Reset for next round
	roundData.round = roundData.round + 1
	roundData.firstShooterResult = nil
	roundData.secondShooterResult = nil
	roundData.waitingForSecondShot = false
	roundData.firstShotMade = true -- After surviving round 1, this stays true

	if roundData.round > roundData.maxRounds then
		print("MAX REDEMPTION ROUNDS REACHED! It's a DRAW!")
		PongService.HandleDraw(tableModel, player1, player2)

		return
	end

	local firstSide = GetPlayerSide(tableModel, firstShooter)
	local secondSide = GetPlayerSide(tableModel, secondShooter)

	local firstCups = GetCupCount(tableModel, firstSide)
	local secondCups = GetCupCount(tableModel, secondSide)

	print("Before respawn - First shooter cups:", firstCups, "Second shooter cups:", secondCups)

	if firstCups == 0 then
		SpawnRedemptionCup(tableModel, firstShooter)
	end
	if secondCups == 0 then
		SpawnRedemptionCup(tableModel, secondShooter)
	end

	local resultText = (firstResult == "hit" and secondResult == "hit") and "BOTH HIT!" or "BOTH MISSED!"

	PongServiceEvent:FireClient(player1, {
		["Action"] = "RedemptionRoundReset",
		["ResultText"] = resultText,
		["Round"] = roundData.round,
		["MaxRounds"] = roundData.maxRounds,
	})
	PongServiceEvent:FireClient(player2, {
		["Action"] = "RedemptionRoundReset",
		["ResultText"] = resultText,
		["Round"] = roundData.round,
		["MaxRounds"] = roundData.maxRounds,
	})

	task.delay(2, function()
		if not IsGameActive(player1, player2) then
			return
		end

		roundData.currentShooter = firstShooter
		PongService.GiveRedemptionTurn(tableModel, firstShooter, secondShooter, player1, player2)
	end)
end

function PongService.HandleDraw(tableModel, player1, player2)
	redemptionRounds[tableModel] = nil
	redemptionState[player1] = nil
	redemptionState[player2] = nil

	local cam = tableModel.Cams.cam3
	local totalMoney = tableModel:GetAttribute("money")
	local splitMoney = math.floor(totalMoney / 2)

	local player1Multiplier = player1.PlayerStats.Multiplier.Value + player1.PlayerStats.MoneyUpgradeMultiplier.Value
	local player2Multiplier = player2.PlayerStats.Multiplier.Value + player2.PlayerStats.MoneyUpgradeMultiplier.Value

	local player1Money = splitMoney * player1Multiplier
	local player2Money = splitMoney * player2Multiplier

	if player1.PlayerStats.Vip.Value then
		player1.leaderstats.Coins.Value += math.floor(player1Money * 2)
	else
		player1.leaderstats.Coins.Value += player1Money
	end

	if player2.PlayerStats.Vip.Value then
		player2.leaderstats.Coins.Value += math.floor(player2Money * 2)
	else
		player2.leaderstats.Coins.Value += player2Money
	end

	player1.PlayerStats.EarnedMoney.Value = player1Money
	player2.PlayerStats.EarnedMoney.Value = player2Money

	player1.Character.InGame.Value = false
	player2.Character.InGame.Value = false

	CleanupPlayerGame(player1)
	CleanupPlayerGame(player2)

	PongServiceEvent:FireClient(player1, {
		["Action"] = "Draw",
		["Cam"] = cam,
		["SplitMoney"] = player1Money,
	})
	PongServiceEvent:FireClient(player2, {
		["Action"] = "Draw",
		["Cam"] = cam,
		["SplitMoney"] = player2Money,
	})

	player1.Character.Humanoid.Health = 0
	player2.Character.Humanoid.Health = 0

	print("DRAW! Money split:", player1.Name, "gets", player1Money, ",", player2.Name, "gets", player2Money)
end

function PongService.GiveRedemptionTurn(tableModel, shooter, opponent, player1, player2)
	local shooterSide = GetPlayerSide(tableModel, shooter)
	local roundData = redemptionRounds[tableModel]
	local shooterUpcomingTurn = 1

	if roundData and roundData.turns then
		local shooterCurrentTurn = roundData.turns[shooter] or 0
		shooterUpcomingTurn = shooterCurrentTurn + 1
	end

	local ball = ReplicatedStorage.Assets.Models.Balls:FindFirstChild(shooter.PlayerStats.EquippedBalls.Value):Clone()
	ball.Parent = tableModel.Balls
	ball.Name = shooter.Name .. "_Ball"

	local roundText = "Round " .. roundData.round .. "/" .. roundData.maxRounds
	local powerSpeed = playerPowerSpeeds[shooter] or 1
	local redemptionHitSucceeded = roundData.redemptionHitSucceeded[shooter]

	if shooterSide == 1 then
		ball.CFrame = tableModel.Main.ball1.WorldCFrame
		tableModel:SetAttribute("side", 1)

		PongServiceEvent:FireClient(shooter, {
			["Action"] = "YourTurn",
			["CamSide"] = tableModel.Cams.cam1,
			["Ball"] = ball,
			["PowerSpeed"] = powerSpeed,
			["RedemptionTurn"] = shooterUpcomingTurn,
			["RedemptionHitSucceeded"] = redemptionHitSucceeded,
		})
		PongServiceEvent:FireClient(opponent, {
			["Action"] = "OpponentsTurn",
			["CamSide"] = tableModel.Cams.cam5,
			["OpponentRedemptionTurn"] = shooterUpcomingTurn,
			["RedemptionHitSucceeded"] = redemptionHitSucceeded,
		})
	else
		ball.CFrame = tableModel.Main.ball2.WorldCFrame
		tableModel:SetAttribute("side", 2)
		PongServiceEvent:FireClient(shooter, {
			["Action"] = "YourTurn",
			["CamSide"] = tableModel.Cams.cam2,
			["Ball"] = ball,
			["PowerSpeed"] = powerSpeed,
			["RedemptionTurn"] = shooterUpcomingTurn,
			["RedemptionHitSucceeded"] = redemptionHitSucceeded,
		})
		PongServiceEvent:FireClient(opponent, {
			["Action"] = "OpponentsTurn",
			["CamSide"] = tableModel.Cams.cam4,
			["OpponentRedemptionTurn"] = shooterUpcomingTurn,
			["RedemptionHitSucceeded"] = redemptionHitSucceeded,
		})
	end

	local text = roundData.round < 2 and "REDEMPTION " .. roundText .. " - " .. shooter.Name .. "'s Shot!"
		or "Overtime " .. roundText .. " - " .. shooter.Name .. "'s Shot!"

	tableModel.Main.BillboardGui.TextLabel.Text = text

	PongService.StartPowerMeter(ball, shooter)
end

function PongService.CheckBallCollision(ball, power, direction, startPos, tableModel)
	if activeBallChecks[ball] then
		task.cancel(activeBallChecks[ball])
		activeBallChecks[ball] = nil
	end

	local params = PongService.CalculateTrajectoryParams(power)
	local startTime = tick()
	local hitDetected = false

	local checkThread = task.defer(function()
		while not hitDetected and ball and ball.Parent do
			local elapsed = tick() - startTime
			local t = elapsed / params.duration

			if t >= 1 then
				print("Ball missed: Trajectory complete without collision")

				if ball and ball.Parent then
					local player1 = Players:FindFirstChild(tableModel["1"]:GetAttribute("taken"))
					local player2 = Players:FindFirstChild(tableModel["2"]:GetAttribute("taken"))

					-- Game no longer active after ball miss
					if not player1 or not player2 or not IsGameActive(player1, player2) then
						if ball and ball.Parent then
							ball:Destroy()
						end
						break
					end

					local shooterName = string.match(ball.Name, "(.+)_Ball")
					local shooter = Players:FindFirstChild(shooterName)
					local Table = ball.Parent.Parent

					ball:Destroy()

					-- Check if we're in redemption mode
					local roundData = redemptionRounds[tableModel]

					if roundData and roundData.active then
						-- Record the miss
						-- Increment this shooter's redemption turn count
						roundData.turns[shooter] = (roundData.turns[shooter] or 0) + 1
						roundData.redemptionHitSucceeded[shooter] = false

						if shooter == roundData.firstShooter then
							roundData.firstShooterResult = "miss"
							print(shooter.Name, "MISSED their redemption shot (first shooter)")
						else
							roundData.secondShooterResult = "miss"
							print(shooter.Name, "MISSED their redemption shot (second shooter)")
						end

						-- Check if both have shot
						if roundData.firstShooterResult and roundData.secondShooterResult then
							task.delay(1, function()
								if IsGameActive(player1, player2) then
									PongService.EvaluateRedemptionRound(tableModel, player1, player2)
								end
							end)
						else
							-- First shooter missed but survived (not round 1 first shot), second shooter's turn
							roundData.waitingForSecondShot = true
							local nextShooter = roundData.secondShooter
							local waitingPlayer = roundData.firstShooter

							PongServiceEvent:FireClient(player1, {
								["Action"] = "RedemptionMiss",
								["Shooter"] = shooter,
								["NextShooter"] = nextShooter,
							})
							PongServiceEvent:FireClient(player2, {
								["Action"] = "RedemptionMiss",
								["Shooter"] = shooter,
								["NextShooter"] = nextShooter,
							})

							task.delay(1.5, function()
								if IsGameActive(player1, player2) then
									roundData.currentShooter = nextShooter
									PongService.GiveRedemptionTurn(
										tableModel,
										nextShooter,
										waitingPlayer,
										player1,
										player2
									)
								end
							end)
						end
						break
					else
						local p1_cups = GetCupCount(tableModel, GetPlayerSide(tableModel, player1))
						local p2_cups = GetCupCount(tableModel, GetPlayerSide(tableModel, player2))

						local side = Table:GetAttribute("side")
						local cam = Table.Cams[`cam{side}`]
						local target = side == 1 and player2 or player1

						-- Test: Instant win
						-- PongService.FinalizeWin(tableModel, target, shooter, cam, true)
						-- break

						if p1_cups == 0 or p2_cups == 0 then
							if p1_cups == p2_cups then
								PongServiceEvent:FireClient(player1, {
									["Action"] = "MiddleTurn",
									["Cam"] = cam,
									["Drink"] = true,
									["Target"] = target,
								})
								PongServiceEvent:FireClient(player2, {
									["Action"] = "MiddleTurn",
									["Cam"] = cam,
									["Drink"] = true,
									["Target"] = target,
								})

								task.delay(1.5, function()
									if not IsGameActive(player1, player2) then
										return
									end
									PongService.StartRedemption(tableModel, target, shooter, player1, player2)
								end)
							elseif p2_cups == 0 then
								PongService.FinalizeWin(tableModel, target, shooter, cam, true)
							else
								PongService.FinalizeWin(tableModel, target, shooter, cam, true)
							end
							break
						end
					end

					-- Normal game miss (not in redemption)
					PongServiceEvent:FireClient(player1, { ["Action"] = "TurnTransition" })
					PongServiceEvent:FireClient(player2, { ["Action"] = "TurnTransition" })

					task.wait(0.25)

					if IsGameActive(player1, player2) then
						PongService.PickASide(player1, player2, false)
					end
				end
				break
			end

			local currentPos = PongService.CalculatePositionAtTime(t, startPos, direction, params)

			local region =
				Region3.new(currentPos - Vector3.new(0.25, 0.25, 0.25), currentPos + Vector3.new(0.25, 0.25, 0.25))

			local partsInRegion = workspace:FindPartsInRegion3WithIgnoreList(region, {}, 100)

			for _, part in ipairs(partsInRegion) do
				if part.Name ~= "Hitbox" or hitDetected then
					continue
				end
				hitDetected = true

				local player1 = Players:FindFirstChild(tableModel["1"]:GetAttribute("taken"))
				local player2 = Players:FindFirstChild(tableModel["2"]:GetAttribute("taken"))

				Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.ballcup, part, 2)
				part.Attachment.shockwave:Emit(3)

				local cupModel = part.Parent
				local cupPosition = cupModel:FindFirstChild("Cup") and cupModel.Cup.Position or part.Position
				local currentBallPos = PongService.CalculatePositionAtTime(t, startPos, direction, params)

				local sinkData = {
					["Action"] = "BallInCup",
					["BallName"] = ball.Name,
					["BallPosition"] = currentBallPos,
					["CupPosition"] = cupPosition,
				}

				PongServiceEvent:FireClient(player1, sinkData)
				PongServiceEvent:FireClient(player2, sinkData)

				task.delay(1, function()
					if ball and ball.Parent then
						ball:Destroy()
					end

					if not player1 or not player2 or not IsGameActive(player1, player2) then
						return print("Game no longer active after cup hit")
					end

					local cam = nil
					local target = nil
					local winner = nil

					if part.Parent.Parent.Name == "cups1" then
						cam = tableModel.Cams.cam6
						target = player1
						winner = player2
					else
						cam = tableModel.Cams.cam7
						target = player2
						winner = player1
					end

					local currentSpeed = playerPowerSpeeds[winner] or 1
					playerPowerSpeeds[winner] = currentSpeed + 0.4

					task.delay(0.8, function()
						if not IsGameActive(player1, player2) then
							return print("Game no longer active during cup destruction")
						end

						local parent3 = part.Parent.Parent
						local Table = parent3.Parent.Parent
						local firstThrower = Table:GetAttribute("firstThrower")

						part.Parent:Destroy()

						local holdableCup = ReplicatedStorage.Assets.Models.HoldableCups
							:FindFirstChild(target.PlayerStats.EquippedCups.Value)
							:Clone()

						holdableCup.Parent = target.Character
						holdableCup.PrimaryPart.CFrame = target.Character.RightHand.CFrame
							* CFrame.new(0, -0.25, -0.5)
							* CFrame.Angles(math.rad(-90), 0, 0)

						Essentials.WeldPartsTogether(holdableCup.PrimaryPart, target.Character.RightHand)

						task.delay(0.5, function()
							if holdableCup and holdableCup.Parent then
								Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.drink, holdableCup, 2)
							end
						end)

						task.delay(1.5, function()
							if holdableCup and holdableCup.Parent then
								holdableCup:Destroy()
							end
						end)

						task.delay(0.2, function()
							if not IsGameActive(player1, player2) then
								return print("Game no longer active before checking win condition")
							end

							local shooterName = string.match(ball.Name, "(.+)_Ball")
							local shooter = Players:FindFirstChild(shooterName)

							-- Check if we're in redemption mode
							local roundData = redemptionRounds[tableModel]

							if roundData and roundData.active then
								-- Record the hit
								-- Increment this shooter's redemption turn count
								roundData.turns[shooter] = (roundData.turns[shooter] or 0) + 1
								roundData.redemptionHitSucceeded[shooter] = true

								if shooter == roundData.firstShooter then
									roundData.firstShooterResult = "hit"
									roundData.firstShotMade = true -- Mark first shot was successful
									print(
										shooter.Name,
										"HIT their redemption shot (first shooter) - redemption continues!"
									)
								else
									roundData.secondShooterResult = "hit"
									print(shooter.Name, "HIT their redemption shot (second shooter)")
								end

								local shooterSpeed = playerPowerSpeeds[shooter] or 1
								playerPowerSpeeds[shooter] = shooterSpeed + 0.5
								print(shooter.Name, "power speed increased to:", playerPowerSpeeds[shooter])

								PongServiceEvent:FireClient(player1, {
									["Action"] = "RedemptionHit",
									["Shooter"] = shooter,
									["Cam"] = cam,
									["Drink"] = true,
									["Target"] = target,
								})
								PongServiceEvent:FireClient(player2, {
									["Action"] = "RedemptionHit",
									["Shooter"] = shooter,
									["Cam"] = cam,
									["Drink"] = true,
									["Target"] = target,
								})

								-- Check if both have shot
								if roundData.firstShooterResult and roundData.secondShooterResult then
									task.delay(1, function()
										if IsGameActive(player1, player2) then
											PongService.EvaluateRedemptionRound(tableModel, player1, player2)
										end
									end)
								else
									roundData.waitingForSecondShot = true
									local nextShooter = roundData.secondShooter
									local waitingPlayer = roundData.firstShooter

									task.delay(1.5, function()
										if IsGameActive(player1, player2) then
											roundData.currentShooter = nextShooter
											PongService.GiveRedemptionTurn(
												tableModel,
												nextShooter,
												waitingPlayer,
												player1,
												player2
											)
										end
									end)
								end
								return
							end

							local p1_cups = GetCupCount(tableModel, GetPlayerSide(tableModel, winner))
							local p2_cups = GetCupCount(tableModel, GetPlayerSide(tableModel, target))

							warn(winner.Name, target.Name, firstThrower)
							if #parent3:GetChildren() == 0 and (p1_cups - 1) ~= p2_cups then
								if p1_cups == p2_cups then
									PongServiceEvent:FireClient(player1, {
										["Action"] = "MiddleTurn",
										["Cam"] = cam,
										["Drink"] = true,
										["Target"] = target,
									})
									PongServiceEvent:FireClient(player2, {
										["Action"] = "MiddleTurn",
										["Cam"] = cam,
										["Drink"] = true,
										["Target"] = target,
									})

									task.delay(1.5, function()
										if not IsGameActive(player1, player2) then
											return
										end
										PongService.StartRedemption(tableModel, winner, target, player1, player2)
									end)
								else
									PongService.FinalizeWin(tableModel, winner, target, cam, true)
								end
								return
							elseif
								#parent3:GetChildren() == 0
								and (p1_cups - 1) == p2_cups
								and winner.Name ~= firstThrower
							then
								PongService.FinalizeWin(tableModel, winner, target, cam, true)
							end

							-- Normal hit - continue game
							if not IsGameActive(player1, player2) then
								return print("Game no longer active before drinking animation")
							end

							PongServiceEvent:FireClient(player1, {
								["Action"] = "MiddleTurn",
								["Cam"] = cam,
								["Drink"] = true,
								["Target"] = target,
							})
							PongServiceEvent:FireClient(player2, {
								["Action"] = "MiddleTurn",
								["Cam"] = cam,
								["Drink"] = true,
								["Target"] = target,
							})

							task.delay(0.5, function()
								if not IsGameActive(player1, player2) then
									return print("Game no longer active before next turn")
								end

								PongServiceEvent:FireClient(player1, { ["Action"] = "TurnTransition" })
								PongServiceEvent:FireClient(player2, { ["Action"] = "TurnTransition" })

								PongService.PickASide(player1, player2, false)
							end)
						end)
					end)
				end)

				break
			end

			task.wait(1 / 60)
		end

		activeBallChecks[ball] = nil
	end)

	activeBallChecks[ball] = checkThread
end

function PongService.StartPowerMeter(ball, player)
	PongService.StopPowerMeter(ball)

	ball:SetAttribute("Power", 0)
	ball.Countdown.Value = 15

	local power = 0
	local increasing = true
	local speed = playerPowerSpeeds[player] or 1
	local countdown = 15
	local lastCountdownUpdate = tick()

	local connection = RunService.Heartbeat:Connect(function(deltaTime)
		if not ball or not ball.Parent then
			PongService.StopPowerMeter(ball)
			return
		end

		if not IsPlayerGameActive(player) then
			PongService.StopPowerMeter(ball)
			return
		end

		if increasing then
			power = power + (speed * deltaTime * 60)
			if power >= 100 then
				power = 100
				increasing = false
			end
		else
			power = power - (speed * deltaTime * 60)
			if power <= 0 then
				power = 0
				increasing = true
			end
		end

		ball.Power.Value = power

		if tick() - lastCountdownUpdate >= 1 then
			countdown = countdown - 1
			ball.Countdown.Value = math.max(0, countdown)
			lastCountdownUpdate = tick()

			if countdown <= 0 then
				PongService.StopPowerMeter(ball)

				local playerName = string.match(ball.Name, "(.+)_Ball")
				local foundPlayer = Players:FindFirstChild(playerName)

				if foundPlayer and IsPlayerGameActive(foundPlayer) then
					PongService.AutoThrowBall(ball, foundPlayer)
				end
			end
		end
	end)

	activePowerConnections[ball] = connection
end

function PongService.StopPowerMeter(ball)
	if activePowerConnections[ball] then
		activePowerConnections[ball]:Disconnect()
		activePowerConnections[ball] = nil
	end

	if ball and ball:FindFirstChild("Countdown") then
		ball.Countdown.Value = 0
	end
end

function PongService.FinalizeWin(tableModel, winner, loser, cam, drink)
	local player1 = Players:FindFirstChild(tableModel["1"]:GetAttribute("taken"))
	local player2 = Players:FindFirstChild(tableModel["2"]:GetAttribute("taken"))

	redemptionRounds[tableModel] = nil
	redemptionState[player1] = nil
	redemptionState[player2] = nil

	CleanupPlayerGame(player1)
	CleanupPlayerGame(player2)

	PongServiceEvent:FireClient(player1, {
		["Action"] = "FinishGame",
		["Cam"] = cam,
		["Drink"] = drink,
		["Target"] = loser,
	})
	PongServiceEvent:FireClient(player2, {
		["Action"] = "FinishGame",
		["Cam"] = cam,
		["Drink"] = drink,
		["Target"] = loser,
	})

	local multiplier = winner.PlayerStats.Multiplier.Value + winner.PlayerStats.MoneyUpgradeMultiplier.Value
	local money = tableModel:GetAttribute("money") * multiplier

	task.spawn(vfxPlayer.play, winner, script.Rebirth)

	if winner.PlayerStats.Vip.Value then
		winner.leaderstats.Coins.Value += math.floor(money * 2)
	else
		winner.leaderstats.Coins.Value += money
	end

	winner.Character.HumanoidRootPart.CFrame = tableModel.Main.Exit.WorldCFrame

	winner.leaderstats.Wins.Value += 1
	winner.leaderstats.Streak.Value += 1

	winner.Character.InGame.Value = false
	loser.Character.InGame.Value = false

	local leaderstats = winner:FindFirstChild("leaderstats")
	assert(leaderstats, "Invalid leaderstats.")

	if leaderstats.Streak.Value > 0 then
		if winner.Character.Head:FindFirstChild("Streak") then
			local billboard = winner.Character.Head.Streak
			billboard.TextLabel.Text = winner.leaderstats.Streak.Value
		else
			local billboard = ReplicatedStorage.Assets.VFX.Streak:Clone()
			billboard.Parent = winner.Character.Head
			billboard.TextLabel.Text = winner.leaderstats.Streak.Value
		end
	end

	if loser.Character.Head:FindFirstChild("Streak") then
		local billboard = loser.Character.Head.Streak
		billboard:Destroy()
	end

	winner.PlayerStats.PastStreak.Value = winner.leaderstats.Streak.Value
	winner.PlayerStats.EarnedMoney.Value = money
	loser.leaderstats.Streak.Value = 0

	--local winningPodium = _G.playerToPodium[winner.UserId]
	--_G.QueueService.ResetTable(tableModel)
	--_G.QueueService.BroadcastEnter(winner, winningPodium)

	PongServiceEvent:FireClient(winner, { ["Action"] = "Win" })
	PongServiceEvent:FireClient(loser, { ["Action"] = "Lose" })

	task.delay(2.5, function()
		if loser and loser.Character and loser.Character:FindFirstChild("Humanoid") then
			loser.Character.Humanoid:TakeDamage(100)
		end
	end)
end

function PongService.StartRedemption(tableModel, potentialWinner, redeemingPlayer, player1, player2)
	print("===========================================")
	print("REDEMPTION STARTING!")
	print("Redeeming player:", redeemingPlayer.Name)
	print("Potential winner:", potentialWinner.Name)
	print("===========================================")

	Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.Redemption, tableModel.Main, 2)

	local redeemingSide = GetPlayerSide(tableModel, redeemingPlayer)
	local winnerSide = GetPlayerSide(tableModel, potentialWinner)

	local redeemingCupsBefore = GetCupCount(tableModel, redeemingSide)
	local winnerCupsBefore = GetCupCount(tableModel, winnerSide)

	print("Before spawning - Redeeming player cups:", redeemingCupsBefore, "Winner cups:", winnerCupsBefore)

	if redeemingCupsBefore == 0 then
		local success = SpawnRedemptionCup(tableModel, redeemingPlayer)
		if success then
			print("Successfully spawned cup for redeeming player:", redeemingPlayer.Name)
		else
			warn("FAILED to spawn cup for redeeming player:", redeemingPlayer.Name)
		end
	end

	if winnerCupsBefore == 0 then
		local success = SpawnRedemptionCup(tableModel, potentialWinner)
		if success then
			print("Successfully spawned cup for potential winner:", potentialWinner.Name)
		else
			warn("FAILED to spawn cup for potential winner:", potentialWinner.Name)
		end
	end

	local redeemingCupsAfter = GetCupCount(tableModel, redeemingSide)
	local winnerCupsAfter = GetCupCount(tableModel, winnerSide)
	print("After spawning - Redeeming player cups:", redeemingCupsAfter, "Winner cups:", winnerCupsAfter)

	-- Initialize redemption round tracking with firstShotMade = false
	redemptionRounds[tableModel] = {
		active = true,
		round = 1,
		maxRounds = 15,
		firstShooter = redeemingPlayer,
		secondShooter = potentialWinner,
		currentShooter = redeemingPlayer,
		firstShooterResult = nil,
		secondShooterResult = nil,
		waitingForSecondShot = false,
		firstShotMade = false, -- CRITICAL: Track if first redemption shot was successful
		-- Track how many redemption "turns" each player has taken (0 = hasn't shot yet)
		turns = {
			[redeemingPlayer] = 0,
			[potentialWinner] = 0,
		},
		redemptionHitSucceeded = {
			[redeemingPlayer] = false,
			[potentialWinner] = false,
		},
	}

	redemptionState[redeemingPlayer] = {
		inRedemption = true,
		isFirstShooter = true,
	}
	redemptionState[potentialWinner] = {
		inRedemption = true,
		isFirstShooter = false,
	}

	PongServiceEvent:FireClient(player1, {
		["Action"] = "RedemptionStart",
		["FirstShooter"] = redeemingPlayer,
		["SecondShooter"] = potentialWinner,
		["Round"] = 1,
		["MaxRounds"] = 15,
	})
	PongServiceEvent:FireClient(player2, {
		["Action"] = "RedemptionStart",
		["FirstShooter"] = redeemingPlayer,
		["SecondShooter"] = potentialWinner,
		["Round"] = 1,
		["MaxRounds"] = 15,
	})

	task.delay(2.5, function()
		if not IsGameActive(player1, player2) then
			print("Game no longer active before redemption turn")
			return
		end

		local currentRedeemingCups = GetCupCount(tableModel, redeemingSide)
		local currentWinnerCups = GetCupCount(tableModel, winnerSide)
		print("Before first turn - Redeeming cups:", currentRedeemingCups, "Winner cups:", currentWinnerCups)

		if currentRedeemingCups == 0 then
			warn("Redeeming player still has 0 cups! Spawning again...")
			SpawnRedemptionCup(tableModel, redeemingPlayer)
		end

		PongService.GiveRedemptionTurn(tableModel, redeemingPlayer, potentialWinner, player1, player2)
	end)
end

function PongService.PickASide(player1, player2, doRandom)
	if not IsGameActive(player1, player2) then
		return warn("Game no longer active in PickASide")
	end

	local Table = PongService.FindTable(player1, player2)
	if not Table then
		return warn("Table not found for players:", player1.Name, player2.Name)
	end

	if not roundState[Table] then
		roundState[Table] = {
			turns = 0,
			round = 1,
		}
	end

	roundState[Table].turns += 1

	if roundState[Table].turns > 2 then
		roundState[Table].turns = 1
		roundState[Table].round += 1
	end

	task.delay(1, function()
		if not IsGameActive(player1, player2) then
			return warn("Game no longer active before turn started")
		end

		if doRandom then
			local random = math.random(1, 2)
			Table:SetAttribute("side", random)

			if random == 1 then
				Table:SetAttribute("firstThrower", player1.Name)
				print("First thrower set to:", player1.Name, "(player1, side 1)")
			else
				Table:SetAttribute("firstThrower", player2.Name)
				print("First thrower set to:", player2.Name, "(player2, side 2)")
			end

			local player1Speed = playerPowerSpeeds[player1] or 1
			local player2Speed = playerPowerSpeeds[player2] or 1

			if random == 1 then
				local ball = ReplicatedStorage.Assets.Models.Balls
					:FindFirstChild(player1.PlayerStats.EquippedBalls.Value)
					:Clone()
				ball.Parent = Table.Balls
				ball.Name = player1.Name .. "_Ball"
				ball.CFrame = Table.Main.ball1.WorldCFrame

				PongService.StartPowerMeter(ball, player1)

				PongServiceEvent:FireClient(player1, {
					["Action"] = "YourTurn",
					["CamSide"] = Table.Cams.cam1,
					["Ball"] = ball,
					["PowerSpeed"] = player1Speed,
					["Round"] = roundState[Table].round,
				})
				PongServiceEvent:FireClient(player2, { ["Action"] = "OpponentsTurn", ["CamSide"] = Table.Cams.cam5 })
			else
				local ball = ReplicatedStorage.Assets.Models.Balls
					:FindFirstChild(player2.PlayerStats.EquippedBalls.Value)
					:Clone()
				ball.Parent = Table.Balls
				ball.Name = player2.Name .. "_Ball"
				ball.CFrame = Table.Main.ball2.WorldCFrame

				PongService.StartPowerMeter(ball, player2)

				PongServiceEvent:FireClient(player2, {
					["Action"] = "YourTurn",
					["CamSide"] = Table.Cams.cam2,
					["Ball"] = ball,
					["PowerSpeed"] = player2Speed,
					["Round"] = roundState[Table].round,
				})
				PongServiceEvent:FireClient(player1, { ["Action"] = "OpponentsTurn", ["CamSide"] = Table.Cams.cam4 })
			end
		else
			if Table:GetAttribute("side") == 1 then
				Table:SetAttribute("side", 2)
				local ball = ReplicatedStorage.Assets.Models.Balls
					:FindFirstChild(player2.PlayerStats.EquippedBalls.Value)
					:Clone()
				ball.Parent = Table.Balls
				ball.Name = player2.Name .. "_Ball"
				ball.CFrame = Table.Main.ball2.WorldCFrame

				PongService.StartPowerMeter(ball, player2)

				PongServiceEvent:FireClient(player2, {
					["Action"] = "YourTurn",
					["CamSide"] = Table.Cams.cam2,
					["Ball"] = ball,
					["PowerSpeed"] = playerPowerSpeeds[player2] or 1,
					["Round"] = roundState[Table].round,
				})
				PongServiceEvent:FireClient(player1, { ["Action"] = "OpponentsTurn", ["CamSide"] = Table.Cams.cam4 })
			else
				Table:SetAttribute("side", 1)
				local ball = ReplicatedStorage.Assets.Models.Balls
					:FindFirstChild(player1.PlayerStats.EquippedBalls.Value)
					:Clone()
				ball.Parent = Table.Balls
				ball.Name = player1.Name .. "_Ball"
				ball.CFrame = Table.Main.ball1.WorldCFrame

				PongService.StartPowerMeter(ball, player1)

				PongServiceEvent:FireClient(player1, {
					["Action"] = "YourTurn",
					["CamSide"] = Table.Cams.cam1,
					["Ball"] = ball,
					["PowerSpeed"] = playerPowerSpeeds[player1] or 1,
					["Round"] = roundState[Table].round,
				})
				PongServiceEvent:FireClient(player2, { ["Action"] = "OpponentsTurn", ["CamSide"] = Table.Cams.cam5 })
			end
		end
	end)

	return nil
end

function PongService.Start(player1, player2)
	print("PongService Start Invoked with players:", player1.Name, player2.Name)

	activeGames[player1] = player2
	activeGames[player2] = player1

	playerPowerSpeeds[player1] = 1
	playerPowerSpeeds[player2] = 1

	local Table = PongService.FindTable(player1, player2)

	activeTables[player1] = Table
	activeTables[player2] = Table

	local gameCancelled = false

	local function checkPlayersValid()
		if not player1 or not player1.Parent or not player2 or not player2.Parent then
			gameCancelled = true
			return false
		end
		return true
	end

	local tempConnections = {}

	local function cancelGameStart()
		if gameCancelled then
			return
		end
		gameCancelled = true
		print("Game start cancelled - player left during setup")

		for _, conn in tempConnections do
			conn:Disconnect()
			conn = nil
		end

		table.clear(tempConnections)
		CleanupPlayerGame(player1)
		CleanupPlayerGame(player2)
	end

	if player1 and player1.Parent then
		table.insert(
			tempConnections,
			player1.AncestryChanged:Connect(function()
				if not player1.Parent then
					cancelGameStart()
				end
			end)
		)

		if player1.Character then
			local humanoid = player1.Character:FindFirstChild("Humanoid")
			if humanoid then
				table.insert(tempConnections, humanoid.Died:Once(cancelGameStart))
			end
		end
	end

	if player2 and player2.Parent then
		table.insert(
			tempConnections,
			player2.AncestryChanged:Connect(function()
				if not player2.Parent then
					cancelGameStart()
				end
			end)
		)

		if player2.Character then
			local humanoid = player2.Character:FindFirstChild("Humanoid")
			if humanoid then
				table.insert(tempConnections, humanoid.Died:Once(cancelGameStart))
			end
		end
	end

	for _, v in Table.Main["1"]:GetChildren() do
		local clone =
			ReplicatedStorage.Assets.Models.Cups:FindFirstChild(player1.PlayerStats.EquippedCups.Value):Clone()
		clone.Parent = Table.Main["cups1"]
		clone:PivotTo(v.WorldCFrame)
		clone.Name = v.Name
	end

	for _, v in Table.Main["2"]:GetChildren() do
		local clone =
			ReplicatedStorage.Assets.Models.Cups:FindFirstChild(player2.PlayerStats.EquippedCups.Value):Clone()
		clone.Parent = Table.Main["cups2"]
		clone:PivotTo(v.WorldCFrame)
		clone.Name = v.Name
	end

	PongServiceEvent:FireClient(player1, { ["Action"] = "Start", ["Opponent"] = player2, ["Table"] = Table })
	PongServiceEvent:FireClient(player2, { ["Action"] = "Start", ["Opponent"] = player1, ["Table"] = Table })

	if not checkPlayersValid() then
		for _, conn in tempConnections do
			conn:Disconnect()
			conn = nil
		end

		table.clear(tempConnections)
		return
	end

	local MoneyFolder = ReplicatedStorage.Assets.Money
	local MoneyGoToCFrame = Table.Main.Money.WorldCFrame

	task.spawn(function()
		local moneyModels = {}
		for _, model in MoneyFolder:GetChildren() do
			if model:IsA("Model") then
				table.insert(moneyModels, model)
			end
		end

		table.sort(moneyModels, function(a, b)
			return tonumber(a.Name) < tonumber(b.Name)
		end)

		local ServerPotLuck = ReplicatedStorage.Server.LuckBoost

		local player1Multiplier = player1.PlayerStats.PotLuckMultiplier.Value or 1
		local player2Multiplier = player2.PlayerStats.PotLuckMultiplier.Value or 1
		local maxPotLuckMultiplier = math.max(player1Multiplier, player2Multiplier, 1) * ServerPotLuck.Value

		local function getRandomMoneyModel()
			local totalWeight = 0
			local weights = {}

			local baseWeights = {
				["100"] = 50,
				["500"] = 30,
				["1000"] = 15,
				["1500"] = 4,
				["2500"] = 1,
			}

			for _, model in moneyModels do
				local value = model.Name
				local baseWeight = baseWeights[value] or 25

				local potLuckBoost = (maxPotLuckMultiplier - 1) * 0.3
				local finalWeight = baseWeight * (1 + potLuckBoost)

				weights[model] = finalWeight
				totalWeight = totalWeight + finalWeight
			end

			local random = math.random() * totalWeight
			local currentWeight = 0

			for model, weight in pairs(weights) do
				currentWeight = currentWeight + weight
				if random <= currentWeight then
					return model
				end
			end

			return moneyModels[1]
		end

		local rollCount = 15
		local currentModel = nil

		for i = 1, rollCount do
			if gameCancelled or not checkPlayersValid() then
				if currentModel then
					currentModel:Destroy()
				end
				return
			end

			if currentModel then
				local shrinkDuration = 0.1
				local startTime = tick()

				while tick() - startTime < shrinkDuration do
					local progress = (tick() - startTime) / shrinkDuration
					local scale = math.max(1 - progress, 0.01)
					currentModel:ScaleTo(scale)
					task.wait()
				end

				currentModel:Destroy()
				currentModel = nil
			end

			local selectedModel = getRandomMoneyModel()
			currentModel = selectedModel:Clone()
			currentModel.Parent = Table.Main
			currentModel:PivotTo(MoneyGoToCFrame)

			Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.flip, Table.Main, 2)

			currentModel:ScaleTo(0.01)
			local growDuration = 0.15
			local startTime = tick()

			while tick() - startTime < growDuration do
				local progress = (tick() - startTime) / growDuration
				local scale = math.max(progress, 0.01)
				currentModel:ScaleTo(scale)
				task.wait()
			end

			currentModel:ScaleTo(1)

			local minWait = 0.05
			local maxWait = 0.4
			local progress = (i - 1) / (rollCount - 1)
			local easedProgress = progress * progress

			local waitTime = minWait + (easedProgress * (maxWait - minWait))

			task.wait(waitTime)
		end

		if currentModel then
			Essentials.PlaySoundRandomSpeed(ReplicatedStorage.Assets.Sounds.Chosen, Table.Main, 2)

			Table.Main.BillboardGui1.TextLabel.Text = "Playing for: " .. currentModel.Name .. "$"

			Table:SetAttribute("money", tonumber(currentModel.Name))

			for bounce = 1, 2 do
				if gameCancelled or not checkPlayersValid() then
					currentModel:Destroy()
					return
				end

				currentModel:ScaleTo(1.2)
				task.wait(0.1)
				currentModel:ScaleTo(1)
				task.wait(0.1)
			end

			local shrinkDuration = 0.1
			local startTime = tick()

			while tick() - startTime < shrinkDuration do
				if gameCancelled or not checkPlayersValid() then
					currentModel:Destroy()
					return
				end

				local progress = (tick() - startTime) / shrinkDuration
				local scale = math.max(1 - progress, 0.01)
				currentModel:ScaleTo(scale)
				task.wait()
			end

			currentModel:Destroy()
		end

		for _, conn in tempConnections do
			conn:Disconnect()
			conn = nil
		end

		table.clear(tempConnections)
	end)

	task.delay(6, function()
		if gameCancelled or not checkPlayersValid() or not IsGameActive(player1, player2) then
			warn("Game cancelled before PickASide - player left during setup")
			return
		end

		PongService.PickASide(player1, player2, true)
	end)
end

function PongService._onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid")

	characterMaid[player][humanoid] = humanoid.Died:Once(function()
		characterMaid[player][humanoid] = nil
		local opponent = activeGames[player]

		if opponent then
			CleanupPlayerGame(opponent)
			InstaLose(player, opponent)
		end

		CleanupPlayerGame(player)
	end)
end

function PongService._onPlayerAdded(player)
	characterMaid[player] = safeCharacterAdded(player, function(character)
		PongService._onCharacterAdded(player, character)
	end)
end

function PongService._onPlayerRemoving(player)
	characterMaid[player] = nil

	local opponent = activeGames[player]

	if opponent then
		CleanupPlayerGame(opponent)
		InstaLose(player, opponent)
	end

	CleanupPlayerGame(player)
end

function PongService.Handler()
	safePlayerAdded(PongService._onPlayerAdded)
	Players.PlayerRemoving:Connect(PongService._onPlayerRemoving)
	PongServiceEvent.OnServerEvent:Connect(OnPongServiceEvent)
end

return PongService
