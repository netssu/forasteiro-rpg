local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Resources = ReplicatedStorage:WaitForChild("Resources")
local ServerResources = ServerStorage:WaitForChild("Resources")
local Data = Resources:WaitForChild("Data")

local EntityFolder = workspace.Entity

local SkinUtils = require(game.ReplicatedStorage.Resources.Skins.Utils)

local ProjectileModule = require(game.ReplicatedStorage.Resources.Modules.ProjectileModule)
local ExplosiveBarrelManager = require(game.ServerStorage.Resources.Modules.ExplosiveBarrelManager)
local Ballistics = require(game.ReplicatedStorage.Resources.Modules.Ballistics)
local BallisticsValidate = require(game.ReplicatedStorage.Resources.Modules.Ballistics.Validation)
local BallisticsUtils = require(game.ReplicatedStorage.Resources.Modules.Ballistics.Utils)
local BallisticsClient = require(game.ReplicatedStorage.Resources.Modules.Ballistics.Client)

local StatusEffect = require(game.ReplicatedStorage.Resources.Modules.StatusEffect)

local Rand = Random.new()
local RandMath = math.random
local mathClamp = math.clamp

local ServerGunFramework = {}
ServerGunFramework.__index = ServerGunFramework

function RigAddresser(self, arg: {})
	if arg[1] == "Character" then
		return self.Character and self.Character:FindFirstChild(arg[2])
	elseif arg[1] == "GunModel" then
		return self.GunModel and self.GunModel:FindFirstChild(arg[2])
	end
end

local function PlayAudio(self, Audio: {Sound:Sound,Pitch:{Value:number,Randomize:{Enabled: boolean,Min: number,Max: number}}})
	local Sound = Audio.Sound
	if Sound then
		local IsString = (typeof(self.ToolData["AudioSettings"].Parent["Worldmodel"]):lower() == "string")
		local IsTable = (typeof(self.ToolData["AudioSettings"].Parent["Worldmodel"]):lower() == "table")
		local Parental = IsTable and RigAddresser(self, self.ToolData["AudioSettings"].Parent["Worldmodel"])
		if not Parental then
			warn("PARENT NOT FOUND")
			return
		end
		
		
	--[[	local toolData = self.ToolData
		local AudioSettings = toolData.AudioSettings
		local Commons = toolData.Commons
		
		if Commons.WeaponType.Melee then
			for _, v:Sound in pairs(Parental:GetChildren()) do
				print(v.Name,AudioSettings[v.Name])
				if v:IsA("Sound") and AudioSettings[v.Name] then
					print(v)
					v.Volume = 0
					v:Destroy()
				end
			end
		end]]
		
		Sound = Sound:Clone()
		Sound.Parent = Parental

		Sound.PlaybackSpeed = Audio.Pitch.Value
		if Audio.Pitch.Randomize.Enabled then
			Sound.PlaybackSpeed = Rand:NextNumber(Audio.Pitch.Randomize.Min, Audio.Pitch.Randomize.Max)
		end
		self.GunEvent:FireClient(self.Player, "HideAudio", Sound)
		Sound:Play()
		Sound.Ended:Once(function()
			Sound:Destroy()
		end)
	end	
end



function SetupGrip(self, enabled: boolean)
	if enabled then
		local rigData = self.ToolData["Rigging"]["Worldmodel"]
		local basePart = RigAddresser(self, rigData["BasePart"])
		local targetPart = RigAddresser(self, rigData["TargetPart"])

		self.GripJoint.Name = rigData["Name"]
		self.GripJoint.Part0 = basePart
		self.GripJoint.Part1 = targetPart
		self.GripJoint.Parent = targetPart
		self.GripJoint.C0 = rigData["Offset"]
		
		if self.ToolData.Rigging.Worldmodel["AkimboName"] then
			local basePart_L = RigAddresser(self, rigData["AkimboBasePart"])
			local targetPart_L = RigAddresser(self, rigData["AkimboTargetPart"])
			self.GripJoint_L.Name = rigData["AkimboName"]
			self.GripJoint_L.Part0 = basePart_L
			self.GripJoint_L.Part1 = targetPart_L
			self.GripJoint_L.C0 = rigData["Offset"]
			self.GripJoint_L.Parent = targetPart_L
		end
	else
		self.GripJoint.Part0 = nil
		self.GripJoint.Part1 = nil
		self.GripJoint.Parent = nil
		if self.Akimbo then
			self.GripJoint_L.Part0 = nil
			self.GripJoint_L.Part1 = nil
			self.GripJoint_L.Parent = nil
		end
	end
