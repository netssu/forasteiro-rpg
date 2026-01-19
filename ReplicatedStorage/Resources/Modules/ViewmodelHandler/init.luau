local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Ballistics = require(game.ReplicatedStorage.Resources.Modules.Ballistics)
local UserInputService = game:GetService("UserInputService")

local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
local mobile = playerGui:WaitForChild('MAINHUD'):WaitForChild('InGame'):WaitForChild('Mobile')

local reloadButton = mobile:WaitForChild('SideButtons'):WaitForChild("Reload")
local inspectButton = mobile:WaitForChild('SideButtons'):WaitForChild("Inspect")
local shootButton = mobile:WaitForChild('SideButtons'):WaitForChild("spray")

local Player = Players.LocalPlayer
local Mouse: Mouse = Player:GetMouse()
local CurrentCamera = workspace.CurrentCamera
local PlayerGui = Player.PlayerGui

local DefaultFOV = CurrentCamera.FieldOfView
local DefaultSensitivity = UserInputService.MouseDeltaSensitivity

local Resources = ReplicatedStorage:WaitForChild("Resources")

local Miscs = Resources.Miscs
local Modules = Resources.Modules

local EventHandler = script:WaitForChild("ViewmodelHandler")
local primaryButton = mobile:WaitForChild('DownBar'):WaitForChild("Primary") 
local secondaryButton = mobile:WaitForChild('DownBar'):WaitForChild("Secondary")
local meleeButton = mobile:WaitForChild('DownBar'):WaitForChild("Melee")

local Spring = require(Modules.Spring)
--local ProjectileVisual = require(Modules.ProjectileVisual)
local Constants = require(script:WaitForChild("Constants"))
local scopeButton = mobile:WaitForChild('SideButtons'):WaitForChild("aim")
local CameraRecoil = Spring.create()
local SwaySpring = Spring.create()

local Vec3 = Vector3.new

local CFAngle = CFrame.Angles
local CFZero = CFrame.identity
local CFPosition: Vector3 = CFrame.new

local Rand = Random.new()
local Clmp = math.clamp
local Abs = math.abs
local Rad = math.rad
local Sin = math.sin
local Cos = math.cos
local Lerp = math.lerp
local RandMath = math.random

local SkinsUtils = require(game.ReplicatedStorage.Resources.Skins.Utils)

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local ViewmodelHandler = {}
ViewmodelHandler.__index = ViewmodelHandler

local function IsDead(self)
	return self.Humanoid and (self.Humanoid.Health <= 0)
end

local function IsFirstPerson()
	local head = Player.Character and Player.Character:FindFirstChild("Head")
	if not head then return false end

	return CurrentCamera.CFrame.Position:FuzzyEq(head.Position, 1.5)
end

local function GetAllAvailableFireMode(Data)
	local FireMode = {}
	for _, v in ipairs(Data) do
		if v.Enabled then
			table.insert(FireMode, v)
		end
	end
	return FireMode
end


local function UpdateRaycastFilter()
	local character = Player.Character
	if character then
		raycastParams.FilterDescendantsInstances = {character, CurrentCamera}
	end
end

local function ClientRaycast(self, origin, direction)
	local character = Player.Character
	if not character then return end

	local maxDistance = self.CurrentData.Commons.Range or 500
	local maxIterations = 10

	local ignored = {character}

	local result

	for i = 1, maxIterations do
		-- recriar o RaycastParams a cada iteração
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignored
		params.IgnoreWater = true

		result = workspace:Raycast(origin, direction * maxDistance, params)

		-- sem hit → parar
		if not result or not result.Instance then
			break
		end

		local hit = result.Instance

		-- verificar se bateu em acessório
		local ancestor = hit
		local shouldIgnore = false

		while ancestor and ancestor ~= workspace do
			if ancestor:IsA("Accessory") then
				shouldIgnore = true
				break
			end
			ancestor = ancestor.Parent
		end

		-- se for acessório, ignorar e tentar novamente
		if shouldIgnore then
			table.insert(ignored, ancestor)
			result = nil
			continue
		end

		-- hit válido encontrado
		break
	end

	return result
end

function CanFire(self)
	return self.Vars.States.ActuallyEquipped
		and self.Vars.States.Equipped
		and not self.Vars.States.Reloading
		and not IsDead(self)
		and (self.Vars.States.AllowtoActivate or self.Vars.States.IsBursting)
end

local function RigAddresser(self, Data: {})
	local Viewmodel: Model = self.Viewmodel
	local GunModel: Model = Viewmodel:FindFirstChild("GunModel")

	if Data[1] == "Viewmodel" then
		return Viewmodel:FindFirstChild(Data[2])
	elseif Data[1] == "GunModel" then
		if GunModel then
			return GunModel:FindFirstChild(Data[2])
		end
	elseif Data[1] == "Worldmodel_GunModel" then
		local WM_GunModel = self.Character:FindFirstChild("GunModel")
		if WM_GunModel then
			local WM_GunModelTargetPart = WM_GunModel:FindFirstChild(Data[2])
			return WM_GunModelTargetPart
		end
	end
end

function EmitMuzzle(self)
	local VMTargetPart = RigAddresser(self, self.CurrentData.Rigging.Viewmodel.TargetPart)
	if VMTargetPart then
		local MuzzleNode

		if self.Akimbo then
			if self.LocalResources.FireSide.Value == "Left" then
				MuzzleNode = VMTargetPart.Parent.Grip_L:FindFirstChild("MuzzleFlash")
			else
				MuzzleNode = VMTargetPart:FindFirstChild("MuzzleFlash")
			end
		else
			MuzzleNode = VMTargetPart:FindFirstChild("MuzzleFlash")
		end

		if MuzzleNode then
			local Muzzleflash: Folder = self.CurrentData.Muzzleflash:Clone()
			local Light = Muzzleflash:FindFirstChildWhichIsA("PointLight") 
			if Light then
				Light.Parent = MuzzleNode
				game.TweenService:Create(Light, TweenInfo.new(0.2), {Brightness = 0}):Play()
				spawn(function()
					task.wait(0.5)
					Light:Destroy()
				end)
				--game.Debris:AddItem(Muzzleflash.PointLight, 0.12)
			else
			end
			for i,v: ParticleEmitter in Muzzleflash:GetChildren() do
				if v:IsA("ParticleEmitter") then
					if MuzzleNode then
						local EmitOrigin = Instance.new("ObjectValue")
						EmitOrigin.Name = "EmitOrigin"
						EmitOrigin.Value = MuzzleNode
						EmitOrigin.Parent = v
					end

					v.Parent = MuzzleNode
					v:Emit(1)

					self.Vars.MuzzleFlashes[v] = v
					task.delay(3, function()
						v:Destroy()
						self.Vars.MuzzleFlashes[v] = nil
					end)
				end
			end
		end
	end	
end

