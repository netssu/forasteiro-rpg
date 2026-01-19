local Figure = script:FindFirstAncestorOfClass("Model") or script.Parent
local Humanoid = Figure:FindFirstChildOfClass("Humanoid") or Figure:WaitForChild("Humanoid")
local Animator = Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", Humanoid)

local AnimSets = {
	Idle = {
		{ Id = "rbxassetid://180435571", Weight = 9 },
		{ Id = "rbxassetid://180435792", Weight = 1 },
	},
	Walk = {
		{ Id = "rbxassetid://180426354", Weight = 10 },
	},
	Run = {
		{ Id = "rbxassetid://180426354", Weight = 10 },
	},
	Jump = {
		{ Id = "rbxassetid://125750702", Weight = 10 },
	},
	Fall = {
		{ Id = "rbxassetid://180436148", Weight = 10 },
	},
	Climb = {
		{ Id = "rbxassetid://180436334", Weight = 10 },
	},
	Sit = {
		{ Id = "rbxassetid://178130996", Weight = 10 },
	},
	ToolNone = {
		{ Id = "rbxassetid://182393478", Weight = 10 },
	},
	ToolSlash = {
		{ Id = "rbxassetid://129967390", Weight = 10 },
	},
	ToolLunge = {
		{ Id = "rbxassetid://129967478", Weight = 10 },
	},
	Wave = {
		{ Id = "rbxassetid://128777973", Weight = 10 },
	},
	Point = {
		{ Id = "rbxassetid://128853357", Weight = 10 },
	},
	Dance1 = {
		{ Id = "rbxassetid://182435998", Weight = 10 },
		{ Id = "rbxassetid://182491037", Weight = 10 },
		{ Id = "rbxassetid://182491065", Weight = 10 },
	},
	Dance2 = {
		{ Id = "rbxassetid://182436842", Weight = 10 },
		{ Id = "rbxassetid://182491248", Weight = 10 },
		{ Id = "rbxassetid://182491277", Weight = 10 },
	},
	Dance3 = {
		{ Id = "rbxassetid://182436935", Weight = 10 },
		{ Id = "rbxassetid://182491368", Weight = 10 },
		{ Id = "rbxassetid://182491423", Weight = 10 },
	},
	Laugh = {
		{ Id = "rbxassetid://129423131", Weight = 10 },
	},
	Cheer = {
		{ Id = "rbxassetid://129423030", Weight = 10 },
	},
}

local EmoteLoop = { Wave = false, Point = false, Dance1 = true, Dance2 = true, Dance3 = true, Laugh = false, Cheer = false }

local Loaded = {}
local CurrentName = ""
local CurrentTrack = nil
local CurrentSpeed = 1
local JumpTime = 0
local JumpDuration = 0.3
local ToolName = ""
local ToolTrack = nil
local ToolUntil = 0
local Pose = "Standing"

local function LoadSet(Name)
	if Loaded[Name] then return end
	Loaded[Name] = {}
	for _, Data in ipairs(AnimSets[Name]) do
		local A = Instance.new("Animation")
		A.AnimationId = Data.Id
		local T = Animator:LoadAnimation(A)
		T.Priority = Enum.AnimationPriority.Core
		table.insert(Loaded[Name], { Track = T, Weight = Data.Weight })
	end
end

local function EnsureAll()
	for K in pairs(AnimSets) do LoadSet(K) end
end

local function Pick(Set)
	local Total = 0
	for _, V in ipairs(Set) do Total += V.Weight end
	local Roll = math.random(1, Total)
	for _, V in ipairs(Set) do
		if Roll <= V.Weight then return V.Track end
		Roll -= V.Weight
	end
	return Set[1].Track
end

local function Stop(T, Fade)
	if T and T.IsPlaying then T:Stop(Fade or 0.1) end
end

local function Play(Name, Fade)
	if CurrentName == Name then return end
	if CurrentTrack then Stop(CurrentTrack, Fade or 0.1) end
	local Track = Pick(Loaded[Name])
	CurrentName = Name
	CurrentTrack = Track
	CurrentSpeed = 1
	Track:Play(Fade or 0.1)
