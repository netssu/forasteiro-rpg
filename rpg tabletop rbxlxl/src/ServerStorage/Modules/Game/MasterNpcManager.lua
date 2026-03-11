------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace: Workspace = game:GetService("Workspace")

------------------//CONSTANTS
local CHARACTERS_FOLDER_NAME: string = "Characters"

------------------//VARIABLES
local MasterNpcManager = {}
local assetsFolder: Folder = ReplicatedStorage:WaitForChild("Assets")
local charactersFolder: Folder = Workspace:WaitForChild(CHARACTERS_FOLDER_NAME)

------------------//FUNCTIONS
function MasterNpcManager.create_npc(position: Vector3): ()
	local modelsFolder = assetsFolder:FindFirstChild("Models")
	local rigTemplate = modelsFolder and modelsFolder:FindFirstChild("Rig")

	if not rigTemplate then
		warn("Rig não encontrado em ReplicatedStorage.Assets.Models!")
		return
	end

	local npc = rigTemplate:Clone()
	npc.Name = "Inimigo"
	npc:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
	end

	npc:SetAttribute("IsNPC", true)
	npc:SetAttribute("RoleImageId", "rbxassetid://124119036634479")
	npc:SetAttribute("TokenScale", 1)
	npc:SetAttribute("MaxMovementDistance", math.huge)

	npc.Parent = charactersFolder
end

function MasterNpcManager.process_request(player: Player, data: any): ()
	if player.Team == nil or player.Team.Name ~= "Mestre" or typeof(data) ~= "table" then
		return
	end

	local action = data.Action

	if action == "SpawnNpc" then
		if typeof(data.Position) == "Vector3" then
			MasterNpcManager.create_npc(data.Position)
		end
		return
	end

	if action == "DeleteNpc" then
		local npc = data.NPC
		if npc and npc:IsDescendantOf(charactersFolder) then
			if player.Character == npc then
				player.Character = nil
			end
			npc:Destroy()
		end
		return
	end

	if action == "UpdateNpc" then
		local npc = data.NPC
		if not npc or not npc:IsDescendantOf(charactersFolder) then 
			return 
		end

		if typeof(data.ImageId) == "string" then npc:SetAttribute("RoleImageId", data.ImageId) end
		if typeof(data.Scale) == "number" then npc:SetAttribute("TokenScale", data.Scale) end
		if typeof(data.HealthAnnotation) == "string" then npc:SetAttribute("NpcHealthAnnotation", data.HealthAnnotation) end

		if typeof(data.WalkSpeed) == "number" then
			local humanoid = npc:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.WalkSpeed = data.WalkSpeed end
		end

		if typeof(data.RotationY) == "number" then
			local currentPos = npc:GetPivot().Position
			npc:PivotTo(CFrame.new(currentPos) * CFrame.Angles(0, math.rad(data.RotationY), 0))
		end
		return
	end

	if action == "Possess" then
		local npc = data.NPC
		if npc and npc:IsDescendantOf(charactersFolder) then
			local oldChar = player.Character
			if oldChar == npc then return end

			if oldChar and oldChar:GetAttribute("IsNPC") then
				oldChar.Archivable = true
				local clone = oldChar:Clone()
				clone.Parent = charactersFolder
				oldChar:Destroy()
			end

			player.Character = npc
		end
		return
	end

	if action == "Unpossess" then
		local oldChar = player.Character
		if oldChar and oldChar:GetAttribute("IsNPC") then
			oldChar.Archivable = true
			local clone = oldChar:Clone()
			clone.Parent = charactersFolder
			oldChar:Destroy()
		end

		player.Character = nil
		player:LoadCharacter()
		return
	end
end

return MasterNpcManager