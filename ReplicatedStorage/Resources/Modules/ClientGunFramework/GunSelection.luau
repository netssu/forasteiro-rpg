local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local PlayerGui: typeof(Player.PlayerGui) = Player:WaitForChild("PlayerGui")

local Resources = ReplicatedStorage:WaitForChild("Resources")
local Modules = Resources:WaitForChild("Modules")

local Weapons = require(Resources.Weapons)

local INGAME_HUD

local Primary
local Secondary
local Melee

local Icons:{ImageLabel}
local Selection

local TweenInfo1 = TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut)

local SelectedData = {ImageTransparency = 0}
local UnselectedData = {ImageTransparency = 0.4}

local module = {}

function module.Init(self)
	
	--[[INGAME_HUD = self.GunHud
	
	Primary = INGAME_HUD.Primary
	Secondary = INGAME_HUD.Secondary
	Melee = INGAME_HUD.Melee
	
	Selection = INGAME_HUD.Selected
	
	Icons = {
		Primary = Primary,
		Secondary = Secondary,
		Melee = Melee,
	}
	
	local ToolData = self.ToolData
	local ToolName = self.ToolName
	local ToolSlot = ToolData.Slot
	
	local SlotImage = Icons[ToolSlot]
	if not SlotImage then
		return
	end
	
	SlotImage.Visible = true]]
end





function module.Equip(self)
	print('equipped',self)
	
	--[[local ToolData = self.ToolData
	local ToolSlot = ToolData.Slot
	local Tool = self.Tool
	
	local SlotImage = Icons[ToolSlot]
	
	module.UnequipAll()
	
	if not SlotImage then
		return
	end
	
	SlotImage.ToolName.Visible = true
	
	local Tween = TweenService:Create(SlotImage,TweenInfo1,SelectedData)
	Tween:Play()
	Selection.Position = UDim2.new(0.999, 0,SlotImage.Position.Y.Scale,0)
	module.TweenSelection(true)]]
	
end

function module.Unequip(self)

	--[[local ToolData = self.ToolData
	local ToolSlot = ToolData.Slot

	local SlotImage = Icons[ToolSlot]
	if not SlotImage then
		return
	end
	
	SlotImage.ToolName.Visible = false

	local Tween = TweenService:Create(SlotImage,TweenInfo1,UnselectedData)
	Tween:Play()
	
	module.TweenSelection(false)]]
end


function module.UnequipAll()
	
	--[[for i, img in pairs(Icons) do
		local Tween = TweenService:Create(img,TweenInfo1,UnselectedData)
		Tween:Play()
	end
	
	module.TweenSelection(false)]]
end


function module.TweenSelection(state)
	--[[if state then
		Selection.ImageTransparency = 1
		TweenService:Create(Selection,TweenInfo1,{ImageTransparency = 0.5}):Play()
		return
	end
	TweenService:Create(Selection,TweenInfo1,{ImageTransparency = 1}):Play()]]
end


function module.UpdateIcons()
	
	local Backpack = Player.Backpack
	local Character = Player.Character
	
	local Tools = {}
	
	local function addTool(v)
		if v:IsA("Tool") then
			table.insert(Tools,v)
		end
	end
	
	for _, v in pairs(Backpack:GetChildren()) do
		addTool(v)
	end
	for _, v in pairs(Character:GetChildren()) do
		addTool(v)
	end
	
	for _, tool in pairs(Tools) do
		
		local DataModule = Resources:WaitForChild("Data"):FindFirstChild(tool.Name)
		if not DataModule then
			continue
		end
		
		local Data = require(DataModule)
		local metadata = {
			ToolData = Data
		}
		
		local InGameHud = PlayerGui.MAINHUD.InGame
		metadata.GunHud = InGameHud
		
		--module.Init(metadata,tool.Name)
		
	end
	
end

module.UpdateIcons()

return module
