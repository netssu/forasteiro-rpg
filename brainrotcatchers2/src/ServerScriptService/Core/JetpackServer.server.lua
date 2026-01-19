------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local REMOTES_FOLDER_NAME: string = "Remotes"
local EVENTS_FOLDER_NAME: string = "Events"
local AIR_TICK_EVENT_NAME: string = "JetpackAirTick"

local TICK_COOLDOWN: number = 0.9
local FUEL_COST_PER_TICK: number = 1
local DEFAULT_FUEL: number = 100

------------------//VARIABLES
local remotesFolder: Folder = ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME)
local eventsFolder: Folder = remotesFolder:WaitForChild(EVENTS_FOLDER_NAME)

local airTickEvent: RemoteEvent = eventsFolder:FindFirstChild(AIR_TICK_EVENT_NAME)

airTickEvent.OnServerEvent:Connect(function(player : Player , turn : boolean)
	
end)
