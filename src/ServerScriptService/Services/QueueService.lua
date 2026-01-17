local QueueService = {}
_G.QueueService = QueueService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedModules = ReplicatedStorage.Modules
local Maid = require(sharedModules.Nevermore.Maid)
local PongService = require(script.Parent.PongService)
local safeCharacterAdded = require(sharedModules.Utils.safeCharacterAdded)
local safePlayerAdded = require(sharedModules.Utils.safePlayerAdded)
local characterMaid = Maid.new()
local QueueServiceEvent = ReplicatedStorage.Remotes.Events.QueueService

-- Track active matches per table
local activeMatches = {}
-- Track player connections for cleanup
local playerConnections = {}
-- Track which podium each player is in
local playerToPodium = {}
_G.playerToPodium = {}
-- Track countdown threads per table
local countdownThreads = {}
-- Track character connections for respawn detection

function QueueService.BroadcastEnter(player, podium)
	QueueServiceEvent:FireClient(player, { ["Action"] = "Enter", ["Podium"] = podium })
end

function QueueService.CheckBothReady(tableModel)
	-- Don't allow new matches to start if one is already active
	if activeMatches[tableModel] then
		return
	end

	local podium1 = tableModel:FindFirstChild("1")
	local podium2 = tableModel:FindFirstChild("2")
	local main = tableModel:FindFirstChild("Main")
	local bGui = main and main:FindFirstChild("BillboardGui")

	if not podium1 or not podium2 or not bGui then
		return
	end

	local taken1 = podium1:GetAttribute("taken") or ""
	local taken2 = podium2:GetAttribute("taken") or ""

	if taken1 ~= "" and taken2 ~= "" then
		-- Both players ready, start countdown
		QueueService.StartMatchCountdown(tableModel, taken1, taken2)
	end
end

function QueueService.LeaveQueue(player)
	local podium = playerToPodium[player.UserId]

	if not podium or not podium:IsA("BasePart") then
		warn("Invalid podium provided for", player.Name, debug.traceback())
		return
	end

	-- Get the table model
	local tableModel = podium.Parent
	if not tableModel then
		warn("Podium is not part of a valid table")
		return
	end

	-- Don't allow leaving if match is active
	if activeMatches[tableModel] then
		warn("Cannot leave - match is active")
		return
	end

	-- Check if this player owns this podium
	local takenBy = podium:GetAttribute("taken") or ""
	if takenBy ~= player.Name then
		warn("Player", player.Name, "does not own this podium")
		return
	end

	-- Cancel countdown if it's running
	if countdownThreads[tableModel] then
		task.cancel(countdownThreads[tableModel])
		countdownThreads[tableModel] = nil
		print("Countdown cancelled for table", tableModel.Name)
	end

	-- Clear podium FIRST (most important)
	podium:SetAttribute("taken", "")
	playerToPodium[player.UserId] = nil

	-- Re-enable the proximity prompt so others can join
	local prompt = podium:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Enabled = true
	end

	-- Update visuals EARLY (before any potential errors)
	for _, e in podium.PlayerTP:GetChildren() do
		e.Color = Color3.fromRGB(237, 234, 234)
	end

	-- Safely set InGame value
	if player.Character and player.Character:FindFirstChild("InGame") then
		player.Character.InGame.Value = false
	end

	-- Unanchor player and restore movement
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		player.Character.HumanoidRootPart.Anchored = false

		-- Teleport the player to the exit location
		local exitPart = tableModel.Main:FindFirstChild("Exit")
		if exitPart then
			player.Character.HumanoidRootPart.CFrame = exitPart.WorldCFrame
		end

		local humanoid = player.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 16
		end
	end

	-- Update player count on billboard
	local main = tableModel:FindFirstChild("Main")
	if main then
		local bGui = main:FindFirstChild("BillboardGui")
		if bGui then
			local podium1 = tableModel:FindFirstChild("1")
			local podium2 = tableModel:FindFirstChild("2")
			local playerCount = 0
			if podium1 and (podium1:GetAttribute("taken") or "") ~= "" then
				playerCount = playerCount + 1
			end
			if podium2 and (podium2:GetAttribute("taken") or "") ~= "" then
				playerCount = playerCount + 1
			end
			bGui.TextLabel.Text = "Waiting for players [" .. playerCount .. "/2]"
		end
	end

	print("Player", player.Name, "left queue from podium", podium.Name)
