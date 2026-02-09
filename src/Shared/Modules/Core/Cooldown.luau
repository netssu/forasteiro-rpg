local CooldownModule = {}

-- // Types
local cooldownData: {
	[number]: {
		[string]: {
			EndTime: number,
			Duration: number,
			Thread: thread?,
		},
	},
} =
	{}

-- // Private Functions
local function getTime(): number
	return os.clock()
end

local function getPlayerKey(player: Player | any): number
	return typeof(player) == 'Instance'
			and player:IsA('Player')
			and player.UserId
		or player
end

-- // Public Functions
function CooldownModule:HasCooldown(
	player: Player | any,
	key: string
): (boolean, number)
	local p = getPlayerKey(player)
	local cd = cooldownData[p] and cooldownData[p][key]
	if not cd then return false, 0 end

	local remaining = cd.EndTime - getTime()
	if remaining > 0 then
		return true, remaining
	else
		self:ClearCooldown(player, key)
		return false, 0
	end
end

function CooldownModule:SetCooldown(
	player: Player | any,
	key: string,
	duration: number
)
	local p = getPlayerKey(player)

	cooldownData[p] = cooldownData[p] or {}

	local current = cooldownData[p][key]
	if current and current.Thread then task.cancel(current.Thread) end

	cooldownData[p][key] = {
		EndTime = getTime() + duration,
		Duration = duration,
		Thread = nil,
	}

	local thread = task.spawn(function()
		task.wait(duration)

		local data = cooldownData[p]
		local cd = data and data[key]
		if cd and cd.EndTime <= getTime() then data[key] = nil end
	end)

	cooldownData[p][key].Thread = thread
end

function CooldownModule:ClearCooldown(player: Player | any, key: string)
	local p = getPlayerKey(player)

	local playerCooldowns = cooldownData[p]
	if playerCooldowns and playerCooldowns[key] then
		local cd = playerCooldowns[key]

		if cd.Thread then task.cancel(cd.Thread) end

		playerCooldowns[key] = nil
	end
end

function CooldownModule:ClearAllCooldowns(player: Player | any)
	local p = getPlayerKey(player)

	local playerCooldowns = cooldownData[p]
	if playerCooldowns then
		for _, cd in pairs(playerCooldowns) do
			if cd.Thread then task.cancel(cd.Thread) end
		end

		cooldownData[p] = nil
	end
end

function CooldownModule:GetCooldownInfo(
	player: Player | any,
	key: string
): (number, number)
	local has, remaining = self:HasCooldown(player, key)
	if has then
		local p = getPlayerKey(player)
		return remaining, cooldownData[p][key].Duration
	end

	return 0, 0
end

function CooldownModule:CleanupPlayer(player: Player | any)
	self:ClearAllCooldowns(player)
end

return CooldownModule
