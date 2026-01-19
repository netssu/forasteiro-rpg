export type StatusType = "Stunned" | "Slowed"

export type StatusData = {
	Type: StatusType,
	Duration: number,
	StartTime: number,
	Value: number?,
}

export type BrainrotState = "Hidden" | "Emerging" | "Active" | "Eating" | "Startled" | "Fleeing" | "Pulled" | "Escaped" | "Dead"

export type BrainrotData = {
	ID: string,
	Name: string,
	Part: BasePart,
	Health: number,
	MaxHealth: number,
	State: BrainrotState,
	Position: Vector3,
	GoalPosition: Vector3?,
	Speed: number,
	BaseSpeed: number,
	SpawnPoint: BasePart,
	TargetBrain: Model?,
	EatingStartTime: number?,
	EatingSpeed: number,
	DetectionRadius: number,
	BaseDetectionRadius: number,
	Rarity: string,
	Statuses: {StatusData},
	LanePosition: Vector3?,
	EscapeEndPosition: Vector3?,
}

return {}