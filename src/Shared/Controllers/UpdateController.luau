local UpdateController = {}

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- VARIABLES
local UpdateData = require(ReplicatedStorage.Modules.Constants.UpdatesData)
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local main = playerGui:WaitForChild("Main")
local frFrame = main:WaitForChild("UpdateFR")
local bgFrame = frFrame:WaitForChild("UpdateBG")
local scrollingFrame = bgFrame:WaitForChild("ScrollingFrame")
local template = scrollingFrame:WaitForChild("Template")

-- FUNCTIONS
local function applyStyle(titleLabel, phraseLabel, info)
	if titleLabel then
		titleLabel.TextSize = info.TitleSize
	end
	
	if phraseLabel then
		phraseLabel.TextSize = info.PhraseSize
	end
end

local function updateCanvasSize()
	local listLayout = scrollingFrame:FindFirstChildOfClass("UIListLayout")
	if listLayout then
		scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
	end
end

function UpdateController.InitializeUI()
	template.Visible = false
	
	local updates = UpdateData.GetUpdates()
	
	for _, info in ipairs(updates) do
		local newCard = template:Clone()
		
		local titleLbl = newCard:FindFirstChild("TitleLabel")
		local phraseLbl = newCard:FindFirstChild("PhraseLabel")
		
		if titleLbl and phraseLbl then
			titleLbl.Text = info.Title
			phraseLbl.Text = info.Phrase
			
			applyStyle(titleLbl, phraseLbl, info)
			
			newCard.Name = "Update_" .. info.Title
			newCard.Visible = true
			newCard.Parent = scrollingFrame
		end
	end
	
	updateCanvasSize()
	
	local listLayout = scrollingFrame:FindFirstChildOfClass("UIListLayout")
	if listLayout then
		listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)
	end
end

-- INIT
UpdateController.InitializeUI()

return UpdateController