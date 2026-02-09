local module = {}

-- // Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- // Dependencies
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local MetaPlayerType = require(ReplicatedStorage.Modules.Constants.MetaPlayer)
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local PinataData = require(ReplicatedStorage.Modules.Constants.PinataData)
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local PlotmeService = require(script.Parent.PlotmeService)

-- // Public Functions
function module:Init()
	PlotmeService.Signals.AssignPlot:Connect(
		function(MetaPlayer: MetaPlayerType.MetaPlayer)
			module.CreatePinata(MetaPlayer)
		end
	)
end

function module.CreatePinata(MetaPlayer: MetaPlayerType.MetaPlayer)
	local player = MetaPlayer.Instance
	local plot = MetaPlayer.Cache['Plot']
	local pinataFolder = plot:FindFirstChild('Pinata')

	local currentPinata = PlayerDataManager:Get(player, { 'Pinata', 'Current' })
	local pinataData = PinataData[currentPinata]
	local janitor = Janitor.new()

	local pinata: Model =
		ReplicatedStorage.Assets.Pinatas:FindFirstChild(currentPinata):Clone()
	pinata.Name = 'Pinata'
	pinata.Parent = pinataFolder
	pinata:PivotTo(pinataFolder:FindFirstChild('Handle').End.CFrame)

	pinata:SetAttribute('Pinata', currentPinata)
	pinata:SetAttribute('Health', pinataData.Health)
	pinata:SetAttribute('IsDead', false)
	pinata:SetAttribute('Type', 'Pinata')

	local RopeConstraint: RopeConstraint = pinataFolder.Handle.RopeConstraint
	RopeConstraint.Length = pinataData.RopeLength

	local weldConstraint = Instance.new('WeldConstraint')
	weldConstraint.Parent = pinata
	weldConstraint.Part0 = pinata:FindFirstChild('Handle')
	weldConstraint.Part1 = pinataFolder.Handle.End

	janitor:Add(pinata:GetAttributeChangedSignal('Health'):Connect(function()
		local Health = pinata:GetAttribute('Health') :: number

		if Health <= 0 and not pinata:GetAttribute('IsDead') then
			pinata:SetAttribute('IsDead', true)

			Packets.Replicator:Fire('pinata_destroy', { Pinata = pinata })

			task.delay(2.5, function()
				pinata:SetAttribute('Health', pinataData.Health)
				pinata:SetAttribute('IsDead', true)
			end)
		end
	end))
end

return module
