local WaveTransition = {}
WaveTransition.__index = WaveTransition

local TYPEDEF_ONLY = {} -- hack para o sistema de tipos do roblox

-- Opções para criar um objeto de transição
type WaveTransitionParams = {
	color: Color3?; -- cor dos quadrados (padrão branco)
	width: number?; -- número de quadrados na largura (padrão 10)
	waveDirection: Vector2?; -- vetor de direção da onda (padrão (1,1))
	waveFunction: ((x: number, t: number) -> number)? -- forma da onda (padrão abaixo)
}

-- esta função: https://www.desmos.com/calculator/linp7zw3sa
local function DefaultWaveFunction(x: number, t: number): number
	local l = 0.5 -- comprimento da onda
	local edge = t * (1 + l)
	if x < edge - l then return 1
	elseif x > edge then return 0
	else return 0.5 + 0.5 * math.cos(math.pi / l * (x - edge + l))
	end
end

-- Cria um novo objeto de transição com os parâmetros (opcionais) dados
-- o contêiner deve provavelmente ser um ScreenGui com IgnoreGuiInsets ativado
function WaveTransition.new(container: GuiBase2d, params: WaveTransitionParams?)
	local width = params and params.width and params.width or 30

	-- calcula o número de linhas necessárias para cobrir a tela
	local size = container.AbsoluteSize.X / width
	local height = math.ceil(container.AbsoluteSize.Y / size)

	local self = {
		squares = table.create(width*height) :: {GuiObject},
		percents = table.create(width*height) :: {number},
		color = params and params.color and params.color or Color3.new(0, 0, 0),
		width = width,
		height = height,
		size = size,
		waveDirection = params and params.waveDirection and params.waveDirection or Vector2.new(1, 1),
		waveFunction = params and params.waveFunction and params.waveFunction or DefaultWaveFunction
	}

	if container ~= TYPEDEF_ONLY then -- hack do sistema de tipos

		local shortest = math.huge
		local longest = -math.huge

		for r = 1, self.height do
			for c = 1, self.width do
				local pos = Vector2.new((c-1) * self.size, (r-1) * self.size)
				local f = Instance.new("Frame")
				f.AnchorPoint = Vector2.new(0.5, 0.5)
				-- adicionamos 1 para que haja sobreposição entre os frames (bordas não nos deixariam fazer um tamanho 0,0)
				f.Size = UDim2.fromOffset(self.size + 1, self.size + 1)
				f.Position = UDim2.fromOffset(pos.X + self.size/2, pos.Y + self.size/2)
				f.BackgroundColor3 = self.color
				f.BorderSizePixel = 0
				f.Parent = container

				-- projeta a posição 2D ao longo da linha de direção
				local percent = self.waveDirection:Dot(pos)
				if percent < shortest then shortest = percent end
				if percent > longest then longest = percent end

				local idx = (r - 1) * self.width + c

				self.squares[idx] = f
				self.percents[idx] = percent
			end
		end

		-- remapeia as posições projetadas em uma escala de 0 a 1
		for i, s in ipairs(self.squares) do
			self.percents[i] = (self.percents[i] - shortest) / (longest - shortest)
		end

	end

	setmetatable(self, WaveTransition)

	return self
end

-- (privado) atualiza um único quadrado com base em sua posição ao longo do vetor de direção
-- usando a função da onda
-- alpha: 0 a 1
function WaveTransition:_UpdateOne(square: GuiObject, percent: number, alpha: number)
	local self: WaveTransition = self
	local t = self.waveFunction(percent, alpha)
	square.Size = UDim2.fromOffset(t * (self.size + 1), t * (self.size + 1))
end

-- Define o progresso da onda
-- alpha: de 0 a 1
function WaveTransition:Update(alpha)
	local self: WaveTransition = self
	for i, square in ipairs(self.squares) do
		self:_UpdateOne(square, self.percents[i], alpha)
	end
end

-- Destrói todos os objetos GUI e libera sua memória
-- O objeto é inválido e inutilizável após
function WaveTransition:Destroy()
	local self: WaveTransition = self
	for _, s in ipairs(self.squares) do
		s:Destroy()
	end
	self.squares = nil :: any
	self.percents = nil :: any
end

-- hack porque o roblox não gosta de OOP
type WaveTransition = typeof(WaveTransition.new(TYPEDEF_ONLY :: any)) 

return WaveTransition