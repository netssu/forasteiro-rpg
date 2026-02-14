-- SERVICES
local Players = game:GetService('Players')
local CollectionService = game:GetService('CollectionService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- CONSTANTS
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild('PlayerGui')

-- VARIABLES
local UIController = {}
local AnimationManager = require(script.Animations)
local SoundController = require(ReplicatedStorage.Controllers.SoundController)
local SoundsData = require(ReplicatedStorage.Modules.Constants.SoundData)
local CurrentOpenFrame = nil

-- FUNCTIONS
export type ButtonConnections = {
	MouseEnter: RBXScriptConnection?,
	MouseLeave: RBXScriptConnection?,
	MouseDown: RBXScriptConnection?,
	MouseUp: RBXScriptConnection?,
}

function UIController:OpenFrame(frame: GuiObject | ScreenGui, animName: string?)
	if CurrentOpenFrame and CurrentOpenFrame ~= frame and CurrentOpenFrame.Visible then
		AnimationManager:PlayFrameAnimation(CurrentOpenFrame, animName or 'Default', 'Close')
	end
	
	CurrentOpenFrame = frame
	AnimationManager:PlayFrameAnimation(frame, animName or 'Default', 'Open')
end

function UIController:SetupButton(
	Button: GuiButton,
	AnimationType: string?,
	Callback: (() -> ())?
): ButtonConnections
	assert(Button and Button:IsA('GuiButton'), 'Invalid button')
	
	local animType = AnimationType or 'Default'
	local connections: ButtonConnections = {}
	
	connections.MouseEnter = Button.MouseEnter:Connect(function()
		SoundController.PlaySFX(SoundsData.SFX.Hover)
		AnimationManager:PlayButtonAnimation(Button, animType, 'MouseEnter')
	end)
	
	connections.MouseLeave = Button.MouseLeave:Connect(function()
		AnimationManager:PlayButtonAnimation(Button, animType, 'MouseLeave')
	end)
	
	connections.MouseDown = Button.MouseButton1Down:Connect(function()
		SoundController.PlaySFX(SoundsData.SFX.Click)
		AnimationManager:PlayButtonAnimation(Button, animType, 'MouseDown')
	end)
	
	connections.MouseUp = Button.MouseButton1Up:Connect(function()
		AnimationManager:PlayButtonAnimation(Button, animType, 'MouseUp')
		
		if Button:GetAttribute('Link') then
			local ScreenGui: ScreenGui = PlayerGui:FindFirstChild(Button:GetAttribute('Link'))
			if ScreenGui then
				local frameAnim = ScreenGui:GetAttribute('Animation') or 'Default'
				self:OpenFrame(ScreenGui, frameAnim)
			else
				warn('[UIController] ScreenGui não existe.')
			end
		end
		
		if Callback then 
			task.spawn(Callback)
		end
	end)
	
	return connections
end

function UIController:RegisterButton(button: GuiButton)
	if button:GetAttribute('UIController_Registered') then 
		return 
	end
	
	button:SetAttribute('UIController_Registered', true)
	
	if button.Parent and button.Parent.Name == 'SideBTFR' then
		if not button:GetAttribute('HoverScale') then
			button:SetAttribute('HoverScale', 1.12)
		end
		if not button:GetAttribute('HoverRotation') then
			button:SetAttribute('HoverRotation', 3)
		end
		
		self:SetupButton(button, 'Default', function()
			local Main = button:FindFirstAncestor('Main')
			if Main then
				local targetHud = Main:FindFirstChild(button.Name)
				if targetHud then
					self:OpenFrame(targetHud, 'Default')
				else
					warn('[UIController] Nenhuma HUD encontrada:', button.Name)
				end
			end
		end)
		
	elseif CollectionService:HasTag(button, 'Close') then
		if not button:GetAttribute('HoverScale') then
			button:SetAttribute('HoverScale', 1.12)
		end
		if not button:GetAttribute('HoverRotation') then
			button:SetAttribute('HoverRotation', 3)
		end
		
		self:SetupButton(button, 'Default', function()
			local targetFrame = button.Parent
			if targetFrame and targetFrame:IsA("GuiObject") then
				AnimationManager:PlayFrameAnimation(targetFrame, 'Default', 'Close')
			end
		end)
		
	else
		self:SetupButton(button, 'Default')
	end
end

function UIController:Start()
	SoundController.PlayMusic(SoundsData.Music.MainMenu, true, true)
	
	for _, descendant in ipairs(PlayerGui:GetDescendants()) do
		if descendant:IsA('GuiButton') then
			self:RegisterButton(descendant)
		end
	end
	
	PlayerGui.DescendantAdded:Connect(function(descendant)
		if descendant:IsA('GuiButton') then
			self:RegisterButton(descendant)
		end
	end)
end

-- INIT
return UIController