local module = {}

-- // SERVICES
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

-- // DEPENDENCIES
local ToolModule = require(script.Tool)
local WeaponModule = require(script.Weapon)

-- // PUBLIC FUNCTIONS
function module:ToolAdded(tool: Tool, character: Model)
	local settings = tool:FindFirstChild("Settings")
	if not settings then return end

	ToolModule:Equip(tool, character)

	if character == Player.Character then
		WeaponModule:Equip(tool, character)
	end
end

function module:ToolRemove(tool: Tool, character: Model)
	ToolModule:Unequip(character)

	if character == Player.Character then
		WeaponModule:Unequip(character)
	end
end

return module