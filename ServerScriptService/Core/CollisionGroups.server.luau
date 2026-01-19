local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

PhysicsService:RegisterCollisionGroup("Players")
PhysicsService:RegisterCollisionGroup("Debris")

PhysicsService:CollisionGroupSetCollidable("Debris", "Default", true)
PhysicsService:CollisionGroupSetCollidable("Players", "Debris", false)

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		for _, part in character:GetDescendants() do
			if not part:IsA("BasePart") then continue end
			
			part.CollisionGroup = "Players"
		end
	end)
end)