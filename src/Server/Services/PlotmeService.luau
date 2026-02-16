local module = {}

-- // Services
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')

-- // Dependencies
local MetaPlayer = require(ServerScriptService.Modules.Core.MetaPlayer)
local Signal = require(ReplicatedStorage.Packages.Signal)
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local MachinesConstants = require(ReplicatedStorage.Modules.Constants.Machines)
local Short = require(ReplicatedStorage.Modules.Core.Short)
local Packets = require(ReplicatedStorage.Modules.Game.Packets)

-- // Assets
local RecursosRoot = ReplicatedStorage:WaitForChild('Assets')
	:WaitForChild('Maquinas')
	:WaitForChild('Recursos')
local MachinesRoot = RecursosRoot:WaitForChild('Maquinas')
local MapSizeRoot = RecursosRoot:WaitForChild('MapSize')
local BuyRoot = RecursosRoot:WaitForChild('Buy')

-- // Variables
module.Signals = {
	AssignPlot = Signal.new(),
	RemovePlot = Signal.new(),
}

local _RebirthWatchers: { [Player]: RBXScriptConnection } = {}

-- // Machine Placement
local MAPSIZE_OFFSETS = {
	[1] = Vector3.new(-0.404, -4.756, -106.161),
	[2] = Vector3.new(-0.404, -4.756, -147.494),
	[3] = Vector3.new(-0.404, -4.756, -252.976),
	[4] = Vector3.new(-0.404, -4.756, -358.425),
}
local MAPSIZE_CLONE_ATTRIBUTE = 'MapSizeClone'
local BUY_FOLDER_NAME = "_BuyModels"
local BUY_ANIMATION_DELAY = 1.2
local BUY_ROTATION_OFFSET = 180
local GROUP_ANCHOR_NAME = "__GroupAnchor"
local GROUP_ANCHOR_ATTR = "MachineAnchor"
local PLOT_INDEX_ATTRIBUTE = "PlotIndex"
local PLOT_ROTATION_OFFSET_ATTRIBUTE = "PlotRotationOffset"
local DEBUG_BUY = true
local PLOT_ROTATION_BY_INDEX = {
	[1] = 0,
	[2] = 0,
	[3] = -90,
	[4] = -90,
	[5] = -180,
	[6] = -180,
	[7] = 90,
	[8] = 90,
}

local function debug_buy(message: string, ...: any)
	if not DEBUG_BUY then
		return
	end
	print(string.format("[BuyDebug] " .. message, ...))
end

local function get_plot_index(plot: Model): number
	local attributeIndex = plot:GetAttribute(PLOT_INDEX_ATTRIBUTE)
	if typeof(attributeIndex) == "number" and attributeIndex >= 1 then
		return math.floor(attributeIndex + 0.5)
	end

	local digits = string.match(plot.Name, '%d+')
	if digits then
		local parsed = tonumber(digits)
		if parsed and parsed >= 1 then
			return math.floor(parsed + 0.5)
		end
	end

	return 1
end

local function get_plot_rotation(plot: Model): number
	local pivot = plot:GetPivot()
	local _, yaw, _ = pivot:ToOrientation()
	if yaw ~= yaw then
		return 0
	end
	local yawDegrees = math.deg(yaw)
	-- Normalize to [-180, 180] to keep values consistent.
	yawDegrees = (yawDegrees + 180) % 360 - 180
	return yawDegrees
end

local function round_half_away_from_zero(value: number): number
	if value >= 0 then
		return math.floor(value + 0.5)
	end
	return math.ceil(value - 0.5)
end

local function normalize_yaw_degrees(value: number): number
	local normalized = (value + 180) % 360 - 180
	if math.abs(normalized) < 0.001 then
		return 0
	end
	if math.abs(normalized + 180) < 0.001 then
		return -180
	end
	return normalized
end

local function get_plot_rotation_offset(plot: Model): number
	local index = get_plot_index(plot)
	local wrappedIndex = ((index - 1) % 8) + 1
	local mappedOffset = PLOT_ROTATION_BY_INDEX[wrappedIndex]
	if typeof(mappedOffset) == "number" then
		return mappedOffset
	end

	local attributeOffset = plot:GetAttribute(PLOT_ROTATION_OFFSET_ATTRIBUTE)
	if typeof(attributeOffset) == "number" then
		local snappedAttribute = round_half_away_from_zero(attributeOffset / 90) * 90
		return normalize_yaw_degrees(snappedAttribute)
	end

	local yawDegrees = get_plot_rotation(plot)
	local snappedYaw = round_half_away_from_zero(yawDegrees / 90) * 90
	local offset = normalize_yaw_degrees(snappedYaw)
	plot:SetAttribute(PLOT_ROTATION_OFFSET_ATTRIBUTE, offset)
	return offset
end

local function normalize_name(name: string): string
	local lower = string.lower(name)
	lower = lower:gsub("%s+", "")
	lower = lower:gsub("_", "")
	lower = lower:gsub("-", "")
	return lower
end

local function get_group_placement(groupConfig: any): (Vector3, number)
	local placement = if typeof(groupConfig) == "table" then groupConfig.Placement else nil
	if typeof(placement) == "table" then
		local offset = placement.PlotOffset
		local yawOffset = placement.YawOffset
		if typeof(offset) == "Vector3" and typeof(yawOffset) == "number" then
			return offset, yawOffset
		end
	end
	return Vector3.new(), 0
end

local function get_slot_rotation(plot: Model, slotConfig: any): number
	local rotation = if typeof(slotConfig) == "table" and typeof(slotConfig.RotationDefault) == "number"
		then slotConfig.RotationDefault
		else 0
	local useByPlot = if typeof(slotConfig) == "table" then slotConfig.UseRotationByPlot else nil
	local byPlot = if typeof(slotConfig) == "table" then slotConfig.RotationByPlot else nil
	local shouldUseByPlot = useByPlot == true and typeof(byPlot) == "table"
	if shouldUseByPlot then
		local index = get_plot_index(plot)
		if index then
			local value = byPlot[index]
			if typeof(value) ~= "number" then
				local maxByPlotIndex = 0
				for key, mapped in byPlot do
					if typeof(key) == "number" and typeof(mapped) == "number" and key > maxByPlotIndex then
						maxByPlotIndex = key
					end
				end
				if maxByPlotIndex > 0 then
					local wrappedIndex = ((index - 1) % maxByPlotIndex) + 1
					value = byPlot[wrappedIndex]
				end
			end
			if typeof(value) == "number" then
				rotation = value
			end
		end
	end
	local modelOffset = if typeof(slotConfig) == "table" and typeof(slotConfig.ModelRotationOffset) == "number"
		then slotConfig.ModelRotationOffset
		else 0
	return rotation + modelOffset
end

local function ensure_folder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function find_first_basepart(target: Instance): BasePart?
	if target:IsA("BasePart") then
		return target
	end
	for _, descendant in target:GetDescendants() do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
	return nil
end

local function is_anchor_part(target: Instance): boolean
	return target:IsA("BasePart") and (target.Name == GROUP_ANCHOR_NAME or target:GetAttribute(GROUP_ANCHOR_ATTR) == true)
end

local function ensure_group_anchor(model: Model): BasePart
	local existing: Instance? = model:FindFirstChild(GROUP_ANCHOR_NAME)
	if existing and existing:IsA("BasePart") then
		return existing
	end
	local anchor = Instance.new("Part")
	anchor.Name = GROUP_ANCHOR_NAME
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.CFrame = model:GetPivot()
	anchor.Parent = model
	anchor:SetAttribute(GROUP_ANCHOR_ATTR, true)
	return anchor
end

local function get_group_anchor_cframe(target: Instance): CFrame?
	if target:IsA("Model") then
		local anchor = target:FindFirstChild(GROUP_ANCHOR_NAME)
		if anchor and anchor:IsA("BasePart") then
			return anchor.CFrame
		end
	end
	return nil
end

