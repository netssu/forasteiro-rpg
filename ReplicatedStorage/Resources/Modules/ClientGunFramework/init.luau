local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui: typeof(Player.PlayerGui) = Player:WaitForChild("PlayerGui")

local Resources = ReplicatedStorage:WaitForChild("Resources")
local Modules = Resources:WaitForChild("Modules")

local GunSelection = require(script.GunSelection)

local UserInputService = game:GetService("UserInputService")

local ClientGunFramework = {}
ClientGunFramework.__index = ClientGunFramework


function RigAddresser(self, arg: {})
	if arg[1] == "Character" then
		return self.Character and self.Character:FindFirstChild(arg[2])
	elseif arg[1] == "GunModel" then
		return self.GunModel and self.GunModel:FindFirstChild(arg[2])
	end
end

function IsDead(self)
	return self.Humanoid and (self.Humanoid.Health <= 0)
end

function SetupGrip(self, enabled: boolean)
	if enabled then
		local rigData = self.ToolData["Rigging"]["Worldmodel"]
		local basePart = RigAddresser(self, rigData["BasePart"])
		local targetPart = RigAddresser(self, rigData["TargetPart"])

		self.GripJoint.Name = rigData["Name"]
		self.GripJoint.Part0 = basePart
		self.GripJoint.Part1 = targetPart
		self.GripJoint.C0 = rigData["Offset"]
		self.GripJoint.Parent = targetPart
		
		if self.Akimbo then
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

function OnUpdater(self)
	
	local Hud = self.GunHud
	
	local Ammo = Hud.Pc.Ammo
	local SelectedBar = Hud.Pc.Selected
	
	local weaponType = self.ToolData.Commons.WeaponType
	
	if not weaponType.Melee then
		Ammo.CurrentAmmo.Text = self.LocalResources.CurrentAmmo.Value.."/"
		Ammo.SpareAmmo.Text = self.ToolData["Commons"]["AmmoPerMagazine"]
	end
	
	--local Bound = self.GunHud.Container.Bound
	--Bound.GunName.Text = self.Tool.Name
	--Bound.CurrentAmmo.Text = self.LocalResources.CurrentAmmo.Value
	--Bound.TotalAmmo.Text = self.ToolData["Commons"]["AmmoPerMagazine"]
	--Bound.Mode.Text = self.ViewmodelHandlerEvent.Parent:GetAttribute("___FireMode")

	--Bound.Parent.Sniper.Visible = self.ViewmodelHandlerEvent.Parent:GetAttribute("___Aim")

	if IsDead(self) then
		OnUnequipped(self)
	end
end

function OnEquipped(self)
	local Hud = self.GunHud
	
	local weaponType = self.ToolData.Commons.WeaponType
	if not weaponType.Melee then
		Hud.Pc.Ammo.Visible = true
	end
	
	--self.GunHud.Enabled = true
	--self.GunHud.Parent = PlayerGui
	
	self.Character = self.Tool.Parent
	self.Humanoid = self.Character:WaitForChild("Humanoid")
	
	if self.GunModel:FindFirstChild("Grip_L") then
		self.Akimbo = true
	end
	
	SetupGrip(self, true)
	self.GunModel.Parent = self.Character

	Player.PlayerGui.HUD.CROSSHAIR.Enabled = true
	
	if self.ToolData.Commons.WeaponType.Shotgun then
		Player.PlayerGui.HUD.CROSSHAIR.SniperCursor.Visible = false
		Player.PlayerGui.HUD.CROSSHAIR.ShotgunCursor.Visible = true
		Player.PlayerGui.HUD.CROSSHAIR.Cursor.Visible = false
	elseif self.ToolData.Commons.WeaponType.Sniper then
			Player.PlayerGui.HUD.CROSSHAIR.SniperCursor.Visible = true
	    Player.PlayerGui.HUD.CROSSHAIR.ShotgunCursor.Visible = false
		Player.PlayerGui.HUD.CROSSHAIR.Cursor.Visible = false
	else
		Player.PlayerGui.HUD.CROSSHAIR.SniperCursor.Visible = false
		Player.PlayerGui.HUD.CROSSHAIR.ShotgunCursor.Visible = false
		Player.PlayerGui.HUD.CROSSHAIR.Cursor.Visible = true
	end


	if self.OnUpdater then
		self.OnUpdater:Disconnect()
		self.OnUpdater = nil
	end
	

	self.ViewmodelHandlerEvent:Fire("equip", self.Tool)
	self.OnUpdater = RunService.RenderStepped:Connect(function()
		OnUpdater(self)
	end)
	
	GunSelection.Equip(self)
