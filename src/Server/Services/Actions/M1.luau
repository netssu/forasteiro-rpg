local module = {}

------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

------------------//DEPENDENCIES
local Cooldown = require(ReplicatedStorage.Modules.Core.Cooldown)
local PinataService = require(ServerScriptService.Services.PinataService)
local WeaponsData = require(ReplicatedStorage.Modules.Constants.WeaponsData)
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)

------------------//CONSTANTS
local HITBOX_SIZE = Vector3.new(8, 8, 8)

------------------//PUBLIC FUNCTIONS
function module.OnStart(player: Player, packet: any)
	if Cooldown:HasCooldown(player, "M1") then warn("return")  return end
	
	local character = player.Character
	if not character then warn("return")  return end
	
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then warn("return")  return end

	local equippedName = PlayerDataManager:Get(player, {"Inventory", "EquippedWeapon"})
	local weaponData = WeaponsData[equippedName] or WeaponsData["WoodenStick"]
	if not weaponData then warn("return") return else warn(weaponData) end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	
	local hitboxCFrame = root.CFrame * CFrame.new(0, 0, -3)
	local partsFound = workspace:GetPartBoundsInBox(hitboxCFrame, HITBOX_SIZE, overlapParams)
	
	local hitTargets = {}
	
	for _, part in partsFound do
		local model = part:FindFirstAncestorOfClass("Model")
		warn("part",part)
		if model and not hitTargets[model] then
			if model:GetAttribute("Type") == "Pinata" then
				warn(model)
				hitTargets[model] = true
				
				local ownerPlot = model:FindFirstAncestor("Plots") -- Assumindo estrutura de pastas
				PinataService:Damage(player, model, weaponData.Damage)
				break
			end
		end
	end
	
	Cooldown:SetCooldown(player, "M1", weaponData.Cooldown)
end

return module