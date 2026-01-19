local CharacterService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packet
local EntityFolder = workspace:FindFirstChild("Entity") or Instance.new("Folder")
EntityFolder.Name = "Entity"
EntityFolder.Parent = workspace

local DiedService
local LoadoutService

local RagdollService = require(ReplicatedStorage.Resources.Modules.RagdollModule)

function CharacterService:LoadCharacter(Player: Player)
	if not Player or not Player:IsDescendantOf(game.Players) then
		return
	end
	
	-- serve para nn ter 2 threads carregando o mesmo jogador
	if Player:GetAttribute("Spawning") then
		return
	end
	
	
	repeat
		Player:SetAttribute("Spawning", true)
		task.wait()
	until workspace.Lobby:FindFirstChildWhichIsA("SpawnLocation", true) or not Player or not Player.Parent
	
	if not Player or not Player.Parent then 
		return
	end
	
	
	Player:LoadCharacterAsync()
	Player:SetAttribute("Spawning", false)
	

	local Character: Model = Player.Character or Player.CharacterAdded:Wait()	
	while Character.Parent ~= EntityFolder do
		Character.Parent = EntityFolder 
		task.wait()
	end
	
	local Humanoid = Character:WaitForChild("Humanoid")
	Character.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	
	
	Humanoid.Died:Once(function()
		local Action = DiedService:GetPlayerDiedAction(Player)
		RagdollService:Ragdoll(Character)
		if Action then
			Action(Player)
		else
			task.wait(3)
			CharacterService:LoadCharacter(Player)
		end
	end)


	for _, Part in Character:GetChildren() do
		if Part:IsA("BasePart") then
			if Part.CollisionGroup == "Default" then
				Part.CollisionGroup = "Players"
			end
		end
	end
end




function CharacterService:Init()
	DiedService = self.Services.DiedService
	LoadoutService = self.Services.LoadoutService
end

function CharacterService.Start()
end

return CharacterService