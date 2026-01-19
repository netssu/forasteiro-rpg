-- NEEDS UPDATING

--// Services //--
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Configs = Shared.Configs
local Utilities = Shared.Utilities

local TankConfig = require(Configs.TankConfig)

-- Centralized type definitions for Base and components
export type TankData = {
	Name: string,
	Unlocked: boolean,
	Level: number,
	Brainrot: string?,
	BrainrotCount: number,
	UsesRemaining: number,
	Model: Model?,
	Dropper: Part?,
	Button: Part?,
	Cell: Part?,
	ItemTravelTime: number?,
	Config: TankConfig.TankInfo,
	Debounce: boolean,
}

export type ProductionItemData = {
	Name: string,
	Value: string, -- BigNum serialized string
	SpawnTime: number,
	ArrivalTime: number,
}

export type CustomerData = {
	Instance: Part,
	QueuePosition: number,
	CurrentCheckpoint: number,
	PurchaseComplete: boolean,
}

export type BaseObject = {
	ID: number,
	Folder: Folder,
	Owned: boolean,
	Owner: Player?,
	Building: Model?,
	Foundation: Part,
	ConveyorCheckpoints: {[number]: Attachment},
	-- Components
	Tank: TankClass,
	Production: ProductionClass,
	Customer: CustomerClass,
	Cage: CageClass,
}

export type CageClass = {
	new: (baseObject: BaseObject) -> CageClass,
	Base: BaseObject,
	Values: Folder?,
	Contents: {[string]: number},
	onSpawnBuilding: (self: CageClass) -> (),
	addBrainrots: (self: CageClass, brainrots: {[string]: number}) -> number,
	removeBrainrots: (self: CageClass, brainrots: {[string]: number}) -> number,
	getContents: (self: CageClass) -> {[string]: number},
	serializeData: (self: CageClass) -> {},
	deserializeData: (self: CageClass, data: {}) -> (),
	cleanup: (self: CageClass) -> (),
}

export type TankClass = {
	new: (baseObject: BaseObject) -> TankClass,
	Base: BaseObject,
	Tanks: {[string]: TankData},
	Connections: {RBXScriptConnection},
	setupInstances: (self: TankClass, building: Model) -> (),
	-- Actions (no purchase)
	unlockTank: (self: TankClass, tankName: string) -> boolean,
	upgradeTank: (self: TankClass, tankName: string) -> boolean,
	addBrainrotToTank: (self: TankClass, tankName: string, amount: number) -> number,
	transferBrainrotFromCage: (self: TankClass, tankName: string) -> number,
	setPremiumTankBrainrot: (self: TankClass, tankName: string, brainrotName: string) -> boolean,
	-- Purchases
	purchaseUnlock: (self: TankClass, tankName: string) -> boolean,
	purchaseUpgrade: (self: TankClass, tankName: string) -> boolean,
	purchaseAddBrainrot: (self: TankClass, tankName: string, amount: number) -> number,
	-- Accessors
	getTankData: (self: TankClass, tankName: string) -> TankData?,
	isUnlocked: (self: TankClass, tankName: string) -> boolean,
	getLevel: (self: TankClass, tankName: string) -> number?,
	-- Data
	serializeData: (self: TankClass) -> {},
	deserializeData: (self: TankClass, data: {}) -> (),
	cleanup: (self: TankClass) -> (),
}

export type ProductionClass = {
	new: (baseObject: BaseObject) -> ProductionClass,
	Base: BaseObject,
	Storage: {ProductionItemData},
	startProduction: (self: ProductionClass, tankData: TankData) -> (),
	getStorage: (self: ProductionClass) -> {ProductionItemData},
	removeItemFromStorage: (self: ProductionClass, index: number) -> ProductionItemData?,
	cleanup: (self: ProductionClass) -> (),
}

export type CustomerClass = {
	new: (baseObject: BaseObject) -> CustomerClass,
	Base: BaseObject,
	CustomersFolder: Folder?,
	Customers: {CustomerData},
	QueueCheckpoints: {Attachment},
	QueueStart: Attachment?,
	QueueEnd: Attachment?,
	onSpawnBuilding: (self: CustomerClass) -> (),
	startSpawnThread: (self: CustomerClass) -> (),
	stopSpawnThread: (self: CustomerClass) -> (),
	cleanup: (self: CustomerClass) -> (),
}

return {}