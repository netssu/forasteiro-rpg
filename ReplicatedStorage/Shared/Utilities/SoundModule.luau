--// Services //--
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

--// Variables //--
local SoundModule = {}
local sourceCache = {}

export type SoundInfo = {Sound:Sound,ScheduledRemove:number}
local soundCache = {} :: {[string]: SoundInfo}

local soundFolder = ReplicatedStorage.Assets.Sounds
local isServer = RunService:IsServer()

local CACHE_CLEANUP_TIME = 30
local SOUND_CLEANUP_TIME = 10

local player = Players.LocalPlayer

SoundModule.RemoteEvent = ReplicatedStorage.Remotes.Events.PlaySound

--// Helper Functions //--
local function findSound(soundName) : Sound
	if sourceCache[soundName] then
		return sourceCache[soundName]
	end

	local sound = soundFolder:FindFirstChild(soundName, true)
	if sound and sound:IsA("Sound") then
		sourceCache[soundName] = sound
		task.delay(CACHE_CLEANUP_TIME,function()
			sourceCache[soundName] = nil
		end)
		return sound
	end

	return nil
end

local function getSoundDuration(sound:Sound)
	return sound.TimeLength / sound.PlaybackSpeed
end

local function scheduleSoundCleanup(soundInfo:SoundInfo)
	task.delay(SOUND_CLEANUP_TIME + getSoundDuration(soundInfo.Sound) + 0.1,function()
		if tick() >= soundInfo.ScheduledRemove and soundInfo.Sound then
			soundInfo.Sound:Destroy()

			if soundCache[soundInfo.Sound.Name] then
				soundCache[soundInfo.Sound.Name] = nil
			end
		else
			scheduleSoundCleanup(soundInfo)
		end
	end)
end

local function getSound(source:Sound) : Sound
	local list = soundCache[source.Name]
	if not list then
		list = {}
		soundCache[source.Name] = list
	end

	for _, entry in list do
		if not entry.Sound.IsPlaying then
			entry.LastUsed = tick()
			return entry.Sound
		end
	end

	local clone = source:Clone()
	clone.Parent = SoundService

	table.insert(list, {
		Sound = clone,
		LastUsed = tick()
	})

	task.delay(SOUND_CLEANUP_TIME + getSoundDuration(clone), function()
		if not clone.IsPlaying and soundCache[source.Name] then
			for i, entry in soundCache[source.Name] do
				if entry.Sound == clone and tick() - entry.LastUsed >= SOUND_CLEANUP_TIME then
					clone:Destroy()
					table.remove(soundCache[source.Name], i)
					break
				end
			end
		end
	end)

	return clone
end

--// Main Functions //--
function SoundModule.Play(soundName, volume, speed, parent, soundGroup: string)
	local sound = findSound(soundName)
	if not sound then
		warn("Sound not found: " .. soundName)
		return
	end

	local soundClone = getSound(sound)
	soundClone.Volume = volume or sound.Volume
	soundClone.PlaybackSpeed = speed or sound.PlaybackSpeed
	soundClone.SoundGroup = SoundService:FindFirstChild(soundGroup or "Effects")
	soundClone.Parent = parent or SoundService
	soundClone:Play()
	
	return soundClone
end

if isServer then
	function SoundModule.PlayForPlayers(players, soundName, volume, speed, parent)
		if typeof(players) == "Instance" and players:IsA("Player") then
			players = {players}
		end

		for _, player in players do
			SoundModule.RemoteEvent:FireClient(player, soundName, volume, speed, parent)
		end
	end

	function SoundModule.PlayForAll(soundName, volume, speed, parent)
		SoundModule.RemoteEvent:FireAllClients(soundName, volume, speed, parent)
	end
else
	SoundModule.RemoteEvent.OnClientEvent:Connect(function(soundName, volume, speed, parent)
		SoundModule.Play(soundName, volume, speed, parent)
	end)
end

return SoundModule