local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Remotes //--
local Remotes = ReplicatedStorage.Remotes
local NotificationEvent = Remotes.Events.Notification

--// Module //--
local Notifications = {}

--// Main Functions //--

-- Send notification to a single player
function Notifications.sendNotification(player: Player, message: string, isError: boolean?)
	if not player or not player:IsA("Player") then
		warn("[Notifications] Invalid player")
		return
	end

	if not message or message == "" then
		warn("[Notifications] Empty message")
		return
	end

	-- Send to client
	NotificationEvent:FireClient(player, {
		Message = message,
		IsError = isError or false,
		Timestamp = tick(),
	})
end

-- Send notification to all players
function Notifications.sendNotificationToAll(message: string, isError: boolean?)
	if not message or message == "" then
		warn("[Notifications] Empty message")
		return
	end

	NotificationEvent:FireAllClients({
		Message = message,
		IsError = isError or false,
		Timestamp = tick(),
	})
end

-- Send notification to multiple players
function Notifications.sendNotificationToPlayers(players: {Player}, message: string, isError: boolean?)
	if not message or message == "" then
		warn("[Notifications] Empty message")
		return
	end

	local data = {
		Message = message,
		IsError = isError or false,
		Timestamp = tick(),
	}

	for _, player in ipairs(players) do
		if player and player:IsA("Player") then
			NotificationEvent:FireClient(player, data)
		end
	end
end

-- Send rich notification (with icon, color, etc.)
function Notifications.sendRichNotification(player: Player, data: {
	Message: string,
	IsError: boolean?,
	Icon: string?,
	Duration: number?,
	Color: Color3?,
	})
	if not player or not player:IsA("Player") then
		warn("[Notifications] Invalid player")
		return
	end

	if not data.Message or data.Message == "" then
		warn("[Notifications] Empty message")
		return
	end

	-- Add timestamp
	data.Timestamp = tick()
	data.IsError = data.IsError or false

	NotificationEvent:FireClient(player, data)
end

return Notifications