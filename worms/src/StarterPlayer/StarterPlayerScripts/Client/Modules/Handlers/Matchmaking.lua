local Handler = {}

local Players = game.Players
local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local MainUi = PlayerGui:WaitForChild("TD")
local Frames = MainUi:WaitForChild("Frames")
local SearchingFrame = MainUi:WaitForChild("Searching")
local InnerSearch = SearchingFrame:WaitForChild("Frame")
local CancelButton = InnerSearch:WaitForChild("End")
local StatusLabel = InnerSearch:WaitForChild("Status")
local TimeLabel = InnerSearch:WaitForChild("Time")

local ReplicatedStorage = game.ReplicatedStorage
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MatchmakingRemotes = Remotes:WaitForChild("Matchmaking")
local ClientSearching = MatchmakingRemotes:WaitForChild("ClientSearching")

local timerRunning = false

ClientSearching.OnClientEvent:Connect(function(statusText: string)
	if statusText == "Cancelled" then
		SearchingFrame.Visible = false
		timerRunning = false
		return
	end

	StatusLabel.Text = statusText
	TimeLabel.Text = "00:00"

	SearchingFrame.Visible = true

	if timerRunning then return end
	timerRunning = true

	local startTime = tick()
	task.spawn(function()
		while SearchingFrame.Visible do
			local elapsed = math.floor(tick() - startTime)
			TimeLabel.Text = string.format("%02d:%02d", elapsed // 60, elapsed % 60)
			task.wait(1)
		end
		timerRunning = false
	end)
end)

CancelButton.Activated:Connect(function()
	SearchingFrame.Visible = false
	game.ReplicatedStorage.Remotes.Matchmaking.CancelMatchmaking:FireServer()
end)

return Handler