--!strict

local module = {}

type UpgradeContext = {
	Short: any,
	TweenService: TweenService,
	TweenModule: any,
	Packets: any,
	ActionUpgradeLevel: string,
	ActionUpgradeLevelMax: string,
	ActionUpgradeSpecial: string,
	MaxUpgradeLevel: number?,
	GetCoins: (() -> number?)?,
	GetUpgradeKey: (GroupId: string, SlotId: string, UpgradeId: string?) -> string,
	GetNumberAttribute: (Plot: Model, Key: string, Default: number) -> number,
	ConnectValueChanged: (Plot: Model, Key: string, Callback: () -> ()) -> (),
	DescribeChildren: (Parent: Instance) -> string,
	TweenButtonSize: (ButtonPart: BasePart, TargetSize: Vector3, Duration: number, OnComplete: (() -> ())?) -> (),
	DefaultNumber: number,
}

local _Ctx: UpgradeContext? = nil

local UPGRADE_SUCCESS_COLOR: Color3 = Color3.fromRGB(70, 255, 120)
local UPGRADE_FAIL_COLOR: Color3 = Color3.fromRGB(255, 70, 70)
local UPGRADE_PULSE_SCALE: number = 1.08
local UPGRADE_PULSE_TIME: number = 0.08

local _UpgradeUiMap: {
	[string]: {
		Button: GuiButton,
		Scale: UIScale,
		BaseScale: number,
		Stroke: UIStroke?,
		BaseColor: Color3,
		Model: Model?,
		ModelBaseScale: number?,
		ModelHighlight: Highlight?,
		Part: BasePart?,
		PartBaseSize: Vector3?,
		PartBaseColor: Color3?,
		PartHighlight: Highlight?,
	}
} = {}

local _UpgradeBoardWatchers: { [Instance]: RBXScriptConnection } = {}
local _UpgradeContainerWatchers: { [Instance]: RBXScriptConnection } = {}
local _BoardContexts: { [string]: { Plot: Model, GroupId: string, GroupConfig: any, GroupFolder: Instance, IsLocalOwner: boolean } } =
	{}

local function _DebugUpgrade(_: string, ...: any): ()
	return
end

local function _NormalizeName(Name: string): string
	local Lower: string = string.lower(Name)
	Lower = Lower:gsub("%s+", "")
	Lower = Lower:gsub("_", "")
	Lower = Lower:gsub("-", "")
	return Lower
end

local function _MakeBoardKey(Plot: Model, GroupId: string): string
	return string.format("%s|%s", Plot:GetFullName(), GroupId)
end

local function _GetCoins(): number?
	if not _Ctx then
		return nil
	end
	local Provider: any = (_Ctx :: UpgradeContext).GetCoins
	if typeof(Provider) == "function" then
		local Success: boolean, Value: any = pcall(Provider)
		if Success and typeof(Value) == "number" then
			return Value
		end
	end
	return nil
end

local function _SetBuyableGradient(Target: Instance?, CanBuy: boolean): ()
	if not Target then
		return
	end
	local Buyable: Instance? = Target:FindFirstChild("Buyable", true)
	if Buyable and Buyable:IsA("UIGradient") then
		Buyable.Enabled = CanBuy
	end
	local NotBuyable: Instance? = Target:FindFirstChild("NotBuyable", true)
	if NotBuyable and NotBuyable:IsA("UIGradient") then
		NotBuyable.Enabled = not CanBuy
	end
end

local function _ResolveBuyable(Cost: number?): boolean
	if not Cost then
		return false
	end
	if Cost <= 0 then
		return true
	end
	local Coins: number? = _GetCoins()
	if Coins == nil then
		return false
	end
	return Coins >= Cost
end

local function _MakeUpgradeUiKey(GroupId: string, SlotId: string, UpgradeId: string?): string
	return string.format("%s|%s|%s", GroupId, SlotId, UpgradeId or "Level")
end

local function _GetOrCreateScale(Button: GuiButton): UIScale
	local Existing: UIScale? = Button:FindFirstChildOfClass("UIScale")
	if Existing then
		return Existing
	end
	local Scale: UIScale = Instance.new("UIScale")
	Scale.Scale = 1
	Scale.Parent = Button
	return Scale
end

local function _FindCoinsAmount(Root: Instance): TextLabel?
	local Coins: Instance? = Root:FindFirstChild("Coins", true)
	if Coins then
		local Amount: Instance? = Coins:FindFirstChild("Amount", true)
		if Amount and Amount:IsA("TextLabel") then
			return Amount
		end
	end

	local Fallback: Instance? = Root:FindFirstChild("Amount", true)
	if Fallback and Fallback:IsA("TextLabel") then
		return Fallback
	end

	return nil
end

local function _FindTextLabel(Root: Instance, Name: string): TextLabel?
	local Result: Instance? = Root:FindFirstChild(Name, true)
	if Result and Result:IsA("TextLabel") then
		return Result
	end
	return nil
end

