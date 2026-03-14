------------------//SERVICES
local TweenService: TweenService = game:GetService("TweenService")

------------------//CONSTANTS
local DEFAULT_TILE_SIZE: number = 100
local DEFAULT_FILL_TIME: number = 0.15
local DEFAULT_SHRINK_TIME: number = 0.15
local DEFAULT_TILE_DELAY_STEP: number = 0.03
local DEFAULT_ZINDEX: number = 10_000

------------------//TYPES
export type TransitionOptions = {
	tileSize: number?,
	fillTime: number?,
	shrinkTime: number?,
	tileDelayStep: number?,
	zIndex: number?,
	onFilled: (() -> ())?,
}

------------------//MAIN FUNCTIONS
local SquareTransition = {}

local function get_option_number(value: number?, defaultValue: number): number
	if value and value > 0 then
		return value
	end

	return defaultValue
end

function SquareTransition.play(container: GuiObject, options: TransitionOptions?): ()
	local tileSize = get_option_number(options and options.tileSize, DEFAULT_TILE_SIZE)
	local fillTime = get_option_number(options and options.fillTime, DEFAULT_FILL_TIME)
	local shrinkTime = get_option_number(options and options.shrinkTime, DEFAULT_SHRINK_TIME)
	local tileDelayStep = get_option_number(options and options.tileDelayStep, DEFAULT_TILE_DELAY_STEP)
	local zIndex = get_option_number(options and options.zIndex, DEFAULT_ZINDEX)
	local onFilled = options and options.onFilled

	local columns = math.max(1, math.ceil(container.AbsoluteSize.X / tileSize))
	local rows = math.max(1, math.ceil(container.AbsoluteSize.Y / tileSize))
	local tileCount = columns * rows

	local overlay = Instance.new("Frame")
	overlay.Name = "SquareTransition"
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Position = UDim2.fromScale(0, 0)
	overlay.ZIndex = zIndex
	overlay.ClipsDescendants = true
	overlay.Parent = container

	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(0, 0)
	layout.CellSize = UDim2.fromOffset(tileSize, tileSize)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.FillDirectionMaxCells = columns
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = overlay

	local tiles = table.create(tileCount)

	for row = 1, rows do
		for column = 1, columns do
			local tile = Instance.new("Frame")
			tile.Name = "Tile_" .. row .. "_" .. column
			tile.BackgroundColor3 = Color3.new(0, 0, 0)
			tile.BorderSizePixel = 0
			tile.Size = UDim2.fromOffset(0, 0)
			tile.LayoutOrder = (row - 1) * columns + column
			tile.ZIndex = zIndex
			tile.Parent = overlay
			table.insert(tiles, tile)
		end
	end

	for row = 1, rows do
		for column = 1, columns do
			local index = (row - 1) * columns + column
			local tile = tiles[index]
			local delayTime = (row - 1 + column - 1) * tileDelayStep

			task.delay(delayTime, function()
				if tile and tile.Parent then
					TweenService:Create(tile, TweenInfo.new(fillTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = UDim2.fromOffset(tileSize, tileSize),
					}):Play()
				end
			end)
		end
	end

	task.wait(((rows - 1) + (columns - 1)) * tileDelayStep + fillTime + 0.05)

	if onFilled then
		onFilled()
	end

	for row = rows, 1, -1 do
		for column = columns, 1, -1 do
			local index = (row - 1) * columns + column
			local tile = tiles[index]
			local delayTime = ((rows - row) + (columns - column)) * tileDelayStep

			task.delay(delayTime, function()
				if tile and tile.Parent then
					TweenService:Create(tile, TweenInfo.new(shrinkTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Size = UDim2.fromOffset(0, 0),
					}):Play()
				end
			end)
		end
	end

	task.wait(((rows - 1) + (columns - 1)) * tileDelayStep + shrinkTime + 0.05)
	overlay:Destroy()
end

return SquareTransition