local function get_reference_cframe(target: Instance): CFrame?
	if target:IsA("Model") then
		local anchor = get_group_anchor_cframe(target)
		if anchor then
			return anchor
		end
		return target:GetPivot()
	end
	if target:IsA("BasePart") then
		return target.CFrame
	end
	local base = find_first_basepart(target)
	if base then
		return base.CFrame
	end
	return nil
end

local function get_all_baseparts(target: Instance): { BasePart }
	local results: { BasePart } = {}
	if target:IsA("BasePart") then
		table.insert(results, target)
	end
	for _, descendant in target:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(results, descendant)
		end
	end
	return results
end

local function find_anchor_basepart(target: Instance): BasePart?
	if target:IsA("BasePart") then
		return target
	end
	if target:IsA("Model") and target.PrimaryPart then
		return target.PrimaryPart
	end
	local parts = get_all_baseparts(target)
	if #parts == 0 then
		return nil
	end
	table.sort(parts, function(a: BasePart, b: BasePart): boolean
		if a.Name == b.Name then
			return a:GetFullName() < b:GetFullName()
		end
		return a.Name < b.Name
	end)
	return parts[1]
end

local function get_anchor_cframe(target: Instance): CFrame?
	local anchor = find_anchor_basepart(target)
	if anchor then
		return anchor.CFrame
	end
	if target:IsA("Model") then
		return target:GetPivot()
	end
	return nil
end

local function get_stable_reference_cframe(target: Instance): CFrame?
	return get_reference_cframe(target)
end

local slot_container_matches_slot
local find_slot_container
local resolve_slot_part

local function position_clone_from_template(
	cloneRoot: Instance,
	templateRoot: Instance,
	templateRef: Instance,
	targetRef: Instance,
	translationOnly: boolean?
): ()
	local templateRefCFrame = get_stable_reference_cframe(templateRef)
	local targetRefCFrame = get_stable_reference_cframe(targetRef)
	if not templateRefCFrame or not targetRefCFrame then
		return
	end

	local templateAnchor = get_anchor_cframe(templateRoot)
	if not templateAnchor then
		return
	end

	local cloneAnchor = get_anchor_cframe(cloneRoot)
	if not cloneAnchor then
		return
	end

	local delta: CFrame
	if translationOnly then
		local localOffset = templateRefCFrame:VectorToObjectSpace(templateAnchor.Position - templateRefCFrame.Position)
		local targetPos = targetRefCFrame.Position + targetRefCFrame:VectorToWorldSpace(localOffset)
		delta = CFrame.new(targetPos - cloneAnchor.Position)
	else
		local localCFrame = templateRefCFrame:ToObjectSpace(templateAnchor)
		local targetCFrame = targetRefCFrame:ToWorldSpace(localCFrame)
		delta = targetCFrame * cloneAnchor:Inverse()
	end

	for _, part in get_all_baseparts(cloneRoot) do
		part.CFrame = delta * part.CFrame
	end
end

local function position_clone_relative_to_slot(
	cloneRoot: Instance,
	templateRoot: Instance,
	templateGroup: Instance,
	targetGroup: Instance,
	slotId: string,
	slotPartName: string,
	requireSlotMatch: boolean?
): boolean
	local templateSlot = find_slot_container(templateGroup, slotId, slotPartName)
	if requireSlotMatch and templateSlot and not slot_container_matches_slot(templateGroup, templateSlot, slotId) then
		templateSlot = nil
	end
	local targetSlot = find_slot_container(targetGroup, slotId, slotPartName)
	if requireSlotMatch and targetSlot and not slot_container_matches_slot(targetGroup, targetSlot, slotId) then
		targetSlot = nil
	end
	if not templateSlot or not targetSlot then
		return false
	end

	local templatePart = resolve_slot_part(templateSlot, slotPartName)
	local targetPart = resolve_slot_part(targetSlot, slotPartName)
	if not templatePart or not targetPart then
		return false
	end

	local templateAnchor = get_anchor_cframe(templateRoot)
	local cloneAnchor = get_anchor_cframe(cloneRoot)
	if not templateAnchor or not cloneAnchor then
		return false
	end

	local localCFrame = templatePart.CFrame:ToObjectSpace(templateAnchor)
	local targetCFrame = targetPart.CFrame:ToWorldSpace(localCFrame)
	local delta = targetCFrame * cloneAnchor:Inverse()

	for _, part in get_all_baseparts(cloneRoot) do
		part.CFrame = delta * part.CFrame
	end
	return true
end

local function is_excluded_from_scan(target: Instance, buyFolder: Instance?): boolean
	if is_anchor_part(target) then
		return true
	end
	if buyFolder and target:IsDescendantOf(buyFolder) then
		return true
	end
	return false
end

find_slot_container = function(groupFolder: Instance, slotId: string, slotPartName: string): Instance?
	local direct = groupFolder:FindFirstChild(slotId)
	if direct then
		return direct
	end

	local normalizedSlot = normalize_name(slotId)
	local normalizedSlotKey = normalize_name("slot" .. slotId)
	local bestCandidate: Instance? = nil
	for _, descendant in groupFolder:GetDescendants() do
		if descendant:IsA("Model") or descendant:IsA("Folder") or descendant:IsA("BasePart") then
			local normalized = normalize_name(descendant.Name)
			local matches = (normalized ~= "" and (normalized == normalizedSlot or normalized == normalizedSlotKey))
			if not matches and normalizedSlot ~= "" then
				if string.find(normalized, normalizedSlot, 1, true) and string.find(normalized, "slot", 1, true) then
					matches = true
				end
			end
			if matches then
				if slotPartName ~= "" and descendant:FindFirstChild(slotPartName, true) then
					return descendant
				end
				if not bestCandidate then
					bestCandidate = descendant
				end
			end
		end
	end
	if bestCandidate then
		return bestCandidate
	end

	local partDirect = groupFolder:FindFirstChild(slotPartName)
	if partDirect then
		return partDirect
	end

	local partDeep = groupFolder:FindFirstChild(slotPartName, true)
	if partDeep then
		return partDeep
	end

	local normalizedPart = normalize_name(slotPartName)
	if normalizedPart ~= "" then
		local match: BasePart? = nil
		for _, descendant in groupFolder:GetDescendants() do
			if descendant:IsA("BasePart") then
				local normalized = normalize_name(descendant.Name)
				if normalized == normalizedPart then
					if match then
						match = nil
						break
					end
					match = descendant
				end
			end
		end
		if match then
			return match
		end
	end

	return nil
end

local function find_named_ancestor(
	target: Instance,
	root: Instance,
	targetSlot: string,
	targetPart: string,
	requireSlotMatch: boolean
): Instance?
	local current: Instance? = target
	while current and current ~= root do
		local normalized = normalize_name(current.Name)
		local slotMatch = targetSlot ~= "" and string.find(normalized, targetSlot, 1, true)
		local partMatch = targetPart ~= "" and string.find(normalized, targetPart, 1, true)
		if requireSlotMatch then
			if slotMatch then
				return current
			end
		elseif slotMatch or partMatch then
			return current
		end
		current = current.Parent
	end
	return nil
end