function EjectShell(self)
	local WeaponType = "Rifle"

	for Type, Weapon in self.CurrentData.Commons.WeaponType do
		if Weapon then
			WeaponType = Type
		end
	end

	local Shell = Resources.Cartiges:FindFirstChild(WeaponType.. "Shell") 

	local WeaponModel
	if IsFirstPerson() then
		WeaponModel = self.Viewmodel:FindFirstChild("GunModel")
	else
		WeaponModel = self.Character:FindFirstChild("GunModel")
	end

	if not WeaponModel then
		return
	end

	local ShellEjectAttachment
	if self.Akimbo then
		if self.LocalResources.FireSide.Value == "Left" then
			ShellEjectAttachment = self.ShellEjectAttachment_L
		elseif self.LocalResources.FireSide.Value == "Right" then
			ShellEjectAttachment = self.ShellEjectAttachment
		end
	end

	if ShellEjectAttachment then
		task.defer(function()
			local ShellClone = Shell:Clone()
			ShellClone:PivotTo(ShellEjectAttachment.WorldCFrame)
			ShellClone.CanCollide = true
			ShellClone.CollisionGroup = "Debris"

			local BaseVelocity = self.Character.HumanoidRootPart.AssemblyLinearVelocity
			ShellClone.AssemblyLinearVelocity = BaseVelocity + (((ShellClone:GetPivot().RightVector * 2 + ShellClone:GetPivot().UpVector)) * 3)
			ShellClone.Parent = workspace

			game:GetService("Debris"):AddItem(ShellClone, 3)
		end)
	end
end


local function PlayAudio(self, AudioConfig)
	local template = AudioConfig.Sound
	if not template then return end

	local IsString = (typeof(self.CurrentData.AudioSettings.Parent["Viewmodel"]):lower() == "string")
	local IsTable = (typeof(self.CurrentData.AudioSettings.Parent["Viewmodel"]):lower() == "table")
	local Parental = (IsTable and RigAddresser(self, self.CurrentData.AudioSettings.Parent["Viewmodel"])) or
		(IsString and self.CurrentData.AudioSettings.Parent["Viewmodel"] == "CurrentCamera" and CurrentCamera) or nil
	if not Parental then return end

	local toolData = self.CurrentData
	local AudioSettings = toolData.AudioSettings
	local Commons = toolData.Commons

	if Commons.WeaponType.Melee then
		for _, v:Sound in pairs(Parental:GetChildren()) do
			if v:IsA("Sound") and AudioSettings[v.Name] then
				v:Destroy()
			end
		end
	end

	local sound = template:Clone()
	sound.Parent = Parental

	sound.Looped = false

	if AudioConfig.Pitch and AudioConfig.Pitch.Randomize and AudioConfig.Pitch.Randomize.Enabled then
		sound.PlaybackSpeed = Rand:NextNumber(AudioConfig.Pitch.Randomize.Min, AudioConfig.Pitch.Randomize.Max)
	else
		sound.PlaybackSpeed = AudioConfig.Pitch and AudioConfig.Pitch.Value or 1
	end

	table.insert(self.PlayingAudios, sound)

	if sound.Ended then
		sound.Ended:Once(function()
			local idx = table.find(self.PlayingAudios, sound)
			if idx then table.remove(self.PlayingAudios, idx) end
			if sound and sound.Parent then
				sound:Destroy()
			end
		end)
	else
		local conn
		conn = sound:GetPropertyChangedSignal("Playing"):Connect(function()
			if not sound.Playing then
				if conn then conn:Disconnect() end
				local idx = table.find(self.PlayingAudios, sound)
				if idx then table.remove(self.PlayingAudios, idx) end
				if sound and sound.Parent then sound:Destroy() end
			end
		end)
	end

	sound:Play()
end

local function StopAudio(self, AudioName)
	if not self.PlayingAudios then return end

	for i = #self.PlayingAudios, 1, -1 do
		local snd = self.PlayingAudios[i]
		if snd and snd.Name == AudioName then
			table.remove(self.PlayingAudios, i)
			if snd.IsPlaying or snd.Playing then
				pcall(function() snd:Stop() end)
			end
			if snd and snd.Parent then
				pcall(function() snd:Destroy() end)
			end
		end
	end
end


local function UpdateAppearance(self)
	local Viewmodel = self.Viewmodel

	local BodyColors: BodyColors = self.Character:FindFirstChildOfClass("BodyColors")

	local LeftArm = Viewmodel:WaitForChild("Left Arm")
	local RightArm = Viewmodel:WaitForChild("Right Arm")

	local WorldmodelShirt = self.Character:FindFirstChildOfClass("Shirt")
	if WorldmodelShirt then
		Viewmodel.Shirt.ShirtTemplate = WorldmodelShirt.ShirtTemplate
	end

	if BodyColors then
		if LeftArm then
			LeftArm.Color = BodyColors.LeftArmColor3
		end
		if RightArm then
			RightArm.Color = BodyColors.RightArmColor3
		end
	end
end

local function LoadAnimationTrack(self)
	self.Animations = {}

	local AnimationDirectory = Resources.Data[self.CurrentItem.Name]

	local ViewmodelAnimator: AnimationController = self.Animator
	local WorldmodelAnimator: Humanoid = self.Character:FindFirstChild("Humanoid")

	local ViewmodelAnimations = {}
	local WorldmodelAnimations = {}

	if ViewmodelAnimator then
		local groups = {}

		for _, anim in AnimationDirectory.ViewmodelAnimations:GetChildren() do
			local name = anim.Name
			groups[name] = groups[name] or {}
			table.insert(groups[name], anim)
		end

		for name, list in groups do
			if #list == 1 then
				ViewmodelAnimations[name] = ViewmodelAnimator:LoadAnimation(list[1])
			else
				local t = {}
				for _, anim in list do
					table.insert(t, ViewmodelAnimator:LoadAnimation(anim))
				end
				ViewmodelAnimations[name] = t
			end
		end
	end

	if WorldmodelAnimator then
		local groups = {}

		for _, anim in AnimationDirectory.WorldmodelAnimations:GetChildren() do
			local name = anim.Name
			groups[name] = groups[name] or {}
			table.insert(groups[name], anim)
		end

		for name, list in groups do
			if #list == 1 then
				WorldmodelAnimations[name] = WorldmodelAnimator:LoadAnimation(list[1])
			else
				local t = {}
				for _, anim in list do
					table.insert(t, WorldmodelAnimator:LoadAnimation(anim))
				end
				WorldmodelAnimations[name] = t
			end
		end
	end

	self.Animations = {
		Viewmodel = ViewmodelAnimations,
		Worldmodel = WorldmodelAnimations
	}
end


local function StopAnimation(self, AnimationTrack: string)
	local VMAnimations = self.Animations.Viewmodel[AnimationTrack]
	local WMAnimations = self.Animations.Worldmodel[AnimationTrack]

	if VMAnimations then
		if typeof(VMAnimations) ~= "table" then
			VMAnimations:Stop(0)
		else
			for _, Animation in VMAnimations do 
				Animation:Stop(0)
			end
		end
	end
	if WMAnimations then
		if typeof(WMAnimations) ~= "table" then
			WMAnimations:Stop(0)
		else
			for _, Animation in WMAnimations do 
				Animation:Stop(0)
			end
		end
	end
end