end

function QueueService.EnterQueue(player, podium)
	if not podium or not podium:IsA("BasePart") then
		warn("Invalid podium provided for", player.Name, debug.traceback())
		return
	end

	-- Check if player is already in a queue
	if playerToPodium[player.UserId] then
		warn("Player", player.Name, "is already in a queue")
		return
	end

	-- Get the table model
	local tableModel = podium.Parent
	if not tableModel or tableModel.Parent ~= workspace.QueueTables then
		warn("Podium is not part of a valid queue table")
		return
	end

	-- Don't allow joining if match is active
	if activeMatches[tableModel] then
		warn("Cannot join - match is active on this table")
		return
	end

	-- Check if podium is already taken
	local takenBy = podium:GetAttribute("taken") or ""
	if takenBy ~= "" then
		warn("Podium is already taken by", takenBy)
		return
	end

	-- Lock player in this podium
	podium:SetAttribute("taken", player.Name)
	playerToPodium[player.UserId] = podium

	-- Disable the proximity prompt server-side so no one else can join this podium
	local prompt = podium:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Enabled = false
	end

	-- Teleport and anchor player, fix animation
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		local humanoid = player.Character:FindFirstChild("Humanoid")

		-- Stop movement and reset animation state
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			task.wait()
			humanoid:ChangeState(Enum.HumanoidStateType.None)
		end

		player.Character.HumanoidRootPart.CFrame = podium.CFrame
		player.Character.Humanoid.WalkSpeed = 0
		task.delay(0.1, function()
			-- Only anchor if player is still in this specific queue
			if playerToPodium[player.UserId] == podium and player.Character then
				local hrp = player.Character:FindFirstChild("HumanoidRootPart")
				local humanoid = player.Character:FindFirstChild("Humanoid")
				if hrp and humanoid then
					humanoid.WalkSpeed = 16
					hrp.Anchored = true
				end
			end
		end)
	end

	player.Character.InGame.Value = true
	-- Update visuals
	for _, e in podium.PlayerTP:GetChildren() do
		e.Color = Color3.fromRGB(21, 255, 0)
	end

	-- Update player count on billboard
	local main = tableModel:FindFirstChild("Main")
	if main then
		local bGui = main:FindFirstChild("BillboardGui")
		if bGui then
			local podium1 = tableModel:FindFirstChild("1")
			local podium2 = tableModel:FindFirstChild("2")
			local playerCount = 0
			if podium1 and (podium1:GetAttribute("taken") or "") ~= "" then
				playerCount = playerCount + 1
			end
			if podium2 and (podium2:GetAttribute("taken") or "") ~= "" then
				playerCount = playerCount + 1
			end
			bGui.TextLabel.Text = "Waiting for players [" .. playerCount .. "/2]"
		end
	end

	print("Player", player.Name, "entered queue at podium", podium.Name)

	-- Check if both players are ready
	QueueService.CheckBothReady(tableModel)
end

function QueueService.Listener()
	QueueServiceEvent.OnServerEvent:Connect(function(plr, argtable)
		if argtable["Action"] == "Enter" then
			local podium = argtable["Podium"]
			QueueService.EnterQueue(plr, podium)
		elseif argtable["Action"] == "Leave" then
			QueueService.LeaveQueue(plr)
		end
	end)
end

local function onCharacterAdded(player, character)
	-- Handle player character respawn - automatically remove from queue
	-- Check if player is in queue
	if playerToPodium[player.UserId] then
		QueueService.LeaveQueue(player)
	end
end

local function onPlayerAdded(player)
	characterMaid[player] = safeCharacterAdded(player, function(character)
		onCharacterAdded(player, character)
	end)
end