slot_container_matches_slot = function(groupFolder: Instance, container: Instance, slotId: string): boolean
	local normalizedSlot = normalize_name(slotId)
	if normalizedSlot == "" then
		return false
	end
	local normalizedSlotKey = normalize_name("slot" .. slotId)

	local current: Instance? = container
	while current and current ~= groupFolder do
		local normalized = normalize_name(current.Name)
		if normalized == normalizedSlot or normalized == normalizedSlotKey then
			return true
		end
		if string.find(normalized, normalizedSlot, 1, true) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function collect_slot_containers(
	groupFolder: Instance,
	slotId: string,
	slotPartName: string,
	board: Instance?,
	buyFolder: Instance?,
	requireSlotMatch: boolean
): { Instance }
	local results: { Instance } = {}
	local seen: { [Instance]: boolean } = {}
	local function add(target: Instance?)
		if not target or seen[target] then
			return
		end
		if board and target:IsDescendantOf(board) then
			return
		end
		if is_excluded_from_scan(target, buyFolder) then
			return
		end
		seen[target] = true
		table.insert(results, target)
	end

	local direct = find_slot_container(groupFolder, slotId, slotPartName)
	if requireSlotMatch and direct and not slot_container_matches_slot(groupFolder, direct, slotId) then
		direct = nil
	end
	add(direct)
	if not requireSlotMatch and direct and (direct:IsA("Model") or direct:IsA("Folder")) then
		return results
	end

	local targetSlot = normalize_name("slot" .. slotId)
	local targetPart = normalize_name(slotPartName)
	for _, descendant in groupFolder:GetDescendants() do
		if is_excluded_from_scan(descendant, buyFolder) then
			continue
		end
		if board and descendant:IsDescendantOf(board) then
			continue
		end
		local normalized = normalize_name(descendant.Name)
		local slotMatch = targetSlot ~= "" and string.find(normalized, targetSlot, 1, true)
		local partMatch = targetPart ~= "" and string.find(normalized, targetPart, 1, true)
		if slotMatch or (not requireSlotMatch and partMatch) then
			add(find_named_ancestor(descendant, groupFolder, targetSlot, targetPart, requireSlotMatch))
		end
	end

	return results
end

local function is_slot_part_shared(groupConfig: any, slotPartName: string): boolean
	local count = 0
	for _, slotConfig: any in groupConfig.Slots do
		if slotConfig.SlotPartName == slotPartName then
			count += 1
			if count > 1 then
				return true
			end
		end
	end
	return false
end

local function name_matches_slot(name: string, slotId: string): boolean
	local normalizedSlot = normalize_name(slotId)
	if normalizedSlot == "" then
		return false
	end
	local normalizedName = normalize_name(name)
	if normalizedName == "" then
		return false
	end
	local normalizedSlotKey = normalize_name("slot" .. slotId)
	if normalizedName == normalizedSlot or normalizedName == normalizedSlotKey then
		return true
	end
	if string.find(normalizedName, "upgrade", 1, true) and string.find(normalizedName, normalizedSlot, 1, true) then
		return true
	end
	return false
end

local function upgrade_matches_slot(root: Instance, instance: Instance, slotId: string): boolean
	if name_matches_slot(instance.Name, slotId) then
		return true
	end
	local normalizedSlot = normalize_name(slotId)
	if normalizedSlot == "" then
		return false
	end
	local current: Instance? = instance.Parent
	while current and current ~= root do
		if name_matches_slot(current.Name, slotId) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function resolve_direct_child(root: Instance, target: Instance?): Instance?
	local current: Instance? = target
	while current and current.Parent ~= root do
		current = current.Parent
	end
	if current and current.Parent == root then
		return current
	end
	return nil
end

local function remove_duplicate_direct_slots(groupFolder: Instance, slotId: string, keep: Instance?)
	local normalizedSlot = normalize_name(slotId)
	if normalizedSlot == "" then
		return
	end
	local keepDirect = resolve_direct_child(groupFolder, keep)
	for _, child in groupFolder:GetChildren() do
		if child ~= keepDirect and normalize_name(child.Name) == normalizedSlot then
			child:Destroy()
		end
	end
end

local function remove_extra_upgrade_models(board: Instance, slotId: string)
	local targetModel = normalize_name("Upgrade" .. slotId .. "Model")
	local candidates: { Model } = {}
	for _, descendant in board:GetDescendants() do
		if descendant:IsA("Model") and normalize_name(descendant.Name) == targetModel then
			table.insert(candidates, descendant)
		end
	end
	if #candidates > 1 then
		local keep: Model? = nil
		for _, candidate in candidates do
			if upgrade_matches_slot(board, candidate, slotId) then
				keep = candidate
				break
			end
		end
		keep = keep or candidates[1]
		for _, candidate in candidates do
			if candidate ~= keep then
				candidate:Destroy()
			end
		end
	end

	local targetRoot = normalize_name("Upgrade" .. slotId)
	local rootCandidates: { Instance } = {}
	for _, descendant in board:GetDescendants() do
		if normalize_name(descendant.Name) == targetRoot then
			table.insert(rootCandidates, descendant)
		end
	end
	if #rootCandidates > 1 then
		local keepRoot: Instance? = nil
		for _, candidate in rootCandidates do
			if upgrade_matches_slot(board, candidate, slotId) then
				keepRoot = candidate
				break
			end
		end
		keepRoot = keepRoot or rootCandidates[1]
		for _, candidate in rootCandidates do
			if candidate ~= keepRoot then
				candidate:Destroy()
			end
		end
	end
end

resolve_slot_part = function(slotContainer: Instance, slotPartName: string): BasePart?
	if slotContainer:IsA("BasePart") then
		if slotContainer.Name == slotPartName then
			return slotContainer
		end
		local child = slotContainer:FindFirstChild(slotPartName, true)
		if child and child:IsA("BasePart") then
			return child
		end
		return slotContainer
	end

	local found = slotContainer:FindFirstChild(slotPartName, true)
	if found then
		if found:IsA("BasePart") then
			return found
		end
		return find_first_basepart(found)
	end

	local target = string.lower((slotPartName:gsub("[%s_%-]", "")))
	local bestMatch: BasePart? = nil
	local bestScore: number = math.huge
	for _, descendant in slotContainer:GetDescendants() do
		if descendant:IsA("BasePart") then
			local normalized = string.lower((descendant.Name:gsub("[%s_%-]", "")))
			if normalized == target then
				return descendant
			end
			if target ~= "" and string.find(normalized, target, 1, true) then
				local score = #normalized
				if score < bestScore then
					bestScore = score
					bestMatch = descendant
				end
			end
		end
	end
	if bestMatch then
		return bestMatch
	end

	return find_first_basepart(slotContainer)
end

local function get_slot_locator_data(
	groupFolder: Instance,
	templateGroup: Instance?,
	slotId: string,
	slotPartName: string,
	requireSlotMatch: boolean?
): (CFrame?, Vector3?)
	local slotContainer = find_slot_container(groupFolder, slotId, slotPartName)
	if requireSlotMatch and slotContainer and not slot_container_matches_slot(groupFolder, slotContainer, slotId) then
		slotContainer = nil
	end
	if slotContainer then
		local slotPart = resolve_slot_part(slotContainer, slotPartName)
		if slotPart then
			debug_buy(
				"slot locator from plot: group=%s slot=%s part=%s container=%s",
				groupFolder.Name,
				slotId,
				slotPartName,
				slotContainer.Name
			)
			return slotPart.CFrame, slotPart.Size
		end
	end

	if templateGroup then
		local templateSlotContainer = find_slot_container(templateGroup, slotId, slotPartName)
		if requireSlotMatch and templateSlotContainer and not slot_container_matches_slot(templateGroup, templateSlotContainer, slotId) then
			templateSlotContainer = nil
		end
		if templateSlotContainer then
			local templateSlotPart = resolve_slot_part(templateSlotContainer, slotPartName)
			if templateSlotPart then
				local templatePivot = get_reference_cframe(templateGroup)
				local targetPivot = get_reference_cframe(groupFolder)
				if not templatePivot or not targetPivot then
					return nil, nil
				end
				local localCFrame = templatePivot:ToObjectSpace(templateSlotPart.CFrame)
				local worldCFrame = targetPivot:ToWorldSpace(localCFrame)
				debug_buy(
					"slot locator from template: group=%s slot=%s part=%s container=%s",
					groupFolder.Name,
					slotId,
					slotPartName,
					templateSlotContainer.Name
				)
				return worldCFrame, templateSlotPart.Size
			end
		end
	end

	debug_buy("slot locator missing: group=%s slot=%s part=%s", groupFolder.Name, slotId, slotPartName)
	return nil, nil
end

