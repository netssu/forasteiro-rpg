local module = {}

-- // SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

-- // DEPENDENCIES
local ToolModule = require(script.Tool)
local WeaponModule = require(script.Weapon)
local WeaponData = require(ReplicatedStorage.Modules.Constants.WeaponsData) 

-- // PRIVATE FUNCTIONS
local function OnCharacterAdded(character)
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			module:ToolAdded(child, character)
		end
	end

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.wait() 
			module:ToolAdded(child, character)
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			module:ToolRemove(child, character)
		end
	end)
end

-- // PUBLIC FUNCTIONS
function module:ToolAdded(tool: Tool, character: Model)
	local toolName = tool.Name
	
	if WeaponData[toolName] then
		if character == Player.Character then
			WeaponModule:Equip(tool, character)
		end
		
		ToolModule:Equip(tool, character)
	else
		ToolModule:Equip(tool, character)
	end
end

function module:ToolRemove(tool: Tool, character: Model)
	ToolModule:Unequip(tool, character)

	if character == Player.Character then
		WeaponModule:Unequip(tool, character)
	end
end

function module:Init()
	if Player.Character then
		OnCharacterAdded(Player.Character)
	end
	
	Player.CharacterAdded:Connect(OnCharacterAdded)
end

return module