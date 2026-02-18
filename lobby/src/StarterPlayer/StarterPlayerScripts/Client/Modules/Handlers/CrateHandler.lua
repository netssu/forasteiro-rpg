local Handler = {}

--services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

--player references
local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui

--ui references
local MainGui = PlayerGui:WaitForChild("TD")
local Frames = MainGui:WaitForChild("Frames")

--data references
local UserData = Player:WaitForChild("UserData")

--modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local StoredData = Modules:WaitForChild("StoredData")
local TowerData = require(StoredData:WaitForChild("TowerData"))

--chance templates
local ChanceCommon = script.Template_Common_Chance
local ChanceUncommon = script.Template_Uncommon_Chance
local ChanceRare = script.Template_Rare_Chance
local ChanceEpic = script.Template_Epic_Chance
local ChanceLegendary = script.Template_Legendary_Chance

--returns the appropriate chance template based on rarity
local function getChance(rarity)
	rarity = rarity or "Common"

	if rarity == "Common" then
		return ChanceCommon:Clone()
	elseif rarity == "Uncommon" then
		return ChanceUncommon:Clone()
	elseif rarity == "Rare" then
		return ChanceRare:Clone()
	elseif rarity == "Epic" then
		return ChanceEpic:Clone()
	elseif rarity == "Legendary" then
		return ChanceLegendary:Clone()
	end

	warn("Unknown rarity:", rarity)
	return ChanceCommon:Clone()
end

--formats a number with commas
local function formatWithCommas(n)
	return tostring(n):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

--handles all crate ui functionality
local function HandleCrateUI()
	task.spawn(function()

		--ui references
		local CrateFrame = Frames:WaitForChild("Crates")
		local PreviewContainer = CrateFrame:WaitForChild("ItemFrame")
		local ChancesFrame = CrateFrame:WaitForChild("ChancesFrame")
		local CratesContainer = CrateFrame:WaitForChild("ScrollingFrame")

		--preview elements
		local PreviewTitle = PreviewContainer:WaitForChild("CrateName")
		local OpenButton = PreviewContainer:WaitForChild("Open")
		local PurchaseButton = PreviewContainer:WaitForChild("Buy")
		local ChancesButton = PreviewContainer:WaitForChild("Chances")
		local PriceText = PurchaseButton:WaitForChild("Frame"):WaitForChild("Price")
		local OwnedAmountLabel = OpenButton:WaitForChild("Owned")
		local CrateIcon = PreviewContainer:WaitForChild("MainIcon")

		--crate data
		local CratePriceData = require(StoredData:WaitForChild("CrateData"))

		--state
		local SelectedCrate = "Normal"

		--crate icon assets
		local CrateIcons = {
			Normal = "rbxassetid://79132028062877",
			Steel = "rbxassetid://78854786317873",
			Golden = "rbxassetid://77544826310708",
			Diamond = "rbxassetid://139414131564390",
		}

		--updates the crate preview panel
		local function updatePreview(hideItemFrame)
			local CratesFolder = UserData:FindFirstChild("Crates")
			local Amount = 0

			--get owned amount
			if CratesFolder then
				local Crate = CratesFolder:FindFirstChild(SelectedCrate)
				if Crate then
					Amount = Crate.Value
				end
			end

			--toggle visibility
			if not hideItemFrame then
				CrateFrame.ItemFrame.Visible = true
			else
				CrateFrame.ChancesFrame.Visible = false
			end

			--update labels
			PreviewTitle.Text = SelectedCrate
			OwnedAmountLabel.Text = "Owned: " .. Amount

			--update icon
			if CrateIcons[SelectedCrate] then
				CrateIcon.Image = CrateIcons[SelectedCrate]
			end

			--update price display
			local price = CratePriceData[SelectedCrate] and CratePriceData[SelectedCrate].Price

			if price then
				PriceText.Parent.Icon.Visible = true
				PriceText.TextColor3 = Color3.fromRGB(255, 213, 0)
				PriceText.Text = "$" .. formatWithCommas(price)
			elseif SelectedCrate == "Diamond" then
				PriceText.Parent.Icon.Visible = false
				PriceText.TextColor3 = Color3.fromRGB(0, 255, 127)
				PriceText.Text = " 99"
			else
				PriceText.Parent.Icon.Visible = false
				PriceText.TextColor3 = Color3.fromRGB(255, 213, 0)
				PriceText.Text = "???"
			end
		end

		--setup crate selection buttons
		for _, Button in ipairs(CratesContainer:GetChildren()) do
			if not Button:IsA("ImageButton") then continue end

			local Holder = Button:FindFirstChild("Holder")
			local ButtonPriceText = Holder:FindFirstChild("Price")
			local Price = CratePriceData[Button.Name] and CratePriceData[Button.Name].Price

			--set button price text
			if Button.Name == "Diamond" then
				ButtonPriceText.Text = " 99"
			else
				ButtonPriceText.Text = "$" .. formatWithCommas(Price)
			end

			--selection handler
			Button.Activated:Connect(function()
				SelectedCrate = Button.Name
				ChancesFrame.Visible = false
				updatePreview()
			end)
		end

		--refresh preview when frame opens
		CrateFrame:GetPropertyChangedSignal("Visible"):Connect(function()
			if CrateFrame.Visible then
				updatePreview(true)
			end
		end)

		--open crate handler
		OpenButton.Activated:Connect(function()
			ReplicatedStorage.Remotes.Game.Unbox:FireServer(SelectedCrate)
			updatePreview()
		end)

		--toggle chances display
		ChancesButton.Activated:Connect(function()
			ChancesFrame.Visible = not ChancesFrame.Visible

			--clear existing chance entries
			for _, Frame in ipairs(ChancesFrame:GetChildren()) do
				if Frame:IsA("ImageButton") then
					Frame:Destroy()
				end
			end

			--populate chance entries
			if not SelectedCrate then return end
			if not CratePriceData[SelectedCrate] then return end

			local Contents = CratePriceData[SelectedCrate].Contains

			for TowerName, Chance in pairs(Contents) do
				local TowerStorage = ReplicatedStorage.Storage.Towers:FindFirstChild(TowerName)
				if not TowerStorage then continue end

				local Rarity = TowerStorage:GetAttribute("Rarity")
				local NewEntry = getChance(Rarity)

				NewEntry.Parent = ChancesFrame
				NewEntry.Visible = true
				NewEntry.Chance.Text = Chance / 10 .. "%"
				NewEntry.WormName.Text = TowerName

				--set tower icon
				if TowerData[TowerName] then
					NewEntry.Worm_Icon.Image = "rbxassetid://" .. TowerData[TowerName].ImageId
				end
			end
		end)

		--purchase crate handler
		PurchaseButton.Activated:Connect(function()
			local CratesFolder = UserData:FindFirstChild("Crates")
			if not CratesFolder then return end

			local Crate = CratesFolder:FindFirstChild(SelectedCrate)
			local oldAmount = Crate and Crate.Value or 0

			--handle purchase based on crate type
			if SelectedCrate == "Diamond" then
				MarketplaceService:PromptProductPurchase(Player, 3449816999)
			else
				ReplicatedStorage.Remotes.Game.PurchaseBox:FireServer(SelectedCrate)
			end

			--wait for purchase to complete and refresh
			task.spawn(function()
				local timeout = 3
				local startTime = tick()

				repeat
					task.wait(0.1)
					Crate = CratesFolder:FindFirstChild(SelectedCrate)
				until (Crate and Crate.Value > oldAmount) or (tick() - startTime > timeout)

				updatePreview()
			end)
		end)
	end)
end

--initialize
HandleCrateUI()

return Handler