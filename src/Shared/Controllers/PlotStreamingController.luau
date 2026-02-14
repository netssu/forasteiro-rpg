local module = {}

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // Dependencies
local MachinesConstants = require(ReplicatedStorage.Modules.Constants.Machines)

-- // Constants
local LOAD_DISTANCE: number = 150
local UNLOAD_DISTANCE: number = 200
local UPDATE_INTERVAL: number = 0.5

local CACHE_FOLDER_NAME: string = "_ClientPlotCache"
local CACHE_ID_ATTRIBUTE: string = "ClientCacheId"
local HIDDEN_ATTRIBUTE: string = "ClientHidden"

-- // Variables
local PLAYER: Player = Players.LocalPlayer
local _MachineFolders: { string } = {}

-- // Private Functions
local function EnsureCacheFolder(): Folder
	local Existing: Instance? = ReplicatedStorage:FindFirstChild(CACHE_FOLDER_NAME)
	if Existing then
		if Existing:IsA("Folder") then
			return Existing
		end
		Existing:Destroy()
	end

	local Folder: Folder = Instance.new("Folder")
	Folder.Name = CACHE_FOLDER_NAME
	Folder.Parent = ReplicatedStorage
	return Folder
end

local function EnsureMachineFolders(): { string }
	if #_MachineFolders > 0 then
		return _MachineFolders
	end

	local Seen: { [string]: boolean } = {}
	for _, GroupConfig: any in MachinesConstants.Machines do
		if typeof(GroupConfig) == "table" then
			local PlotFolder: any = GroupConfig.PlotFolder
			if typeof(PlotFolder) == "string" and PlotFolder ~= "" and not Seen[PlotFolder] then
				Seen[PlotFolder] = true
				table.insert(_MachineFolders, PlotFolder)
			end
		end
	end

	table.sort(_MachineFolders)
	return _MachineFolders
end

local function EnsurePlotCacheFolder(CacheRoot: Folder, Plot: Model): Folder
	local CacheId: any = Plot:GetAttribute(CACHE_ID_ATTRIBUTE)
	if typeof(CacheId) ~= "string" or CacheId == "" then
		local Base: string = Plot.Name
		local Candidate: string = Base
		local Index: number = 2
		while CacheRoot:FindFirstChild(Candidate) do
			Candidate = string.format("%s_%d", Base, Index)
			Index += 1
		end
		CacheId = Candidate
		Plot:SetAttribute(CACHE_ID_ATTRIBUTE, CacheId)
	end

	local Existing: Instance? = CacheRoot:FindFirstChild(CacheId)
	if Existing and Existing:IsA("Folder") then
		return Existing
	end
	if Existing then
		Existing:Destroy()
	end

	local Folder: Folder = Instance.new("Folder")
	Folder.Name = CacheId
	Folder.Parent = CacheRoot
	return Folder
end

local function GetPlotsFolder(): Instance?
	local Map: Instance? = workspace:FindFirstChild("Map")
	if not Map then
		return nil
	end

	local Plots: Instance? = Map:FindFirstChild("Plots")
	if not Plots then
		return nil
	end

	if Plots:IsA("Folder") or Plots:IsA("Model") then
		return Plots
	end

	return nil
end

local function GetRoot(): BasePart?
	local Character: Model? = PLAYER.Character
	if not Character then
		return nil
	end
	return Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function GetPlotCenter(Plot: Model): Vector3?
	local Primary: BasePart? = Plot.PrimaryPart
	if Primary then
		return Primary.Position
	end

	local AnyPart: BasePart? = Plot:FindFirstChildWhichIsA("BasePart", true)
	if AnyPart then
		return AnyPart.Position
	end

	return nil
end

local function DistanceSquared(Left: Vector3, Right: Vector3): number
	local Delta: Vector3 = Left - Right
	return (Delta.X * Delta.X) + (Delta.Y * Delta.Y) + (Delta.Z * Delta.Z)
end

