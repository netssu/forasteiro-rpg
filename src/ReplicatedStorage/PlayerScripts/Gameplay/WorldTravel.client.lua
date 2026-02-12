------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

------------------//MODULES
local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility)
local WorldConfig = require(ReplicatedStorage.Modules.Datas.WorldConfig)
local NotificationUtility = require(ReplicatedStorage.Modules.Utility.NotificationUtility)

------------------//VARIABLES
local player = Players.LocalPlayer
local travelEvent = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("TravelAction")
local portalsFolder = Workspace:WaitForChild("Portals")

local currentWorldId = 1
local currentPower = 0
local currentRebirths = 0
local lastTouch = 0

local portalLabels = {}

------------------//FUNCTIONS
local function update_portal_visuals()
	for destId, info in pairs(portalLabels) do
		local label = info.label
		local data = info.data

		local isTargetNext = destId == currentWorldId + 1
		local isCurrentPos = destId == currentWorldId

		local textBase = string.format("%s\n⚡ %d  |  ♻️ %d", string.upper(data.name), data.requiredPogoPower, data.requiredRebirths)

		if isTargetNext then
			local powerOk = currentPower >= data.requiredPogoPower
			local rebirthsOk = currentRebirths >= data.requiredRebirths

			if powerOk and rebirthsOk then
				label.TextColor3 = Color3.fromRGB(0, 255, 100)
				label.Text = textBase .. "\n[ TOUCH TO TRAVEL ]"
			else
				label.TextColor3 = Color3.fromRGB(255, 80, 80)
				label.Text = textBase .. "\n[ LOCKED ]"
			end

		elseif isCurrentPos and destId > 1 then
			label.TextColor3 = Color3.fromRGB(255, 200, 50)
			label.Text = string.upper(data.name) .. "\n[ TOUCH TO RETURN ]"

		elseif destId < currentWorldId then
			label.TextColor3 = Color3.fromRGB(150, 150, 150)
			label.Text = string.upper(data.name) .. "\n[ UNLOCKED ]"

		else
			label.TextColor3 = Color3.fromRGB(100, 100, 100)
			label.Text = "???"
		end
	end
end

local function create_billboard(part, worldData)
	if part:FindFirstChild("InfoGui") then part.InfoGui:Destroy() end

	local bb = Instance.new("BillboardGui")
	bb.Name = "InfoGui"
	bb.Size = UDim2.new(12, 0, 5, 0)
	bb.StudsOffset = Vector3.new(0, 6, 0)
	bb.AlwaysOnTop = true
	bb.Parent = part

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextScaled = true
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextStrokeTransparency = 0
	lbl.TextStrokeColor3 = Color3.new(0,0,0)
	lbl.Parent = bb

	portalLabels[worldData.id] = {label = lbl, data = worldData}
end

local function setup_portals()
	for _, part in portalsFolder:GetChildren() do
		local destId = tonumber(part.Name)

		if destId then
			local worldData = WorldConfig.GetWorld(destId)
			if worldData then
				create_billboard(part, worldData)

				part.Touched:Connect(function(hit)
					if os.clock() - lastTouch < 1 then return end

					if hit.Parent == player.Character then

						if destId == currentWorldId then
							lastTouch = os.clock()
							part.Transparency = 0.2
							task.delay(0.2, function() part.Transparency = 0.8 end)
							travelEvent:FireServer(destId - 1)

						elseif destId == currentWorldId + 1 then
							local powerOk = currentPower >= worldData.requiredPogoPower
							local rebirthsOk = currentRebirths >= worldData.requiredRebirths

							if powerOk and rebirthsOk then
								lastTouch = os.clock()
								part.Transparency = 0.2
								task.delay(0.2, function() part.Transparency = 0.8 end)
								travelEvent:FireServer(destId)
							end

						elseif destId < currentWorldId then
							lastTouch = os.clock()
							travelEvent:FireServer(destId)
						end
					end
				end)
			end
		end
	end
end

------------------//BINDS
DataUtility.client.ensure_remotes()

DataUtility.client.bind("CurrentWorld", function(val)
	currentWorldId = val
	update_portal_visuals()

	local worldData = WorldConfig.GetWorld(val)
	if worldData then
		local msg = string.format("%s - Gravity: %sx", string.upper(worldData.name), tostring(worldData.gravityMult))
		NotificationUtility:Success(msg, 5)
	end
end)

DataUtility.client.bind("PogoSettings.base_jump_power", function(val)
	currentPower = val
	update_portal_visuals()
end)

DataUtility.client.bind("Rebirths", function(val)
	currentRebirths = val
	update_portal_visuals()
end)

currentWorldId = DataUtility.client.get("CurrentWorld") or 1
currentPower = DataUtility.client.get("PogoSettings.base_jump_power") or 0
currentRebirths = DataUtility.client.get("Rebirths") or 0

setup_portals()
update_portal_visuals()