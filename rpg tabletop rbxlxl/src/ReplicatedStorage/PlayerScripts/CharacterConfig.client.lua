------------------//SERVICES
local Players: Players = game:GetService("Players")

------------------//CONSTANTS
local WALK_SPEED: number = 14
local JUMP_HEIGHT: number = 5

local CUSTOM_SOUNDS: {[string]: string} = {
	Died = "rbxassetid://0",
	Jumping = "rbxassetid://139595320123961",
	Splash = "rbxassetid://0",
	Swimming = "rbxassetid://0"
}

------------------//VARIABLES
local player: Player = Players.LocalPlayer

------------------//FUNCTIONS
local function check_and_update_sound(child: Instance): ()
	if child:IsA("Sound") and CUSTOM_SOUNDS[child.Name] then
		child.SoundId = CUSTOM_SOUNDS[child.Name]
	end
end

local function on_character_added(character: Model): ()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

	humanoid.WalkSpeed = WALK_SPEED
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = JUMP_HEIGHT

	for _, child in ipairs(rootPart:GetChildren()) do
		check_and_update_sound(child)
	end

	rootPart.ChildAdded:Connect(check_and_update_sound)

	for soundName, soundId in pairs(CUSTOM_SOUNDS) do
		if not rootPart:FindFirstChild(soundName) then
			local newSound = Instance.new("Sound")
			newSound.Name = soundName
			newSound.SoundId = soundId
			newSound.Parent = rootPart
		end
	end
end

------------------//MAIN FUNCTIONS
player.CharacterAdded:Connect(on_character_added)

------------------//INIT
if player.Character then
	task.spawn(on_character_added, player.Character)
end