local function onPlayerRemoving(player)
	characterMaid[player] = nil

	-- Remove from queue if they're in one
	if playerToPodium[player.UserId] then
		local podium = playerToPodium[player.UserId]
		local tableModel = podium.Parent

		-- Clear the podium
		podium:SetAttribute("taken", "")
		playerToPodium[player.UserId] = nil

		-- Re-enable the proximity prompt so others can join
		local prompt = podium:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.Enabled = true
		end

		-- Reset podium colors
		for _, e in podium.PlayerTP:GetChildren() do
			e.Color = Color3.fromRGB(237, 234, 234)
		end

		-- Update billboard player count
		if tableModel then
			local main = tableModel:FindFirstChild("Main")
			if main then
				local bGui = main:FindFirstChild("BillboardGui")
				if bGui then
					local podium1 = tableModel:FindFirstChild("1")
					local podium2 = tableModel:FindFirstChild("2")
					local playerCount = 0
					if podium1 and (podium1:GetAttribute("taken") or "") ~= "" then
						playerCount = playerCount + 1
					end
					if podium2 and (podium2:GetAttribute("taken") or "") ~= "" then
						playerCount = playerCount + 1
					end
					bGui.TextLabel.Text = "Waiting for players [" .. playerCount .. "/2]"
				end
			end

			-- Cancel countdown if running
			if countdownThreads[tableModel] then
				task.cancel(countdownThreads[tableModel])
				countdownThreads[tableModel] = nil
			end

			-- Notify the other player if there is one
			local otherPodium = (podium.Name == "1") and tableModel:FindFirstChild("2")
				or tableModel:FindFirstChild("1")
			if otherPodium then
				local otherPlayerName = otherPodium:GetAttribute("taken") or ""
				if otherPlayerName ~= "" then
					local otherPlayer = Players:FindFirstChild(otherPlayerName)
					if otherPlayer then
						QueueServiceEvent:FireClient(otherPlayer, { ["Action"] = "PartnerLeft" })
					end
				end
			end
		end
	end
end

