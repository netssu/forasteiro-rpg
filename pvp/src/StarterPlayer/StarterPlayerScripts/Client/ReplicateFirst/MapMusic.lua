-- // services

local SoundService = game:GetService("SoundService")

-- // settings

local MapMusic = "Wild West"

-- // function

local function findAndPlay()
	
	local TargetSound = MapMusic
	
	for _, Sound in ipairs(SoundService:GetDescendants()) do
		if Sound:IsA("Sound") and Sound.Name == TargetSound then
			Sound:Play()
			Sound.Looped = true
			Sound.Volume = .5
		end
	end
	
end

-- // conn

if game.Players.LocalPlayer then
	findAndPlay()
end

return {}