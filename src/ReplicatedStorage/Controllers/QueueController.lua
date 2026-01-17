local QueueController = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local queueServiceEvent = ReplicatedStorage.Remotes.Events.QueueService
local currentPodium = nil
local plr = Players.LocalPlayer

-- Handle character respawn/reset
local function clearQueueState()
	currentPodium = nil
	local gui = plr.PlayerGui:FindFirstChild("MainGameUi")
	if gui then
		local leaveGui = gui:FindFirstChild("Leave")
		local inviteGui = gui:FindFirstChild("Invite")
		if leaveGui then
			leaveGui.Visible = false
		end
		if inviteGui then
			inviteGui.Visible = false
		end
	end
end

-- Separate function for refreshing prompts - called with known-good state
local function refreshProximityPrompts(forceEnableAll)
	for _, v in workspace:GetDescendants() do
		if v:IsA("ProximityPrompt") then
			if forceEnableAll then
				-- Server told us to reset, trust it
				v.Enabled = true
			else
				-- Normal refresh - check attributes with longer delay for replication
				v.Enabled = true
				if v.Parent.Name == "1" or v.Parent.Name == "2" then
					task.delay(0.5, function()  -- Increased delay for replication
						if v.Parent and v.Parent:GetAttribute("taken") ~= "" and v.Parent:GetAttribute("taken") ~= nil then
							v.Enabled = false
						end
					end)
				end
			end
		end
	end
end

function QueueController.Listener()
	queueServiceEvent.OnClientEvent:Connect(function(argtable)
		if argtable["Action"] == "Leave" then
			clearQueueState()
			-- Server reset the table, force enable all prompts
			-- Trust the server - don't check attributes
			refreshProximityPrompts(true)

		elseif argtable["Action"] == "PartnerLeft" then
			-- Partner left but we're still in queue
			-- Only refresh the podium prompts for our table
			for _, v in workspace:GetDescendants() do
				if v:IsA("ProximityPrompt") and (v.Parent.Name == "1" or v.Parent.Name == "2") then
					task.delay(0.5, function()
						if v.Parent and v.Parent:GetAttribute("taken") == "" then
							v.Enabled = true
						end
					end)
				end
			end
		end
	end)
end

function QueueController.Leave()
	queueServiceEvent:FireServer({ ["Action"] = "Leave", ["Podium"] = currentPodium })
	clearQueueState()
	refreshProximityPrompts(false)
	
	local gui = plr.PlayerGui:FindFirstChild("MainGameUi")
	if gui then
		local PlayUI = gui:FindFirstChild("TopButtons"):FindFirstChild("Play")
		if PlayUI then
			PlayUI.Visible = true
		end
	end
	
end

function QueueController.Enter(podium)
	queueServiceEvent:FireServer({ ["Action"] = "Enter", ["Podium"] = podium })
	currentPodium = podium

	local gui = plr.PlayerGui:FindFirstChild("MainGameUi")
	if gui then
		local leaveGui = gui:FindFirstChild("Leave")
		local inviteGui = gui:FindFirstChild("Invite")
		local PlayUI = gui:FindFirstChild("TopButtons"):FindFirstChild("Play")
		if leaveGui then
			leaveGui.Visible = true
		end
		if inviteGui then
			inviteGui.Visible = true
		end
		
		if PlayUI then
			PlayUI.Visible = false
		end
	end

	for _, v in workspace:GetDescendants() do
		if v:IsA("ProximityPrompt") then
			v.Enabled = false
		end
	end
end

function QueueController.Handler()
	QueueController.Listener()

	-- Listen for attribute changes on all podiums
	for _, tableModel in workspace.QueueTables:GetChildren() do
		local podium1 = tableModel:FindFirstChild("1")
		local podium2 = tableModel:FindFirstChild("2")

		if podium1 then
			podium1:GetAttributeChangedSignal("taken"):Connect(function()
				local prompt = podium1:FindFirstChildWhichIsA("ProximityPrompt", true)
				if prompt then
					local taken = podium1:GetAttribute("taken") or ""
					-- Disable if taken by someone else, enable if empty (and we're not in a queue)
					if taken ~= "" then
						prompt.Enabled = false
					elseif currentPodium == nil then
						prompt.Enabled = true
					end
				end
			end)
		end

		if podium2 then
			podium2:GetAttributeChangedSignal("taken"):Connect(function()
				local prompt = podium2:FindFirstChildWhichIsA("ProximityPrompt", true)
				if prompt then
					local taken = podium2:GetAttribute("taken") or ""
					if taken ~= "" then
						prompt.Enabled = false
					elseif currentPodium == nil then
						prompt.Enabled = true
					end
				end
			end)
		end
	end

	plr.CharacterAdded:Connect(function(newCharacter)
		clearQueueState()
		refreshProximityPrompts(false)
	end)
end

return QueueController