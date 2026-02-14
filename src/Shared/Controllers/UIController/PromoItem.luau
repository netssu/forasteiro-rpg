-- SERVICES
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- VARIABLES
local PromoItemModule = {}
local player = Players.LocalPlayer
local playerGui = player.PlayerGui

-- UI
local Main = playerGui:WaitForChild("Main")
local HUDFR = Main:WaitForChild("HUDFR")
local PromoItemFR = HUDFR:WaitForChild("PromoItemFR")
local GlowBG = PromoItemFR:WaitForChild("GlowBG")
local ImageLabel = PromoItemFR:WaitForChild("ImageLabel")

local originalSize = ImageLabel.Size

local spinInfo = TweenInfo.new(
	10,
	Enum.EasingStyle.Linear,
	Enum.EasingDirection.InOut,
	-1
)

local spinTween = TweenService:Create(GlowBG, spinInfo, {
	Rotation = 360
})
spinTween:Play()

local pulseInfo = TweenInfo.new(
	1.1,
	Enum.EasingStyle.Sine,
	Enum.EasingDirection.InOut,
	-1,
	true 
)

local pulseTween = TweenService:Create(ImageLabel, pulseInfo, {
	Size = UDim2.new(
		originalSize.X.Scale,
		originalSize.X.Offset + 8,
		originalSize.Y.Scale,
		originalSize.Y.Offset + 8
	)
})

pulseTween:Play()

-- INIT
return PromoItemModule