local function PlayAnimation(self, AnimName: string, fireside)
	local VM = self.Animations.Viewmodel[AnimName]
	local WM = self.Animations.Worldmodel[AnimName]

	if AnimName ~= "Inspect" then
		StopAnimation(self, "Inspect")
		StopAudio(self, "Inspect")
	end

	self.Vars.AnimationIndex = self.Vars.AnimationIndex or {}

	local index = self.Vars.AnimationIndex[AnimName] or 1
	local maxVM = typeof(VM) == "table" and #VM or 1
	local maxWM = typeof(WM) == "table" and #WM or 1
	local maxIndex = math.max(maxVM, maxWM)

	if typeof(VM) == "table" then
		StopAnimation(self, AnimName)
	end

	if typeof(VM) == "table" then
		local anim = VM[index]
		if anim then anim:Play() end
	elseif VM then
		VM:Play()
	end

	if typeof(WM) == "table" then
		local anim = WM[index]
		if anim then anim:Play() end

	elseif WM then
		WM:Play()
	end

	index += 1
	if index > maxIndex then
		index = 1
	end

	self.Vars.AnimationIndex[AnimName] = index
end



local function IsAnimationPlaying(self, AnimationTrack: string)
	for _, Animation in self.Animations.Viewmodel do
		if Animation.Name == AnimationTrack then
			if Animation.IsPlaying then
				return true
			end
		end
	end
end


local function FindFirstChildWithNameAndClass(parent: Instance, child: string, class: string)
	for i,v in parent:GetChildren() do
		if v:IsA(class) and v.Name == child then
			return v
		end
	end
end

local function SetupGlovesModel(self)
	local Viewmodel: Model = self.Viewmodel

	local LoadoutController = _G.Controllers.LoadoutController
	local EquippedSkins = LoadoutController:GetEquippedSkins()
	local SkinTable = EquippedSkins["Gloves"]

	local Gloves = game.ReplicatedStorage.Resources.Miscs.Gloves.Gloves
	if SkinTable then
		local SkinData = SkinsUtils.GetSkinByID(SkinTable.SkinID)

		if SkinData then
			Gloves = game.ReplicatedStorage.Resources.Miscs.Gloves[SkinData.Name]
		end
	end

	if Viewmodel:FindFirstChild(Gloves.Name) then
		return
	end

	for _, Part in Viewmodel:GetChildren() do
		if Part:GetAttribute("Gloves") then
			Part:Destroy()
		end
	end


	if Gloves then
		Gloves = Gloves:Clone()
		for _, Part in Gloves:GetChildren() do
			if Part:IsA("BasePart") then
				local GloveWeld = Part:FindFirstChild("GloveWeld")
				if GloveWeld then
					local Part1

					if Part.Name:sub(1,1) == "R" then
						Part1 = Viewmodel:FindFirstChild("Right Arm")
					else
						Part1 = Viewmodel:FindFirstChild("Left Arm")
					end					

					GloveWeld.Part1 = Part1
				end
			end
		end
		Gloves:SetAttribute("Gloves", true)
		Gloves.Parent = Viewmodel
	end
end

local function SetupGunModel(self)
	local Viewmodel: Model = self.Viewmodel
	local GunModel = Viewmodel:FindFirstChild("GunModel")
	if GunModel then
		local LoadoutController = _G.Controllers.LoadoutController
		local EquippedSkins = LoadoutController:GetEquippedSkins()
		local SkinTable = EquippedSkins[self["CurrentItem"].Name]

		if SkinTable then
			local SkinData = SkinsUtils.GetSkinByID(SkinTable.SkinID)

			if SkinData then
				self.CurrentData["Model"].Viewmodel = game.ReplicatedStorage.Resources.Miscs.GunModel.Skins[self["CurrentItem"].Name][SkinData.Name]
			end
		end

		local VM_GunModel = self.CurrentData["Model"].Viewmodel

		if VM_GunModel then
			VM_GunModel = VM_GunModel:Clone()
			for i,v in VM_GunModel:GetChildren() do
				v.Parent = GunModel
			end
		end	

		local ViewmodelJoint = Instance.new("Motor6D")

		if GunModel:FindFirstChild("Grip_L") then
			local AkimboJoint = Instance.new("Motor6D")
			local AkimboBasePart = RigAddresser(self, self.CurrentData["Rigging"]["Viewmodel"]["AkimboBasePart"])
			local AkimboTargetPart = RigAddresser(self, self.CurrentData["Rigging"]["Viewmodel"]["AkimboTargetPart"])

			AkimboJoint.Name = self.CurrentData["Rigging"]["Viewmodel"]["AkimboName"]

			AkimboJoint.Part0 = AkimboBasePart
			AkimboJoint.Part1 = AkimboTargetPart

			AkimboJoint.Parent = AkimboTargetPart
		end

		local BasePart = RigAddresser(self, self.CurrentData["Rigging"]["Viewmodel"]["BasePart"])
		local TargetPart = RigAddresser(self, self.CurrentData["Rigging"]["Viewmodel"]["TargetPart"])

		ViewmodelJoint.Name = self.CurrentData["Rigging"]["Viewmodel"]["Name"]

		ViewmodelJoint.Part0 = BasePart
		ViewmodelJoint.Part1 = TargetPart

		ViewmodelJoint.Parent = TargetPart

		Viewmodel.Torso.CanCollide = false
	end
end

function FireLogic(self)
	if self.Vars.States.Reloading then return end
	if not CanFire(self) then return end

	local ToolResources = self.LocalResources
	if not ToolResources then return end
	local CurrentAmmo = ToolResources:FindFirstChild("CurrentAmmo")
	if not CurrentAmmo or (CurrentAmmo.Value ~= "INF" and CurrentAmmo.Value <= 0) then return end

	local firemode = self.CurrentFiremode.String:lower()

	if firemode == "burst" then
		if self.TaskSchedulers.Burst then return end
		if self.Vars.States.IsBursting then return end

		local shots = self.CurrentData.Commons.BurstFireIteration
		local interval = 60 / self.CurrentData.Commons.Firerate

		self.Vars.States.AllowtoActivate = false
		self.Vars.States.IsBursting = true

		self.TaskSchedulers.Burst = task.spawn(function()
			for i = 1, shots do
				if not self.Vars.States.IsBursting then break end
				if self.Vars.States.Reloading then break end
				if not self.Vars.States.ActuallyEquipped then break end
				if not self.Vars.States.Equipped then break end
				if not CurrentAmmo or (CurrentAmmo.Value ~= "INF" and CurrentAmmo.Value <= 0) then break end

				self:Active()

				if i < shots then
					task.wait(interval)
				end
			end

			task.wait(interval * 1.5)

			self.Vars.States.IsBursting = false
			if not self.Vars.States.Reloading then
				self.Vars.States.AllowtoActivate = true
			end

			self.TaskSchedulers.Burst = nil
		end)
	elseif firemode == "auto" then
		self.TaskSchedulers.AutoFire = task.spawn(function()
			while self.Vars.Hold and CanFire(self) and (CurrentAmmo.Value == "INF" or CurrentAmmo.Value > 0) do
				if self.Vars.States.Reloading then
					break
				end
				self:Active()
				task.wait(60 / self.CurrentData.Commons.Firerate)
			end
			self.TaskSchedulers.AutoFire = nil
		end)

	else
		if CanFire(self) then
			self:Active()
		end
	end
end

