local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Use a reference to the container instead of the NPC itself immediately
local npcContainer = workspace:WaitForChild("VIP GUY")
local oldNpc = npcContainer:WaitForChild("npc")

-- Put your animation ID here
local animationId = "rbxassetid://1069977950"

local function replaceWithClone()
	-- 1. Get the player's current appearance
	local success, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
	end)

	if not success then 
		warn("Failed to fetch HumanoidDescription: " .. tostring(description))
		return 
	end

	-- 2. Create the clone model
	local clone = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)

	-- Store the original NPC's location before destroying it
	local originalCFrame = oldNpc:GetPivot()

	clone.Name = "VIPClone"
	clone.Parent = npcContainer

	-- 3. Position and Scale
	-- Note: ScaleTo should happen before positioning if possible, or use PivotTo after scaling.
	clone:ScaleTo(1.25)
	clone:PivotTo(originalCFrame)

	-- 4. Clean up the old NPC
	--oldNpc:Destroy()

	-- 5. Handle Physics and Animation
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	local rootPart = clone:FindFirstChild("HumanoidRootPart")

	if rootPart then
		rootPart.Anchored = true -- Ensures the clone doesn't fall through the floor
	end

	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

		-- Optional: Disable state changes to save resources on an idle NPC
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

		local animator = humanoid:FindFirstChildOfClass("Animator")
		assert(animator, "Invalid Animator.")

		local animation = Instance.new("Animation")
		animation.AnimationId = animationId

		-- Load and play the track
		local track = animator:LoadAnimation(animation)
		track.Looped = true
		track:Play()
	end
end

-- Run the replacement
replaceWithClone()