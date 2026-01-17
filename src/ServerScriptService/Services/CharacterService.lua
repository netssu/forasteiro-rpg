local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedModules = ReplicatedStorage.Modules
local Maid = require(sharedModules.Nevermore.Maid)
local PlayerDataService = require(script.Parent.PlayerDataService)
local safeCharacterAdded = require(sharedModules.Utils.safeCharacterAdded)
local safePlayerAdded = require(sharedModules.Utils.safePlayerAdded)
local characterMaid = Maid.new()

local CharacterService = {}

function CharacterService.Handler()
	safePlayerAdded(CharacterService._onPlayerAdded)
	Players.PlayerRemoving:Connect(CharacterService._onPlayerRemoving)
end

function CharacterService._onCharacterAdded(player, character)
	local playerStats = player:WaitForChild("PlayerStats", 5)

	if not playerStats then
		return
	end

	if playerStats.Vip.Value then
		local billboard = ReplicatedStorage.Assets.VFX.VIPBanner:Clone()
		billboard.Parent = character.Head
	end

	local leaderstats = player:WaitForChild("leaderstats", 5)

	if not leaderstats then
		return
	end

	if leaderstats.Streak.Value > 0 then
		local billboard = ReplicatedStorage.Assets.VFX.Streak:Clone()
		billboard.Parent = character.Head
		billboard.TextLabel.Text = leaderstats.Streak.Value
	end
end

function CharacterService._onPlayerAdded(player)
	-- Poll until profile is available
	local profile = PlayerDataService.getOneProfileAsync(player)

	if not profile then
		return
	end

	-- Now safe to access profile.Data
	if profile.Data.LikeRewardVisible and not profile.Data.CanClaimLikeReward then
		profile.Data.CanClaimLikeReward = true
	end

	-- Check if profile was successfully loaded
	if not profile then
		warn("Failed to load profile for player:", player.Name)
		return
	end

	characterMaid[player] = safeCharacterAdded(player, function(character)
		CharacterService._onCharacterAdded(player, character)
	end)
end

function CharacterService._onPlayerRemoving(player)
	characterMaid[player] = nil
end

return CharacterService
