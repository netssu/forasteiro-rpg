local module = {}

-- // Services
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')

-- // Dependencies
local MetaPlayer = require(ServerScriptService.Modules.Core.MetaPlayer)
local Signal = require(ReplicatedStorage.Packages.Signal)

-- // Variables
module.Signals = {
	AssignPlot = Signal.new(),
	RemovePlot = Signal.new(),
}

-- // Private Functions
local function create_plot_visuals(plot: Model, player: Player)
	local signPart = plot:FindFirstChild("Sign") or plot.PrimaryPart
	if not signPart then return end
	
	local existingGui = signPart:FindFirstChild("OwnerInfo")
	if existingGui then existingGui:Destroy() end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "OwnerInfo"
	billboard.Size = UDim2.fromScale(10, 6) 

	billboard.StudsOffset = Vector3.new(0, 12, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 150
	billboard.Parent = signPart
	
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = billboard
	
	-- Imagem
	local image = Instance.new("ImageLabel")
	image.AnchorPoint = Vector2.new(0.5, 0)
	image.Size = UDim2.fromScale(0.8, 0.75)
	image.Position = UDim2.fromScale(0.5, 0)
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Fit
	image.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	image.Parent = frame
	
	-- Texto
	local text = Instance.new("TextLabel")
	text.AnchorPoint = Vector2.new(0.5, 1)
	text.Size = UDim2.fromScale(1, 0.25)
	text.Position = UDim2.fromScale(0.5, 1)
	text.BackgroundTransparency = 1
	text.Text = player.DisplayName
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextScaled = true
	
	text.FontFace = Font.new(
		"rbxassetid://11702779409", -- Poppins
		Enum.FontWeight.Bold, 
		Enum.FontStyle.Normal
	)
	
	text.Parent = frame

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = 4
	uiStroke.Color = Color3.fromRGB(39, 21, 7)
	uiStroke.Parent = text
end

local function clear_plot_visuals(plot: Model)
	local signPart = plot:FindFirstChild("Sign") or plot.PrimaryPart
	if signPart and signPart:FindFirstChild("OwnerInfo") then
		signPart.OwnerInfo:Destroy()
	end
end

local function find_slot()
	for _, plot in workspace.Map.Plots:GetChildren() do
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
		else
			player:Kick('No plots available.')
		end
	end)

	MetaPlayer.Signals.PlayerRemoving:Connect(function(metaPlayer)
		local plot = metaPlayer.Cache.Plot
		if plot then
			plot:SetAttribute('Owner', nil)
			clear_plot_visuals(plot)
			module.Signals.RemovePlot:Fire(metaPlayer)
		end
	end)
end

return module