end

local function SetSpeed(Mult)
	if CurrentTrack and CurrentSpeed ~= Mult then
		CurrentSpeed = Mult
		CurrentTrack:AdjustSpeed(Mult)
	end
end

local function PlayTool(Name, Fade, Priority)
	if ToolName == Name then return end
	if ToolTrack then Stop(ToolTrack, Fade or 0.1) end
	local Track = Pick(Loaded[Name])
	if Priority then Track.Priority = Priority end
	ToolName = Name
	ToolTrack = Track
	Track:Play(Fade or 0.05)
end

local function StopTool(Fade)
	if ToolTrack then
		Stop(ToolTrack, Fade or 0.1)
		ToolTrack = nil
		ToolName = ""
	end
end

EnsureAll()
Play("Idle", 0)

Humanoid.Running:Connect(function(Speed)
	if Speed > 0.1 then
		Play("Walk", 0.1)
		SetSpeed(math.clamp(Speed / 14.5, 0.2, 2.5))
		Pose = "Running"
	else
		if not EmoteLoop[CurrentName] then Play("Idle", 0.1) end
		Pose = "Standing"
	end
end)

Humanoid.Jumping:Connect(function()
	Play("Jump", 0.1)
	JumpTime = JumpDuration
	Pose = "Jumping"
end)

Humanoid.FreeFalling:Connect(function()
	if JumpTime <= 0 then Play("Fall", 0.2) end
	Pose = "FreeFall"
end)

Humanoid.Climbing:Connect(function(Speed)
	Play("Climb", 0.1)
	SetSpeed(math.clamp(Speed / 12, 0.2, 2.5))
	Pose = "Climbing"
end)

Humanoid.Seated:Connect(function()
	Play("Sit", 0.2)
	Pose = "Seated"
end)

Humanoid.GettingUp:Connect(function()
	Pose = "GettingUp"
end)

Humanoid.FallingDown:Connect(function()
	Pose = "FallingDown"
end)

Humanoid.PlatformStanding:Connect(function()
	Pose = "PlatformStanding"
end)

Humanoid.Swimming:Connect(function(Speed)
	if Speed > 0 then
		Pose = "Running"
	else
		Pose = "Standing"
	end
end)

Humanoid.Died:Connect(function()
	Stop(CurrentTrack, 0.1)
	StopTool(0.1)
end)

game:GetService("RunService").Heartbeat:Connect(function(Dt)
	if JumpTime > 0 then JumpTime -= Dt end
	local Tool = nil
	for _, C in ipairs(Figure:GetChildren()) do
		if C:IsA("Tool") then Tool = C break end
	end
	if Tool and Tool:FindFirstChild("Handle") then
		local Sv = Tool:FindFirstChild("toolanim")
		if Sv and Sv:IsA("StringValue") then
			if Sv.Value == "Slash" then
				PlayTool("ToolSlash", 0, Enum.AnimationPriority.Action)
			elseif Sv.Value == "Lunge" then
				PlayTool("ToolLunge", 0, Enum.AnimationPriority.Action)
			else
				PlayTool("ToolNone", 0.05, Enum.AnimationPriority.Idle)
			end
			Sv.Parent = nil
			ToolUntil = time() + 0.3
		end
		if time() > ToolUntil and ToolName ~= "ToolNone" then
			PlayTool("ToolNone", 0.05, Enum.AnimationPriority.Idle)
		end
	else
		StopTool(0.05)
	end
end)

if not script:FindFirstChild("PlayEmote") then
	local B = Instance.new("BindableFunction")
	B.Name = "PlayEmote"
	B.Parent = script
end

script.PlayEmote.OnInvoke = function(EmoteName)
	if Pose ~= "Standing" then return false end
	local Map = { wave = "Wave", point = "Point", dance1 = "Dance1", dance2 = "Dance2", dance3 = "Dance3", laugh = "Laugh", cheer = "Cheer" }
	local Key = Map[string.lower(EmoteName or "")]
	if not Key then return false end
	Play(Key, 0.1)
	return true, CurrentTrack
end