local function should_use_part_for_placement(part: BasePart): boolean
	local normalized = normalize_name(part.Name)
	if string.find(normalized, "hitbox", 1, true) then
		return false
	end
	if part.Transparency >= 1 and not part.CanCollide and not part.CanQuery and not part.CanTouch then
		return false
	end
	return true
end

local function get_part_min_dot(part: BasePart, slotUp: Vector3): number
	local half = part.Size * 0.5
	local right = part.CFrame.RightVector
	local up = part.CFrame.UpVector
	local look = part.CFrame.LookVector
	local extent = math.abs(slotUp:Dot(right)) * half.X
		+ math.abs(slotUp:Dot(up)) * half.Y
		+ math.abs(slotUp:Dot(look)) * half.Z
	return part.Position:Dot(slotUp) - extent
end

local function get_model_min_dot(model: Model, slotUp: Vector3, usePrimaryPart: boolean?): number?
	if usePrimaryPart and model.PrimaryPart then
		return get_part_min_dot(model.PrimaryPart, slotUp)
	end
	local best: number? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and should_use_part_for_placement(descendant) then
			local minDot = get_part_min_dot(descendant, slotUp)
			if not best or minDot < best then
				best = minDot
			end
		end
	end
	return best
end

local function position_model_on_slot(
	model: Model,
	slotPart: BasePart,
	rotationDegrees: number,
	usePrimaryPart: boolean?
): ()
	if not model.PrimaryPart then
		local primary = find_first_basepart(model)
		if primary then
			model.PrimaryPart = primary
		end
	end

	local slotUp = slotPart.CFrame.UpVector
	local slotTop = slotPart.Position + (slotUp * (slotPart.Size.Y * 0.5))

	do
		local pivot = model:GetPivot()
		local slotRotation = slotPart.CFrame - slotPart.Position
		local targetRotation = slotRotation
		if rotationDegrees ~= 0 then
			local rotation = CFrame.fromAxisAngle(slotUp, math.rad(rotationDegrees))
			targetRotation = rotation * targetRotation
		end
		model:PivotTo(CFrame.new(pivot.Position) * targetRotation)
	end

	local bboxCFrame, bboxSize = model:GetBoundingBox()
	local center = bboxCFrame.Position
	local toSlot = slotPart.Position - center
	local verticalComponent = slotUp * toSlot:Dot(slotUp)
	local horizontalOffset = toSlot - verticalComponent

	local halfSize = bboxSize * 0.5
	local right = bboxCFrame.RightVector
	local up = bboxCFrame.UpVector
	local look = bboxCFrame.LookVector
	local extentAlongUp =
		math.abs(slotUp:Dot(right)) * halfSize.X
		+ math.abs(slotUp:Dot(up)) * halfSize.Y
		+ math.abs(slotUp:Dot(look)) * halfSize.Z

	local minDot = get_model_min_dot(model, slotUp, usePrimaryPart)
	if not minDot then
		minDot = center:Dot(slotUp) - extentAlongUp
	end
	local targetDot = slotTop:Dot(slotUp)
	local verticalOffset = slotUp * (targetDot - minDot)
	local totalOffset = horizontalOffset + verticalOffset

	model:PivotTo(model:GetPivot() + totalOffset)
end

local function get_buy_rotation_offset(groupConfig: any, slotConfig: any): number
	if typeof(slotConfig) == "table" and typeof(slotConfig.BuyRotationOffset) == "number" then
		return slotConfig.BuyRotationOffset
	end
	if typeof(groupConfig) == "table" and typeof(groupConfig.BuyRotationOffset) == "number" then
		return groupConfig.BuyRotationOffset
	end
	return BUY_ROTATION_OFFSET
end

local function position_buy_model(
	model: Model,
	slotLocatorCFrame: CFrame?,
	slotLocatorSize: Vector3?,
	rotationDegrees: number,
	usePrimaryPartForPlacement: boolean,
	groupId: string,
	slotId: string
): boolean
	if not slotLocatorCFrame or not slotLocatorSize then
		debug_buy("buy locator missing for placement: group=%s slot=%s", groupId, slotId)
		return false
	end

	local locator = Instance.new("Part")
	locator.Anchored = true
	locator.CanCollide = false
	locator.Transparency = 1
	locator.Size = slotLocatorSize
	locator.CFrame = slotLocatorCFrame

	position_model_on_slot(model, locator, rotationDegrees, usePrimaryPartForPlacement)
	locator:Destroy()
	return true
end

local function find_upgrade_board(groupFolder: Instance, boardName: string): Instance?
	local candidates = {}
	for _, descendant in groupFolder:GetDescendants() do
		if descendant.Name == boardName then
			table.insert(candidates, descendant)
		end
	end
	if #candidates == 0 then
		return nil
	end
	for _, candidate in candidates do
		for _, child in candidate:GetDescendants() do
			local normalized = normalize_name(child.Name)
			if string.find(normalized, "upgrade", 1, true) then
				return candidate
			end
		end
	end
	return candidates[1]
end

local function find_upgrade_root(board: Instance, slotId: string): Instance?
	local direct = board:FindFirstChild("Upgrade" .. slotId, true)
	if direct and upgrade_matches_slot(board, direct, slotId) then
		return direct
	end
	local directModel = board:FindFirstChild("Upgrade" .. slotId .. "Model", true)
	if directModel and upgrade_matches_slot(board, directModel, slotId) then
		return directModel
	end

	local target = normalize_name("Upgrade" .. slotId)
	local candidates: { Instance } = {}
	for _, descendant in board:GetDescendants() do
		local normalized = normalize_name(descendant.Name)
		if normalized == target then
			table.insert(candidates, descendant)
		end
		if string.find(normalized, "upgrade", 1, true) and string.find(normalized, slotId, 1, true) then
			table.insert(candidates, descendant)
		end
	end

	if #candidates > 0 then
		for _, candidate in candidates do
			if upgrade_matches_slot(board, candidate, slotId) then
				return candidate
			end
		end
		return candidates[1]
	end
	return nil
end

local function find_upgrade_model(board: Instance, slotId: string): Model?
	local targetName = "Upgrade" .. slotId .. "Model"
	local direct = board:FindFirstChild(targetName, true)
	if direct and direct:IsA("Model") and upgrade_matches_slot(board, direct, slotId) then
		return direct
	end
	local targetNormalized = normalize_name(targetName)
	local candidates: { Model } = {}
	for _, descendant in board:GetDescendants() do
		if descendant:IsA("Model") and normalize_name(descendant.Name) == targetNormalized then
			table.insert(candidates, descendant)
		end
	end
	if #candidates > 0 then
		for _, candidate in candidates do
			if upgrade_matches_slot(board, candidate, slotId) then
				return candidate
			end
		end
		return candidates[1]
	end
	return nil
end

local function get_buy_folder(groupFolder: Instance): Folder
	return ensure_folder(groupFolder, BUY_FOLDER_NAME)
end

local function find_buy_model(groupFolder: Instance, groupId: string, slotId: string): Model?
	local buyFolder = groupFolder:FindFirstChild(BUY_FOLDER_NAME)
	if not buyFolder then
		return nil
	end
	local targetName = string.format("Buy_%s_%s", groupId, slotId)
	for _, child in buyFolder:GetChildren() do
		if child:IsA("Model") then
			local g = child:GetAttribute("MachineGroup")
			local s = child:GetAttribute("MachineSlot")
			if g == groupId and s == slotId then
				return child
			end
			if child.Name == targetName then
				return child
			end
		end
	end
	return nil
end

local function find_buy_template(groupId: string, slotId: string, slotConfig: any): Instance?
	local groupFolder: Instance? = BuyRoot:FindFirstChild(groupId)
	if not groupFolder then
		return nil
	end

	local byId = groupFolder:FindFirstChild(slotId)
	if byId then
		return byId
	end

	if typeof(slotConfig.AssetName) == "string" then
		local byAsset = groupFolder:FindFirstChild(slotConfig.AssetName)
		if byAsset then
			return byAsset
		end
	end

	local normalizedAsset = typeof(slotConfig.AssetName) == "string" and normalize_name(slotConfig.AssetName) or ""
	local normalizedSlot = normalize_name(slotId)
	for _, child in groupFolder:GetChildren() do
		local normalized = normalize_name(child.Name)
		if normalizedAsset ~= "" and string.find(normalized, normalizedAsset, 1, true) then
			return child
		end
		if normalizedSlot ~= "" and string.find(normalized, normalizedSlot, 1, true) then
			return child
		end
	end

	return nil
