------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")

------------------//CONSTANTS
local STORE_NAME: string = "Released_Data.01"

------------------//VARIABLES
local ProfileStore = require(script:WaitForChild("ProfileStore"))
local ProfileTemplate = require(script:WaitForChild("ProfileTemplate"))
local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))

local store = ProfileStore.New(STORE_NAME, ProfileTemplate)
local profilesByUserId: {[number]: any} = {}

------------------//FUNCTIONS
local function apply_loaded_data_to_player(player: Player, profile: any): ()
	player:SetAttribute("RoleImageId", profile.Data.Image or "")
	player:SetAttribute("MaxLife", profile.Data.MaxLife or 100)
	player:SetAttribute("CurrentLife", profile.Data.CurrentLife or 100)
end

local function attach_player_profile(player: Player): ()
	local profile = store:StartSessionAsync(tostring(player.UserId))

	if not profile then
		warn("Falha ao iniciar sessão do perfil para " .. player.Name)
		return
	end

	profile:Reconcile()
	profile:AddUserId(player.UserId)

	profilesByUserId[player.UserId] = profile

	DataUtility.server.attach_profile(player, profile)
	apply_loaded_data_to_player(player, profile)

	player:GetAttributeChangedSignal("RoleImageId"):Connect(function()
		profile.Data.Image = player:GetAttribute("RoleImageId")
	end)

	task.spawn(function()
		while player.Parent and profilesByUserId[player.UserId] == profile do
			task.wait(1)

			if profilesByUserId[player.UserId] ~= profile then
				break
			end

			local currentTime = profile.Data.TimePlayed or 0
			DataUtility.server.set(player, "TimePlayed", currentTime + 1, false)
		end
	end)

	profile.OnSessionEnd:Connect(function()
		DataUtility.server.detach_profile(player)
		profilesByUserId[player.UserId] = nil
	end)
end

local function release_player_profile(player: Player): ()
	local profile = profilesByUserId[player.UserId]

	if profile then
		profile:Save()
		profile:EndSession()
		profilesByUserId[player.UserId] = nil
	end
end

------------------//MAIN FUNCTIONS
local function on_player_added(player: Player): ()
	attach_player_profile(player)
end

local function on_player_removing(player: Player): ()
	release_player_profile(player)
end

------------------//INIT
DataUtility.server.ensure_remotes()

for _, p in Players:GetPlayers() do
	on_player_added(p)
end

Players.PlayerAdded:Connect(on_player_added)
Players.PlayerRemoving:Connect(on_player_removing)

ProfileStore.OnError:Connect(function(msg: string, storeName: string, key: string)
	warn(("[ProfileStore:%s %s] %s"):format(storeName, key, msg))
end)