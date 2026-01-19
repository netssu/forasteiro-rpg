------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")

------------------//CONSTANTS
local TAG = "[MISSIONS_REMOTES]"
local PLAYERDATA_WAIT_TIMEOUT = 12
local PLAYERDATA_WAIT_STEP = 0.25
local PUSH_POLL_INTERVAL = 5
local HOURLY_INTERVAL_SECONDS = 3600

------------------//VARIABLES
local rng: Random = Random.new()

local remotesFolder: Folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
if not remotesFolder then
--	warn(TAG, "ReplicatedStorage.Remotes não existia, criando")
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local functionsFolder: Folder = remotesFolder:FindFirstChild("Functions") :: Folder
if not functionsFolder then
--	warn(TAG, "ReplicatedStorage.Remotes.Functions não existia, criando")
	functionsFolder = Instance.new("Folder")
	functionsFolder.Name = "Functions"
	functionsFolder.Parent = remotesFolder
end

local eventsFolder: Folder = remotesFolder:FindFirstChild("Events") :: Folder
if not eventsFolder then
--	warn(TAG, "ReplicatedStorage.Remotes.Events não existia, criando")
	eventsFolder = Instance.new("Folder")
	eventsFolder.Name = "Events"
	eventsFolder.Parent = remotesFolder
end

local function ensure_remote_function(name: string): RemoteFunction
	local rf = functionsFolder:FindFirstChild(name) :: RemoteFunction
	if not rf then
	--	warn(TAG, "Criando RemoteFunction", name)
		rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = functionsFolder
	end
	return rf
end

local function ensure_remote_event(name: string): RemoteEvent
	local re = eventsFolder:FindFirstChild(name) :: RemoteEvent
	if not re then
	--	warn(TAG, "Criando RemoteEvent", name)
		re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = eventsFolder
	end
	return re
end

local getPlayerMissions: RemoteFunction = ensure_remote_function("GetPlayerMissions")
local getHourlyMission: RemoteFunction = ensure_remote_function("GetHourlyMission")
local acceptHourlyMission: RemoteFunction = ensure_remote_function("AcceptHourlyMission")
local claimHourlyMission: RemoteFunction = ensure_remote_function("ClaimHourlyMission")
local rerollHourlyMission: RemoteFunction = ensure_remote_function("RerollHourlyMission")

local hourlyMissionUpdate: RemoteEvent = ensure_remote_event("HourlyMissionUpdate")

local lastHourlySignatureByUserId: {[number]: string} = {}

------------------//MODULES
local Core: Folder = ServerScriptService:WaitForChild("Core") :: Folder
local PlayerFolder: Folder = Core:WaitForChild("Player") :: Folder

local MissionManager = require(PlayerFolder:WaitForChild("MissionManager"))
local CurrencyManager = require(PlayerFolder:WaitForChild("CurrencyManager"))

local Shared: Folder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local Configs: Folder = Shared:WaitForChild("Configs") :: Folder
local Utilities: Folder = Shared:WaitForChild("Utilities") :: Folder

local MissionConfig = require(Configs:WaitForChild("MissionConfig"))
local BigNum = require(Utilities:WaitForChild("BigNum"))

------------------//FUNCTIONS
local function wait_for_playerdata(player: Player): any?
	if not MissionManager.getPlayerData then
	--	warn(TAG, "MissionManager.getPlayerData NÃO existe. (PATCH no MissionManager necessário)")
		return nil
	end

	local waited = 0
	while waited < PLAYERDATA_WAIT_TIMEOUT do
		local pd = MissionManager.getPlayerData(player)
		if pd and pd.Hourly then
			return pd
		end
		task.wait(PLAYERDATA_WAIT_STEP)
		waited += PLAYERDATA_WAIT_STEP
	end

--	warn(TAG, "Timeout esperando PlayerData/Hourly para", player.Name, "(", player.UserId, ")")
	return MissionManager.getPlayerData(player)
end

local function safe_bignum_to_number(v: any): number?
	local ok, bn = pcall(function()
		return BigNum.new(v or "0")
	end)
	if not ok or not bn then
		return nil
	end

	local n = bn:toNumber()
	if n ~= n or n == math.huge or n == -math.huge then
		return nil
	end

	return n
end