local function _FormatMultiplier(Value: number): string
	local Text: string = string.format("%.2f", Value)
	Text = Text:gsub("%.?0+$", "")
	return Text
end

local function _RoundValue(Value: number): number
	return math.floor(Value + 0.5)
end

local function _GetLevelTier(LevelConfig: any, Level: number): any?
	if Level <= 0 then
		return nil
	end
	local Tier: any = LevelConfig.Levels[Level]
	if Tier then
		return Tier
	end
	return LevelConfig.Levels[#LevelConfig.Levels]
end

local function _GetSpecialTier(SpecialConfig: any, Level: number): any?
	if Level <= 0 then
		return nil
	end
	local Tier: any = SpecialConfig.Levels[Level]
	if Tier then
		return Tier
	end
	return SpecialConfig.Levels[#SpecialConfig.Levels]
end

local function _GetSpecialMultiplier(Plot: Model, GroupId: string, SlotId: string, SpecialConfig: any): number
	local Ctx: UpgradeContext = _Ctx :: UpgradeContext
	local LevelKey: string = Ctx.GetUpgradeKey(GroupId, SlotId, SpecialConfig.Id)
	local Level: number = Ctx.GetNumberAttribute(Plot, LevelKey, Ctx.DefaultNumber)
	local Tier: any = _GetSpecialTier(SpecialConfig, Level)
	if Tier and typeof(Tier.Multiplier) == "number" then
		return Tier.Multiplier
	end
	return 1
end

local function _GetDropXpForLevel(LevelConfig: any, Level: number, XpMultiplier: number): number
	local BaseDrop: number = LevelConfig.BaseDropXp or 0
	local Bonus: number = 0
	if typeof(LevelConfig.Growth) == "number" then
		Bonus = math.max(0, Level - 1) * LevelConfig.Growth
	else
		local Tier: any = _GetLevelTier(LevelConfig, Level)
		if Tier and typeof(Tier.XpBonus) == "number" then
			Bonus = Tier.XpBonus
		end
	end
	return _RoundValue((BaseDrop + Bonus) * XpMultiplier)
end

local function _HasUpgradeDescendant(Target: Instance): boolean
	for _, Descendant: Instance in Target:GetDescendants() do
		local Normalized: string = _NormalizeName(Descendant.Name)
		if string.find(Normalized, "upgrade", 1, true) then
			return true
		end
		if Normalized == "levelup" then
			return true
		end
	end
	return false
end

local function _FindUpgradeBoard(GroupFolder: Instance, BoardName: string): Instance?
	local Candidates: { Instance } = {}
	for _, Descendant: Instance in GroupFolder:GetDescendants() do
		if Descendant.Name == BoardName then
			table.insert(Candidates, Descendant)
		end
	end

	if #Candidates == 0 then
		return nil
	end

	for _, Candidate: Instance in Candidates do
		if _HasUpgradeDescendant(Candidate) then
			return Candidate
		end
	end

	return Candidates[1]
end

local function _FindUpgradeRoot(Board: Instance, SlotId: string): Instance?
	local Direct: Instance? = Board:FindFirstChild("Upgrade" .. SlotId, true)
	if Direct then
		return Direct
	end

	local Variants: { string } = {
		"Upgrade " .. SlotId,
		"Upgrade_" .. SlotId,
		"Upgrade-" .. SlotId,
		"Upgrade" .. SlotId .. "_",
		"Upgrade" .. SlotId .. " ",
	}

	for _, Name: string in Variants do
		local Found: Instance? = Board:FindFirstChild(Name, true)
		if Found then
			return Found
		end
	end

	local Target: string = _NormalizeName("Upgrade" .. SlotId)
	local Candidates: { Instance } = {}
	for _, Descendant: Instance in Board:GetDescendants() do
		local Normalized: string = _NormalizeName(Descendant.Name)
		if Normalized == Target then
			return Descendant
		end
		if string.find(Normalized, "upgrade", 1, true) and string.find(Normalized, SlotId, 1, true) then
			table.insert(Candidates, Descendant)
		end
	end

	if #Candidates == 1 then
		return Candidates[1]
	end

	for _, Descendant: Instance in Board:GetDescendants() do
		if Descendant.Name == "LevelUp" and Descendant:IsA("GuiButton") then
			local Current: Instance? = Descendant.Parent
			while Current and Current ~= Board do
				local Normalized: string = _NormalizeName(Current.Name)
				if string.find(Normalized, "upgrade", 1, true) and string.find(Normalized, SlotId, 1, true) then
					return Current
				end
				Current = Current.Parent
			end
		end
	end

	return nil
end

local function _FindNormalizedDescendant(Parent: Instance, Target: string): Instance?
	local NormalizedTarget: string = _NormalizeName(Target)
	for _, Descendant: Instance in Parent:GetDescendants() do
		if _NormalizeName(Descendant.Name) == NormalizedTarget then
			return Descendant
		end
	end
	return nil
end

local function _HasDescendantWithName(Parent: Instance, Name: string): boolean
	for _, Descendant: Instance in Parent:GetDescendants() do
		if Descendant.Name == Name then
			return true
		end
	end
	return false
end

local function _FindLevelRootByButton(
	UpgradeRoot: Instance,
	UpgradeModel: Model?,
	Button: GuiButton
): Instance?
	local Current: Instance? = Button.Parent
	while Current and Current ~= UpgradeRoot and Current ~= UpgradeModel do
		if _HasDescendantWithName(Current, "Title") or _HasDescendantWithName(Current, "XP") or _HasDescendantWithName(Current, "Coins") then
			return Current
		end
		Current = Current.Parent
	end
	if Current and Current ~= UpgradeRoot and Current ~= UpgradeModel then
		return Current
	end
	return Button.Parent
end

local function _FindAnyLevelButton(UpgradeRoot: Instance, UpgradeModel: Model?): GuiButton?
	for _, Descendant: Instance in UpgradeRoot:GetDescendants() do
		if Descendant:IsA("GuiButton") and _NormalizeName(Descendant.Name) == "levelup" then
			return Descendant
		end
	end
	if UpgradeModel then
		for _, Descendant: Instance in UpgradeModel:GetDescendants() do
			if Descendant:IsA("GuiButton") and _NormalizeName(Descendant.Name) == "levelup" then
				return Descendant
			end
		end
	end
	return nil
end

local function _FindUpgradeModel(Board: Instance, UpgradeRoot: Instance, SlotId: string): Model?
	local TargetName: string = "Upgrade" .. SlotId .. "Model"
	local Direct: Instance? = Board:FindFirstChild(TargetName, true)
	if Direct and Direct:IsA("Model") then
		return Direct
	end

	local TargetNormalized: string = _NormalizeName(TargetName)
	for _, Descendant: Instance in Board:GetDescendants() do
		if Descendant:IsA("Model") and _NormalizeName(Descendant.Name) == TargetNormalized then
			return Descendant
		end
	end

	local Current: Instance? = UpgradeRoot
	while Current and Current ~= Board do
		if Current:IsA("Model") then
			local Normalized: string = _NormalizeName(Current.Name)
			if string.find(Normalized, "upgrade", 1, true)
				and string.find(Normalized, SlotId, 1, true)
				and string.find(Normalized, "model", 1, true)
			then
				return Current
			end
		end
		Current = Current.Parent
	end

	return nil
end

local function _FindUpgradePart(UpgradeRoot: Instance, SlotId: string, UpgradeModel: Model?): BasePart?
	if UpgradeModel then
		local TargetName: string = "Upgrade" .. SlotId
		for _, Descendant: Instance in UpgradeModel:GetDescendants() do
			if Descendant:IsA("BasePart") and Descendant.Name == TargetName then
				return Descendant
			end
		end
		if UpgradeModel.PrimaryPart then
			return UpgradeModel.PrimaryPart
		end
		for _, Descendant: Instance in UpgradeModel:GetDescendants() do
			if Descendant:IsA("BasePart") then
				return Descendant
			end
		end
	end

	if UpgradeRoot:IsA("BasePart") then
		return UpgradeRoot
	end

	if UpgradeRoot:IsA("Model") and UpgradeRoot.PrimaryPart then
		return UpgradeRoot.PrimaryPart
	end

	local TargetName: string = "Upgrade" .. SlotId
	for _, Descendant: Instance in UpgradeRoot:GetDescendants() do
		if Descendant:IsA("BasePart") and Descendant.Name == TargetName then
			return Descendant
		end
	end

	for _, Descendant: Instance in UpgradeRoot:GetDescendants() do
		if Descendant:IsA("BasePart") then
			return Descendant
		end
	end

	return nil
end

local function _FindLevelButton(UpgradeRoot: Instance): GuiButton?
	for _, Descendant: Instance in UpgradeRoot:GetDescendants() do
		if Descendant:IsA("GuiButton") and _NormalizeName(Descendant.Name) == "levelup" then
			return Descendant
		end
	end
	return nil
end

local function _FindMaxButton(UpgradeRoot: Instance, LevelRoot: Instance?, UpgradeModel: Model?): GuiButton?
	if LevelRoot then
		for _, Descendant: Instance in LevelRoot:GetDescendants() do
			if Descendant:IsA("GuiButton") and _NormalizeName(Descendant.Name) == "max" then
				return Descendant
			end
		end
	end

	for _, Descendant: Instance in UpgradeRoot:GetDescendants() do
		if Descendant:IsA("GuiButton") and _NormalizeName(Descendant.Name) == "max" then
			return Descendant
		end
	end

	if UpgradeModel then
		for _, Descendant: Instance in UpgradeModel:GetDescendants() do
			if Descendant:IsA("GuiButton") and _NormalizeName(Descendant.Name) == "max" then
				return Descendant
			end
		end
	end

	return nil
end

local function _WatchUpgradeBoard(
	Board: Instance,
	Plot: Model,
	GroupId: string,
	GroupConfig: any,
	GroupFolder: Instance,
	IsLocalOwner: boolean
): ()
	if _UpgradeBoardWatchers[Board] then
		return
	end

	_DebugUpgrade("Watching board descendants (plot=%s group=%s board=%s)", Plot.Name, GroupId, Board:GetFullName())
	_UpgradeBoardWatchers[Board] = Board.DescendantAdded:Connect(function(): ()
		local Connection: RBXScriptConnection? = _UpgradeBoardWatchers[Board]
		if Connection then
			Connection:Disconnect()
		end
		_UpgradeBoardWatchers[Board] = nil
		_DebugUpgrade("Board descendant added, retry setup (plot=%s group=%s)", Plot.Name, GroupId)
		module.SetupBoard(Plot, GroupId, GroupConfig, GroupFolder, IsLocalOwner)
	end)
end

local function _WatchUpgradeContainer(
	Target: Instance,
	Plot: Model,
	GroupId: string,
	GroupConfig: any,
	GroupFolder: Instance,
	IsLocalOwner: boolean
): ()
	if _UpgradeContainerWatchers[Target] then
		return
	end

	_DebugUpgrade(
		"Watching upgrade container (plot=%s group=%s target=%s)",
		Plot.Name,
		GroupId,
		Target:GetFullName()
	)
	_UpgradeContainerWatchers[Target] = Target.DescendantAdded:Connect(function(): ()
		local Connection: RBXScriptConnection? = _UpgradeContainerWatchers[Target]
		if Connection then
			Connection:Disconnect()
		end
		_UpgradeContainerWatchers[Target] = nil
		_DebugUpgrade("Upgrade container descendant added, retry setup (plot=%s group=%s)", Plot.Name, GroupId)
		module.SetupBoard(Plot, GroupId, GroupConfig, GroupFolder, IsLocalOwner)
	end)
end

local function _RegisterUpgradeButton(
	Button: GuiButton,
	GroupId: string,
	SlotId: string,
	UpgradeId: string?,
	OnClick: () -> (),
	UpgradeModel: Model?,
	UpgradePart: BasePart?
): ()
	local Key: string = _MakeUpgradeUiKey(GroupId, SlotId, UpgradeId)
	local Scale: UIScale = _GetOrCreateScale(Button)
	local Stroke: UIStroke? = Button:FindFirstChildOfClass("UIStroke")
	local BaseColor: Color3 = if Stroke then Stroke.Color else Button.BackgroundColor3
	local ModelHighlight: Highlight? = nil
	local PartHighlight: Highlight? = nil
	local HighlightTarget: Instance? = if UpgradePart then UpgradePart else UpgradeModel

	if HighlightTarget then
		local ExistingHighlight: Highlight? = HighlightTarget:FindFirstChildOfClass("Highlight")
		if ExistingHighlight then
			if HighlightTarget == UpgradeModel then
				ModelHighlight = ExistingHighlight
			else
				PartHighlight = ExistingHighlight
			end
		else
			local HighlightInstance: Highlight = Instance.new("Highlight")
			HighlightInstance.Enabled = false
			HighlightInstance.FillTransparency = 0.7
			HighlightInstance.OutlineTransparency = 0.7
			HighlightInstance.Adornee = HighlightTarget
			HighlightInstance.Parent = HighlightTarget
			if HighlightTarget == UpgradeModel then
				ModelHighlight = HighlightInstance
			else
				PartHighlight = HighlightInstance
			end
		end

		local ActiveHighlight: Highlight? = if HighlightTarget == UpgradeModel then ModelHighlight else PartHighlight
		if ActiveHighlight then
			ActiveHighlight.FillTransparency = 0.7
			ActiveHighlight.OutlineTransparency = 0.7
		end
	end

	local ModelBaseScale: number? = nil
	if UpgradeModel then
		local Success: boolean, ScaleValue: number = pcall(function(): number
			return UpgradeModel:GetScale()
		end)
		if Success then
			ModelBaseScale = ScaleValue
		end
	end

	_UpgradeUiMap[Key] = {
		Button = Button,
		Scale = Scale,
		BaseScale = Scale.Scale,
		Stroke = Stroke,
		BaseColor = BaseColor,
		Model = UpgradeModel,
		ModelBaseScale = ModelBaseScale,
		ModelHighlight = ModelHighlight,
		Part = UpgradePart,
		PartBaseSize = if UpgradePart then UpgradePart.Size else nil,
		PartBaseColor = if UpgradePart then UpgradePart.Color else nil,
		PartHighlight = PartHighlight,
	}

	if not Button:GetAttribute("UpgradeBound") then
		Button:SetAttribute("UpgradeBound", true)
		Button.Active = true
		Button.Selectable = true
		_DebugUpgrade("Bind button %s (group=%s slot=%s upgrade=%s)", Button:GetFullName(), GroupId, SlotId, tostring(UpgradeId))
		Button.Activated:Connect(function(): ()
			_DebugUpgrade("Click button (group=%s slot=%s upgrade=%s)", GroupId, SlotId, tostring(UpgradeId))
			OnClick()
		end)
	end
end

local function _PlayUpgradeFeedback(Key: string, Success: boolean): ()
	local Entry = _UpgradeUiMap[Key]
	if not Entry then
		_DebugUpgrade("Upgrade feedback missing UI key %s (success=%s)", Key, tostring(Success))
		return
	end

	local Button: GuiButton = Entry.Button
	local Scale: UIScale = Entry.Scale
	if not Button.Parent or not Scale.Parent then
		_DebugUpgrade("Upgrade feedback invalid UI key %s (success=%s)", Key, tostring(Success))
		return
	end
	local BaseScale: number = Entry.BaseScale
	local TargetScale: number = BaseScale * UPGRADE_PULSE_SCALE
	local FlashColor: Color3 = if Success then UPGRADE_SUCCESS_COLOR else UPGRADE_FAIL_COLOR

	if Entry.Stroke then
		Entry.Stroke.Color = FlashColor
	else
		Button.BackgroundColor3 = FlashColor
	end

	local Ctx: UpgradeContext = _Ctx :: UpgradeContext

	Scale.Scale = BaseScale
	local PulseTween: Tween = Ctx.TweenService:Create(
		Scale,
		TweenInfo.new(UPGRADE_PULSE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Scale = TargetScale }
	)

	PulseTween.Completed:Once(function(): ()
		Ctx.TweenService:Create(
			Scale,
			TweenInfo.new(UPGRADE_PULSE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Scale = BaseScale }
		):Play()
	end)

	PulseTween:Play()

	task.delay(0.18, function(): ()
		if Entry.Stroke then
			Entry.Stroke.Color = Entry.BaseColor
		else
			Button.BackgroundColor3 = Entry.BaseColor
		end
	end)

	local ScaledModel: boolean = false
	if Entry.Model and Entry.Model.Parent then
		local Model: Model = Entry.Model
		local BaseModelScale: number = Entry.ModelBaseScale or 1
		if not Entry.ModelBaseScale then
			local SuccessScale: boolean, ScaleValue: number = pcall(function(): number
				return Model:GetScale()
			end)
			if SuccessScale then
				BaseModelScale = ScaleValue
			end
		end
		local TargetModelScale: number = BaseModelScale * UPGRADE_PULSE_SCALE

		Ctx.TweenModule:TweenScale(Model, UPGRADE_PULSE_TIME, "Sine", "Out", TargetModelScale, function(): ()
			Ctx.TweenModule:TweenScale(Model, UPGRADE_PULSE_TIME, "Sine", "Out", BaseModelScale, nil)
		end)

		if Entry.ModelHighlight and not Entry.PartHighlight then
			Entry.ModelHighlight.FillColor = FlashColor
			Entry.ModelHighlight.OutlineColor = FlashColor
			Entry.ModelHighlight.Enabled = true
			task.delay(0.18, function(): ()
				if Entry.ModelHighlight then
					Entry.ModelHighlight.Enabled = false
				end
			end)
		end
		ScaledModel = true
	end

	if Entry.Part and Entry.Part.Parent then
		local Part: BasePart = Entry.Part
		if not ScaledModel then
			local BaseSize: Vector3 = Entry.PartBaseSize or Part.Size
			local TargetSize: Vector3 = BaseSize * UPGRADE_PULSE_SCALE
			Ctx.TweenButtonSize(Part, TargetSize, UPGRADE_PULSE_TIME, function(): ()
				Ctx.TweenButtonSize(Part, BaseSize, UPGRADE_PULSE_TIME, nil)
			end)
		end

		local BaseColor: Color3 = Entry.PartBaseColor or Part.Color
		Part.Color = FlashColor
		if Entry.PartHighlight then
			Entry.PartHighlight.FillColor = FlashColor
			Entry.PartHighlight.OutlineColor = FlashColor
			Entry.PartHighlight.Enabled = true
		end

		task.delay(0.18, function(): ()
			if Part.Parent then
				Part.Color = BaseColor
			end
			if Entry.PartHighlight then
				Entry.PartHighlight.Enabled = false
			end
		end)
	end
end

local function _UpdateLevelUpgradeUi(
	Plot: Model,
	GroupId: string,
	SlotId: string,
	SlotConfig: any,
	TitleLabel: TextLabel?,
	XpLabel: TextLabel?,
	CostLabel: TextLabel?
): (number?, boolean)
	local Ctx: UpgradeContext = _Ctx :: UpgradeContext
	local LevelKey: string = Ctx.GetUpgradeKey(GroupId, SlotId, "Level")
	local Level: number = Ctx.GetNumberAttribute(Plot, LevelKey, Ctx.DefaultNumber)
	local MaxLevel: number = Ctx.MaxUpgradeLevel or 100
	_DebugUpgrade("Level UI (plot=%s group=%s slot=%s level=%d)", Plot.Name, GroupId, SlotId, Level)

	if TitleLabel then
		TitleLabel.Text = string.format("Level %d", Level)
	end

	if Level >= MaxLevel then
		if CostLabel then
			CostLabel.Text = "MAX"
		end
		if XpLabel then
			XpLabel.Text = "MAX"
			XpLabel.RichText = false
		end
		return nil, false
	end

	local LevelConfig: any = SlotConfig.Upgrades.Level
	local NextTier: any = _GetLevelTier(LevelConfig, Level + 1)
	local Cost: number? = nil
	if NextTier and typeof(NextTier.Cost) == "number" then
		Cost = NextTier.Cost
	end
	if CostLabel then
		if Cost ~= nil then
			CostLabel.Text = Ctx.Short:Abbreviate(Cost)
		else
			CostLabel.Text = "MAX"
		end
	end

	local XpMultiplier: number = 1
	local Specials: any = SlotConfig.Upgrades.Specials
	if Specials and Specials.Xp then
		XpMultiplier = _GetSpecialMultiplier(Plot, GroupId, SlotId, Specials.Xp)
	end

	local CurrentXp: number = _GetDropXpForLevel(LevelConfig, Level, XpMultiplier)
	local NextXp: number = CurrentXp
	if NextTier then
		NextXp = _GetDropXpForLevel(LevelConfig, Level + 1, XpMultiplier)
	end

	if XpLabel then
		XpLabel.Text = string.format(
			"%s<font size=\"20\" color=\"rgb(50,150,255)\">XP</font>  >  %s<font size=\"20\" color=\"rgb(50,150,255)\">XP</font>",
			Ctx.Short:Abbreviate(CurrentXp),
			Ctx.Short:Abbreviate(NextXp)
		)
		XpLabel.RichText = true
	end
	return Cost, _ResolveBuyable(Cost)
end

local function _UpdateSpecialUpgradeUi(
	Plot: Model,
	GroupId: string,
	SlotId: string,
	UpgradeId: string,
	UpgradeConfig: any,
	Button: GuiButton
): ()
	local Ctx: UpgradeContext = _Ctx :: UpgradeContext
	local LevelKey: string = Ctx.GetUpgradeKey(GroupId, SlotId, UpgradeId)
	local Level: number = Ctx.GetNumberAttribute(Plot, LevelKey, Ctx.DefaultNumber)
	local NextTier: any = UpgradeConfig.Levels[Level + 1]
	_DebugUpgrade("Special UI (plot=%s group=%s slot=%s upgrade=%s level=%d)", Plot.Name, GroupId, SlotId, UpgradeId, Level)

	local TitleLabel: TextLabel? = nil
	local Content: Instance? = Button:FindFirstChild("Content", true)
	if Content then
		TitleLabel = _FindTextLabel(Content, "Title")
	end
	if not TitleLabel then
		TitleLabel = _FindTextLabel(Button, "Title")
	end

	local CostLabel: TextLabel? = _FindCoinsAmount(Button)

	local Multiplier: number = 1
	if NextTier and typeof(NextTier.Multiplier) == "number" then
		Multiplier = NextTier.Multiplier
	else
		local CurrentTier: any = _GetSpecialTier(UpgradeConfig, Level)
		if CurrentTier and typeof(CurrentTier.Multiplier) == "number" then
			Multiplier = CurrentTier.Multiplier
		end
	end

	if TitleLabel then
		TitleLabel.Text = string.format("%sx %s", _FormatMultiplier(Multiplier), UpgradeConfig.Label)
	end
	if CostLabel then
		if NextTier and typeof(NextTier.Cost) == "number" then
			CostLabel.Text = Ctx.Short:Abbreviate(NextTier.Cost)
		else
			CostLabel.Text = "MAX"
		end
	end
	local Cost: number? = if NextTier and typeof(NextTier.Cost) == "number" then NextTier.Cost else nil
	_SetBuyableGradient(Button, _ResolveBuyable(Cost))
end

function module.SetupBoard(
	Plot: Model,
	GroupId: string,
	GroupConfig: any,
	GroupFolder: Instance,
	IsLocalOwner: boolean
): ()
	if not _Ctx then
		return
	end
	_BoardContexts[_MakeBoardKey(Plot, GroupId)] = {
		Plot = Plot,
		GroupId = GroupId,
		GroupConfig = GroupConfig,
		GroupFolder = GroupFolder,
		IsLocalOwner = IsLocalOwner,
	}

	local Ctx: UpgradeContext = _Ctx :: UpgradeContext
	local Board: Instance? = _FindUpgradeBoard(GroupFolder, GroupConfig.BoardName)
	if not Board then
		_DebugUpgrade("Board not found (plot=%s group=%s board=%s)", Plot.Name, GroupId, GroupConfig.BoardName)
		return
	end
	_DebugUpgrade(
		"Board found (plot=%s group=%s board=%s class=%s children=%s)",
		Plot.Name,
		GroupId,
		Board:GetFullName(),
		Board.ClassName,
		Ctx.DescribeChildren(Board)
	)

	for SlotId: string, SlotConfig: any in GroupConfig.Slots do
		local UpgradeRoot: Instance? = _FindUpgradeRoot(Board, SlotId)
		if not UpgradeRoot then
			_DebugUpgrade("Upgrade root missing (plot=%s group=%s slot=%s)", Plot.Name, GroupId, SlotId)
			_WatchUpgradeBoard(Board, Plot, GroupId, GroupConfig, GroupFolder, IsLocalOwner)
			continue
		end
		_DebugUpgrade("Upgrade root found (plot=%s group=%s slot=%s root=%s)", Plot.Name, GroupId, SlotId, UpgradeRoot:GetFullName())

		local UpgradeModel: Model? = _FindUpgradeModel(Board, UpgradeRoot, SlotId)
		if UpgradeModel then
			local InModelRoot: Instance? = _FindUpgradeRoot(UpgradeModel, SlotId)
			if InModelRoot then
				UpgradeRoot = InModelRoot
				_DebugUpgrade(
					"Upgrade root overridden by model (plot=%s group=%s slot=%s root=%s)",
					Plot.Name,
					GroupId,
					SlotId,
					UpgradeRoot:GetFullName()
				)
			end
		end

		local UpgradePart: BasePart? = _FindUpgradePart(UpgradeRoot, SlotId, UpgradeModel)
		if UpgradeModel then
			_DebugUpgrade("Upgrade model found (plot=%s group=%s slot=%s model=%s)", Plot.Name, GroupId, SlotId, UpgradeModel:GetFullName())
		end
		if UpgradePart then
			_DebugUpgrade("Upgrade part found (plot=%s group=%s slot=%s part=%s)", Plot.Name, GroupId, SlotId, UpgradePart:GetFullName())
		end

		local LevelRoot: Instance? = UpgradeRoot:FindFirstChild("Level", true)
		if not LevelRoot then
			local Normalized: Instance? = _FindNormalizedDescendant(UpgradeRoot, "Level")
			if Normalized then
				LevelRoot = Normalized
			end
		end
		if not LevelRoot and UpgradeModel then
			local NormalizedInModel: Instance? = _FindNormalizedDescendant(UpgradeModel, "Level")
			if NormalizedInModel then
				LevelRoot = NormalizedInModel
			end
		end

		if not LevelRoot then
			local AnyButton: GuiButton? = _FindAnyLevelButton(UpgradeRoot, UpgradeModel)
			if AnyButton then
				LevelRoot = _FindLevelRootByButton(UpgradeRoot, UpgradeModel, AnyButton)
			end
		end

		if not LevelRoot then
			_DebugUpgrade("Level root missing (plot=%s group=%s slot=%s)", Plot.Name, GroupId, SlotId)
			if UpgradeModel then
				_DebugUpgrade("Upgrade model children (slot=%s) = %s", SlotId, Ctx.DescribeChildren(UpgradeModel))
			end
			_DebugUpgrade("Upgrade root children (slot=%s) = %s", SlotId, Ctx.DescribeChildren(UpgradeRoot))
			if UpgradeModel then
				_WatchUpgradeContainer(UpgradeModel, Plot, GroupId, GroupConfig, GroupFolder, IsLocalOwner)
			end
			_WatchUpgradeContainer(UpgradeRoot, Plot, GroupId, GroupConfig, GroupFolder, IsLocalOwner)
		end
		local LevelButton: GuiButton? = nil
		if LevelRoot then
			for _, Descendant: Instance in LevelRoot:GetDescendants() do
				if Descendant:IsA("GuiButton") and _NormalizeName(Descendant.Name) == "levelup" then
					LevelButton = Descendant
					break
				end
			end
		end
		if not LevelButton then
			LevelButton = _FindAnyLevelButton(UpgradeRoot, UpgradeModel)
		end
		if LevelButton and not LevelRoot then
			LevelRoot = _FindLevelRootByButton(UpgradeRoot, UpgradeModel, LevelButton)
		end

		if LevelRoot then
			if LevelButton then
				_DebugUpgrade("Level button found (plot=%s group=%s slot=%s)", Plot.Name, GroupId, SlotId)
			else
				_DebugUpgrade("Level root found but no button (plot=%s group=%s slot=%s)", Plot.Name, GroupId, SlotId)
			end
			local TitleLabel: TextLabel? = _FindTextLabel(LevelRoot, "Title")
			local XpLabel: TextLabel? = _FindTextLabel(LevelRoot, "XP")
			local CostLabel: TextLabel? = nil
			if LevelButton then
				CostLabel = _FindCoinsAmount(LevelButton)
			end
			if not CostLabel then
				CostLabel = _FindCoinsAmount(LevelRoot)
			end
			local MaxButton: GuiButton? = if IsLocalOwner then _FindMaxButton(UpgradeRoot, LevelRoot, UpgradeModel) else nil

			local function RefreshLevel(): ()
				local _, CanBuy: boolean = _UpdateLevelUpgradeUi(Plot, GroupId, SlotId, SlotConfig, TitleLabel, XpLabel, CostLabel)
				if LevelButton then
					_SetBuyableGradient(LevelButton, CanBuy)
				end
				if MaxButton then
					_SetBuyableGradient(MaxButton, CanBuy)
				end
			end

			RefreshLevel()

			local LevelKey: string = Ctx.GetUpgradeKey(GroupId, SlotId, "Level")
			Ctx.ConnectValueChanged(Plot, LevelKey, function(): ()
				RefreshLevel()
			end)

			local Specials: any = SlotConfig.Upgrades.Specials
			if Specials and Specials.Xp then
				local XpKey: string = Ctx.GetUpgradeKey(GroupId, SlotId, "Xp")
				Ctx.ConnectValueChanged(Plot, XpKey, function(): ()
					RefreshLevel()
				end)
			end

			if IsLocalOwner and LevelButton then
				_RegisterUpgradeButton(LevelButton, GroupId, SlotId, "Level", function(): ()
					Ctx.Packets.Machines:Fire(Ctx.ActionUpgradeLevel, {
						GroupId = GroupId,
						SlotId = SlotId,
					})
				end, UpgradeModel, UpgradePart)
			end

			if IsLocalOwner then
				if MaxButton then
					_RegisterUpgradeButton(MaxButton, GroupId, SlotId, "LevelMax", function(): ()
						Ctx.Packets.Machines:Fire(Ctx.ActionUpgradeLevelMax, {
							GroupId = GroupId,
							SlotId = SlotId,
						})
					end, UpgradeModel, UpgradePart)
				end
			end
		end

		local Specials: any = SlotConfig.Upgrades.Specials
		if Specials then
			local TemplateInstance: Instance? = UpgradeRoot:FindFirstChild("Templete", true)
			if not TemplateInstance then
				TemplateInstance = UpgradeRoot:FindFirstChild("Template", true)
			end
			local Template: GuiButton? = nil
			if TemplateInstance and TemplateInstance:IsA("GuiButton") then
				Template = TemplateInstance
			end
			if Template then
				_DebugUpgrade("Special template found (plot=%s group=%s slot=%s)", Plot.Name, GroupId, SlotId)
				Template.Visible = false
				local Container: Instance = Template.Parent

				local UpgradeIds: { string } = {}
				for UpgradeId: string in Specials do
					table.insert(UpgradeIds, UpgradeId)
				end
				table.sort(UpgradeIds)

				for _, UpgradeId: string in UpgradeIds do
					local UpgradeConfig: any = Specials[UpgradeId]
					local Existing: Instance? = Container:FindFirstChild(UpgradeId)
					local Button: GuiButton? = if Existing and Existing:IsA("GuiButton") then Existing else nil
					if not Button then
						local Clone: Instance = Template:Clone()
						Clone.Name = UpgradeId
						Clone.Visible = true
						Clone.Parent = Container
						if Clone:IsA("GuiButton") then
							Button = Clone
						end
					end

					if Button then
						_DebugUpgrade("Special button ready (plot=%s group=%s slot=%s upgrade=%s)", Plot.Name, GroupId, SlotId, UpgradeId)
						Button.Visible = true
						_UpdateSpecialUpgradeUi(Plot, GroupId, SlotId, UpgradeId, UpgradeConfig, Button)

						local UpgradeKey: string = Ctx.GetUpgradeKey(GroupId, SlotId, UpgradeId)
						Ctx.ConnectValueChanged(Plot, UpgradeKey, function(): ()
							_UpdateSpecialUpgradeUi(Plot, GroupId, SlotId, UpgradeId, UpgradeConfig, Button)
						end)

						if IsLocalOwner then
							_RegisterUpgradeButton(Button, GroupId, SlotId, UpgradeId, function(): ()
								Ctx.Packets.Machines:Fire(Ctx.ActionUpgradeSpecial, {
									GroupId = GroupId,
									SlotId = SlotId,
									UpgradeId = UpgradeId,
								})
							end, UpgradeModel, UpgradePart)
						end
					end
				end
			end
		end
	end
end

function module.HandleUpgradeResult(Data: any): ()
	if typeof(Data) ~= "table" then
		return
	end
	local GroupId: string? = if typeof(Data.GroupId) == "string" then Data.GroupId else nil
	local SlotId: string? = if typeof(Data.SlotId) == "string" then Data.SlotId else nil
	local UpgradeId: string? = if typeof(Data.UpgradeId) == "string" then Data.UpgradeId else nil
	local Success: boolean = Data.Success == true
	_DebugUpgrade(
		"UpgradeResult (group=%s slot=%s upgrade=%s success=%s)",
		tostring(GroupId),
		tostring(SlotId),
		tostring(UpgradeId),
		tostring(Success)
	)
	if GroupId and SlotId then
		local Key: string = _MakeUpgradeUiKey(GroupId, SlotId, UpgradeId)
		_PlayUpgradeFeedback(Key, Success)
	end
end

function module.RefreshBoards(): ()
	for _, Context in _BoardContexts do
		module.SetupBoard(Context.Plot, Context.GroupId, Context.GroupConfig, Context.GroupFolder, Context.IsLocalOwner)
	end
end

function module.Init(Context: UpgradeContext): ()
	_Ctx = Context
end

return module