local function Reload(self)
	if self.Vars.States.Reloading then return end
	if not self.CurrentData or not self.CurrentItem then return end
	if not self.Vars.States.ActuallyEquipped or not self.Vars.States.Equipped then return end

	local ToolResources = self.LocalResources
	if not ToolResources then return end

	local CurrentAmmo = ToolResources:FindFirstChild("CurrentAmmo")
	if not CurrentAmmo then return end
	if self.CurrentData.Commons.AmmoPerMagazine == "INF" or CurrentAmmo.Value >= self.CurrentData.Commons.AmmoPerMagazine then return end

	self.Vars.States.Reloading = true
	self.Vars.States.AllowtoActivate = false
	self.Vars.States.IsBursting = false
	self.Vars.Hold = false

	if self.TaskSchedulers.AllowedToFire then
		task.cancel(self.TaskSchedulers.AllowedToFire)
		self.TaskSchedulers.AllowedToFire = nil
	end
	if self.TaskSchedulers.AutoFire then
		task.cancel(self.TaskSchedulers.AutoFire)
		self.TaskSchedulers.AutoFire = nil
	end
	if self.TaskSchedulers.Burst then
		task.cancel(self.TaskSchedulers.Burst)
		self.TaskSchedulers.Burst = nil
	end
	if self.TaskSchedulers.PumpAction then
		task.cancel(self.TaskSchedulers.PumpAction)
		self.TaskSchedulers.PumpAction = nil
	end

	local GunEvent: RemoteEvent = self.LocalResources:FindFirstChild("GunEvent")
	local ReloadType = CurrentAmmo.Value <= 0 and "EmptyReload" or "Reload"

	if GunEvent then
		GunEvent:FireServer("Reload")
	end

	-- reload especifico de Shotgun
	if self.CurrentData.Commons.WeaponType.Shotgun then
		PlayAnimation(self, "PreReload")
		PlayAudio(self, self.CurrentData.AudioSettings.ReloadStart)
		self.TaskSchedulers.Reloading = task.spawn(function()
			while CurrentAmmo.Value < self.CurrentData.Commons.AmmoPerMagazine and self.Vars.States.Reloading do
				CurrentAmmo.Value = math.clamp(CurrentAmmo.Value + 1, 0, self.CurrentData.Commons.AmmoPerMagazine)

				PlayAnimation(self, "InsertAction")
				PlayAudio(self, self.CurrentData.AudioSettings.Insert)
				task.wait(self.CurrentData.Commons.InsertTime)
			end

			if self.CurrentData.Commons.PumpAction and self.Vars.States.Reloading then
				StopAnimation(self, "InsertAction")
				PlayAnimation(self, "AfterReloadAnimation")
				PlayAudio(self, self.CurrentData.AudioSettings.ReloadEnd)
				self.TaskSchedulers.PumpAction = task.delay(
					self.CurrentData.Commons.DelayBeforePump or 0.001,
					function()
						if self.Vars.States.Reloading then
							PlayAnimation(self, "PumpAction")
							PlayAudio(self, self.CurrentData.AudioSettings.BoltAction)
						end
						self.TaskSchedulers.PumpAction = nil
					end
				)
			end

			if self.Vars.States.Equipped and self.Vars.States.ActuallyEquipped then
				self.Vars.States.Reloading = false
				self.Vars.States.AllowtoActivate = true
			end

			self.TaskSchedulers.Reloading = nil
		end)
	else
		-- outras armas
		PlayAnimation(self, ReloadType)
		PlayAudio(self, self.CurrentData.AudioSettings[ReloadType])

		self.TaskSchedulers.Reloading = task.delay(
			self.CurrentData.Commons["Reload_Time"][ReloadType],
			function()
				if self.CurrentData.Commons.PumpAction and self.Vars.States.Reloading then
					PlayAnimation(self, "PumpAction")
					if not self.CurrentData.Commons.ExcludePumpSoundOnReload then
						PlayAudio(self, self.CurrentData.AudioSettings.BoltAction)
					end
				end

				if self.Vars.States.Equipped and self.Vars.States.ActuallyEquipped then
					self.Vars.States.Reloading = false
					self.Vars.States.AllowtoActivate = true
				end
				self.TaskSchedulers.Reloading = nil
			end
		)
	end
end


function ShowScope(state)
	PlayerGui.MAINHUD.Scope.Enabled = state
	--PlayerGui.HUD.CROSSHAIR.Cursor.Visible = not state
	if not PlayerGui.HUD.CROSSHAIR.ShotgunCursor.Visible and not PlayerGui.HUD.CROSSHAIR.SniperCursor.Visible then
		PlayerGui.HUD.CROSSHAIR.Cursor.Visible = not state
	end
end