local function ensure_hourly_flags(hourlyData: {}): {}
	hourlyData.Flags = hourlyData.Flags or {}
	hourlyData.Flags.Accepted = hourlyData.Flags.Accepted == true
	hourlyData.Flags.Claimed = hourlyData.Flags.Claimed == true
	hourlyData.Flags.Rerolled = hourlyData.Flags.Rerolled == true
	hourlyData.Flags.LastSeenReset = hourlyData.Flags.LastSeenReset or 0
	return hourlyData.Flags
end

local function reset_hourly_flags(hourlyData: {})
	hourlyData.Flags = {
		Accepted = false,
		Claimed = false,
		Rerolled = false,
		LastSeenReset = hourlyData.LastReset or 0,
	}
end

local function pick_new_hourly_mission(excludeId: string?): string?
	local list = MissionConfig.getMissionsByType("Hourly")
	if #list == 0 then
		return nil
	end
	if #list == 1 then
		return list[1]
	end

	local tries = 0
	while tries < 20 do
		tries += 1
		local id = list[rng:NextInteger(1, #list)]
		if id ~= excludeId then
			return id
		end
	end

	for i = 1, #list do
		if list[i] ~= excludeId then
			return list[i]
		end
	end

	return list[1]
end

local function ensure_hourly_cycle(playerData: any): boolean
	if not playerData or not playerData.Hourly then
		return false
	end

	local hourlyData = playerData.Hourly
	hourlyData.Missions = hourlyData.Missions or {}
	hourlyData.Progress = hourlyData.Progress or {}

	local now = tick()

	hourlyData.LastReset = tonumber(hourlyData.LastReset or 0) or 0
	hourlyData.NextResetAt = tonumber(hourlyData.NextResetAt or 0) or 0

	if hourlyData.NextResetAt <= 0 then
		if hourlyData.LastReset > 0 then
			hourlyData.NextResetAt = hourlyData.LastReset + HOURLY_INTERVAL_SECONDS
		else
			hourlyData.LastReset = now
			hourlyData.NextResetAt = now + HOURLY_INTERVAL_SECONDS
		end
	end

	if now < hourlyData.NextResetAt and hourlyData.Missions[1] then
		return false
	end

	local oldId = hourlyData.Missions[1]
	local newId = pick_new_hourly_mission(oldId)
	if not newId then
		return false
	end

	hourlyData.Missions[1] = newId
	hourlyData.Progress[newId] = {
		Progress = {},
		Completed = false,
		ClaimTime = nil,
	}

	if oldId and oldId ~= newId then
		hourlyData.Progress[oldId] = nil
	end

	hourlyData.LastReset = now
	hourlyData.NextResetAt = now + HOURLY_INTERVAL_SECONDS

	reset_hourly_flags(hourlyData)

	return true
end

local function build_tasks_payload(missionDef: {}, progress: {[string]: any}?): ({})
	local tasks = {}
	local idx = 0

	for taskName, required in pairs(missionDef.Tasks) do
		idx += 1

		local currentValue = progress and progress[taskName] or nil
		local percent = 0

		if taskName == "CashEarned" or taskName == "TotalCashEarned" then
			local curN = safe_bignum_to_number(currentValue)
			local reqN = safe_bignum_to_number(required)

			if curN and reqN and reqN > 0 then
				percent = math.clamp(curN / reqN, 0, 1)
			else
				local curBN = BigNum.new(currentValue or "0")
				local reqBN = BigNum.new(required or "0")
				percent = (curBN:greaterThan(reqBN) or curBN:equals(reqBN)) and 1 or 0
			end
		else
			local cur = tonumber(currentValue or 0) or 0
			local req = tonumber(required or 0) or 0
			if req > 0 then
				percent = math.clamp(cur / req, 0, 1)
			end
		end

		tasks[idx] = {
			Task = taskName,
			Current = currentValue or (((taskName == "CashEarned" or taskName == "TotalCashEarned") and "0") or 0),
			Required = required,
			Percent = percent,
		}
	end

	return tasks
end

local function compute_percent(tasks: {any}?): number
	if not tasks or #tasks == 0 then return 0 end
	local sum = 0
	for i = 1, #tasks do
		sum += math.clamp(tonumber(tasks[i].Percent) or 0, 0, 1)
	end
	return sum / #tasks
end

local function is_progress_complete(missionDef: any, progress: {[string]: any}?): boolean
	if not missionDef or type(missionDef.Tasks) ~= "table" then
		return false
	end

	progress = progress or {}

	for taskName, required in pairs(missionDef.Tasks) do
		local currentValue = progress[taskName]

		if taskName == "CashEarned" or taskName == "TotalCashEarned" then
			local curBN = BigNum.new(currentValue or "0")
			local reqBN = BigNum.new(required or "0")
			if curBN < reqBN then
				return false
			end
		else
			local cur = tonumber(currentValue or 0) or 0
			local req = tonumber(required or 0) or 0  
			if cur < req then
				return false
			end
		end
	end

	return true
end

local function build_mission_payload(missionId: string, missionProgress: {}?): {}?
	local missionDef = MissionConfig.getMission(missionId)
	if not missionDef then
	--	warn(TAG, "MissionDef não encontrado:", missionId)
		return nil
	end

	local progressTable = missionProgress and missionProgress.Progress or nil
	local completed = missionProgress and missionProgress.Completed == true or false
	local tasks = build_tasks_payload(missionDef, progressTable)

	return {
		Id = missionId,
		Type = missionDef.Type,
		Name = missionDef.Name,
		Description = missionDef.Description,
		Tip = missionDef.Tip,
		Difficulty = missionDef.Difficulty,
		ImageId = missionDef.ImageId,
		Completed = completed,
		ClaimTime = missionProgress and missionProgress.ClaimTime or nil,
		Tasks = tasks,
		Percent = compute_percent(tasks),
		Rewards = missionDef.Rewards or {},
	}
end

local function build_hourly_payload(playerData: any?): {}
	if not playerData or not playerData.Hourly then
		return { Ok = false, Reason = "NoHourlyData" }
	end

	ensure_hourly_cycle(playerData)

	local hourlyData = playerData.Hourly
	local flags = ensure_hourly_flags(hourlyData)

	if (hourlyData.LastReset or 0) ~= (flags.LastSeenReset or 0) then
		reset_hourly_flags(hourlyData)
		flags = hourlyData.Flags
	end

	local missionId = hourlyData.Missions and hourlyData.Missions[1]
	if not missionId then
	--	warn(TAG, "Hourly sem missionId (Hourly.Missions[1] nil)")
		return { Ok = false, Reason = "NoMission", NextReset = hourlyData.NextResetAt, Flags = flags }
	end

	local missionProgress = hourlyData.Progress and hourlyData.Progress[missionId]
	local missionPayload = build_mission_payload(missionId, missionProgress)
	if not missionPayload then
		return { Ok = false, Reason = "MissingMissionDef", NextReset = hourlyData.NextResetAt, Flags = flags }
	end

	local progressTable = missionProgress and missionProgress.Progress or {}
	local computedComplete = is_progress_complete(MissionConfig.getMission(missionId), progressTable)
	if computedComplete and missionProgress then
		missionProgress.Completed = true
		missionPayload.Completed = true
	end

	return {
		Ok = true,
		NextReset = hourlyData.NextResetAt,
		Flags = flags,
		Mission = missionPayload,
	}
end

local function signature_for_hourly(playerData: any?): string
	if not playerData or not playerData.Hourly then
		return "nil"
	end

	local hourly = playerData.Hourly
	local id = hourly.Missions and hourly.Missions[1] or "nil"
	local nextReset = hourly.NextResetAt or 0

	return tostring(id) .. ":" .. tostring(nextReset)
end

local function fire_hourly_update(player: Player, reason: string)
	local playerData = MissionManager.getPlayerData and MissionManager.getPlayerData(player) or nil
	local payload = build_hourly_payload(playerData)
	hourlyMissionUpdate:FireClient(player, { Reason = reason, Payload = payload })
end

local function apply_hourly_mission(playerData: any, newMissionId: string)
	local hourlyData = playerData.Hourly
	if not hourlyData then return end

	hourlyData.Missions = hourlyData.Missions or {}
	hourlyData.Progress = hourlyData.Progress or {}

	local oldId = hourlyData.Missions[1]
	hourlyData.Missions[1] = newMissionId

	hourlyData.Progress[newMissionId] = {
		Progress = {},
		Completed = false,
		ClaimTime = nil,
	}

	if oldId and oldId ~= newMissionId then
		hourlyData.Progress[oldId] = nil
	end

	reset_hourly_flags(hourlyData)
	hourlyData.Flags.Accepted = true
	hourlyData.Flags.Rerolled = true
end

local function debug_dump(player: Player)
	if MissionManager._debugDump then
		local dump = MissionManager._debugDump(player)
	--	warn(TAG, "MissionManager._debugDump", player.Name, dump.ok, dump.hourlyMission, dump.hourlyReset)
	end
end

------------------//MAIN FUNCTIONS
getPlayerMissions.OnServerInvoke = function(player: Player)
--	warn(TAG, "OnServerInvoke GetPlayerMissions <-", player.Name)
	debug_dump(player)

	if not MissionManager.getPlayerData then
	--	warn(TAG, "ERRO: MissionManager.getPlayerData não existe")
		return { Daily = {Missions = {}}, Weekly = {Missions = {}}, Hourly = {Missions = {}}, Quest = {Current = nil, Completed = {}} }
	end

	local playerData = MissionManager.getPlayerData(player)
	if not playerData then
	--	warn(TAG, "playerData nil em GetPlayerMissions para", player.Name)
		return { Daily = {Missions = {}}, Weekly = {Missions = {}}, Hourly = {Missions = {}}, Quest = {Current = nil, Completed = {}} }
	end

	ensure_hourly_cycle(playerData)

	local function build_timed_type_payload(playerData2: {}, missionType: string): {}
		local typeData = playerData2[missionType]
		if not typeData then
			return { Missions = {}, NextReset = nil }
		end

		local ids = typeData.Missions or {}
		local result = table.create(#ids)

		for i = 1, #ids do
			local id = ids[i]
			local prog = typeData.Progress and typeData.Progress[id] or nil
			result[i] = build_mission_payload(id, prog)
		end

		return { Missions = result, NextReset = typeData.NextResetAt or typeData.LastReset }
	end

	local function build_quest_payload(playerData2: {}): {}
		local questData = playerData2.Quest
		if not questData then
			return { Current = nil, Completed = {} }
		end

		local currentId = questData.CurrentQuest
		local currentProgress = currentId and questData.Progress and questData.Progress[currentId] or nil

		return {
			Current = currentId and build_mission_payload(currentId, currentProgress) or nil,
			Completed = questData.CompletedQuests or {},
		}
	end

	return {
		Daily = build_timed_type_payload(playerData, "Daily"),
		Weekly = build_timed_type_payload(playerData, "Weekly"),
		Hourly = build_timed_type_payload(playerData, "Hourly"),
		Quest = build_quest_payload(playerData),
	}
end

getHourlyMission.OnServerInvoke = function(player: Player)
--	warn(TAG, "OnServerInvoke GetHourlyMission <-", player.Name)
	debug_dump(player)
	local playerData = wait_for_playerdata(player)
	local payload = build_hourly_payload(playerData)
	----warn(TAG, "GetHourlyMission ->", player.Name, "Ok:", payload.Ok, "Reason:", payload.Reason, "Mission:", payload.Mission and payload.Mission.Id, "NextReset:", payload.NextReset)
	return payload
end

acceptHourlyMission.OnServerInvoke = function(player: Player)
--	warn(TAG, "OnServerInvoke AcceptHourlyMission <-", player.Name)
	debug_dump(player)

	local playerData = wait_for_playerdata(player)
	if not playerData or not playerData.Hourly then
	--	warn(TAG, "AcceptHourlyMission sem hourly data para", player.Name)
		return { Ok = false, Reason = "NoHourlyData" }
	end

	ensure_hourly_cycle(playerData)

	local flags = ensure_hourly_flags(playerData.Hourly)
	flags.Accepted = true

	local payload = build_hourly_payload(playerData)
	fire_hourly_update(player, "Accepted")
	return payload
end

rerollHourlyMission.OnServerInvoke = function(player: Player)
--	warn(TAG, "OnServerInvoke RerollHourlyMission <-", player.Name)
	debug_dump(player)

	local playerData = wait_for_playerdata(player)
	if not playerData or not playerData.Hourly then
	--	warn(TAG, "RerollHourlyMission sem hourly data para", player.Name)
		return { success = false, message = "No data" }
	end

	ensure_hourly_cycle(playerData)

	local hourlyData = playerData.Hourly
	local flags = ensure_hourly_flags(hourlyData)

	if flags.Claimed then
	--	warn(TAG, "Reroll bloqueado: já claimed", player.Name)
		return { success = false, message = "Already claimed" }
	end

	if flags.Rerolled then
	--	warn(TAG, "Reroll bloqueado: já rerolled", player.Name)
		return { success = false, message = "Already rerolled" }
	end

	local currentId = hourlyData.Missions and hourlyData.Missions[1]
	local newId = pick_new_hourly_mission(currentId)

--	warn(TAG, "Reroll pick -> current:", currentId, "new:", newId)

	if not newId then
		return { success = false, message = "No hourly missions" }
	end

	apply_hourly_mission(playerData, newId)

	local payload = build_hourly_payload(playerData)
	fire_hourly_update(player, "Rerolled")
	return { success = true, payload = payload }
end

claimHourlyMission.OnServerInvoke = function(player: Player)
--	warn(TAG, "OnServerInvoke ClaimHourlyMission <-", player.Name)
	debug_dump(player)

	local playerData = wait_for_playerdata(player)
	if not playerData or not playerData.Hourly then
	--	warn(TAG, "ClaimHourlyMission sem hourly data para", player.Name)
		return { success = false, message = "No data" }
	end

	ensure_hourly_cycle(playerData)

	local hourlyData = playerData.Hourly
	local flags = ensure_hourly_flags(hourlyData)

	if flags.Claimed then
	--	warn(TAG, "Claim bloqueado: já claimed", player.Name)
		return { success = false, message = "Already claimed" }
	end

	local missionId = hourlyData.Missions and hourlyData.Missions[1]
	if not missionId then
	--	warn(TAG, "ClaimHourlyMission sem missionId", player.Name)
		return { success = false, message = "No mission" }
	end

	local missionDef = MissionConfig.getMission(missionId)
	if not missionDef then
	--	warn(TAG, "ClaimHourlyMission sem MissionDef", missionId)
		return { success = false, message = "Missing mission def" }
	end

	local missionProgress = hourlyData.Progress and hourlyData.Progress[missionId]
	local progressTable = missionProgress and missionProgress.Progress or {}

	local complete = (missionProgress and missionProgress.Completed == true) or is_progress_complete(missionDef, progressTable)
	if not complete then
	--	warn(TAG, "Claim bloqueado: não completou", player.Name, "mission:", missionId)
		return { success = false, message = "Not completed" }
	end

	if missionProgress then
		missionProgress.Completed = true
	end

	local rewards = missionDef.Rewards or {}
--	warn(TAG, "Claim -> rewards", player.Name, rewards.Cash, rewards.Plutonium, rewards.Exp)

	if rewards.Cash then
		CurrencyManager.adjust(player, "Cash", rewards.Cash)
	end
	if rewards.Plutonium then
		CurrencyManager.adjust(player, "Plutonium", rewards.Plutonium)
	end
	if rewards.Exp then
		CurrencyManager.adjust(player, "Exp", rewards.Exp)
	end

	flags.Claimed = true

	local payload = build_hourly_payload(playerData)
	fire_hourly_update(player, "Claimed")
	return { success = true, payload = payload }
end

------------------//INIT
Players.PlayerAdded:Connect(function(player: Player)
	task.defer(function()
		local playerData = wait_for_playerdata(player)
		if not playerData then
		--	warn(TAG, "PlayerAdded push abortado: playerData nil", player.Name)
			return
		end

		ensure_hourly_cycle(playerData)

		lastHourlySignatureByUserId[player.UserId] = signature_for_hourly(playerData)
		fire_hourly_update(player, "Initial")
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
--	warn(TAG, "PlayerRemoving:", player.Name)
	lastHourlySignatureByUserId[player.UserId] = nil
end)

task.spawn(function()
	while true do
		task.wait(PUSH_POLL_INTERVAL)

		local plrs = Players:GetPlayers()
		for i = 1, #plrs do
			local p = plrs[i]
			if not MissionManager.getPlayerData then
				continue
			end

			local playerData = MissionManager.getPlayerData(p)
			if not playerData then
				continue
			end

			local changed = ensure_hourly_cycle(playerData)

			local sig = signature_for_hourly(playerData)
			local last = lastHourlySignatureByUserId[p.UserId]

			if changed or last ~= sig then
			--	warn(TAG, "Detectou mudança hourly:", p.Name, "old:", last, "new:", sig, "changed:", changed)
				lastHourlySignatureByUserId[p.UserId] = sig
				fire_hourly_update(p, "ResetOrChanged")
			end
		end
	end
end)
