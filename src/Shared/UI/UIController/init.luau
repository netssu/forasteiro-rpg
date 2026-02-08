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
	for _, Close: ImageButton in next, CollectionService:GetTagged('Close') do
		if Close:IsA('ImageButton') then
			UIController:SetupButton(Close, 'HUD', function()
				Animations:Play(
					Close,
					'Frame',
					'Default',
					'Close',
					{ ScreenGui = Close:FindFirstAncestorWhichIsA('ScreenGui') }
				)
			end)
		end
	end
end

return UIController
