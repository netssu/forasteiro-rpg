------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")

------------------//CONSTANTS
local SoundController = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("SoundUtility"))
local SoundData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("SoundData"))

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer.PlayerGui
local ButtonRegistry = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("HudManager"))
local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))

------------------//FUNCTIONS
local function check_function_exists(inst: Instance, funcName: string, attrType: string)
	local isStarter = (attrType == "Starter")
	if not ButtonRegistry.exists(funcName, isStarter) and not RunService:IsStudio() then
		warn(string.format("[Binder] A função '%s' definida no atributo '%s' do objeto '%s' não existe no Registry.", funcName, attrType, inst:GetFullName()))
	end
end

local function process_starter(inst: GuiObject)
	local starterFunc = inst:GetAttribute("Starter")
	if starterFunc then
		check_function_exists(inst, starterFunc, "Starter")
		ButtonRegistry.callStarter(starterFunc, {
			player = localPlayer,
			gui = inst,
			type = "starter"
		})
	end
end

local function bind_button_interaction(btn: GuiButton)
	local fname = btn:GetAttribute("Function")

	btn.MouseEnter:Connect(function()
		SoundController.PlaySFX(SoundData.SFX.Hover)
	end)

	if fname then
		check_function_exists(btn, fname, "Function")
		btn.Activated:Connect(function()
			SoundController.PlaySFX(SoundData.SFX.Click)
			ButtonRegistry.call(fname, {
				player = localPlayer,
				gui = btn,
				type = "button",
			})
		end)
	end
end

local function bind_textbox_interaction(tb: TextBox)
	local fname = tb:GetAttribute("Function")
	if fname then
		check_function_exists(tb, fname, "Function")
		tb:GetPropertyChangedSignal("Text"):Connect(function()
			ButtonRegistry.call(fname, {
				player = localPlayer,
				gui = tb,
				type = "textbox",
				text = tb.Text,
			})
		end)
	end
end

local function bind_element(inst: Instance)
	if not inst:IsA("GuiObject") then
		return
	end

	process_starter(inst)

	if inst:IsA("GuiButton") then
		bind_button_interaction(inst)
	elseif inst:IsA("TextBox") then
		bind_textbox_interaction(inst)
	end
end

local function bind_all(): ()
	local desc = playerGui:GetDescendants()
	for i , inst in desc do
		bind_element(inst)
	end
end

local function on_descendant_added(inst: Instance): ()
	bind_element(inst)
end

------------------//INIT
playerGui.DescendantAdded:Connect(on_descendant_added)
bind_all()

ButtonRegistry.load()
