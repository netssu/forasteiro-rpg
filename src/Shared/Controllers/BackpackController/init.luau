local module = {}

-- // Services
local Player = game:GetService('Players').LocalPlayer

-- // Dependencies
local Tool = require(script.Tool)
local Weapons = require(script.Weapon)

-- // Public Functions
function module:ToolAdded(a0: Tool, character: Model)
	local Settings = a0:FindFirstChild('Settings') :: Configuration
	if not Settings then return end

	Tool:Equip(a0, character)
	if Player.Character == character then Weapons:Equip(a0, character) end
end

function module:ToolRemove(Character: Model)
	Tool:Unequip(Character)
	Tool.Equip(self, tool, character)
end

return module