local function Renderer(self, deltatime: number)
	if not self.CurrentData or not self.CurrentItem then return end
	if IsDead(self) then self:Unequip() return end

	local Viewmodel = self.Viewmodel
	local Humanoid = self.Humanoid
	local MouseDelta = UserInputService:GetMouseDelta()
	local Root = self.Character.PrimaryPart
	local Camera = CurrentCamera

	self.Vars.DeltaTime = deltatime

	-----------------------------------------------------
	-- SPRINGS
	-----------------------------------------------------

	-- Sway
	SwaySpring:shove(Vector3.new(MouseDelta.X, MouseDelta.Y, 0), deltatime)
	local CameraRecoilUpdater = CameraRecoil:update(deltatime)
	local SwaySpringUpdater = SwaySpring:update(deltatime) * .1

	-- Walk Tilt Spring
	if not self.Vars.WalkTiltSpring then
		self.Vars.WalkTiltSpring = Spring.create(Vector3.new())
		self.Vars.WalkTiltSpring.s = 3.2
		self.Vars.WalkTiltSpring.d = 1.8
	end

	-- Animation Spring
	if not self.Vars.AnimationSpring then
		self.Vars.AnimationSpring = Spring.create(Vector3.new())
		self.Vars.AnimationSpring.s = 3.2
		self.Vars.AnimationSpring.d = 1.8
	end

	self.Vars.LastAnimationOrientation = self.Vars.LastAnimationOrientation or Vector3.new()

	-----------------------------------------------------
	-- BOBBING & IDLE
	-----------------------------------------------------

	local BobbingCondition = (Humanoid:GetState() ~= Enum.HumanoidStateType.Freefall and Humanoid.MoveDirection.Magnitude > 0.1)
	local WalkSpeedAlpha = (Root.Velocity.Magnitude / math.max(Humanoid.WalkSpeed, 0.1))
	WalkSpeedAlpha = math.clamp(WalkSpeedAlpha, 0, 1.6)

	local BobbingCycle = (7 * WalkSpeedAlpha)

	self.Vars.BobbingSpeedMultipilerCache = Lerp(
		self.Vars.BobbingSpeedMultipilerCache,
		WalkSpeedAlpha,
		.1 * (deltatime * 60)
	)

	if not self.Character:GetAttribute("Slide") then
		self.CFrames.ProceduralCFrames.Idle = self.CFrames.ProceduralCFrames.Idle:Lerp(
			(not BobbingCondition) and CFPosition(
				Sin(tick() * 2 * Constants.Procedural_IdleSpeed) * .015,
				Abs(Cos(tick() * 2 * Constants.Procedural_IdleSpeed)) * .02,
				0	
			) * CFAngle(
				0,
				0,
				Rad(Sin(tick() * 3 * Constants.Procedural_IdleSpeed)) * .1
			) or CFZero,
			(0.075 / 2) * (deltatime * 300)
		)
	end

	self.CFrames.Sway = CFAngle(
		-Rad(SwaySpringUpdater.Y),
		-Rad(SwaySpringUpdater.X),
		0
	) * CFPosition(-(SwaySpringUpdater.X * .05) * 1.5, (SwaySpringUpdater.Y * .1), Abs(SwaySpringUpdater.X * .05))

	if not self.Vars.BobbingTime then
		self.Vars.BobbingTime = 0
	end
	if BobbingCondition then
		self.Vars.BobbingTime += (deltatime * BobbingCycle)
	end

	self.CFrames.Bobbing = self.CFrames.Bobbing:Lerp(
		CFPosition(
			Vec3(
				Sin(self.Vars.BobbingTime) * .1,
				Abs(Cos(self.Vars.BobbingTime)) * .15,
				-Abs(Cos(self.Vars.BobbingTime)) * .05
			) * (BobbingCondition and self.Vars.BobbingSpeedMultipilerCache or 0)
		),
		0.1 * (deltatime * 60)
	)

	-----------------------------------------------------
	-- WALK TILT
	-----------------------------------------------------

	local moveDir = Humanoid.MoveDirection
	local camRight = Camera.CFrame.RightVector
	local lateral = moveDir:Dot(camRight)

	local targetTilt = Vector3.new(0, 0, math.clamp(-lateral * 2.2, -2.2, 2.2))
	self.Vars.WalkTiltSpring:shove((targetTilt - self.Vars.WalkTiltSpring.Position) * 0.25, deltatime)
	local WalkTilt = self.Vars.WalkTiltSpring:update(deltatime)



	local baseRot = Camera.CFrame.Rotation

	local tiltRot = CFAngle(
		Rad(CameraRecoilUpdater.Y ),
		Rad(CameraRecoilUpdater.X),
		Rad( WalkTilt.Z)
	)

	local finalRot = baseRot * tiltRot

	Camera.CFrame = CFrame.new(Camera.CFrame.Position) * finalRot

	-----------------------------------------------------
	-- VIEWMODEL CF
	-----------------------------------------------------

	local VIEWMODELCFRAME = Camera.CFrame
		* self.CurrentData.Offsets.Viewmodel_Offset
		* CFAngle(0, 0, Rad(WalkTilt.Z))
		* self.CFrames.ProceduralCFrames.Idle
		* self.CFrames.Bobbing
		* self.CFrames.Sway

	if Viewmodel then
		Viewmodel:PivotTo(VIEWMODELCFRAME)
	end

	-----------------------------------------------------
	-- ANIMATION ORIENTATION
	-----------------------------------------------------

	self.Vars.LastHeadLook = self.Vars.LastHeadLook or nil

	local HRP = Root
	local Head = self.Viewmodel and self.Viewmodel:FindFirstChild("Head")

	if HRP and Head then
		local currentRot = Head.CFrame.Rotation

		if not self.Vars.LastHeadRot then
			self.Vars.LastHeadRot = currentRot
		end

		local rotDelta = self.Vars.LastHeadRot:ToObjectSpace(currentRot)
		self.Vars.LastHeadRot = currentRot

		local x, y, z = rotDelta:ToEulerAnglesYXZ()

		local ViewmodelAnimations = self.Animations.Viewmodel
		local ApplyOffset = false

		for Name, Animation in ViewmodelAnimations do
			if Name ~= "Fire" and Name ~= "Idle" and Animation.IsPlaying then
				ApplyOffset = true
				break
			end
		end

		if ApplyOffset then
			Camera.CFrame *= CFrame.Angles(
				x * 0.15, 
				y * 0.15,
				z * 0.15
			)
		end
	end

	-----------------------------------------------------
	-- VISIBILITY
	-----------------------------------------------------

	if script:GetAttribute("___Aim") then
		Player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		Player.CameraMode = Enum.CameraMode.LockFirstPerson
		ShowScope(false)
	end

	if not IsFirstPerson() or script:GetAttribute("___Aim") then
		for i, v in self.Vars.MuzzleFlashes do
			local TargetPart = RigAddresser(self, {
				self.CurrentData.Rigging.Worldmodel.TargetPart[1]:lower() == "gunmodel" and "Worldmodel_GunModel",
				self.CurrentData.Rigging.Worldmodel.TargetPart[2]
			})
			if TargetPart then
				local Node = TargetPart:FindFirstChild("MuzzleFlash")
				if Node then
					if not v or not v:IsA("ParticleEmitter") or not v:IsDescendantOf(workspace) then
						v = self.Vars.MuzzleFlashes[i]:Clone()
						self.Vars.MuzzleFlashes[i] = v
					end
					v.Parent = Node
				end
			end
		end
		self:Visible(false)
	else
		for i, v: ParticleEmitter in self.Vars.MuzzleFlashes do
			local TargetPart
			local EmitOrigin = v:FindFirstChild("EmitOrigin")
			if EmitOrigin then
				if not script:GetAttribute("___Aim") then
					TargetPart = EmitOrigin.Value
				else
					TargetPart = nil
				end
			end
			v.Parent = TargetPart
		end
		self:Visible(true)
	end
end


local function Initialization(self)
	self.Character = Player.Character or Player.CharacterAdded:Wait()

	local PlayerCharacter = self.Character
	local Humanoid: Humanoid = PlayerCharacter:WaitForChild("Humanoid")
	self.Humanoid = Humanoid

	local ClientContainer = Instance.new("Folder")
	ClientContainer.Name = "_CLIENT_CONTAINER"
	ClientContainer.Parent = workspace
	self.ClientContainer = ClientContainer

	local Viewmodel = Miscs.Viewmodel:Clone()
	Viewmodel.Parent = ClientContainer
	self.Viewmodel = Viewmodel


	local WorldmodelShirt = PlayerCharacter:WaitForChild("Shirt", 10)
	if WorldmodelShirt then
		Viewmodel.Shirt.ShirtTemplate = WorldmodelShirt.ShirtTemplate
	else
		Viewmodel.Shirt.ShirtTemplate = ""
	end

	UpdateAppearance(self)

	local Animator: AnimationController = Viewmodel:FindFirstChildOfClass("AnimationController")
	if Animator then
		self.Animator = Animator
	else
		local Alt = Viewmodel:FindFirstChildOfClass("Humanoid")
		if Alt then
			self.Animator = Alt
		else
			warn("Not found 'AnimationController' or 'Humanoid' class inside Viewmodel, Please construct one!")
		end
	end

	self.Vars.Hold = false

	self.Vars.MuzzleFlashes = {}

	self.Vars.States = {}
	self.Vars.States.Reloading = false
	self.Vars.States.Equipped = false
	self.Vars.States.ActuallyEquipped = false
	self.Vars.States.IsBursting = false
	self.Vars.States.Aiming = false	

	self.Vars.DefaultWalkSpeed = Humanoid.WalkSpeed
	self.Vars.BobbingSpeedMultipilerCache = 0

	self.Vars.CurrentZoomLayer = 0

	self.CFrames.ProceduralCFrames = {}
	self.CFrames.ProceduralCFrames.Idle = CFZero

	self.CFrames.Sway = CFZero
	self.CFrames.Bobbing = CFZero


	self:Visible(true)
