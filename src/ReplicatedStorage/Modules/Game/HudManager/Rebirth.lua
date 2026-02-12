------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local NEED_ICONS = {
	Coins = "rbxassetid://82346463581106",
	Power = "rbxassetid://113221502801232"
}

local PERK_ICONS = {
	Tokens = "rbxassetid://87250551762062",
	Reset = "rbxassetid://77228037161086"
}

local REBIRTH_SCALE = 0.5

------------------//VARIABLES
local RebirthController = {}
local localPlayer = Players.LocalPlayer

local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local RebirthConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("RebirthConfig"))
local MathUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("MathUtility"))
local NotificationUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("NotificationUtility"))

local rebirthEvent = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("RebirthAction")

local currentRebirths = 0
local currentCoins = 0
local currentPower = 0

local createdNeedFrames = {}
local createdPerkFrames = {}

local hasNotifiedAvailability = false

------------------//FUNCTIONS
local function get_ui_references()
	local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
	if not playerGui then return nil end

	local rebirthFrame = playerGui:FindFirstChild("Rebirth", true)
	if not rebirthFrame then return nil end

	local rebirthBG = rebirthFrame:FindFirstChild("RebirthBG")
	if not rebirthBG then return nil end

	local rebirthNeedFR = rebirthBG:FindFirstChild("RebirthNeedFR")
	local templateNeedBG = rebirthNeedFR and rebirthNeedFR:FindFirstChild("TemplateNeedBG")

	local rebirthPerksFR = rebirthBG:FindFirstChild("RebirthPerksFR")
	local templatePerksBG = rebirthPerksFR and rebirthPerksFR:FindFirstChild("TemplatePerksBG")

	local rebirthBT = rebirthBG:FindFirstChild("RebirthBT")

	local confirmationFrame = playerGui:FindFirstChild("Confirmation", true)
	local confirmationBG = confirmationFrame and confirmationFrame:FindFirstChild("ConfirmationBG")

	local confirmBT = confirmationBG and confirmationBG:FindFirstChild("ConfirmBT")
	local denyBT = confirmationBG and confirmationBG:FindFirstChild("DenyBT")
	local bgTX = confirmationBG and confirmationBG:FindFirstChild("BGTX")

	-- CORREÇÃO AQUI: Aplica o ZIndex no Frame PAI e no BG
	if confirmationFrame then
		confirmationFrame.ZIndex = 100 -- Prioridade Maxima para o container
	end

	if confirmationBG then
		confirmationBG.ZIndex = 100 -- Prioridade Maxima para o fundo
	end

	-- Garante que o Rebirth fique atras (opcional, mas seguro)
	if rebirthFrame then
		rebirthFrame.ZIndex = 1 
	end

	return {
		Main = rebirthFrame,
		NeedContainer = rebirthNeedFR,
		NeedTemplate = templateNeedBG,
		PerksContainer = rebirthPerksFR,
		PerksTemplate = templatePerksBG,
		RebirthButton = rebirthBT,
		Confirmation = {
			Main = confirmationFrame,
			ConfirmButton = confirmBT,
			DenyButton = denyBT,
			BgText = bgTX
		}
	}
end

local function clear_frames(frameTable)
	for _, frame in pairs(frameTable) do
		frame:Destroy()
	end
	table.clear(frameTable)
end

local function create_need_frame(needType, requiredAmount, currentAmount, parent, template)
	local newFrame = template:Clone()
	newFrame.Name = needType
	newFrame.Visible = true

	local imageItem = newFrame:FindFirstChild("ImageItem")
	local icon = NEED_ICONS[needType]
	if imageItem and icon then
		imageItem.Image = icon
	end

	local descriptionTX = newFrame:FindFirstChild("DescriptionTX")
	if descriptionTX then
		descriptionTX.Text = MathUtility.format_number(requiredAmount)
	end

	local checkImage = newFrame:FindFirstChild("CheckImage")
	if checkImage then
		checkImage.Visible = currentAmount >= requiredAmount
	end

	newFrame.Parent = parent
	return newFrame
end

local function create_perk_frame(perkType, perkAmount, parent, template)
	local newFrame = template:Clone()
	newFrame.Name = perkType
	newFrame.Visible = true

	local imageItem = newFrame:FindFirstChild("ImageItem")
	local icon = PERK_ICONS[perkType]
	if imageItem and icon then
		imageItem.Image = icon
	end

	local descriptionTX = newFrame:FindFirstChild("DescriptionTX")
	if descriptionTX then
		if perkType == "Tokens" then
			descriptionTX.Text = "+" .. perkAmount .. " Tokens"
		elseif perkType == "Reset" then
			descriptionTX.Text = "Reset Progress"
		end
	end

	newFrame.Parent = parent
	return newFrame