end

local function collect_upgrade_targets(
	board: Instance?,
	groupFolder: Instance,
	slotId: string,
	buyFolder: Instance?
): { Instance }
	local results: { Instance } = {}
	local seen: { [Instance]: boolean } = {}
	local candidates: { Instance } = {}
	local function add(target: Instance?, root: Instance, targetUpgrade: string, targetModel: string)
		if not target then
			return
		end
		local match = find_named_ancestor(target, root, targetUpgrade, targetModel, false)
		if not match then
			return
		end
		if is_excluded_from_scan(match, buyFolder) then
			return
		end
		table.insert(candidates, match)
	end

	local root = board or groupFolder
	local targetUpgrade = normalize_name("Upgrade" .. slotId)
	local targetModel = normalize_name("Upgrade" .. slotId .. "Model")

	for _, descendant in root:GetDescendants() do
		if is_excluded_from_scan(descendant, buyFolder) then
			continue
		end
		local normalized = normalize_name(descendant.Name)
		if normalized == targetUpgrade or normalized == targetModel then
			add(descendant, root, targetUpgrade, targetModel)
		elseif string.find(normalized, "upgrade", 1, true) == 1 and string.find(normalized, slotId, 1, true) then
			add(descendant, root, targetUpgrade, targetModel)
		end
	end

	for _, match in candidates do
		if not seen[match] then
			seen[match] = true
		end
	end

	if #candidates > 0 then
		for _, match in candidates do
			if upgrade_matches_slot(root, match, slotId) then
				table.insert(results, match)
			end
		end
		if #results > 0 then
			return results
		end
	end

	for match, _ in seen do
		table.insert(results, match)
	end

	return results
end

local function find_buy_button(model: Instance): TextButton?
	local candidate = model:FindFirstChild("Buy", true)
	if candidate and candidate:IsA("TextButton") then
		return candidate
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("TextButton") and normalize_name(descendant.Name) == "buy" then
			return descendant
		end
	end
	return nil
end

local function as_text_like(value: Instance?): Instance?
	if value and (value:IsA("TextLabel") or value:IsA("TextButton") or value:IsA("TextBox")) then
		return value
	end
	return nil
end

local function find_buy_price_label(model: Instance): Instance?
	local coins = model:FindFirstChild("Coins", true)
	if coins then
		local amount = coins:FindFirstChild("Amount", true)
		return as_text_like(amount)
	end
	local fallback = model:FindFirstChild("Amount", true)
	local fallbackLabel = as_text_like(fallback)
	if fallbackLabel then
		return fallbackLabel
	end
	local buyNamed = model:FindFirstChild("Buy", true)
	local buyNamedLabel = as_text_like(buyNamed)
	if buyNamedLabel then
		return buyNamedLabel
	end
	for _, descendant in model:GetDescendants() do
		if normalize_name(descendant.Name) == "buy" then
			local label = as_text_like(descendant)
			if label then
				return label
			end
		end
	end
	return as_text_like(find_buy_button(model))
end

local function find_building_sign_title(model: Instance): Instance?
	local sign = model:FindFirstChild("BuildingSign", true)
	if sign then
		local title = sign:FindFirstChild("Title", true)
		return as_text_like(title)
	end
	return nil
end

local function find_building_sign_buy_root(model: Instance): Instance?
	local sign = model:FindFirstChild("BuildingSign", true)
	if sign then
		return sign:FindFirstChild("Buy", true)
	end
	return nil
end

local function set_buyable_gradient(target: Instance?, canBuy: boolean): ()
	if not target then
		return
	end
	local buyable = target:FindFirstChild("Buyable", true)
	if buyable and buyable:IsA("UIGradient") then
		buyable.Enabled = canBuy
	end
	local notBuyable = target:FindFirstChild("NotBuyable", true)
	if notBuyable and notBuyable:IsA("UIGradient") then
		notBuyable.Enabled = not canBuy
	end
end

local function configure_buy_model(
	model: Model,
	player: Player,
	groupId: string,
	slotId: string,
	cost: number,
	requiredRebirth: number,
	displayName: string?,
	minCoinsToShow: number?,
	coins: number?
): ()
	local function apply_buy_attributes(target: Instance): ()
		target:SetAttribute("MachineGroup", groupId)
		target:SetAttribute("MachineSlot", slotId)
		target:SetAttribute("PurchaseCost", cost)
		target:SetAttribute("RequiredRebirth", requiredRebirth)
		target:SetAttribute("PlotOwner", player.UserId)
		target:SetAttribute("DisplayName", displayName or "")
		target:SetAttribute("MinCoinsToShow", minCoinsToShow or 0)
	end

	model:SetAttribute("MachineGroup", groupId)
	model:SetAttribute("MachineSlot", slotId)
	model:SetAttribute("PurchaseCost", cost)
	model:SetAttribute("RequiredRebirth", requiredRebirth)
	model:SetAttribute("PlotOwner", player.UserId)
	model:SetAttribute("DisplayName", displayName or "")
	model:SetAttribute("MinCoinsToShow", minCoinsToShow or 0)

	local button = find_buy_button(model)
	if button then
		apply_buy_attributes(button)
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("GuiButton") then
			local normalized = normalize_name(descendant.Name)
			if normalized == "buy" or normalized == "click" then
				apply_buy_attributes(descendant)
			end
		end
	end

	local titleLabel = find_building_sign_title(model)
	if titleLabel and displayName and displayName ~= "" then
		titleLabel.Text = displayName
	end

	local priceLabel = find_buy_price_label(model)
	if priceLabel then
		priceLabel.Text = Short:Abbreviate(cost, 1000, 2)
	end

	local coinsValue = if typeof(coins) == "number" then coins else (PlayerDataManager:Get(player, { "Currency", "Coins" }) or 0)
	set_buyable_gradient(find_building_sign_buy_root(model), coinsValue >= cost)
end

local function animate_buy_model(model: Model): ()
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(70, 255, 120)
	highlight.OutlineColor = Color3.fromRGB(70, 255, 120)
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 0.2
	highlight.Parent = model

	task.delay(BUY_ANIMATION_DELAY, function()
		if highlight.Parent then
			highlight:Destroy()
		end
	end)
end

local function get_purchase_config(slotConfig: any): (number, number, boolean, string, number)
	local purchase: any = slotConfig.Purchase
	local cost = 0
	local requiredRebirth = 0
	local defaultOwned = false
	local displayName = ""
	local minCoinsToShow = 0
	if typeof(purchase) == "table" then
		if typeof(purchase.Cost) == "number" then
			cost = purchase.Cost
		end
		if typeof(purchase.RequiredRebirth) == "number" then
			requiredRebirth = purchase.RequiredRebirth
		end
		if typeof(purchase.DefaultOwned) == "boolean" then
			defaultOwned = purchase.DefaultOwned
		end
		if typeof(purchase.DisplayName) == "string" then
			displayName = purchase.DisplayName
		end
		if typeof(purchase.MinCoinsToShow) == "number" then
			minCoinsToShow = purchase.MinCoinsToShow
		end
	end
	return cost, requiredRebirth, defaultOwned, displayName, minCoinsToShow
end