end
-- ID: 134
function HandleFire(self, player: Player, data)
	if not (self.States.ActuallyEquipped and not self.States.Reload) then return end
	if typeof(data) ~= "table" then return end
	
	local data = BallisticsUtils:ConvertPacketToServer(data)
	
	if not BallisticsValidate:Validate(player.Character,  data) then
		return
	end
	
	local origin = data.Origin
	local direction = data.Direction
	
	
	if not (origin and direction) then return end

	local currentAmmo = self.LocalResources:FindFirstChild("CurrentAmmo")
	local fireside = self.LocalResources:FindFirstChild("CurrentAmmo")
	if not currentAmmo then return end

	local Range = self.ToolData.Commons.Range
	local MaxPenetration = self.ToolData.Commons.MaxPenetration or 1
	local LastHit = data.Hits[#data.Hits]

	if (currentAmmo.Value == "INF" or currentAmmo.Value > 0) then
		if currentAmmo.Value ~= "INF" then
			currentAmmo.Value = math.clamp(currentAmmo.Value - 1, 0, self.ToolData.Commons.AmmoPerMagazine)
		end
	else
		return
	end
	
	for _, Hit in data.Hits do
		if not (self.ToolData.Commons.WeaponType.Melee or self.ToolData.Commons.WeaponType.Shotgun) and LastHit then
			_G.Services.RenderService:RenderForOthers({player}, "Tracer", "Normal", {
				Character = player.Character,
				End = LastHit.Position or Data.origin + (direction * (Range or 500)),
			})
		end

		local fireSounds = self.ToolData.AudioSettings.MultiFireSound -- randomize fire sounds if many
		if fireSounds then
			local soundNum = math.random(1,fireSounds)
			local sound = self.ToolData.AudioSettings["Fire" .. soundNum]
			PlayAudio(self, sound or self.ToolData.AudioSettings.Fire)
		else
			PlayAudio(self, self.ToolData.AudioSettings.Fire)
		end

		if self.ToolData.Commons.PumpAction then
			local delayBeforePump = self.ToolData.Commons.DelayBeforePump or 0.001
			self.TaskSchedulers.PumpAction = task.delay(delayBeforePump, function()
				if not self.States.Reload then
					PlayAudio(self, self.ToolData.AudioSettings.BoltAction)
				end
				self.TaskSchedulers.PumpAction = nil
			end)
		end
	
		if Hit.Type == "Char" then
			HitCharacter(self, player, Hit)
		elseif Hit.Type == "Glass" then
			HitGlass(self,player, Hit)
		elseif Hit.Type == "Barrel" then
			HitBarrel(self, player, Hit)
		end
	end

	local BulletHoles = BallisticsClient:GetBulletHoles(data)
	if #BulletHoles > 0 then
		BallisticsClient:FireClients(BulletHoles)
	end
	if self.ToolData.Commons.WeaponType.Shotgun then
		local dispersion = self.ToolData.Commons.Dispersion

		local shots = RandMath(dispersion.Min,dispersion.Max)
		local offset = mathClamp(RandMath()*dispersion.MaxOffset,dispersion.MinOffset,dispersion.MaxOffset)

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {player.Character}
		params.IgnoreWater = true
		
		for i = shots,0,-1 do
	
			local X = RandMath(-offset,offset)*0.1
			local Y = RandMath(-offset,offset)*0.1
			local Z = RandMath(-offset,offset)*0.1
			local vectorAdd = Vector3.new(X,Y,Z)

			local directionOffset = (direction.Unit + vectorAdd).Unit
		
			local Bullet = Ballistics.new(origin, directionOffset * Range, MaxPenetration)
			Bullet:Fire(params)
			
			local LastHit = Bullet.Hits[#Bullet.Hits]
			
			if not LastHit then
				_G.Services.RenderService:RenderForPlayers({player}, "Tracer", "Normal", {
					Character = player.Character,
					End = origin + (directionOffset * (Range or 500)),
				})
				Bullet:Destroy()
				continue
			else
				_G.Services.RenderService:RenderForPlayers({player}, "Tracer", "Normal", {
					Character = player.Character,
					End = LastHit.Position or origin + (directionOffset * (Range or 500)),
				})
			end
			
			for _, Hit in Bullet.Hits do
				if Hit.Type == "Char" then
					HitCharacter(self, player, Hit)
				elseif Hit.Type == "Glass" then
					HitGlass(self,player, Hit)
				elseif Hit.Type == "Barrel" then
					HitBarrel(self, player, Hit)
				end
			end
			
			local BulletHoles = BallisticsClient:GetBulletHoles(Bullet)
			if #BulletHoles > 0 then
				BallisticsClient:FireClients(BulletHoles)
			end
			
			Bullet:Destroy()
		end
	end
	
end


function HitCharacter(self,player, Hit)
	
	--local origin = data.Origin
	--local direction = data.Direction
	local isHeadshot = Hit.IsHeadshot
	
	--[[local a = Instance.new("Part",workspace)
	a.CanCollide = false
	a.CanQuery = false
	a.Transparency = 0.5
	a.Size = Vector3.new(0.2,0.2,0.2)
	a.Anchored = true
	a.Position = hitInfo.Position
	a.Color = Color3.fromRGB(255,255,0)
	game.Debris:AddItem(a, 5)]]
	
	if not Hit.CharacterName then
		return
	end
	local character = workspace:FindFirstChild(Hit.CharacterName) 
		or EntityFolder:FindFirstChild(Hit.CharacterName)
	if not character then return end

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then return end

	local targetRoot = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
	if not targetRoot then return end

	
	for name , value in self.ToolData.Commons["Custom Effects"] or {} do
		if value then
			StatusEffect:apply_status_effect(name, {
					character = character, 
					player = player, 
					checkHS = isHeadshot,
					commons = self.ToolData["Commons"]
			})
		end
	end

	local damage = self.ToolData.Commons.Base_Damage * (isHeadshot and self.ToolData.Commons.Headshot_Multipiler or 1)
	local wasAlive = humanoid.Health > 0
	humanoid:TakeDamage(damage)

	if wasAlive and humanoid.Health <= 0 then
		_G.Services.KillService:Kill(player, humanoid.Parent)
	end
	
end

function HitBarrel(self,player,Hit)
	local BarrelInstance = workspace.Map.Map.Barrels:FindFirstChild(Hit.BarrelID)

	if not BarrelInstance then
		return
	end

	ExplosiveBarrelManager:Hit(player.Character, BarrelInstance, self.ToolData.Commons.Base_Damage, if self.ToolData.Commons.WeaponType.Melee then "Melee" else nil, Hit.Position)
end

function HitGlass(self,player,Hit)
	local Glass = Hit.Instance
	
	if Glass and Glass:HasTag("Glass") then
		Glass:SetAttribute("Broken", true)
	end
end

function HandleReload(self)
	if not (self.States.ActuallyEquipped and not self.States.Reload) then return end
	if self.TaskSchedulers.ReloadConnection then return end

	self.States.Reload = true

	local currentAmmo = self.LocalResources:FindFirstChild("CurrentAmmo")
	if not currentAmmo then return end
	if currentAmmo.Value == "INF" then
		return
	end

	if currentAmmo.Value < self.ToolData["Commons"]["AmmoPerMagazine"] then
		local reloadType
		local reloadTime
		
		if currentAmmo.Value <= 0 then
			reloadType = "EmptyReload"
		else
			reloadType = "Reload"
		end
		
		reloadTime = self.ToolData["Commons"]["Reload_Time"][reloadType]
		
		local commons = self.ToolData["Commons"]
		local IsPumpAction = commons["PumpAction"]
		local DelayedBeforePump = commons["DelayBeforePump"] or 0.001

		if not commons["WeaponType"].Shotgun then
			PlayAudio(self, self.ToolData["AudioSettings"][reloadType])
			
			self.TaskSchedulers.ReloadConnection = task.delay(reloadTime, function()
				currentAmmo.Value = commons["AmmoPerMagazine"]
				self.TaskSchedulers.ReloadConnection = nil
				self.States.Reload = false
			end)
		else
			self.TaskSchedulers.ReloadConnection = task.defer(function()
				while currentAmmo.Value < commons["AmmoPerMagazine"] do
					currentAmmo.Value += 1
					PlayAudio(self, self.ToolData["AudioSettings"].Insert)
					if currentAmmo.Value >= commons["AmmoPerMagazine"] then break end
					task.wait(commons["InsertTime"])
				end

				if IsPumpAction then
					self.TaskSchedulers.PumpAction = task.delay(DelayedBeforePump, function()
						if not self.ToolData["Commons"]["ExcludePumpSoundOnReload"] then
							PlayAudio(self, self.ToolData["AudioSettings"].BoltAction)
						end
						self.TaskSchedulers.PumpAction = nil
					end)
				end

				self.States.Reload = false
				task.cancel(self.TaskSchedulers.ReloadConnection)
				self.TaskSchedulers.ReloadConnection = nil
			end)
		end
	end
end

function HandleReloadCancel(self)
	if self.TaskSchedulers.ReloadConnection then
		task.cancel(self.TaskSchedulers.ReloadConnection)
		self.TaskSchedulers.ReloadConnection = nil
	end
end

function OnGunEvent(self, player: Player, Event: string, ...)
	if Event == "Fire" then
		if self.Tool:IsDescendantOf(self.Character) then
			HandleFire(self, player, ...)
		end
	elseif Event == "Reload" then
		if self.Tool:IsDescendantOf(self.Character) then
			HandleReload(self)
		end
	elseif Event == "ReloadCancel" then
		HandleReloadCancel(self)
	end
end

function OnToolEquipped(self)
	self.States.Reload = false
	self.States.ActuallyEquipped = false
	self.States.Equipped = true

	self.Character = self.Tool.Parent
	self.Player = Players:GetPlayerFromCharacter(self.Character)

	ProjectileModule:SetConfigOption("MaxFireRate", 50 / self.ToolData["Commons"]["Firerate"])
	SetupGrip(self, true)
	PlayAudio(self, self.ToolData["AudioSettings"]["Equip"])

	if self.TaskSchedulers.EquipConnection then
		task.cancel(self.TaskSchedulers.EquipConnection)
	end

	self.TaskSchedulers.EquipConnection = task.delay(self.ToolData["Commons"]["Equip_Time"], function()
		self.States.ActuallyEquipped = true
		self.TaskSchedulers.EquipConnection = nil
	end)
end

function OnToolUnequipped(self)
	if self.TaskSchedulers.EquipConnection then
		task.cancel(self.TaskSchedulers.EquipConnection)
		self.TaskSchedulers.EquipConnection = nil
	end
	
	

	HandleReloadCancel(self)
	SetupGrip(self, false)

	self.States.Reload = false
	self.States.Equipped = false
	self.States.ActuallyEquipped = false
end

function ServerGunFramework:Destroy()
	for _, scheduler in pairs(self.TaskSchedulers) do
		if typeof(scheduler) == "thread" then
			task.cancel(scheduler)
		end
	end

	for key, conn in pairs(self.Connections) do
		if typeof(conn) == "RBXScriptConnection" then
			conn:Disconnect()
			self.Connections[key] = nil
		end
	end

	SetupGrip(self, false)

	self.Tool = nil
	self.GunModel = nil
	self.Character = nil
	self.Player = nil

	if self.GripJoint then
		self.GripJoint:Destroy()
		self.GripJoint = nil
	end


	table.clear(self)
end

function ServerGunFramework.Initialize(Tool: Tool)
	local toolData = Data:FindFirstChild(Tool.Name)
	local requiredData = toolData and require(toolData) or nil
	
	local Player 
	if Tool.Parent and Tool.Parent.Name == "Backpack" then 
		Player = Tool.Parent.Parent 
	elseif Tool.Parent then 
		Player = game.Players:GetPlayerFromCharacter(Tool.Parent)
	end
		
	local Loadout = _G.Services.SkinInventoryService:GetEquippedSkins(Player)
	if Loadout then
		local LoadoutData = Loadout[Tool.Name]
		if LoadoutData then
			
			local SkinData = SkinUtils.GetSkinByID(LoadoutData.SkinID)
			if SkinData then
				local GunModel = game.ReplicatedStorage.Resources.Miscs.GunModel.Skins[Tool.Name][SkinData.Name]:Clone()
				Tool.GunModel:Destroy()
				GunModel.Name = "GunModel"
				if GunModel:IsA("Model") then
					GunModel:ScaleTo(0.75)
				end
				GunModel.Parent = Tool
			end
		end
	end
	

	local self = setmetatable({
		Tool = Tool,
		GunModel = Tool:FindFirstChild("GunModel"),
		LocalResources = Tool:WaitForChild("LocalResources"),
		GunEvent = Tool:WaitForChild("LocalResources"):WaitForChild("GunEvent"),
		ToolData = requiredData,

		Player = nil,
		Character = nil,

		GripJoint = Instance.new("Motor6D"),
		GripJoint_L = Instance.new("Motor6D"),

		Connections = {},

		TaskSchedulers = {
			ReloadConnection = nil,
			EquipConnection = nil,
			PumpAction = nil,
		},

		States = {
			ActuallyEquipped = false,
			Equipped = false,
			Reload = false,
		},
	}, ServerGunFramework)

	if self.ToolData and self.LocalResources:FindFirstChild("CurrentAmmo") then
		self.LocalResources.CurrentAmmo.Value = self.ToolData["Commons"]["AmmoPerMagazine"]
	end

	table.insert(self.Connections, Tool.Equipped:Connect(function()
		OnToolEquipped(self)
	end))

	table.insert(self.Connections,Tool.Unequipped:Connect(function()
		OnToolUnequipped(self)
	end))

	table.insert(self.Connections, self.GunEvent.OnServerEvent:Connect(function(player, ...)
		OnGunEvent(self, player, ...)
	end))

	if Tool.Destroying then
		table.insert(self.Connections, Tool.Destroying:Connect(function()
			self:Destroy()
		end))
	else
		table.insert(self.Connections, Tool.AncestryChanged:Connect(function(_, parent)
			if not parent then
				self:Destroy()
			end
		end))
	end
end

return ServerGunFramework