safePlayerAdded(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

function QueueService.StartMatchCountdown(tableModel, player1Name, player2Name)
	local main = tableModel:FindFirstChild("Main")
	local bGui = main:FindFirstChild("BillboardGui")
	local podium1 = tableModel:FindFirstChild("1")
	local podium2 = tableModel:FindFirstChild("2")

	-- Cancel any existing countdown for this table
	if countdownThreads[tableModel] then
		task.cancel(countdownThreads[tableModel])
	end

	-- Store the thread reference
	local thread = task.spawn(function()
		for i = 5, 1, -1 do
			-- Check if both players are still in queue
			local taken1 = podium1:GetAttribute("taken") or ""
			local taken2 = podium2:GetAttribute("taken") or ""

			if taken1 == "" or taken2 == "" then
				-- Someone left, cancel countdown
				print("Player left during countdown, cancelling...")
				countdownThreads[tableModel] = nil

				local playerCount = 0
				if taken1 ~= "" then
					playerCount = playerCount + 1
				end
				if taken2 ~= "" then
					playerCount = playerCount + 1
				end
				bGui.TextLabel.Text = "Waiting for players [" .. playerCount .. "/2]"
				return
			end

			bGui.TextLabel.Text = "Starting match in " .. i .. "..."
			task.wait(1)
		end

		-- Final check before starting match
		local taken1 = podium1:GetAttribute("taken") or ""
		local taken2 = podium2:GetAttribute("taken") or ""

		if taken1 == "" or taken2 == "" then
			print("Player left before match start, cancelling...")
			countdownThreads[tableModel] = nil

			local playerCount = 0
			if taken1 ~= "" then
				playerCount = playerCount + 1
			end
			if taken2 ~= "" then
				playerCount = playerCount + 1
			end
			bGui.TextLabel.Text = "Waiting for players [" .. playerCount .. "/2]"
			return
		end

		local player1 = Players:FindFirstChild(player1Name)
		local player2 = Players:FindFirstChild(player2Name)

		-- Only start if both players still exist
		if player1 and player2 and player1.Character and player2.Character then
			-- Fix animation states before match starts
			local humanoid1 = player1.Character:FindFirstChild("Humanoid")
			local humanoid2 = player2.Character:FindFirstChild("Humanoid")

			if humanoid1 then
				humanoid1.WalkSpeed = 0
				humanoid1:ChangeState(Enum.HumanoidStateType.Physics)
				task.wait()
				humanoid1:ChangeState(Enum.HumanoidStateType.None)
			end

			if humanoid2 then
				humanoid2.WalkSpeed = 0
				humanoid2:ChangeState(Enum.HumanoidStateType.Physics)
				task.wait()
				humanoid2:ChangeState(Enum.HumanoidStateType.None)
			end

			player1.Character.HumanoidRootPart.CFrame = podium1.CFrame
			player2.Character.HumanoidRootPart.CFrame = podium2.CFrame

			player1.Character.HumanoidRootPart.Anchored = true
			player2.Character.HumanoidRootPart.Anchored = true

			-- Mark table as having an active match
			activeMatches[tableModel] = { player1 = player1, player2 = player2 }

			-- Clear countdown thread
			countdownThreads[tableModel] = nil

			-- Setup monitoring for player leaving or dying
			QueueService.SetupPlayerMonitoring(tableModel, player1, player2)

			PongService.Start(player1, player2)

			for _, e in podium1.PlayerTP:GetChildren() do
				e.Color = Color3.fromRGB(0, 255, 234)
			end
			for _, e in podium2.PlayerTP:GetChildren() do
				e.Color = Color3.fromRGB(0, 255, 234)
			end
			bGui.TextLabel.Text = ""
		else
			-- One or both players left, reset the table
			countdownThreads[tableModel] = nil
			QueueService.ResetTable(tableModel)
		end
	end)

	countdownThreads[tableModel] = thread
end

function QueueService.ResetTable(tableModel)
	print("Resetting table:", tableModel.Name)

	local podium1 = tableModel:FindFirstChild("1")
	local podium2 = tableModel:FindFirstChild("2")
	local main = tableModel:FindFirstChild("Main")
	local bGui = main:FindFirstChild("BillboardGui")

	-- Get player names before resetting
	local plr1Name = podium1:GetAttribute("taken")
	local plr2Name = podium2:GetAttribute("taken")

	-- RESET ATTRIBUTES FIRST (before firing to clients)
	podium1:SetAttribute("taken", "")
	podium2:SetAttribute("taken", "")

	-- Re-enable proximity prompts for both podiums
	local prompt1 = podium1:FindFirstChildWhichIsA("ProximityPrompt", true)
	local prompt2 = podium2:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt1 then
		prompt1.Enabled = true
	end
	if prompt2 then
		prompt2.Enabled = true
	end

	-- Small wait to allow attribute replication
	task.wait()

	tableModel.Balls:ClearAllChildren()
	tableModel.Main.cups1:ClearAllChildren()
	tableModel.Main.cups2:ClearAllChildren()

	podium1.BillboardGui.TextLabel.Text = ""
	podium2.BillboardGui.TextLabel.Text = ""

	tableModel.Main.BillboardGui1.TextLabel.Text = ""

	-- Disconnect any existing connections for these players
	if playerConnections[tableModel] then
		print(playerConnections[tableModel])
		for _, conn in playerConnections[tableModel] do
			print(conn)
			conn:Disconnect()
			conn = nil
		end

		playerConnections[tableModel] = nil
	end

	local exitPart = tableModel:FindFirstChild("Main") and tableModel.Main:FindFirstChild("Exit")

	-- NOW fire to clients (after attributes are set)
	if plr1Name and plr1Name ~= "" then
		local player1 = Players:FindFirstChild(plr1Name)
		if player1 then
			if player1.Character and player1.Character:FindFirstChild("HumanoidRootPart") then
				player1.Character.HumanoidRootPart.Anchored = false

				if exitPart and exitPart:IsA("BasePart") then
					player1.Character.HumanoidRootPart.CFrame = exitPart.WorldCFrame
				end

				local humanoid = player1.Character:FindFirstChild("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = 16
				end

				-- Safely set InGame value
				if player1.Character:FindFirstChild("InGame") then
					player1.Character.InGame.Value = false
				end
			end
			playerToPodium[player1.UserId] = nil
			QueueServiceEvent:FireClient(player1, { ["Action"] = "Leave" })
		end
	end

	if plr2Name and plr2Name ~= "" then
		local player2 = Players:FindFirstChild(plr2Name)
		if player2 then
			if player2.Character and player2.Character:FindFirstChild("HumanoidRootPart") then
				player2.Character.HumanoidRootPart.Anchored = false

				if exitPart and exitPart:IsA("BasePart") then
					player2.Character.HumanoidRootPart.CFrame = exitPart.WorldCFrame
				end

				local humanoid = player2.Character:FindFirstChild("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = 16
				end

				-- Safely set InGame value
				if player2.Character:FindFirstChild("InGame") then
					player2.Character.InGame.Value = false
				end
			end
			playerToPodium[player2.UserId] = nil
			QueueServiceEvent:FireClient(player2, { ["Action"] = "Leave" })
		end
	end

	-- Reset podium colors
	for _, e in podium1.PlayerTP:GetChildren() do
		e.Color = Color3.fromRGB(237, 234, 234)
	end
	for _, e in podium2.PlayerTP:GetChildren() do
		e.Color = Color3.fromRGB(237, 234, 234)
	end

	-- Reset billboard text
	bGui.TextLabel.Text = "Waiting for players [0/2]"

	-- Mark table as not having an active match
	activeMatches[tableModel] = nil

	-- Clear any countdown thread
	if countdownThreads[tableModel] then
		task.cancel(countdownThreads[tableModel])
		countdownThreads[tableModel] = nil
	end

	print("Table reset complete:", tableModel.Name)
end

function QueueService.SetupPlayerMonitoring(tableModel, player1, player2)
	-- Initialize connections table for this table
	if not playerConnections[tableModel] then
		playerConnections[tableModel] = {}
	end

	local function onPlayerIssue(player)
		print("Player issue detected:", player.Name)
		QueueService.ResetTable(tableModel)
	end

	-- Monitor players leaving
	table.insert(playerConnections[tableModel], Players.PlayerRemoving:Connect(function(player)
		if player == player1 or player == player2 then
			onPlayerIssue(player)
		end
	end))

	-- Monitor player1 death
	if player1.Character then
		local humanoid = player1.Character:FindFirstChild("Humanoid")

		if humanoid then
			table.insert(playerConnections[tableModel], humanoid.Died:Once(function()
				onPlayerIssue(player1)
			end))
		end
	end

	-- Monitor player2 death
	if player2.Character then
		local humanoid = player2.Character:FindFirstChild("Humanoid")

		if humanoid then
			table.insert(playerConnections[tableModel], humanoid.Died:Once(function()
				onPlayerIssue(player2)
			end))
		end
	end
end

function QueueService.Handler()
	-- Initialize all tables
	local queueTables = workspace.QueueTables
	for _, tableModel in queueTables:GetChildren() do
		local podium1 = tableModel:FindFirstChild("1")
		local podium2 = tableModel:FindFirstChild("2")
		local main = tableModel:FindFirstChild("Main")

		if podium1 and podium2 and main then
			-- Initialize attributes
			podium1:SetAttribute("taken", "")
			podium2:SetAttribute("taken", "")

			-- Ensure prompts are enabled on initialization
			local prompt1 = podium1:FindFirstChildWhichIsA("ProximityPrompt", true)
			local prompt2 = podium2:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt1 then
				prompt1.Enabled = true
			end
			if prompt2 then
				prompt2.Enabled = true
			end

			local bGui = main:FindFirstChild("BillboardGui")
			if bGui then
				bGui.TextLabel.Text = "Waiting for players [0/2]"
			end
		end
	end

	-- Start listening for queue events
	QueueService.Listener()

	print("QueueService initialized")
end

return QueueService