local function ensure_machine_ownership(player: Player): { [string]: { [string]: boolean } }
	local stored: any = PlayerDataManager:Get(player, { "Plot", "MachineOwnership" })
	local ownership: { [string]: { [string]: boolean } } = if typeof(stored) == "table" then stored else {}
	local changed = false

	for groupId: string, groupConfig: any in MachinesConstants.Machines do
		local groupTable = ownership[groupId]
		if typeof(groupTable) ~= "table" then
			groupTable = {}
			ownership[groupId] = groupTable
			changed = true
		end
		for slotId: string, slotConfig: any in groupConfig.Slots do
			if groupTable[slotId] == nil then
				local _, _, defaultOwned = get_purchase_config(slotConfig)
				groupTable[slotId] = defaultOwned
				changed = true
			end
		end
	end

	if changed then
		PlayerDataManager:Set(player, { "Plot", "MachineOwnership" }, ownership)
	end

	return ownership
end

local function set_machine_owned(player: Player, groupId: string, slotId: string): ()
	ensure_machine_ownership(player)
	local groupPath = { "Plot", "MachineOwnership", groupId }
	local groupTable: any = PlayerDataManager:Get(player, groupPath)
	if typeof(groupTable) ~= "table" then
		PlayerDataManager:Set(player, groupPath, {})
	end
	PlayerDataManager:Set(player, { "Plot", "MachineOwnership", groupId, slotId }, true)
end

local function wrap_as_model(instance: Instance): Model
	if instance:IsA('Model') then
		return instance
	end

	local wrapper = Instance.new('Model')
	wrapper.Name = instance.Name
	instance.Parent = wrapper
	return wrapper
end

local function place_machine_group(plot: Model, groupName: string, offset: Vector3, yawOffset: number)
	local template = MachinesRoot:FindFirstChild(groupName)
	if not template then
		warn(`[PlotService]: Machine group "{groupName}" not found in Assets.`)
		return
	end

	local existing = plot:FindFirstChild(groupName)
	if existing then
		existing:Destroy()
	end

	local clone = template:Clone()
	clone.Name = groupName
	local model = wrap_as_model(clone)
	model.Parent = plot

	local plotPos = plot:GetPivot().Position
	local yaw = math.rad(get_plot_rotation(plot) + yawOffset)
	local basePivot = model:GetPivot()
	local baseOrientation = basePivot - basePivot.Position
	local targetCFrame =
		CFrame.new(plotPos) * CFrame.Angles(0, yaw, 0) * CFrame.new(offset) * baseOrientation

	model:PivotTo(targetCFrame)
	ensure_group_anchor(model)
end

local function apply_machine_ownership(plot: Model, player: Player)
	local ownership = ensure_machine_ownership(player)
	local rebirthCount = tonumber(PlayerDataManager:Get(player, { "Currency", "RebirthCount" })) or 0
	debug_buy("apply ownership plot=%s player=%s rebirth=%d", plot.Name, player.Name, rebirthCount)

	local legacyStorage = plot:FindFirstChild("_MachineStorage")
	if legacyStorage then
		legacyStorage:Destroy()
	end

	for groupId: string, groupConfig: any in MachinesConstants.Machines do
		local groupFolder: Instance? = plot:FindFirstChild(groupConfig.PlotFolder)
		if not groupFolder then
			continue
		end

		local buyFolder = get_buy_folder(groupFolder)
		local templateGroup = MachinesRoot:FindFirstChild(groupConfig.PlotFolder)

		local anyOwned = false
		for slotId: string, _ in groupConfig.Slots do
			if ownership[groupId] and ownership[groupId][slotId] == true then
				anyOwned = true
				break
			end
		end

		local board = find_upgrade_board(groupFolder, groupConfig.BoardName)
		if anyOwned then
			if not board then
				if templateGroup then
					local templateBoard = find_upgrade_board(templateGroup, groupConfig.BoardName)
					if templateBoard then
						local clone = templateBoard:Clone()
						clone.Parent = groupFolder
						position_clone_from_template(clone, templateBoard, templateGroup, groupFolder)
						board = clone
					end
				end
			end
		end

		for slotId: string, slotConfig: any in groupConfig.Slots do
			local cost, requiredRebirth, _, displayName, minCoinsToShow = get_purchase_config(slotConfig)
			if displayName == "" then
				displayName = slotConfig.AssetName or string.format("%s %s", groupId, slotId)
			end
			local owned = ownership[groupId] and ownership[groupId][slotId] == true
			debug_buy(
				"group=%s slot=%s owned=%s requiredRebirth=%d cost=%d",
				groupId,
				slotId,
				tostring(owned),
				requiredRebirth,
				cost
			)

			if owned then
				local requireSlotMatch = is_slot_part_shared(groupConfig, slotConfig.SlotPartName)
				local slotContainer = find_slot_container(groupFolder, slotId, slotConfig.SlotPartName)
				if requireSlotMatch and slotContainer and not slot_container_matches_slot(groupFolder, slotContainer, slotId) then
					slotContainer = nil
				end
				local slotPart = if slotContainer then resolve_slot_part(slotContainer, slotConfig.SlotPartName) else nil

				if not slotContainer or not slotPart then
					if templateGroup then
						local templateSlot = find_slot_container(templateGroup, slotId, slotConfig.SlotPartName)
						if requireSlotMatch and templateSlot and not slot_container_matches_slot(templateGroup, templateSlot, slotId) then
							templateSlot = nil
						end
						if templateSlot then
							local clone = templateSlot:Clone()
							clone.Parent = groupFolder
							position_clone_from_template(clone, templateSlot, templateGroup, groupFolder)
							slotContainer = clone
						end
					end
				end

				if slotContainer and requireSlotMatch then
					for _, container in collect_slot_containers(
						groupFolder,
						slotId,
						slotConfig.SlotPartName,
						board,
						buyFolder,
						requireSlotMatch
					) do
						if container ~= slotContainer then
							container:Destroy()
						end
					end
				end

				if board and templateGroup then
					local templateBoard = find_upgrade_board(templateGroup, groupConfig.BoardName)
					if templateBoard then
						local templateUpgrade = find_upgrade_model(templateBoard, slotId) or find_upgrade_root(templateBoard, slotId)
						if templateUpgrade then
							local existingUpgrade = find_upgrade_model(board, slotId) or find_upgrade_root(board, slotId)
							local function positionUpgrade(targetUpgrade: Instance)
								local positioned = position_clone_relative_to_slot(
									targetUpgrade,
									templateUpgrade,
									templateGroup,
									groupFolder,
									slotId,
									slotConfig.SlotPartName,
									requireSlotMatch
								)
								if not positioned then
									position_clone_from_template(targetUpgrade, templateUpgrade, templateGroup, groupFolder, false)
								end
							end

							if existingUpgrade then
								positionUpgrade(existingUpgrade)
							else
								local clone = templateUpgrade:Clone()
								clone.Parent = board
								positionUpgrade(clone)
							end
						end
					end
				end

				local existingBuy = find_buy_model(groupFolder, groupId, slotId)
				if existingBuy then
					existingBuy:Destroy()
				end
			else
				local requireSlotMatch = is_slot_part_shared(groupConfig, slotConfig.SlotPartName)
				local slotLocatorCFrame, slotLocatorSize = get_slot_locator_data(
					groupFolder,
					templateGroup,
					slotId,
					slotConfig.SlotPartName,
					requireSlotMatch
				)
				if slotLocatorCFrame then
					debug_buy(
						"slot locator cframe: group=%s slot=%s pos=%s size=%s",
						groupId,
						slotId,
						tostring(slotLocatorCFrame.Position),
						tostring(slotLocatorSize)
					)
				end
				local rotation = get_slot_rotation(plot, slotConfig)
				local buyOffset = get_buy_rotation_offset(groupConfig, slotConfig)
				debug_buy(
					"collect containers: group=%s slot=%s part=%s requireSlotMatch=%s",
					groupId,
					slotId,
					slotConfig.SlotPartName,
					tostring(requireSlotMatch)
				)
				local slotContainersToDestroy = collect_slot_containers(
					groupFolder,
					slotId,
					slotConfig.SlotPartName,
					board,
					buyFolder,
					requireSlotMatch
				)
				for _, container in slotContainersToDestroy do
					debug_buy("queue slot container destroy: %s", container.Name)
				end

				if board then
					local upgradeTarget = find_upgrade_model(board, slotId) or find_upgrade_root(board, slotId)
					if upgradeTarget then
						upgradeTarget:Destroy()
					else
						for _, target in collect_upgrade_targets(board, groupFolder, slotId, buyFolder) do
							target:Destroy()
						end
					end
				else
					for _, target in collect_upgrade_targets(nil, groupFolder, slotId, buyFolder) do
						target:Destroy()
					end
				end

				if rebirthCount >= requiredRebirth then
					debug_buy("rebirth ok for buy: group=%s slot=%s", groupId, slotId)
					local existingBuy: Model? = find_buy_model(groupFolder, groupId, slotId)
					local buyTemplate: Instance? = find_buy_template(groupId, slotId, slotConfig)
					if not existingBuy then
						if buyTemplate then
							debug_buy("buy template found: %s", buyTemplate.Name)
							local cloneInstance: Instance = buyTemplate:Clone()
							local clone: Model = if cloneInstance:IsA("Model") then cloneInstance else wrap_as_model(cloneInstance)
							clone.Name = string.format("Buy_%s_%s", groupId, slotId)
							clone.Parent = buyFolder
							existingBuy = clone
						else
							debug_buy("buy template NOT found: group=%s slot=%s", groupId, slotId)
						end
					end

					if existingBuy then
						configure_buy_model(existingBuy, player, groupId, slotId, cost, requiredRebirth, displayName, minCoinsToShow, nil)
						local positioned = false
						if templateGroup and buyTemplate then
							positioned = position_clone_relative_to_slot(
								existingBuy,
								buyTemplate,
								templateGroup,
								groupFolder,
								slotId,
								slotConfig.SlotPartName,
								requireSlotMatch
							)
							if positioned then
								debug_buy("position buy via template slot: group=%s slot=%s", groupId, slotId)
							else
								local hasTemplateRef = get_stable_reference_cframe(templateGroup) ~= nil
								local hasTargetRef = get_stable_reference_cframe(groupFolder) ~= nil
								local hasTemplateAnchor = get_anchor_cframe(buyTemplate) ~= nil
								local hasCloneAnchor = get_anchor_cframe(existingBuy) ~= nil
								if hasTemplateRef and hasTargetRef and hasTemplateAnchor and hasCloneAnchor then
									position_clone_from_template(existingBuy, buyTemplate, templateGroup, groupFolder, false)
									positioned = true
									debug_buy("position buy via template group: group=%s slot=%s", groupId, slotId)
								end
							end
						end
						if not positioned then
							debug_buy("position buy via slot locator: group=%s slot=%s", groupId, slotId)
							position_buy_model(
								existingBuy,
								slotLocatorCFrame,
								slotLocatorSize,
								rotation + buyOffset,
								slotConfig.UsePrimaryPartForPlacement == true,
								groupId,
								slotId
							)
						end
					end
				else
					debug_buy(
						"rebirth too low for buy: group=%s slot=%s need=%d have=%d",
						groupId,
						slotId,
						requiredRebirth,
						rebirthCount
					)
					local existingBuy = find_buy_model(groupFolder, groupId, slotId)
					if existingBuy then
						existingBuy:Destroy()
					end
				end

				for _, container in slotContainersToDestroy do
					if container.Parent then
						debug_buy("destroy slot container: %s", container.Name)
						container:Destroy()
					end
				end
			end
			local existingBuy = find_buy_model(groupFolder, groupId, slotId)
			if existingBuy then
				configure_buy_model(existingBuy, player, groupId, slotId, cost, requiredRebirth, displayName, minCoinsToShow, nil)
			end
		end

		if not anyOwned and board then
			board:Destroy()
		end
	end
