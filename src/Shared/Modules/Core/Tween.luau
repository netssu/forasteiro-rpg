--!strict

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Tweens = {}
local MIN_MODEL_SCALE: number = 0.01

--\\ BEZIER CURVE FUNCTIONS \\ -- TR
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function quadraticBezier(t: number, p0: UDim2, p1: UDim2, p2: UDim2): UDim2
	return p1:Lerp(p2, t):Lerp(p2:Lerp(p0, t), t)
end

local function cubicBezier(t: number, p0: UDim2, p1: UDim2, p2: UDim2, p3: UDim2): UDim2
	local L1 = p1:Lerp(p2, t)
	local L2 = p2:Lerp(p3, t)
	return p0:Lerp(p1, t):Lerp(L1, t):Lerp(L1:Lerp(L2, t), t)
end

--\\ TWEEN FUNCTION \\ -- TR
function Tweens:Tween(Object: any, Duration: number, Style: string, Direction: string, Properties: {[string]: any}, Repeats: number?, Reverses: boolean?, Callback: () -> ())
	local TweenInfo = TweenInfo.new(Duration, Enum.EasingStyle[Style], Enum.EasingDirection[Direction], Repeats or 0, Reverses or false)
	local Tween = TweenService:Create(Object, TweenInfo, Properties)

	Tween:Play()

	if Callback then
		Tween.Completed:Once(function()
			Tween:Destroy()
			Callback()
		end)
	end

	return Tween
end

--\\ MODEL TWEEN FUNCTION \\ -- TR
function Tweens:TweenModel(Object: any, Duration: number, Style: string, Direction: string, Properties: {[string]: any}, Repeats: number?, Reverses: boolean?, Callback: () -> ())
	if not Object.Parent then return end

	local isModel = Object:IsA("Model")
	local Pivot = if isModel then Object:GetPivot() else Object.CFrame
	local CFrameValue = Instance.new("CFrameValue")
	CFrameValue.Value = Pivot

	local Shake = Object:FindFirstChild("Shake")
	local ShakeOffset = Vector3.new()

	CFrameValue.Changed:Connect(function()
		if not Object.Parent then
			CFrameValue:Destroy()
			return
		end

		local NewCFrame = CFrameValue.Value

		if Shake then
			ShakeOffset = ShakeOffset:Lerp(Vector3.new(
				math.random(-5, 5),
				math.random(-3, 3),
				math.random(-5, 5)
				), 0.03 * Shake.Value)
			NewCFrame = NewCFrame + ShakeOffset
		end

		Object:PivotTo(NewCFrame)
	end)

	local TweenInfo = TweenInfo.new(Duration, Enum.EasingStyle[Style], Enum.EasingDirection[Direction], Repeats or 0, Reverses or false)
	local Tween = TweenService:Create(CFrameValue, TweenInfo, Properties)

	Tween:Play()

	Tween.Completed:Connect(function()
		CFrameValue:Destroy()
		Tween:Destroy()
		if Callback then
			Callback()
		end
	end)

	return Tween
end

--\\ SCALE TWEEN FUNCTION \\ -- TR
function Tweens:TweenScale(Object: any, Duration: number, Style: string, Direction: string, TargetScale: number, Callback: () -> ())
	local StartTime = os.clock()
	local StartScale = Object:GetScale()
	local SafeTargetScale = math.max(TargetScale, MIN_MODEL_SCALE)

	local Connection
	Connection = RunService.RenderStepped:Connect(function(DeltaTime: number)
		local Elapsed = os.clock() - StartTime
		local Progress = math.min(1, Elapsed / Duration)

		local EasingValue = TweenService:GetValue(Progress, Enum.EasingStyle[Style], Enum.EasingDirection[Direction])
		local CurrentScale = lerp(StartScale, SafeTargetScale, EasingValue)
		if CurrentScale < MIN_MODEL_SCALE then
			CurrentScale = MIN_MODEL_SCALE
		end

		Object:ScaleTo(CurrentScale)

		if Progress >= 1 then
			Connection:Disconnect()
			if Callback then
				Callback()
			end
		end
	end)

	return Connection
end

return Tweens