end


local ProjectileModule = require(game.ReplicatedStorage.Resources.Modules.ProjectileModule)

local function ToolActivation(self)
	local character = Player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local origin = CurrentCamera.CFrame.Position
	local cameraCF = CurrentCamera.CFrame
	local direction = cameraCF.LookVector

	RayCastFire(self, origin, direction)
end



function RayCastFire(self, origin, direction)
	local gunEvent: RemoteEvent = self.LocalResources:FindFirstChild("GunEvent")
	if not gunEvent then return end

	local Range = self.CurrentData.Commons.Range
	local MaxPenetration = self.CurrentData.Commons.MaxPenetration or 1
	local Bullet = Ballistics.new(origin, direction * Range, MaxPenetration)
	Bullet:Fire()

	local MuzzleFlash
	local fside = self.LocalResources:FindFirstChild("FireSide") 

	if self.Akimbo then
		if self.AkimboMuzzle == "Right" then
			MuzzleFlash = self.Viewmodel.GunModel.Grip_L:FindFirstChild("MuzzleFlash", true)
		elseif self.AkimboMuzzle == "Left" then
			MuzzleFlash = self.Viewmodel.GunModel.Grip:FindFirstChild("MuzzleFlash", true)
		end
	else
		MuzzleFlash = self.Viewmodel.GunModel.Grip:FindFirstChild("MuzzleFlash", true)
	end
	--local MuzzleFlash = self.Viewmodel:FindFirstChild("MuzzleFlash", true)

	if not self.CurrentData.Commons.WeaponType.Melee then 
		local LastHit = Bullet.Hits[#Bullet.Hits]

		if LastHit then
			_G.Controllers.RenderController.Render({
				Character = Player.Character,
				Effect = "Normal",
				Module = "Tracer", 
				Origin = if MuzzleFlash then MuzzleFlash.WorldCFrame.Position  else origin,
				End = LastHit.Position or origin + (direction * Range),
			})
		end
	end


	for _, Hit in Bullet.Hits do
		if Hit.Type == "Char" then
			local characterModel = workspace.Entity:FindFirstChild(Hit.CharacterName)
			game.ReplicatedStorage.HitmarkerEvent:Fire(self.CurrentData.Commons.Base_Damage, Hit.IsHeadshot, characterModel, Hit.Instance)
		end
	end

	print(Bullet)
	gunEvent:FireServer("Fire", Bullet:GetPacket())
	Bullet:Destroy()
end



local function AimDownSight(self)
	if not self.CurrentData.Commons.WeaponType.Sniper then return end
	if not IsFirstPerson() then return end

	local SniperConfig = self.CurrentData.Commons.Sniper_Config

	local zooms = SniperConfig and SniperConfig.ZoomLayer
	if not zooms or #zooms == 0 then return end

	self.Vars.CurrentZoomLayer = (self.Vars.CurrentZoomLayer or 0) + 1

	if self.Vars.CurrentZoomLayer > #zooms then
		self.Vars.CurrentZoomLayer = 0

		script:SetAttribute("___Aim", false)
		ShowScope(false)

		if self.Character then
			self.Character:SetAttribute("Scope",nil)
		end

		UserInputService.MouseDeltaSensitivity = DefaultSensitivity

		PlayAudio(self, self.CurrentData.AudioSettings.ZoomInit)
	else
		local goalFov = zooms[self.Vars.CurrentZoomLayer].FOV
		UserInputService.MouseDeltaSensitivity = DefaultSensitivity / zooms[self.Vars.CurrentZoomLayer].Weight

		script:SetAttribute("___Aim", true)
		ShowScope(true)

		if self.Character then
			self.Character:SetAttribute("Scope",goalFov)
		end

		if self.Vars.CurrentZoomLayer == 1 then
			PlayAudio(self, self.CurrentData.AudioSettings.ZoomInit)
		else
			PlayAudio(self, self.CurrentData.AudioSettings.Zoom)
		end
	end
end

local function equipFromLoadout(slotName)
	local loadout = Player:FindFirstChild("Loadout")
	if not loadout then return end

	local value = loadout:FindFirstChild(slotName)
	if not value then return end

	local toolName = value.Value
	if toolName == "" then return end

	local backpack = Player:WaitForChild("Backpack")
	local character = Player.Character or Player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	local tool = backpack:FindFirstChild(toolName)
	if tool then
		humanoid:UnequipTools()
		humanoid:EquipTool(tool)
	end
end

local GunSelection = require(game.ReplicatedStorage.Resources.Modules.ClientGunFramework.GunSelection)
local function InitialConnections(self)
	scopeButton.Activated:Connect(function()
		if not self.CurrentData or not self.CurrentItem then return end
		if not self.Vars.States.ActuallyEquipped or not self.Vars.States.Equipped then return end
		if self.Vars.States.Reloading then return end

		AimDownSight(self)
	end)
	

	task.spawn(function()
		while self and self.Vars do

			if Player.Character:FindFirstChild('AWP') and Player then scopeButton.Active = not false scopeButton.Visible = not false end
			if not Player.Character:FindFirstChild('AWP') and Player then scopeButton.Active =  false scopeButton.Visible =  false end
			task.wait(0.1)
		end
	end)
	local slots = { "Primary", "Secondary", "Melee" }
	local currentSlotIndex = 1
	local function equipCurrentSlot()
		equipFromLoadout(slots[currentSlotIndex])
	end
	primaryButton.Activated:Connect(function()
		equipFromLoadout("Primary")
	end)

	secondaryButton.Activated:Connect(function()
		equipFromLoadout("Secondary")
	end)
	local UserInputService = game:GetService("UserInputService")

	local function isConsole()
		return UserInputService.GamepadEnabled
			and not UserInputService.KeyboardEnabled
	end
	if isConsole and Players then
		UserInputService.InputBegan:Connect(function(input, gp)
			if gp then return end

			if input.KeyCode == Enum.KeyCode.ButtonR1 then
				currentSlotIndex += 1
				if currentSlotIndex > #slots then
					currentSlotIndex = 1
				end
				equipCurrentSlot()

			elseif input.KeyCode == Enum.KeyCode.ButtonL1 then
				currentSlotIndex -= 1
				if currentSlotIndex < 1 then
					currentSlotIndex = #slots
				end
				equipCurrentSlot()
			end
			if input.KeyCode == Enum.KeyCode.ButtonX then
				if self.Vars.States.Reloading then return end
				Reload(self)
			end
			if input.KeyCode == Enum.KeyCode.ButtonY then
				if self.Vars.States.Reloading then return end

				if (tick() - self.Vars.FirerateTick) < (60 / (self.CurrentData.Commons.Firerate * 1.2)) then
					return
				end

				if IsAnimationPlaying(self, "Inspect") then return end

				StopAudio(self, "Inspect")
				PlayAnimation(self, "Inspect")
				PlayAudio(self, self.CurrentData.AudioSettings.Inspect)
			end
		end)
	end


	meleeButton.Activated:Connect(function()
		equipFromLoadout("Melee")
	end)
	shootButton.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		if not self.CurrentData or not self.CurrentItem then return end
		if not self.Vars.States.ActuallyEquipped or not self.Vars.States.Equipped then return end
		if self.Vars.States.Reloading then return end
		if not self.Vars.States.AllowtoActivate then return end
		if self.TaskSchedulers.AllowedToFire then return end

		self.Vars.Hold = true
		FireLogic(self)
	end)
	shootButton.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		self.Vars.Hold = false
	end)


	Initialization(self)
	reloadButton.Activated:Connect(function()
		if self.Vars.States.Reloading then return end
		Reload(self)
	end)
	
	inspectButton.Activated:Connect(function()
		if self.Vars.States.Reloading then return end

		if (tick() - self.Vars.FirerateTick) < (60 / (self.CurrentData.Commons.Firerate * 1.2)) then
			return
		end

		if IsAnimationPlaying(self, "Inspect") then return end

		StopAudio(self, "Inspect")
		PlayAnimation(self, "Inspect")
		PlayAudio(self, self.CurrentData.AudioSettings.Inspect)
	end)
	local function updateMobileVisibility()
		if not UserInputService.TouchEnabled then
			reloadButton.Visible = false
			inspectButton.Visible = false
			shootButton.Visible = false
			return
		end

		local equipped = self.Vars.States.Equipped and self.Vars.States.ActuallyEquipped

		reloadButton.Visible = equipped
		shootButton.Visible = equipped
		inspectButton.Visible = equipped
	end
	task.spawn(function()
		while self and self.Vars do
			updateMobileVisibility()

			reloadButton.Active = not self.Vars.States.Reloading
			shootButton.Active = not self.Vars.States.Reloading
			inspectButton.Active = not self.Vars.States.Reloading

			task.wait(0.1)
		end
	end)

	table.insert(self.Connections, EventHandler.Event:Connect(function(...: any)
		local args = {...}
		if args[1]:lower() == "equip" then
			self:Equip(args[2])		
		elseif args[1]:lower() == "unequip" then
			self:Unequip()
		end
	end))

	table.insert(self.Connections, self.Viewmodel.Shirt:GetPropertyChangedSignal("ShirtTemplate"):Connect(function()
		UpdateAppearance(self)
	end))
	RunService:BindToRenderStep("Renderer", Enum.RenderPriority.Camera.Value + 2, function(deltaTime)
		Renderer(self, deltaTime)
	end)

	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end
		if not self.CurrentData or not self.CurrentItem then return end
		if not self.Vars.States.ActuallyEquipped or not self.Vars.States.Equipped then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			if self.Vars.States.Reloading then return end
			self.Vars.Hold = true
			if not self.Vars.States.AllowtoActivate then return end
			if self.TaskSchedulers.AllowedToFire then return end

			FireLogic(self) 
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
			AimDownSight(self)
		end

		if input.KeyCode == Enum.KeyCode.R then
			if self.Vars.States.Reloading then return end
			Reload(self)
		elseif input.KeyCode == Enum.KeyCode.V then
			if not self.Vars.States.AllowtoActivate then return end
			if self.Vars.States.Reloading then return end

			self.Vars.States.AllowtoActivate = false

			local AvailableFireMode = GetAllAvailableFireMode(self.CurrentData.Commons.FireMode)
			local CurrentFiremode = self.CurrentFiremode.Integer + 1
			if CurrentFiremode > #AvailableFireMode then
				CurrentFiremode = 1
			end

			self.CurrentFiremode = {
				String = AvailableFireMode[CurrentFiremode].Label,
				Integer = CurrentFiremode
			}

			self.Vars.States.AllowtoActivate = true
		elseif input.KeyCode == Enum.KeyCode.F then 
			if self.Vars.States.Reloading then return end
			if (tick() - self.Vars.FirerateTick) < (60 / (self.CurrentData.Commons.Firerate * 1.2)) then
				return
			end

			if IsAnimationPlaying(self, "Inspect") then
				return
			end
			StopAudio(self, "Inspect")
			PlayAnimation(self, "Inspect")
			PlayAudio(self, self.CurrentData.AudioSettings.Inspect)
		end


	end))
	table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if not self.CurrentData or not self.CurrentItem then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.Vars.Hold = false
		end
	end))
