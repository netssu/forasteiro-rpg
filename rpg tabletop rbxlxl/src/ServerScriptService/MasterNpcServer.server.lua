------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace: Workspace = game:GetService("Workspace")
local Players: Players = game:GetService("Players")

------------------//CONSTANTS
local ASSETS_FOLDER_NAME: string = "Assets"
local REMOTES_FOLDER_NAME: string = "Remotes"
local REMOTE_NAME: string = "MasterNpcEvent"
local CHARACTERS_FOLDER_NAME: string = "Characters"

------------------//VARIABLES
local assetsFolder: Folder = ReplicatedStorage:WaitForChild(ASSETS_FOLDER_NAME)
local remotesFolder: Folder = assetsFolder:WaitForChild(REMOTES_FOLDER_NAME)
local npcEvent: RemoteEvent = remotesFolder:FindFirstChild(REMOTE_NAME) or Instance.new("RemoteEvent")

local charactersFolder = Workspace:WaitForChild(CHARACTERS_FOLDER_NAME)

------------------//FUNCTIONS
local function create_npc(position: Vector3): ()
	local modelsFolder = assetsFolder:FindFirstChild("Models")
	local rigTemplate = modelsFolder and modelsFolder:FindFirstChild("Rig")

	if not rigTemplate then
		warn("Rig não encontrado em ReplicatedStorage.Assets.Models!")
		return
	end

	local npc = rigTemplate:Clone()
	npc.Name = "Inimigo"

	-- Posiciona o modelo de forma segura usando o Pivot (evita bugs de física)
	npc:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
	end

	npc:SetAttribute("IsNPC", true)
	npc:SetAttribute("RoleImageId", "rbxassetid://124119036634479")
	npc:SetAttribute("TokenScale", 1)
	npc:SetAttribute("MaxMovementDistance", math.huge)

	-- O RoleCharacterHandler vai escutar esse Parent e colocar a placa 2D
	npc.Parent = charactersFolder
end

local function handle_npc_event(player: Player, data: any): ()
	if player.Team.Name ~= "Mestre" or type(data) ~= "table" then return end

	local action = data.Action

	if action == "SpawnNpc" then
		create_npc(data.Position)

	elseif action == "DeleteNpc" then
		local npc = data.NPC
		if npc and npc:IsDescendantOf(charactersFolder) then
			if player.Character == npc then
				player.Character = nil
			end
			npc:Destroy()
		end

	elseif action == "UpdateNpc" then
		local npc = data.NPC
		if not npc or not npc:IsDescendantOf(charactersFolder) then return end

		if data.ImageId then npc:SetAttribute("RoleImageId", data.ImageId) end
		if data.Scale then npc:SetAttribute("TokenScale", data.Scale) end

		if data.WalkSpeed then
			local humanoid = npc:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.WalkSpeed = data.WalkSpeed end
		end

		if data.RotationY then
			-- Usa PivotTo também para rotacionar com segurança
			local currentPos = npc:GetPivot().Position
			npc:PivotTo(CFrame.new(currentPos) * CFrame.Angles(0, math.rad(data.RotationY), 0))
		end

	elseif action == "Possess" then
		local npc = data.NPC
		if npc and npc:IsDescendantOf(charactersFolder) then
			player.Character = npc
		end

	elseif action == "Unpossess" then
		player.Character = nil
	end
end

------------------//MAIN FUNCTIONS
npcEvent.OnServerEvent:Connect(handle_npc_event)

------------------//INIT
if npcEvent.Name ~= REMOTE_NAME then
	npcEvent.Name = REMOTE_NAME
	npcEvent.Parent = remotesFolder
end