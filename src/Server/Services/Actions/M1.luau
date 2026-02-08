--!strict
local module = {}

-- // Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- // Dependencies
local Cooldown = require(ReplicatedStorage.Modules.Core.Cooldown)
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local WeaponsData = require(ReplicatedStorage.Modules.Constants.WeaponsData)

-- // Constants
local HITBOX_SIZE = vector.create(8, 8, 8)

-- // Public Functions
function module.OnStart(player: Player, data: { any })
	if Cooldown:HasCooldown(player, 'M1') then return end

	local character = player.Character :: Model?
	if not character then return end

	local root = character:FindFirstChild('HumanoidRootPart') :: BasePart?
	if not root then return end

	local tool = character:FindFirstChildOfClass('Tool')
	if not tool then return end

	local settings = tool:FindFirstChild('Settings')
	if not settings then return end

	local toolName = settings:GetAttribute('Name') :: string?
	if not toolName then return end

	local toolData = WeaponsData[toolName]
	if not toolData then return end

	local overlapParams = OverlapParams.new()

	local hitboxCFrame = root.CFrame * CFrame.new(0, 0, -3)
	local partsFound =
		workspace:GetPartBoundsInBox(hitboxCFrame, HITBOX_SIZE, overlapParams)

	local hitTargets = {}
	for _, part in partsFound do
		local model = part:FindFirstAncestorOfClass('Model')
		if model and not hitTargets[model] then
			hitTargets[model] = true

			if model:GetAttribute('Type') == 'Pinata' then
				Packets.Replicator:Fire('pinata_hit', { Pinata = model })
				module:ApplyDamage(player, model, toolData)
			end
		end
	end

	Cooldown:SetCooldown(player, 'M1', toolData.Cooldown)
end

function module:ApplyDamage(player: Player, pinataModel: Model, toolData: any)
	local currentHP = pinataModel:GetAttribute('Health') or 0
	local newHP = math.max(0, currentHP - toolData.Damage)

	pinataModel:SetAttribute('Health', newHP)
end

return module
