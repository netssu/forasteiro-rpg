local KickService = {}

local SoundService = game:GetService("SoundService")
local soundFolder = SoundService.Movement

local Debounce = {}

local KickHitPacket

function KickService:Hit(PlayerWhoHit: Player, CharacterHitted: Model, Direction: Vector3)
	local Character = PlayerWhoHit.Character
	if not CharacterHitted or not Character then
		return
	end
	
	if Debounce[PlayerWhoHit] then
		return
	end
	
	local Humanoid = CharacterHitted:FindFirstChildWhichIsA("Humanoid")
	if not Humanoid then
		return
	end
	
	Debounce[PlayerWhoHit] = true

	
	local damage = 10
	local wasAlive = Humanoid.Health > 0
	Humanoid:TakeDamage(damage)
	
	KickService:PlayAudio(soundFolder.AirKickEnd,CharacterHitted)
	
	local PlayerHitted = game.Players:GetPlayerFromCharacter(CharacterHitted)
	if PlayerHitted then
		KickHitPacket:FireClient(PlayerHitted, Direction)
	end

	if wasAlive and Humanoid.Health <= 0 then
		_G.Services.KillService:Kill(PlayerWhoHit, CharacterHitted)
	end
	
	task.wait(2)
	Debounce[PlayerWhoHit] = false
end


function KickService:PlayAudio(sound:Sound,targetCharacter:Model)
	local part = targetCharacter.PrimaryPart
	local positionCF
	if not part then
		positionCF = targetCharacter:GetPivot()
	else
		positionCF = part.CFrame
	end
	if not positionCF then
		return
	end
	
	local attachment = Instance.new("Attachment")
	attachment.WorldCFrame = positionCF
	
	local newSound = sound:Clone()
	newSound.Parent = attachment
	newSound.Ended:Once(function()
		attachment:Destroy()
	end)
	
	attachment.Name = "SoundAttachment"
	attachment.Parent = workspace
	newSound:Play()
end


function KickService:Init()
	local Packet = self.Libs.Packet
	KickHitPacket = Packet("KickHit", Packet.Any)
end


function KickService:Start()
	KickHitPacket.OnServerEvent:Connect(function(PlayerWhoHit, CharacterHitted)
		KickService:Hit(PlayerWhoHit, CharacterHitted)
	end)
end



return KickService