local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local HudSounds = SoundService:WaitForChild("HudSounds")

local UIButton = {}
UIButton.__index = UIButton

function UIButton.new(button:GuiButton,useSounds:BoolValue,divisor:number)
	local self = setmetatable({},UIButton)
	
	self.Button = button
	self.Size = button.Size
	self.Position = button.Position
	
	self.HasSounds = useSounds
	self.Divisor = divisor or 2
	
	self.Hovering = false
	self.Pressing = false
	
	self.PressTween = TweenService:Create(button,TweenInfo.new(0.1),{
		Size = self.Size - UDim2.new(self.Size.X.Scale/self.Divisor,0,self.Size.Y.Scale/self.Divisor,0)
	})
	self.ReleaseTween = TweenService:Create(button,TweenInfo.new(0.15,Enum.EasingStyle.Bounce),{Size = self.Size})
	
	self.HoverTween = TweenService:Create(button,TweenInfo.new(0.1),{
		Size = self.Size + UDim2.new(self.Size.X.Scale/self.Divisor,0,self.Size.Y.Scale/self.Divisor,0)
	})
	
	self.ReleaseHoverTween = TweenService:Create(button,TweenInfo.new(0.15,Enum.EasingStyle.Bounce),{
		Size = self.Size + UDim2.new(self.Size.X.Scale/self.Divisor,0,self.Size.Y.Scale/self.Divisor,0)
	})
	
	button.Destroying:Connect(function()
		setmetatable(self,nil)
	end)
	
	return self
end


function UIButton:Press(state)
	if state then
		self.PressTween:Play()
		self.Pressing = true
		
		if self.HasSounds then
			HudSounds.Click:Play()
		end
		
	else
		self.Pressing = false
		
		if self.Hovering then
			self.ReleaseHoverTween:Play()
			return
		end
		
		self.ReleaseTween:Play()
	end
end

function UIButton:Hover(state)
	
	if state then
		self.Hovering = true
		self.HoverTween:Play()
		
		if self.HasSounds then
			HudSounds.Hover:Play()
		end
	else
		self.Hovering = false
		self.ReleaseTween:Play()
	end
	
end

return UIButton