end

function ViewmodelHandler:Active()
	if self.Vars.States.Reloading then return end
	if not CanFire(self) then return end

	local ToolResources = self.LocalResources
	if not ToolResources then return end

	local CurrentAmmo = ToolResources:FindFirstChild("CurrentAmmo")
	local fireside = ToolResources:FindFirstChild("FireSide")
	if not CurrentAmmo then return end
	if self.CurrentData.Commons.AmmoPerMagazine ~= "INF" and CurrentAmmo.Value <= 0 then return end

	if self.TaskSchedulers.PumpAction then return end

	local shouldCheckFirerate = not self.Vars.States.IsBursting

	if fireside then self.Akimbo = true end

	if not shouldCheckFirerate or (tick() - self.Vars.FirerateTick) > (60 / self.CurrentData.Commons.Firerate) then
		local IsPumpAction = self.CurrentData.Commons.PumpAction
		local DelayedBeforePump = self.CurrentData.Commons.DelayBeforePump or .001

		local RecoilConfig = self.CurrentData.Commons.Recoil_Config
		local RandomXValue = RecoilConfig.Random_Yaw_KickPower
		local RandomZValue = RecoilConfig.TiltValue

		local ZValue = RandomZValue.Enabled and math.random(RandomZValue.Min, RandomZValue.Max) or 0

		self.Vars.Count += 1

		task.spawn(function()
			ToolActivation(self)
		end)

		if self.Akimbo then
			if fireside.Value == "Right" then
				fireside.Value = "Left"
				self.AkimboMuzzle = "Left"
				PlayAnimation(self, "Fire")
			else
				fireside.Value = "Right"
				self.AkimboMuzzle = "Right"
				PlayAnimation(self, "FireL")
			end
		else
			PlayAnimation(self, "Fire")
		end

		local fireSounds = self.CurrentData.AudioSettings.MultiFireSound -- randomize fire sounds if many
		if fireSounds then
			local soundNum = math.random(1,fireSounds)
			local sound = self.CurrentData.AudioSettings["Fire" .. soundNum]
			PlayAudio(self, sound or self.CurrentData.AudioSettings.Fire)
		else
			PlayAudio(self, self.CurrentData.AudioSettings.Fire)
		end

		--PlayAudio(self, self.CurrentData.AudioSettings["Fire"])

		EmitMuzzle(self)
		EjectShell(self)

		if IsPumpAction then
			self.TaskSchedulers.PumpAction = task.delay(DelayedBeforePump, function()
				if not self.Vars.States.Reloading then
					PlayAnimation(self, "PumpAction")
					PlayAudio(self, self.CurrentData.AudioSettings["BoltAction"])
				end
				self.TaskSchedulers.PumpAction = nil 
			end)
		end


		CameraRecoil:shove(Vec3(
			RandomXValue.Enabled and math.random(RandomXValue.Min, RandomXValue.Max) * .1 or RecoilConfig.Yaw_KickPower,
			RecoilConfig.Pitch_KickPower,
			ZValue
			), self.Vars.DeltaTime)

		if RecoilConfig.Recovery then
			task.delay(self.Vars.DeltaTime , function()
				CameraRecoil:shove(Vec3(
					0,
					-RecoilConfig.Pitch_KickPower,
					-ZValue
					), self.Vars.DeltaTime)
			end)
		end


		self.Vars.FirerateTick = tick()
	end
