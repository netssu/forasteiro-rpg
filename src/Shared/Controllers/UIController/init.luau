local UIController = {}

-- // Services
local Player = game:GetService('Players').LocalPlayer
local CollectionService = game:GetService('CollectionService')

-- // Dependencies
local Animations = require(script.Animations)

-- // Types
export type ButtonConnections = {
	MouseEnter: RBXScriptConnection?,
	MouseLeave: RBXScriptConnection?,
	MouseDown: RBXScriptConnection?,
	MouseUp: RBXScriptConnection?,
}

-- // Variables
local PlayerGui = Player:WaitForChild('PlayerGui')

-- // Public Functions
function UIController:SetupButton(
	Button: GuiButton,
	Animation: string?,
	Callback: () -> ()?
): ButtonConnections
	assert(Button and Button:IsA('GuiButton'), 'Invalid button')

	local connections: ButtonConnections = {}

	connections.MouseEnter = Button.MouseEnter:Connect(function()
		Animations:Play(Button, 'Button', Animation or 'Default', 'MouseEnter')
	end)

	connections.MouseLeave = Button.MouseLeave:Connect(function()
		Animations:Play(Button, 'Button', Animation or 'Default', 'MouseLeave')
	end)

	connections.MouseDown = Button.MouseButton1Down:Connect(function()
		Animations:Play(Button, 'Button', Animation or 'Default', 'MouseDown')
	end)

	connections.MouseUp = Button.MouseButton1Up:Connect(function()
		Animations:Play(Button, 'Button', Animation or 'Default', 'MouseUp')

		if Button:GetAttribute('Link') then
			local ScreenGui: ScreenGui =
				PlayerGui:FindFirstChild(Button:GetAttribute('Link'))

			if ScreenGui then
				local AnimationFrame =
					ScreenGui:GetAttribute('Animation') :: string

				if AnimationFrame then
					Animations:Play(ScreenGui, 'Frame', AnimationFrame, 'Open')
				else
					Animations:Play(ScreenGui, 'Frame', 'Default', 'Open')
				end
			else
				warn('[UIController] ScreenGui not exist.')
			end
		end

		if Callback then task.spawn(function()
				Callback()
			end) end
	end)

	return connections
end

function UIController:Start()
	local function registerButton(button: GuiButton)
		if button:GetAttribute('UIController_Registered') then return end
		button:SetAttribute('UIController_Registered', true)

		if button.Parent and button.Parent.Name == 'SideBTFR' then
			self:SetupButton(button, 'HUD', function()
				local Main = button:FindFirstAncestor('Main')

				if Main then
				
					local targetHud = Main:FindFirstChild(button.Name)

					if targetHud then
						Animations:Play(targetHud, 'Frame', 'Default', 'Open')
					else
						warn('[UIController] Nenhuma HUD encontrada com o nome:', button.Name)
					end
				end
			end)

		elseif CollectionService:HasTag(button, 'Close') then
			self:SetupButton(button, 'HUD', function()
				local targetFrame = button.Parent

				if targetFrame and targetFrame:IsA("GuiObject") then
					Animations:Play(
						targetFrame,
						'Frame',
						'Default',
						'Close'
					)
				end
			end)

		else
			self:SetupButton(button, 'Default')
		end
	end

	for _, descendant in ipairs(PlayerGui:GetDescendants()) do
		if descendant:IsA('GuiButton') then
			registerButton(descendant)
		end
	end

	PlayerGui.DescendantAdded:Connect(function(descendant)
		if descendant:IsA('GuiButton') then
			registerButton(descendant)
		end
	end)
end

return UIController