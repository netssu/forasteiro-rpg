local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local RsvpStatus = Enum.RsvpStatus

-- The LocalPlayer is the client running this script.
local player = Players.LocalPlayer

-- NOTE: The Event ID is treated as a string to prevent Lua's floating-point precision loss on large numbers.
local EVENT_ID = "4837596386381529755"
local DELAY_SECONDS = 5 -- Initial delay
local RECURRING_INTERVAL = 180 -- Subsequent delay (60 seconds)

local function promptRsvp()
	local playerName = player.Name

	-- Initial delay
	print(string.format("[INFO] LocalPlayer %s joined. Starting initial %d-second delay.", playerName, DELAY_SECONDS))
	task.wait(DELAY_SECONDS)

	-- Start recurring prompt cycle
	while true do
		print(string.format("[INFO] Starting RSVP prompt cycle..."))

		-- 1. Check if the player has already RSVP'd (optional but good practice)
		local success, currentRsvpStatus = pcall(function()
			return SocialService:GetEventRsvpStatusAsync(EVENT_ID)
		end)

		if not success then
			warn(string.format("[ERROR] Failed to get RSVP status for %s. Error: %s", playerName, currentRsvpStatus))
			-- Wait the recurring interval before trying again
			task.wait(RECURRING_INTERVAL)
			continue
		end

		if currentRsvpStatus ~= RsvpStatus.None and currentRsvpStatus ~= RsvpStatus.NotGoing then
			print(string.format("[INFO] %s is already RSVP'd with status: %s. Skipping prompt this cycle.", playerName, currentRsvpStatus.Name))
		else
			-- 2. Prompt the RSVP
			print(string.format("[INFO] Attempting to prompt RSVP for %s...", playerName))

			local success, newRsvpStatus = pcall(function()
				return SocialService:PromptRsvpToEventAsync(EVENT_ID)
			end)

			if success then
				-- CORRECTED: Use typeof() to safely check for an EnumItem without relying on .IsA() which
				-- does not exist on primitive types (like strings) that PromptRsvpToEventAsync might return.
				if newRsvpStatus and typeof(newRsvpStatus) == "EnumItem" then
					print(string.format("[SUCCESS] RSVP prompt for %s completed. New Status: %s", playerName, newRsvpStatus.Name))
				else
					print(string.format("[INFO] RSVP prompt closed by %s. Final result: %s", playerName, tostring(newRsvpStatus)))
				end
			else
				warn(string.format("[CRITICAL ERROR] Failed to call PromptRsvpToEventAsync for %s. Error: %s", playerName, newRsvpStatus))
				warn("[HINT] This error is often due to an invalid/expired/archived Event ID.")
			end
		end

		-- Wait for the recurring interval before starting the next cycle
		print(string.format("[INFO] Cycle finished. Waiting %d seconds for next prompt...", RECURRING_INTERVAL))
		task.wait(RECURRING_INTERVAL)
	end
end

if player then
	print(string.format("[SETUP] RSVP Prompt LocalScript Initialized for %s. Targeting Event ID %s.", player.Name, EVENT_ID))
	-- Run the prompting function immediately for the local player.
	task.spawn(promptRsvp)
else
	warn("[SETUP] Waiting for LocalPlayer to load...")
	Players.PlayerAdded:Wait() 
	-- Re-run logic once Player is confirmed
	promptRsvp()
end