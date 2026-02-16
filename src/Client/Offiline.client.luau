local TweenService_upvr = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Modules.Game.Packets)

local _offlineInvokeReady = false
local _offlineInvokeHandler = nil

Packets.OfflineEarning.OnClientInvoke = function(arg1)
	if _offlineInvokeReady and _offlineInvokeHandler then
		return _offlineInvokeHandler(arg1)
	end

	local timeoutAt = os.clock() + 10
	while os.clock() < timeoutAt do
		if _offlineInvokeReady and _offlineInvokeHandler then
			return _offlineInvokeHandler(arg1)
		end
		task.wait()
	end

	warn("[OfflineEarning] invoke received before client handler was ready")
	return false
end

local Playergui = game:GetService("Players").LocalPlayer.PlayerGui
local guioff = Playergui:WaitForChild("OfflineEarning")
local White_upvr = guioff.White
local Title_upvr = White_upvr.Title
local Alert_upvr = guioff.Alert

local TweenInfo_new_result1_upvr = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local any_Create_result1_upvr_3 = TweenService_upvr:Create(Title_upvr, TweenInfo_new_result1_upvr, {
	TextTransparency = 1;
})
local any_Create_result1_upvr_4 = TweenService_upvr:Create(Title_upvr.UIStroke, TweenInfo_new_result1_upvr, {
	Transparency = 1;
})
local function DoTextEffect_upvr(arg1, arg2, arg3)
	Title_upvr.MaxVisibleGraphemes = 0
	Title_upvr.TextTransparency = 0
	Title_upvr.UIStroke.Transparency = 0
	Title_upvr.Text = arg1
	for i = 1, #Title_upvr.Text do
		Title_upvr.MaxVisibleGraphemes = i
		if not arg3 then
			game.SoundService.SFX.TextClick.PlaybackSpeed = math.random(900, 1100) / 1000
			game.SoundService.SFX.TextClick:Play()
		end
		wait(0.025)
	end
	task.wait(arg2)
	if Title_upvr.Text ~= arg1 then
	else
		any_Create_result1_upvr_3:Play()
		any_Create_result1_upvr_4:Play()
		task.wait(TweenInfo_new_result1_upvr.Time)
	end
end
local any_Create_result1_upvr = TweenService_upvr:Create(workspace.CurrentCamera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
	FieldOfView = 100;
})
local any_Create_result1_upvr_6 = TweenService_upvr:Create(White_upvr, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
	BackgroundTransparency = 0;
})
local any_Create_result1_upvr_5 = TweenService_upvr:Create(workspace.CurrentCamera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
	FieldOfView = 70;
})
local any_Create_result1_upvr_2 = TweenService_upvr:Create(White_upvr, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
	BackgroundTransparency = 1;
})
local var26_upvw = false
local var27_upvw = false

_offlineInvokeHandler = function(arg1)
	task.wait(1.5)
	local Saturation_upvr = game.Lighting.ColorCorrection.Saturation
	local Contrast_upvr = game.Lighting.ColorCorrection.Contrast
	local Brightness_upvr = game.Lighting.ColorCorrection.Brightness
	
	White_upvr.Visible = true
	
	TweenService_upvr:Create(game.Lighting.ColorCorrection, TweenInfo.new(3.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
		Saturation = -0.5;
		Contrast = -0.2;
	}):Play()
	
	if os.date("%x") == "12/25/25" then
		DoTextEffect_upvr("Merry Christmas! ❤️", 2)
		task.wait(0.5)
	elseif os.date("%x") == "02/14/25" then
		DoTextEffect_upvr("Happy Valentine's Day! ❤️", 2)
		task.wait(0.5)
	elseif os.date("%x") == "06/12/26" then
		DoTextEffect_upvr("Happy Valentine's Day Brazil! ❤️", 2)
	end
	
	task.wait(0.5)
	task.spawn(DoTextEffect_upvr, "When you left it looked like this...", 4.5)
	task.wait(2.5)
	any_Create_result1_upvr:Play()
	any_Create_result1_upvr_6:Play()
	task.wait(0.3)

		game.SoundService.SFX.OfflineEarningNotif:Play()
		task.wait(0.35)
		any_Create_result1_upvr_5:Play()
		task.wait(0.1)
		task.spawn(function()
			Title_upvr.MaxVisibleGraphemes = 0
			Title_upvr.TextTransparency = 0
			Title_upvr.UIStroke.Transparency = 0
			Title_upvr.Text = "Now it looks like this!"
			for i_2 = 1, #Title_upvr.Text do
				Title_upvr.MaxVisibleGraphemes = i_2
				wait(0.025)
			end
			task.wait(4.5)
			if Title_upvr.Text ~= "Now it looks like this!" then
			else
				any_Create_result1_upvr_3:Play()
				any_Create_result1_upvr_4:Play()
				task.wait(TweenInfo_new_result1_upvr.Time)
			end
		end)
		game.Lighting.ColorCorrection.Saturation = Saturation_upvr
		game.Lighting.ColorCorrection.Contrast = Contrast_upvr
		game.Lighting.ColorCorrection.Brightness = Brightness_upvr
		
		any_Create_result1_upvr_2:Play()
		game.SoundService.SFX.OfflineEarning3:Play()
	return true
end
_offlineInvokeReady = true

game:GetService("GuiService").MenuOpened:Connect(function()
	if var27_upvw then
	else
		var27_upvw = true
		guioff.Alert.Visible = true
		game.SoundService.SFX.OfflineEarningNotif:Play()
		wait(.3)
		var27_upvw = false
	end
end)

game:GetService("GuiService").MenuClosed:Connect(function()
	guioff.Alert.Visible = false
end)

task.wait(15)
var26_upvw = true