end

local function setup_plot_machines(plot: Model, player: Player)
	for groupId: string, groupConfig: any in MachinesConstants.Machines do
		local groupName = if typeof(groupConfig) == "table" and typeof(groupConfig.PlotFolder) == "string" then groupConfig.PlotFolder else groupId
		local offset, yawOffset = get_group_placement(groupConfig)
		place_machine_group(plot, groupName, offset, yawOffset)
	end
	apply_machine_ownership(plot, player)
end

local function clear_mapsize_clones(plot: Model)
	for _, child in plot:GetChildren() do
		if child:GetAttribute(MAPSIZE_CLONE_ATTRIBUTE) == true then
			child:Destroy()
		end
	end
end

local function get_mapsize_templates(): { [number]: Instance }
	local results: { [number]: Instance } = {}

	for _, child in MapSizeRoot:GetChildren() do
		local digits = string.match(child.Name, '%d+')
		if digits then
			local index = tonumber(digits)
			if index and index > 0 then
				local template: Instance? = nil
				if child:IsA('Model') then
					template = child
				else
					local modelChild: Instance? = child:FindFirstChildWhichIsA('Model')
					template = modelChild or child
				end
				if template then
					results[index] = template
				end
			end
		end
	end

	return results
end

local function remove_placa(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant.Name == 'Placa' then
			descendant:Destroy()
		end
	end
end

local function place_mapsize(plot: Model, template: Instance, offset: Vector3, keepPlaca: boolean)
	local cloneInstance: Instance = template:Clone()
	local cloneModel: Model = if cloneInstance:IsA('Model') then cloneInstance else wrap_as_model(cloneInstance)
	cloneModel.Name = template.Name
	cloneModel:SetAttribute(MAPSIZE_CLONE_ATTRIBUTE, true)
	cloneModel.Parent = plot

	if not keepPlaca then
		remove_placa(cloneModel)
	end

	local plotCFrame: CFrame = plot:GetPivot()
	-- Place relative to the plot orientation (offset is local to the plot).
	local desiredAnchor: CFrame = plotCFrame * CFrame.new(offset)
	cloneModel:PivotTo(desiredAnchor)
end

local function setup_plot_mapsize(plot: Model, player: Player)
	clear_mapsize_clones(plot)

	local templates = get_mapsize_templates()
	local maxIndex = 0
	for index, _ in pairs(templates) do
		if index > maxIndex then
			maxIndex = index
		end
	end
	if maxIndex == 0 then
		warn('[PlotService]: MapSize vazio ou invalido.')
		return
	end

	local rebirthCount = tonumber(PlayerDataManager:Get(player, { 'Currency', 'RebirthCount' })) or 0
	local desiredCount = rebirthCount
	if desiredCount < 1 then
		desiredCount = 1
	end
	if desiredCount > maxIndex then
		desiredCount = maxIndex
	end
	for index = 1, desiredCount do
		local template = templates[index]
		if template then
			local keepPlaca = index == desiredCount
			local offset = MAPSIZE_OFFSETS[index] or MAPSIZE_OFFSETS[1] or Vector3.new()
			place_mapsize(plot, template, offset, keepPlaca)
		end
	end
end

-- // Machine Ownership
function module:ApplyMachineOwnership(plot: Model, player: Player)
	apply_machine_ownership(plot, player)
end

function module:IsMachineOwned(player: Player, groupId: string, slotId: string): boolean
	local ownership = ensure_machine_ownership(player)
	return ownership[groupId] ~= nil and ownership[groupId][slotId] == true
end

function module:HandleMachinePurchase(player: Player, plot: Model, groupId: string, slotId: string): boolean
	debug_buy("purchase request: player=%s plot=%s group=%s slot=%s", player.Name, plot and plot.Name or "nil", groupId, slotId)
	if not plot or plot:GetAttribute('Owner') ~= player.UserId then
		debug_buy("purchase denied: not owner or invalid plot")
		return false
	end

	local groupConfig: any = MachinesConstants.Machines[groupId]
	if not groupConfig then
		debug_buy("purchase denied: group config missing")
		return false
	end
	local slotConfig: any = groupConfig.Slots and groupConfig.Slots[slotId]
	if not slotConfig then
		debug_buy("purchase denied: slot config missing")
		return false
	end

	local ownership = ensure_machine_ownership(player)
	if ownership[groupId] and ownership[groupId][slotId] == true then
		debug_buy("purchase denied: already owned")
		return false
	end

	local cost, requiredRebirth = get_purchase_config(slotConfig)
	local rebirthCount = tonumber(PlayerDataManager:Get(player, { 'Currency', 'RebirthCount' })) or 0
	if rebirthCount < requiredRebirth then
		debug_buy("purchase denied: rebirth low need=%d have=%d", requiredRebirth, rebirthCount)
		return false
	end

	if cost > 0 then
		local coins = PlayerDataManager:Get(player, { 'Currency', 'Coins' }) or 0
		if coins < cost then
			debug_buy("purchase denied: coins low need=%d have=%d", cost, coins)
			return false
		end
		PlayerDataManager:Set(player, { 'Currency', 'Coins' }, coins - cost)
	end

	set_machine_owned(player, groupId, slotId)
	debug_buy("purchase approved: player=%s group=%s slot=%s", player.Name, groupId, slotId)

	local groupFolder: Instance? = plot:FindFirstChild(groupConfig.PlotFolder)
	if groupFolder then
		local buyModel = find_buy_model(groupFolder, groupId, slotId)
		if buyModel then
			animate_buy_model(buyModel)
		end
	end

	task.delay(BUY_ANIMATION_DELAY, function(): ()
		if not plot.Parent then
			return
		end
		apply_machine_ownership(plot, player)
		Packets.Machines:FireClient(player, "MachinePurchased", {
			GroupId = groupId,
			SlotId = slotId,
			PlotName = plot.Name,
		})
	end)

	return true
end

-- // Private Functions
local function create_plot_visuals(plot: Model, player: Player)
	local signPart = plot:FindFirstChild('Sign')
	if not signPart then
		local signCFrame

		local pinataFolder = plot:FindFirstChild('Pinata')
		if pinataFolder then
			local handleModel = pinataFolder:FindFirstChild('Handle')
			if handleModel and handleModel:IsA('Model') then
				local handle = handleModel.PrimaryPart or handleModel:FindFirstChild('Handle')
				if handle then signCFrame = handle.CFrame end
			end
		end

		if not signCFrame then signCFrame = plot:GetPivot() end

		local newSign = Instance.new('Part')
		newSign.Name = 'Sign'
		newSign.Size = Vector3.one
		newSign.Anchored = true
		newSign.Transparency = 1
		newSign.CanCollide = false
		newSign.Position = signCFrame.Position + Vector3.new(0, 5, 0)
		newSign.Parent = plot

		signPart = newSign
	end

	local existingGui = signPart:FindFirstChild('OwnerInfo')
	if existingGui then existingGui:Destroy() end

	local billboard = Instance.new('BillboardGui')
	billboard.Name = 'OwnerInfo'
	billboard.Size = UDim2.fromScale(50, 30)

	billboard.StudsOffset = Vector3.new(0, 12, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = signPart

	local frame = Instance.new('Frame')
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = billboard

	-- Imagem
	local image = Instance.new('ImageLabel')
	image.AnchorPoint = Vector2.new(0.5, 0)
	image.Size = UDim2.fromScale(0.8, 0.75)
	image.Position = UDim2.fromScale(0.5, 0)
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Fit
	image.Image = Players:GetUserThumbnailAsync(
		player.UserId,
		Enum.ThumbnailType.HeadShot,
		Enum.ThumbnailSize.Size420x420
	)
	image.Parent = frame

	-- Texto
	local text = Instance.new('TextLabel')
	text.AnchorPoint = Vector2.new(0.5, 1)
	text.Size = UDim2.fromScale(1, 0.25)
	text.Position = UDim2.fromScale(0.5, 1)
	text.BackgroundTransparency = 1
	text.Text = player.DisplayName
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextScaled = true

	text.FontFace = Font.new(
		'rbxassetid://11702779409', -- Poppins
		Enum.FontWeight.Bold,
		Enum.FontStyle.Normal
	)

	text.Parent = frame

	local uiStroke = Instance.new('UIStroke')
	uiStroke.Thickness = 4
	uiStroke.Color = Color3.fromRGB(39, 21, 7)
	uiStroke.Parent = text
end

local function clear_plot_visuals(plot: Model)
	local signPart = plot:FindFirstChild('Sign') or plot.PrimaryPart
	if signPart and signPart:FindFirstChild('OwnerInfo') then
		signPart.OwnerInfo:Destroy()
	end
end

local function find_slot()
	local plots: { Model } = {}
	for _, plotInstance in workspace.Map.Plots:GetChildren() do
		if plotInstance:IsA("Model") then
			table.insert(plots, plotInstance)
		end
	end

	table.sort(plots, function(a: Model, b: Model): boolean
		local aDigits = tonumber(string.match(a.Name, '%d+') or "")
		local bDigits = tonumber(string.match(b.Name, '%d+') or "")
		if aDigits and bDigits and aDigits ~= bDigits then
			return aDigits < bDigits
		end
		if aDigits and not bDigits then
			return true
		end
		if bDigits and not aDigits then
			return false
		end
		return a.Name < b.Name
	end)

	for order: number, plot in ipairs(plots) do
		local resolvedIndex = order
		local indexFromName = string.match(plot.Name, '%d+')
		if indexFromName then
			local parsed = tonumber(indexFromName)
			if parsed and parsed >= 1 then
				resolvedIndex = math.floor(parsed + 0.5)
			end
		end
		plot:SetAttribute(PLOT_INDEX_ATTRIBUTE, resolvedIndex)
		plot:SetAttribute(PLOT_ROTATION_OFFSET_ATTRIBUTE, get_plot_rotation_offset(plot))
		if
			not plot:GetAttribute('Owner')
			or not Players:GetPlayerByUserId(plot:GetAttribute('Owner'))
		then
			plot:SetAttribute('Owner', nil)
			return plot
		end
	end
	return nil
end

-- // Public Functions
function module:Init()
	MetaPlayer.Signals.PlayerAdded:Connect(function(metaPlayer)
		local player = metaPlayer.Instance
		local plot = find_slot()

		if plot then
			plot:SetAttribute('Owner', player.UserId)
			metaPlayer.Cache.Plot = plot

			setup_plot_machines(plot, player)
			setup_plot_mapsize(plot, player)
			create_plot_visuals(plot, player)

			player.CharacterAdded:Connect(function(character)
				local spawnPart = plot.PrimaryPart
				if spawnPart then
					task.defer(function()
						character:PivotTo(
							spawnPart.CFrame + Vector3.new(0, 3, 0)
						)
					end)
				end
			end)

			if player.Character then
				player.Character:PivotTo(
					plot.PrimaryPart.CFrame + Vector3.new(0, 3, 0)
				)
			end

			print(`[PlotService]: {player.Name} assigned to {plot.Name}`)
			module.Signals.AssignPlot:Fire(metaPlayer)

			local rebirthSignal = PlayerDataManager:GetValueChangedSignal(player, { 'Currency', 'RebirthCount' })
			_RebirthWatchers[player] = rebirthSignal:Connect(function()
				local cachedPlot = metaPlayer.Cache.Plot
				if cachedPlot and cachedPlot.Parent and cachedPlot:GetAttribute('Owner') == player.UserId then
					setup_plot_mapsize(cachedPlot, player)
					apply_machine_ownership(cachedPlot, player)
				end
			end)
		else
			player:Kick('No plots available.')
		end
	end)

	MetaPlayer.Signals.PlayerRemoving:Connect(function(metaPlayer)
		local plot = metaPlayer.Cache.Plot
		local player = metaPlayer.Instance
		local connection = _RebirthWatchers[player]
		if connection then
			connection:Disconnect()
			_RebirthWatchers[player] = nil
		end
		if plot then
			plot:SetAttribute('Owner', nil)
			clear_plot_visuals(plot)
			module.Signals.RemovePlot:Fire(metaPlayer)
		end
	end)
end

return module