end

function ViewmodelHandler:Unequip()
	local Viewmodel = self.Viewmodel
	local Worldmodel: Model = Viewmodel:FindFirstChild("GunModel")

	Player.CameraMode = Enum.CameraMode.Classic

	script:SetAttribute("___Aim", false)
	ShowScope(false)

	if self.Character then
		self.Character:SetAttribute("Scope",nil)
	end

	for _, Audio in self.PlayingAudios do
		if Audio and Audio:IsA("Sound") then
			if Audio.IsPlaying or Audio.Playing then
				pcall(function() Audio:Stop() end)
			end

			if Audio.Parent then
				pcall(function() Audio:Destroy() end)
			end
		end
	end


	table.clear(self.PlayingAudios)

	if self.TaskSchedulers.AllowedToFire then
		task.cancel(self.TaskSchedulers.AllowedToFire)
		self.TaskSchedulers.AllowedToFire = nil		
	end
	if self.TaskSchedulers.AutoFire then
		task.cancel(self.TaskSchedulers.AutoFire)
		self.TaskSchedulers.AutoFire = nil
	end
	if self.TaskSchedulers.Burst then
		task.cancel(self.TaskSchedulers.Burst)
		self.TaskSchedulers.Burst = nil
	end
	if self.TaskSchedulers.Equip then
		task.cancel(self.TaskSchedulers.Equip)
		self.TaskSchedulers.Equip = nil
	end
	if self.TaskSchedulers["Reloading"] then
		task.cancel(self.TaskSchedulers["Reloading"])
		self.TaskSchedulers["Reloading"] = nil
	end
	if self.TaskSchedulers.PumpAction then
		task.cancel(self.TaskSchedulers.PumpAction)
		self.TaskSchedulers.PumpAction = nil
	end

	self.CurrentItem = nil
	self.CurrentData = nil

	if not self.LocalResources then return end

	local GunEvent: RemoteEvent = self.LocalResources:FindFirstChild("GunEvent")

	self:Visible(false)

	if GunEvent then	
		GunEvent:FireServer("ReloadCancel")
	end

	self.LocalResources = nil

	if Worldmodel then
		Worldmodel:ClearAllChildren()
	end	

	self.Vars.States.Aiming = false	
	self.Vars.States.Equipped = false	
	self.Vars.States.ActuallyEquipped = false
	self.Vars.States.Reloading = false
	self.Vars.States.IsBursting = false
	self.Akimbo = false;

	self.Vars.Hold = false
	self.Vars.Count = 0
	self.Vars.CurrentZoomLayer = 0

	UserInputService.MouseDeltaSensitivity = DefaultSensitivity

	for i,v in self.Animations do
		for _i,_v in v do
			StopAnimation(self, _i)
		end
	end
end

function ViewmodelHandler:Equip(Tool: Tool)
	self.CurrentItem = Tool
	self.CurrentData = require(Resources.Data[Tool.Name])

	self.Character = self.CurrentItem.Parent
	self.Humanoid = self.Character:WaitForChild("Humanoid")

	self.LocalResources = Tool:FindFirstChild("LocalResources")

	self.Vars.FirerateTick = tick()
	self.Vars.CurrentZoomLayer = 0

	self.Vars.Hold = false

	self.Vars.States.Aiming = false	
	self.Vars.States.Equipped = true
	self.Vars.States.AllowtoActivate = true
	self.Vars.States.ActuallyEquipped = false
	self.Vars.States.Reloading = false
	self.Vars.States.IsBursting = false

	script:SetAttribute("___Aim", false)
	ShowScope(false)

	if IsDead(self) then
		return
	end	

	repeat
		if self.Viewmodel then
			break
		end
		task.wait()
	until self.Viewmodel

	if self.TaskSchedulers.AllowedToFire then
		task.cancel(self.TaskSchedulers.AllowedToFire)
		self.TaskSchedulers.AllowedToFire = nil		
	end
	if self.TaskSchedulers.AutoFire then
		task.cancel(self.TaskSchedulers.AutoFire)
		self.TaskSchedulers.AutoFire = nil
	end
	if self.TaskSchedulers.Burst then
		task.cancel(self.TaskSchedulers.Burst)
		self.TaskSchedulers.Burst = nil
	end
	if self.TaskSchedulers.Equip then
		task.cancel(self.TaskSchedulers.Equip)
		self.TaskSchedulers.Equip = nil
	end
	if self.TaskSchedulers["Reloading"] then
		task.cancel(self.TaskSchedulers["Reloading"])
		self.TaskSchedulers["Reloading"] = nil
	end

	self.TaskSchedulers.Equip = task.delay(self.CurrentData["Commons"]["Equip_Time"], function()
		self.Vars.States.ActuallyEquipped = true	
	end)

	self.CurrentFiremode = {
		String = self.CurrentData["Commons"]["FireMode"][self.CurrentData["Commons"]["CurrentFiremode"]].Label;
		Integer = self.CurrentData["Commons"]["CurrentFiremode"];
	}
	self.Vars.Count = 0
	UserInputService.MouseDeltaSensitivity = DefaultSensitivity


	self:Visible(true)

	SetupGlovesModel(self)
	SetupGunModel(self)
	LoadAnimationTrack(self)

	PlayAudio(self, self.CurrentData.AudioSettings["Equip"])
	PlayAnimation(self, "Equip")
	PlayAnimation(self, "Idle")

	local WeaponModel = self.Character:FindFirstChild("GunModel")
	self.ShellEjectAttachment = self.Viewmodel.GunModel.Grip:FindFirstChild("ShellEject", true)
	if self.Akimbo then
		self.ShellEjectAttachment_L = self.Viewmodel.GunModel.Grip_L:FindFirstChild("ShellEject", true)
	end
end

function ViewmodelHandler:Visible(Boolean: boolean)
	local Viewmodel: Model = self.Viewmodel
	for index, value in Viewmodel:GetDescendants() do
		if value:IsA("BasePart") then
			value.LocalTransparencyModifier = (Boolean and 0 or 1)
		end
	end
end

function ViewmodelHandler.Initial()
	local self = setmetatable({
		CurrentItem = nil;
		CurrentData = {};

		CurrentFiremode = {
			String = "";
			Integer = 0;
		};

		LocalResources = nil;

		ClientContainer = nil;

		Character = nil;
		Humanoid = nil;

		Viewmodel = nil;
		Animator = nil;
		Akimbo = false;
		AkimboMuzzle = nil;
		PlayingAudios = {};

		Vars = {};
		CFrames = {};
		Animations = {};	

		TaskSchedulers = {};
		Connections = {};
	}, ViewmodelHandler)

	InitialConnections(self)

	return self
end

return ViewmodelHandler