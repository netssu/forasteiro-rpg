local module = {}

-- // Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local UserInputService = game:GetService('UserInputService')

-- // Dependencies
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Packets = require(ReplicatedStorage.Modules.Game.Packets)

-- // Variables
local Janitors = {}

-- // Public Functions
function module:Equip(tool: Tool, character: Model)
	if not character then return end

	local rightHand = character:FindFirstChild('RightHand')
	if not rightHand or not rightHand:IsA('BasePart') then return end

	local Settings = tool:FindFirstChild('Settings')
	if not Settings then return end

	local Type = Settings:GetAttribute('Type')
	if not Type then return end

	if Type ~= 'Weapon' then return end

	if Janitors[character] then Janitors[character]:Cleanup() end

	Janitors[character] = Janitor.new()
	local toolModel = ReplicatedStorage.Assets.Tools:FindFirstChild(tool.Name)

	if not toolModel then return end

	Janitors[character]:Add(
		character.AncestryChanged:Connect(function(_, a1: Instance?)
			if a1 and not a1.Parent then
				Janitors[character]:Destroy()
				Janitors[character] = nil
			end
		end),
		'Disconnect'
	)

	Janitors[character]:Add(
		UserInputService.InputBegan:Connect(
			function(a0: InputObject, a1: boolean)
				if a1 then return end

				if a0.UserInputType == Enum.UserInputType.MouseButton1 then
					print('teste')
					Packets.Action:Fire('M1', {})
				end
			end
		),
		'Disconnect'
	)
end

function module:Unequip(character: Model)
	if Janitors[character] then Janitors[character]:Cleanup() end
end

return module
