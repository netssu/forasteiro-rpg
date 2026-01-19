--// Services //--
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--// Configuration //--
local MAX_FRIENDS = 25

--// State //--
local Friends = {}
local allFriends = {}
local isLoading = false

--// Private Functions //--
local function loadFriendsAsync(player: Player)
	if isLoading then return end
	isLoading = true

	task.spawn(function()
		local success, pages = pcall(function()
			return Players:GetFriendsAsync(player.UserId)
		end)

		if not success or not pages then
			warn("[Friends] Failed to fetch friends")
			isLoading = false
			return
		end

		while #allFriends < MAX_FRIENDS do
			local currentPage = pages:GetCurrentPage()

			for _, friend in ipairs(currentPage) do
				if #allFriends >= MAX_FRIENDS then break end

				local descSuccess, description = pcall(function()
					return Players:GetHumanoidDescriptionFromUserIdAsync(friend.Id)
				end)

				if descSuccess and description then
					friend.HumanoidDescription = description
					table.insert(allFriends, friend)
				end

				if #allFriends % 5 == 0 then
					task.wait()
				end
			end

			if pages.IsFinished or #allFriends >= MAX_FRIENDS then
				break
			end

			local advanceSuccess = pcall(function()
				pages:AdvanceToNextPageAsync()
			end)

			if not advanceSuccess then break end
			task.wait()
		end

		print("[Friends] Loaded", #allFriends, "friends")
		isLoading = false
	end)
end

--// Public APIs //--
function Friends.getRandomFriend()
	if #allFriends == 0 then return nil end
	return allFriends[math.random(1, #allFriends)]
end

function Friends.isReady(): boolean
	return #allFriends > 0
end

--// Client Init //--
if RunService:IsClient() then
	loadFriendsAsync(Players.LocalPlayer)
end

return Friends