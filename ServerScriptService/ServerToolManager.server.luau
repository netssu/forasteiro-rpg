local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Resources = ServerStorage:WaitForChild("Resources")
local Modules = Resources:WaitForChild("Modules")

local ServerGunFramework = require(Modules:WaitForChild("ServerGunFramework"))

local InitializedTools = {}

local function InitializeGun(tool: Tool)
	if not tool:IsA("Tool") then return end
	if InitializedTools[tool] then return end

	local success, result = pcall(function()
		return ServerGunFramework.Initialize(tool)
	end)

	if success then
		InitializedTools[tool] = result or true
		print("[ServerToolManager] Initialized:", tool:GetFullName())
	else
		warn("[ServerToolManager] Failed to initialize:", tool.Name, result)
	end

	tool.Destroying:Connect(function()
		InitializedTools[tool] = nil
	end)
end

local function WatchContainer(container)
	for _, tool in ipairs(container:GetChildren()) do
		if tool:IsA("Tool") then
			InitializeGun(tool)
		end
	end

	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			InitializeGun(child)
		end
	end)
end

local function OnPlayerAdded(player: Player)
	local backpack = player:WaitForChild("Backpack")
	WatchContainer(backpack)

	player.CharacterAdded:Connect(function(char)
		WatchContainer(char)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	OnPlayerAdded(player)
end

Players.PlayerAdded:Connect(OnPlayerAdded)

print("[ServerToolManager] Listening for player tool initialization.")