end

local function update_needs_display(ui)
	if not ui.NeedContainer or not ui.NeedTemplate then return end

	ui.NeedTemplate.Visible = false
	clear_frames(createdNeedFrames)

	local coinsReq, powerReq = RebirthConfig.GetRequirement(currentRebirths)

	local coinsFrame = create_need_frame("Coins", coinsReq, currentCoins, ui.NeedContainer, ui.NeedTemplate)
	createdNeedFrames["Coins"] = coinsFrame

	local powerFrame = create_need_frame("Power", powerReq, currentPower, ui.NeedContainer, ui.NeedTemplate)
	createdNeedFrames["Power"] = powerFrame
end

local function update_perks_display(ui)
	if not ui.PerksContainer or not ui.PerksTemplate then return end

	ui.PerksTemplate.Visible = false
	clear_frames(createdPerkFrames)

	local tokensFrame = create_perk_frame("Tokens", RebirthConfig.TOKENS_PER_REBIRTH, ui.PerksContainer, ui.PerksTemplate)
	createdPerkFrames["Tokens"] = tokensFrame

	local resetFrame = create_perk_frame("Reset", 0, ui.PerksContainer, ui.PerksTemplate)
	createdPerkFrames["Reset"] = resetFrame
end

local function check_availability_and_notify()
	local coinsReq, powerReq = RebirthConfig.GetRequirement(currentRebirths)
	local canRebirth = currentCoins >= coinsReq and currentPower >= powerReq

	if canRebirth then
		if not hasNotifiedAvailability then
			NotificationUtility:Info("Rebirth Available", 5)
			hasNotifiedAvailability = true
		end
	else
		hasNotifiedAvailability = false
	end

	return canRebirth
end

local function update_button_state(ui)
	if not ui.RebirthButton then return end

	local canRebirth = check_availability_and_notify()

	if canRebirth then
		ui.RebirthButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
		ui.RebirthButton.Active = true
	else
		ui.RebirthButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		ui.RebirthButton.Active = false
	end
end

local function update_full_ui()
	local ui = get_ui_references()
	if not ui then return end

	update_needs_display(ui)
	update_perks_display(ui)
	update_button_state(ui)
end

local function close_confirmation(ui)
	if ui.Confirmation.Main then
		ui.Confirmation.Main.Visible = false
	end
end

local function setup_interactions(ui)
	if ui.RebirthButton then
		ui.RebirthButton.Activated:Connect(function()
			local coinsReq, powerReq = RebirthConfig.GetRequirement(currentRebirths)
			if currentCoins >= coinsReq and currentPower >= powerReq then
				if ui.Confirmation.Main then
					ui.Confirmation.Main.Visible = true
					if ui.Confirmation.BgText then
						ui.Confirmation.BgText.Text = "Are you sure you want to Rebirth?"
					end
				end
			end
		end)
	end

	if ui.Confirmation.ConfirmButton then
		ui.Confirmation.ConfirmButton.Activated:Connect(function()
			rebirthEvent:FireServer()
			close_confirmation(ui)
		end)
	end

	if ui.Confirmation.DenyButton then
		ui.Confirmation.DenyButton.Activated:Connect(function()
			close_confirmation(ui)
		end)
	end
end

------------------//INIT
DataUtility.client.ensure_remotes()

DataUtility.client.bind("Rebirths", function(val)
	currentRebirths = val or 0
	update_full_ui()
end)

DataUtility.client.bind("Coins", function(val)
	currentCoins = val or 0
	update_full_ui()
end)

DataUtility.client.bind("PogoSettings.base_jump_power", function(val)
	currentPower = val or 0
	update_full_ui()
end)

rebirthEvent.OnClientEvent:Connect(function(status)
	if status == "Success" then
		local currentMult = 1 + (currentRebirths * REBIRTH_SCALE)
		local msg = string.format("You gained +1 Rebirth Token\nMultiplier: x%.1f", currentMult)

		NotificationUtility:Success(msg, 5)
		hasNotifiedAvailability = false
	end
end)

currentRebirths = DataUtility.client.get("Rebirths") or 0
currentCoins = DataUtility.client.get("Coins") or 0
currentPower = DataUtility.client.get("PogoSettings.base_jump_power") or 0

task.spawn(function()
	task.wait(1)
	local ui = get_ui_references()
	if ui then
		setup_interactions(ui)
		update_full_ui()
		close_confirmation(ui)
	end
end)

return RebirthController