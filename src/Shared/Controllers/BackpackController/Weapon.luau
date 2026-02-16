local module = {}

-- // SERVICES
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local UserInputService = game:GetService('UserInputService')

-- // DEPENDENCIES
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Packets = require(ReplicatedStorage.Modules.Game.Packets)

-- // VARIABLES
local Janitors = {}

-- // PUBLIC FUNCTIONS
function module:Equip(tool: Tool, character: Model)
	if not character then return end
	
	if Janitors[character] then 
		Janitors[character]:Cleanup() 
		Janitors[character] = nil
	end

	Janitors[character] = Janitor.new()

	Janitors[character]:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if tool.Parent ~= character then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Packets.Action:Fire('M1', {})
		end
	end), 'Disconnect')
	
	Janitors[character]:Add(character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			module:Unequip(tool, character)
		end
	end), "Disconnect")
end

function module:Unequip(tool: Tool, character: Model)
	if character and Janitors[character] then 
		Janitors[character]:Cleanup()
		Janitors[character] = nil
	end
end

return module