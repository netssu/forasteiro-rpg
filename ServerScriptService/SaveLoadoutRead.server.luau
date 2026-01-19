local Players = game:GetService("Players")
local DataService = require(script.Parent.Init.DataService)
local function createLoadoutFolder(player, loadout)
	
	
	
	local folder = Instance.new("Folder")
	folder.Name = "Loadout"
	folder.Parent = player

	local function make(name, value)
		local v = Instance.new("StringValue")
		v.Name = name
		v.Value = value or ""
		v.Parent = folder
		return v
	end

	local primary = make("Primary", loadout.Primary)
	local secondary = make("Secondary", loadout.Secondary)
	local melee = make("Melee", loadout.Melee)

	local function sync(v)
		v.Changed:Connect(function(val)
			local data = DataService:GetData(player)
			if data then
				data.Loadout[v.Name] = val
			end
		end)
	end

	sync(primary)
	sync(secondary)
	sync(melee)
end

Players.PlayerAdded:Connect(function(player)
	while not DataService:IsDataLoaded(player) do
		task.wait()
	end

	local data = DataService:GetData(player)
	data.Loadout = data.Loadout or { Primary = "", Secondary = "", Melee = "" }

	if player:FindFirstChild("Loadout") then
		player.Loadout:Destroy()
	end

	createLoadoutFolder(player, data.Loadout)
end)
