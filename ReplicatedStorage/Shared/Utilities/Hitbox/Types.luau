local Goodsignal = require(script.Parent.GoodSignal)

export type Hitbox = {
	HitList: {BasePart},
	
	Touched: Goodsignal.Signal<BasePart, Humanoid?>,
	
	VisualizerTransparency: number,
	VisualizerMaterial: Enum.Material,
	VisualizerColor: Color3,
	Visualizer: boolean,
	
	DetectionMode: ("Default" | "ConstantDetection" | "HitOnce" | "HitOne" | "HitParts"),
	OverlapParams: OverlapParams,
	
	PredictionVector: Vector3 | vector,
	PredictionTime: number,
	Prediction: boolean,
	FollowPart: BasePart,

	Size: Vector3,
	Shape: Enum.PartType,
	Offset: CFrame,
	
	Duration: number,
	Rate: number,
	
	Start: (self: Hitbox) -> (),
	Stop: (self: Hitbox) -> (),
	Destroy: (self: Hitbox) -> (),
} & any

return {}