local function CollectPlots(PlotsFolder: Instance): { Model }
	local Results: { Model } = {}

	for _, Plot: Instance in PlotsFolder:GetChildren() do
		if Plot:IsA("Model") then
			table.insert(Results, Plot)
		end
	end

	return Results
end

local function HidePlotMachines(Plot: Model, CachePlotFolder: Folder, MachineFolders: { string }): ()
	for _, FolderName: string in ipairs(MachineFolders) do
		local FolderInstance: Instance? = Plot:FindFirstChild(FolderName)
		if FolderInstance then
			FolderInstance.Parent = CachePlotFolder
		end
	end

	Plot:SetAttribute(HIDDEN_ATTRIBUTE, true)
end

local function ShowPlotMachines(Plot: Model, CachePlotFolder: Folder, MachineFolders: { string }): ()
	for _, FolderName: string in ipairs(MachineFolders) do
		local FolderInstance: Instance? = CachePlotFolder:FindFirstChild(FolderName)
		if FolderInstance then
			FolderInstance.Parent = Plot
		end
	end

	Plot:SetAttribute(HIDDEN_ATTRIBUTE, false)
end

local function UpdatePlots(PlotsFolder: Instance, CacheFolder: Folder, Position: Vector3): ()
	local LoadDistanceSq: number = LOAD_DISTANCE * LOAD_DISTANCE
	local UnloadDistanceSq: number = UNLOAD_DISTANCE * UNLOAD_DISTANCE
	local Candidates: { Model } = CollectPlots(PlotsFolder)
	local MachineFolders: { string } = EnsureMachineFolders()

	local HasAnyReady: boolean = false
	local ClosestPlot: Model? = nil
	local ClosestDistanceSq: number = math.huge
	local Distances: { [Model]: number } = {}

	for _, Plot: Model in ipairs(Candidates) do
		if not Plot.Parent then
			continue
		end

		local PlotPos: Vector3? = GetPlotCenter(Plot)
		if not PlotPos then
			continue
		end

		HasAnyReady = true
		local DistSq: number = DistanceSquared(PlotPos, Position)
		Distances[Plot] = DistSq
		if DistSq < ClosestDistanceSq then
			ClosestDistanceSq = DistSq
			ClosestPlot = Plot
		end
	end

	if not HasAnyReady then
		return
	end

	for _, Plot: Model in ipairs(Candidates) do
		if not Plot.Parent then
			continue
		end

		local DistSq: number? = Distances[Plot]
		if not DistSq then
			continue
		end
		local IsHidden: boolean = Plot:GetAttribute(HIDDEN_ATTRIBUTE) == true

		if Plot == ClosestPlot then
			local CachePlotFolder: Folder = EnsurePlotCacheFolder(CacheFolder, Plot)
			ShowPlotMachines(Plot, CachePlotFolder, MachineFolders)
			continue
		end

		if IsHidden then
			if DistSq <= LoadDistanceSq then
				local CachePlotFolder: Folder = EnsurePlotCacheFolder(CacheFolder, Plot)
				ShowPlotMachines(Plot, CachePlotFolder, MachineFolders)
			end
		else
			if DistSq >= UnloadDistanceSq then
				local CachePlotFolder: Folder = EnsurePlotCacheFolder(CacheFolder, Plot)
				HidePlotMachines(Plot, CachePlotFolder, MachineFolders)
			end
		end
	end
end

-- // Public Functions
function module:Start()
	task.spawn(function(): ()
		local CacheFolder: Folder = EnsureCacheFolder()
		local PlotsFolder: Instance? = nil

		while not PlotsFolder do
			PlotsFolder = GetPlotsFolder()
			if not PlotsFolder then
				task.wait(1)
			end
		end

		while true do
			local Root: BasePart? = GetRoot()
			if Root then
				UpdatePlots(PlotsFolder :: Instance, CacheFolder, Root.Position)
			end
			task.wait(UPDATE_INTERVAL)
		end
	end)
end

return module
