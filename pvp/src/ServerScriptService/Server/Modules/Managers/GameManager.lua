-- // services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

-- // variables

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local GameRemotes = Remotes:FindFirstChild("Game")

local Path = workspace:FindFirstChild("PathA")
local Waypoints = Path:FindFirstChild("Waypoints")

local Units = ServerStorage:FindFirstChild("Units")

local GlobalValues = ReplicatedStorage:FindFirstChild("GlobalValues")

-- // remotes

local RequestGameStart_Event = GameRemotes:FindFirstChild("RequestGameStart")

-- // tables

local GameManager = {}
local Dialogue = require(ReplicatedStorage.Modules.StoredData.Dialogue)

local EnemyStats = require(ReplicatedStorage.Modules.StoredData.EnemyStats)

-- // values

local MaxHealth = GlobalValues:FindFirstChild("Base_Health_A").Value

-- // function

local GameManager = {}

-- // settings

local hasDialogue = false
local collision_Group = "Worms"

-- // functions

local function hideArrows()
	task.spawn(function()
		local Path_Model = workspace:FindFirstChild("Path_Model")
		if not Path_Model then return end

		local Arrows = Path_Model:FindFirstChild("Arrows")
		if not Arrows then return end

		task.wait(30)

		for _, Beam in ipairs(Arrows:GetDescendants()) do
			if Beam:IsA("Beam") then
				Beam.Enabled = false
			end
		end
	end)
end

local function sendDialogueData()
	local DialogueData = Dialogue
	GameRemotes:FindFirstChild("SendDialogueData"):FireAllClients(DialogueData)
end

local Presets = {
	Easy = {
		["Wave1"] = {"Soldier", "Soldier", "Soldier", "Soldier", "Heavy"},
		["Wave2"] = {"Soldier", "Soldier", "Soldier", "Scout", "Heavy"},
		["Wave3"] = {"Soldier", "Scout", "Soldier", "Heavy", "Heavy"},
		["Wave4"] = {"Scout", "Scout", "Soldier", "Heavy", "Heavy"},
		["Wave5"] = {"Soldier", "Scout", "Heavy", "Boss"},
	},
	Medium = {
		["Wave1"] = {"Soldier", "Soldier", "Soldier", "Heavy"},
		["Wave2"] = {"Soldier", "Scout", "Soldier", "Heavy"},
		["Wave3"] = {"Scout", "Soldier", "Heavy", "Scout"},
		["Wave4"] = {"Soldier", "Scout", "Heavy", "Heavy"},
		["Wave5"] = {"Scout", "Scout", "Soldier", "Heavy"},
		["Wave6"] = {"Soldier", "Heavy", "Scout", "Soldier"},
		["Wave7"] = {"Soldier", "Scout", "Heavy", "Boss"},
		["Wave8"] = {"Scout", "Soldier", "Heavy", "Boss"},
	},
	Hard = {
		["Wave1"] = {"Soldier", "Soldier", "Scout", "Heavy"},
		["Wave2"] = {"Scout", "Soldier", "Heavy", "Scout"},
		["Wave3"] = {"Soldier", "Scout", "Heavy", "Heavy"},
		["Wave4"] = {"Scout", "Scout", "Soldier", "Heavy"},
		["Wave5"] = {"Soldier", "Heavy", "Scout", "Soldier"},
		["Wave6"] = {"Soldier", "Scout", "Heavy", "Boss"},
		["Wave7"] = {"Scout", "Soldier", "Heavy", "Boss"},
		["Wave8"] = {"Soldier", "Scout", "Heavy", "Boss"},
		["Wave9"] = {"Scout", "Soldier", "Heavy", "Boss"},
		["Wave10"] = {"Soldier", "Scout", "Heavy", "Boss"},
	},
	Impossible = {
		["Wave1"]  = {"Heavy", "Heavy", "Heavy", "Heavy", "Boss"},
		["Wave2"]  = {"Heavy", "Heavy", "Heavy", "Heavy", "Boss"},
		["Wave3"]  = {"Heavy", "Heavy", "Heavy", "Heavy", "Boss"},
		["Wave4"]  = {"Heavy", "Heavy", "Heavy", "Heavy", "Boss"},
		["Wave5"]  = {"Heavy", "Heavy", "Heavy", "Heavy", "Boss"},
		["Wave6"]  = {"Heavy", "Heavy", "Heavy", "Heavy", "Boss"},
		["Wave7"]  = {"Heavy", "Heavy", "Heavy", "Heavy", "Boss"},
		["Wave8"]  = {"Heavy", "Heavy", "Heavy", "Heavy", "Boss"},
		["Wave9"]  = {"Heavy", "Heavy", "Heavy", "Heavy", "Boss"},
		["Wave10"] = {"Heavy", "Heavy", "Heavy", "Heavy", "Boss"},
		["Wave11"] = {"Heavy", "Heavy", "Heavy", "Heavy", "Boss"},
		["Wave12"] = {"Heavy", "Heavy", "Heavy", "Heavy", "Boss"},
		["Wave13"] = {"Heavy", "Heavy", "Heavy", "Heavy", "Boss"},
		["Wave14"] = {"Heavy", "Heavy", "Heavy", "Heavy", "Boss"},
		["Wave15"] = {"Heavy", "Heavy", "Heavy", "Heavy", "Boss"},
	},
}

function GameManager.Start(Difficulty, Gamemode)
	
	--[[
	for i, plr in ipairs(Players:GetPlayers()) do
		if i == 1 then
			plr:SetAttribute("PathSide", "A")
		else
			plr:SetAttribute("PathSide", "B")
		end
	end
	]]
	
	if not(Difficulty) then
		Difficulty = "Easy"
	end

	hideArrows()
	if hasDialogue == true then
		sendDialogueData()
	end

	local DifficultyPreset = Presets[Difficulty]
	local WaveCount = 0

	if Gamemode == "Endless" then
		WaveCount = math.huge
	else
		for _ in pairs(DifficultyPreset) do
			WaveCount = WaveCount + 1
		end
	end

	local RoundManager = require(script.Parent.Parent.Managers.RoundManager)
	RoundManager.StartGame(WaveCount, DifficultyPreset, Gamemode, Difficulty)

end

RequestGameStart_Event.Event:Connect(function(Difficulty, Gamemode)
	GameManager.Start(Difficulty, Gamemode)
end)

return GameManager