end

function OnUnequipped(self)
	if not self then return end

	if self.OnUpdater then
		self.OnUpdater:Disconnect()
		self.OnUpdater = nil
	end

	if self.GunHud and self.GunHud.Parent then
		self.GunHud.Pc.Ammo.Visible = false
	end

	Player.PlayerGui.HUD.CROSSHAIR.Enabled = false
	
	self.Character = nil
	self.Humanoid = nil
	self.Akimbo = false

	if self.GunModel and self.GunModel.Parent then
		self.GunModel.Parent = self.Tool
	end

	SetupGrip(self, false)

	if self.ViewmodelHandlerEvent then
		self.ViewmodelHandlerEvent:Fire("unequip")
	end
	
	GunSelection.Unequip(self)
end



function ClientGunFramework:Destroy()
	Player.PlayerGui.HUD.CROSSHAIR.Enabled = false

	if self.OnUpdater then
		self.OnUpdater:Disconnect()
		self.OnUpdater = nil
	end

	if self.GunHud then
		self.GunHud.Pc.Ammo.Visible = false
	end
	
	for _, Connection in self.Connections do
		Connection:Disconnect()
	end

	SetupGrip(self, false)

	-- Reset mouse

	if self.GunModel then
		self.GunModel:Destroy()
	end

	if self.ViewmodelHandlerEvent then
		self.ViewmodelHandlerEvent:Fire("unequip")
	end

	-- Clear references
	self.Character = nil
	self.Humanoid = nil
	self.Tool = nil
	self.GunModel = nil
	self.LocalResources = nil
	self.GunEvent = nil
	self.ViewmodelHandlerEvent = nil
	self.Akimbo = false

	if self.GripJoint then
		self.GripJoint:Destroy()
		self.GripJoint = nil
	end
	if self.Akimbo then
		self.GripJoint_L:Destroy()
		self.GripJoint_L = nil
	end

	table.clear(self)
end

function ClientGunFramework.Initialize(Tool: Tool)
	

	local self = setmetatable({
		Tool = Tool,
		ToolData = require(Resources:WaitForChild("Data"):FindFirstChild(Tool.Name)),
		ToolName = Tool.Name,
		
		GunModel = Tool:FindFirstChild("GunModel"),
		LocalResources = Tool:WaitForChild("LocalResources"),
		GunEvent = nil,

		ViewmodelHandlerEvent = Modules:WaitForChild("ViewmodelHandler"):WaitForChild("ViewmodelHandler"),
		GunHud = nil,
		GripJoint = Instance.new("Motor6D"),
		GripJoint_L = Instance.new("Motor6D"),
		Akimbo = false,
		
		Connections = {},

		Character = nil,
		Humanoid = nil,
		OnUpdater = nil,
	}, ClientGunFramework)
	
	table.insert(self.Connections, Tool.ChildAdded:Connect(function(child)
		if child.Name == "GunModel" then
			if child == self.GunModel then
				return
			end
			
			local parent = nil
			if self.GunModel then
				parent = self.GunModel.Parent
				self.GunModel:Destroy()
			end
			
			self.GunModel = child
			self.GunModel.Parent = parent or self.Character
	
		end
	end))
	
	local GunEvent: RemoteEvent = self.LocalResources:WaitForChild("GunEvent")
	self.GunEvent = GunEvent
	
	local InGameHud = PlayerGui.MAINHUD.InGame
	
	self.GunHud = InGameHud
	
	--GunSelection.UpdateIcons()
	
	if GunEvent then
		GunEvent.OnClientEvent:Connect(function(...)
			local Args = {...}
			if Args[1] == "HideAudio" then
				if Args[2] then
					if Args[2]:IsA("Sound") then
						Args[2].Volume = 0
					end
				end
			end
		end)
	end
	
	table.insert(self.Connections, Tool.Equipped:Connect(function()
		OnEquipped(self)
	end))

	table.insert(self.Connections, Tool.Unequipped:Connect(function()
		OnUnequipped(self)
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
	
	return self
end

return ClientGunFramework