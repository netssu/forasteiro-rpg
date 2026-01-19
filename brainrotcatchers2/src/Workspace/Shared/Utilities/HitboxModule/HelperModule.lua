--\\ Services
--\\ Locals
--\\ Variables
local HelperModule = {}
--\\ Functions

local function showHitbox(cframe, size)
	local hitbox = Instance.new("MeshPart")
	hitbox.Color = Color3.fromRGB(255, 0, 0)
	hitbox.Material = Enum.Material.ForceField
	hitbox.Transparency = 0.75
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.Size = size
	hitbox.CFrame = cframe
	hitbox.Parent = workspace:FindFirstChild("Effects") or workspace
	task.delay(0.1, function()
		hitbox:Destroy()
	end)
	return hitbox
end

--\\ Start
HelperModule.ShowHitbox = showHitbox
--\\ End
return HelperModule