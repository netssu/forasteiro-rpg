------------------//SERVICES
local TweenService: TweenService = game:GetService("TweenService")
local RunService: RunService = game:GetService("RunService")

------------------//CONSTANTS
local DEFAULT_TILE_SIZE: number = 100
local DEFAULT_FILL_TIME: number = 0.08
local DEFAULT_SHRINK_TIME: number = 0.08
local DEFAULT_TILE_DELAY_STEP: number = 0.012
local DEFAULT_ZINDEX: number = 10_000

------------------//TYPES
export type TransitionOptions = {
	tileSize: number?,
	fillTime: number?,
	shrinkTime: number?,
	tileDelayStep: number?,
	zIndex: number?,
	color: Color3?,
	onFilled: (() -> ())?,
}

------------------//VARIABLES
local SquareTransition = {}

------------------//FUNCTIONS
local function get_option_number(value: number?, defaultValue: number): number
	if value and value > 0 then
		return value
	end

	return defaultValue
end

local function get_container_size(container: GuiObject): Vector2
	local absoluteSize = container.AbsoluteSize

	if absoluteSize.X > 0 and absoluteSize.Y > 0 then
		return absoluteSize
	end

	for _ = 1, 12 do
		RunService.Heartbeat:Wait()
		absoluteSize = container.AbsoluteSize

		if absoluteSize.X > 0 and absoluteSize.Y > 0 then
			return absoluteSize
		end
	end

	return absoluteSize
end

local function create_overlay(container: GuiObject, zIndex: number): Frame
	local oldOverlay = container:FindFirstChild("SquareTransition")
	if oldOverlay then
		oldOverlay:Destroy()
	end

	local overlay = Instance.new("Frame")
	overlay.Name = "SquareTransition"
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Position = UDim2.fromScale(0, 0)
	overlay.ClipsDescendants = true
	overlay.ZIndex = zIndex
	overlay.Parent = container

	return overlay
end

local function create_tile(overlay: Frame, row: number, column: number, tileSize: number, zIndex: number, color: Color3): Frame
	local tile = Instance.new("Frame")
	tile.Name = "Tile_" .. row .. "_" .. column
	tile.BackgroundColor3 = color
	tile.BorderSizePixel = 0
	tile.AnchorPoint = Vector2.new(0.5, 0.5)
	tile.Position = UDim2.fromOffset(
		(column - 1) * tileSize + (tileSize * 0.5),
		(row - 1) * tileSize + (tileSize * 0.5)
	)
	tile.Size = UDim2.fromOffset(0, 0)
	tile.ZIndex = zIndex
	tile.Parent = overlay

	return tile
end

local function create_tile_tween(tile: Frame, targetSize: number, duration: number, easingDirection: Enum.EasingDirection): Tween
	return TweenService:Create(
		tile,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, easingDirection),
		{
			Size = UDim2.fromOffset(targetSize, targetSize),
		}
	)
end

local function get_fill_delay(row: number, column: number, tileDelayStep: number): number
	return (row + column - 2) * tileDelayStep
end

local function get_shrink_delay(row: number, column: number, rows: number, columns: number, tileDelayStep: number): number
	return ((rows - row) + (columns - column)) * tileDelayStep
end

local function play_phase(
	tiles: {{Frame}},
	rows: number,
	columns: number,
	duration: number,
	tileDelayStep: number,
	targetSize: number,
	easingDirection: Enum.EasingDirection,
	get_delay: (number, number, number, number, number) -> number
): ()
	local totalTiles = rows * columns
	local finishedCount = 0
	local finishedEvent = Instance.new("BindableEvent")

	for row = 1, rows do
		for column = 1, columns do
			local tile = tiles[row][column]
			local delayTime = get_delay(row, column, rows, columns, tileDelayStep)

			task.delay(delayTime, function()
				if not tile or not tile.Parent then
					finishedCount += 1

					if finishedCount >= totalTiles then
						finishedEvent:Fire()
					end

					return
				end

				local tween = create_tile_tween(tile, targetSize, duration, easingDirection)
				local connection: RBXScriptConnection? = nil

				connection = tween.Completed:Connect(function()
					if connection then
						connection:Disconnect()
						connection = nil
					end

					finishedCount += 1

					if finishedCount >= totalTiles then
						finishedEvent:Fire()
					end
				end)

				tween:Play()
			end)
		end
	end

	finishedEvent.Event:Wait()
	finishedEvent:Destroy()
end

local function fill_delay_adapter(row: number, column: number, _: number, _: number, tileDelayStep: number): number
	return get_fill_delay(row, column, tileDelayStep)
end

local function shrink_delay_adapter(row: number, column: number, rows: number, columns: number, tileDelayStep: number): number
	return get_shrink_delay(row, column, rows, columns, tileDelayStep)
end

------------------//MAIN FUNCTIONS
function SquareTransition.play(container: GuiObject, options: TransitionOptions?): ()
	local tileSize = get_option_number(options and options.tileSize, DEFAULT_TILE_SIZE)
	local fillTime = get_option_number(options and options.fillTime, DEFAULT_FILL_TIME)
	local shrinkTime = get_option_number(options and options.shrinkTime, DEFAULT_SHRINK_TIME)
	local tileDelayStep = get_option_number(options and options.tileDelayStep, DEFAULT_TILE_DELAY_STEP)
	local zIndex = get_option_number(options and options.zIndex, DEFAULT_ZINDEX)
	local color = options and options.color or Color3.new(0, 0, 0)
	local onFilled = options and options.onFilled

	local containerSize = get_container_size(container)
	if containerSize.X <= 0 or containerSize.Y <= 0 then
		return
	end

	local columns = math.max(1, math.ceil(containerSize.X / tileSize))
	local rows = math.max(1, math.ceil(containerSize.Y / tileSize))

	local overlay = create_overlay(container, zIndex)
	local tiles = table.create(rows)

	for row = 1, rows do
		tiles[row] = table.create(columns)

		for column = 1, columns do
			tiles[row][column] = create_tile(overlay, row, column, tileSize, zIndex, color)
		end
	end

	play_phase(
		tiles,
		rows,
		columns,
		fillTime,
		tileDelayStep,
		tileSize,
		Enum.EasingDirection.Out,
		fill_delay_adapter
	)

	if onFilled then
		onFilled()
	end

	play_phase(
		tiles,
		rows,
		columns,
		shrinkTime,
		tileDelayStep,
		0,
		Enum.EasingDirection.In,
		shrink_delay_adapter
	)

	if overlay.Parent then
		overlay:Destroy()
	end
end

return SquareTransition