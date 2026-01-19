local ProjectileSystem = {}
ProjectileSystem.__index = ProjectileSystem

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = {
	MaxFireRate = 0.1,
	MaxDistance = 500,
	RaycastParams = nil,
	BulletLifetime = 5,
	MaxBulletsPerPlayer = 100,
	MaxOriginOffset = 5,
	ValidateLineOfSight = false,
}

local ActiveBullets = {}
local LastFireTime = {}
local PlayerBulletCount = {}
local BulletIdCounter = 0

local function InitRaycastParams()
	if not Config.RaycastParams then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = true
		Config.RaycastParams = params
	end
	return Config.RaycastParams
end

local function GenerateBulletId()
	BulletIdCounter = BulletIdCounter + 1
	return "bullet_" .. BulletIdCounter .. "_" .. tick()
end

function ProjectileSystem:GetServerShootingOrigin()


	local shootOrigin = workspace.CurrentCamera.CFrame + workspace.CurrentCamera.CFrame.LookVector * 2
	return shootOrigin.Position, shootOrigin.LookVector
end

function ProjectileSystem:CanPlayerFire(player)
	local userId = player.UserId
	local currentTime = tick()

	if LastFireTime[userId] then
		local timeSinceLastShot = currentTime - LastFireTime[userId]
		if timeSinceLastShot < Config.MaxFireRate then
			warn("player " .. player.Name .. " shoot too fast")
			return false, "FireRateExceeded"
		end
	end

	if PlayerBulletCount[userId] and PlayerBulletCount[userId] >= Config.MaxBulletsPerPlayer then
		warn("player " .. player.Name .. " have too many bullet")
		return false, "TooManyBullets"
	end

	return true
end



function ProjectileSystem:ValidateOrigin(player, clientOrigin)
	local character = player.Character
	if not character then return false, "NoCharacter" end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")

	if not humanoidRootPart or not head then 
		return false, "MissingBodyParts" 
	end

	local distanceFromHead = (clientOrigin - head.Position).Magnitude
	if distanceFromHead > Config.MaxOriginOffset then
		warn("player " .. player.Name .. " shoot from too far " .. distanceFromHead)
		return false, "OriginTooFar"
	end
	
	
	local params = InitRaycastParams()
	params.FilterDescendantsInstances = {character}
	
	local direction = (clientOrigin - head.Position)
	if direction.Magnitude > 0.1 then
		local caster = FastCast.new()
		local rayResult = caster:Fire(head.Position, direction, params) --workspace:Raycast(head.Position, direction, params)
		if rayResult and rayResult.Distance < direction.Magnitude then
			warn("player " .. player.Name .. " origin blocked by wall")
			return false, "OriginBehindWall"
		end
	end

	return true
end

function ProjectileSystem:ValidateLineOfSight(shooterCharacter, targetCharacter, hitPosition)
	if not Config.ValidateLineOfSight then return true end
	if not shooterCharacter or not targetCharacter then return false end

	local shooterHead = shooterCharacter:FindFirstChild("Head")
	if not shooterHead then return false end

	local params = InitRaycastParams()
	params.FilterDescendantsInstances = {shooterCharacter}

	local direction = (hitPosition - shooterHead.Position)
	local distance = direction.Magnitude

	if distance > Config.MaxDistance then
		return false, "ExceedsMaxDistance"
	end

	local rayResult = workspace:Raycast(shooterHead.Position, direction.Unit * distance, params)

	if not rayResult then return false, "NoLineOfSight" end

	local hitModel = rayResult.Instance:FindFirstAncestorOfClass("Model")
	if hitModel ~= targetCharacter then
		warn("line of sight fail hit wrong object")
		return false, "ObstructedLineOfSight"
	end

	return true
end

function ProjectileSystem:ServerValidateHit(origin, direction, clientHitPosition, clientHitPart, ignoreList)
	local params = InitRaycastParams()

	local fullIgnoreList = {}
	if ignoreList then
		for _, obj in ipairs(ignoreList) do
			table.insert(fullIgnoreList, obj)
			if obj:IsA("Model") then
				for _, descendant in ipairs(obj:GetDescendants()) do
					if descendant:IsA("BasePart") then
						table.insert(fullIgnoreList, descendant)
					end
				end
			end
		end
	end

	params.FilterDescendantsInstances = fullIgnoreList

	-- Realiza o raycast
	local raycastResult = workspace:Raycast(origin, direction * Config.MaxDistance, params)

	-- 🔍 Debug visual
	--local function draw_debug_ray(from, to, color)
	--	local distance = (to - from).Magnitude
	--	local part = Instance.new("Part")
	--	part.Anchored = true
	--	part.CanCollide = false
	--	part.Color = color or Color3.new(1, 0, 0)
	--	part.Material = Enum.Material.Neon
	--	part.Size = Vector3.new(0.1, 0.1, distance)
	--	part.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -distance / 2)
	--	part.Parent = workspace
	--	part.CanQuery = false
	--	part.CanCollide = false

	--	game.Debris:AddItem(part, 4) -- remove depois de 2 segundos
	--end
	-- Se achou algo, desenha até o ponto de impacto, senão desenha até o limite máximo
	if raycastResult then
		draw_debug_ray(origin, raycastResult.Position, Color3.new(0, 1, 0)) -- verde = acerto
	else
		draw_debug_ray(origin, origin + direction * Config.MaxDistance, Color3.new(1, 0, 0)) -- vermelho = nada encontrado
	end

	-- Lógica de validação original
	if not raycastResult then
		if clientHitPart then
			warn("client says hit but server found nothing")
			return false, nil, "NoServerHit"
		end
		return true, nil
	end

	if clientHitPart then
		local serverHitPosition = raycastResult.Position
		local positionDifference = (serverHitPosition - clientHitPosition).Magnitude

		if positionDifference > 7 then
			warn("server and client hit not match (" .. math.round(positionDifference) .. ")")
			return false, raycastResult, "HitPositionMismatch"
		end

		local serverModel = raycastResult.Instance:FindFirstAncestorOfClass("Model")
		local clientModel = clientHitPart:FindFirstAncestorOfClass("Model")

		if serverModel ~= clientModel then
			warn("hit part mismatch (server:" .. tostring(serverModel) .. ", client:" .. tostring(clientModel) .. ")")
			return false, raycastResult, "PartMismatch"
		end
	end

	return true, raycastResult
end

function ProjectileSystem:SetConfigOption(optionName, value)
	if Config[optionName] ~= nil then
		Config[optionName] = value
	end
end
-- ID: 195
function ProjectileSystem:FireProjectileSecure(player, clientDirection, hitData)
	local canFire, reason = self:CanPlayerFire(player)
	if not canFire then
		return false, nil, reason
	end

	local serverOrigin, serverLookVector = self:GetServerShootingOrigin(player)
	if not serverOrigin then
		return false, nil, serverLookVector
	end

	local direction = clientDirection.Unit
	local lookDot = serverLookVector:Dot(direction)
	if lookDot < 0.5 then
		warn("player " .. player.Name .. " shoot wrong direction")
		return false, nil, "InvalidShootDirection"
	end

	local ignoreList = {}
	if player.Character then
		table.insert(ignoreList, player.Character) -- yeah im insane rn at this point lol
		for _, part in player.Character:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(ignoreList, part)
			end
		end
	end

	local isValid, serverResult, validationError = self:ServerValidateHit(
		serverOrigin,
		direction,
		hitData.Position,
		hitData.Instance,
		ignoreList
	)

	if not isValid then
		return false, nil, validationError
	end

	if serverResult then
		local hitModel = serverResult.Instance:FindFirstAncestorOfClass("Model")
		local hitPlayer = Players:GetPlayerFromCharacter(hitModel)

		if hitPlayer and hitPlayer ~= player then
			local hasLineOfSight = self:ValidateLineOfSight(
				player.Character,
				hitPlayer.Character,
				serverResult.Position
			)

			if not hasLineOfSight then
				warn("player " .. player.Name .. " no line of sight")
				return false, nil, "NoLineOfSight"
			end
		end
	end

	local bulletId = GenerateBulletId()
	local userId = player.UserId
	LastFireTime[userId] = tick()
	PlayerBulletCount[userId] = (PlayerBulletCount[userId] or 0) + 1

	ActiveBullets[bulletId] = {
		Player = player,
		Origin = serverOrigin,
		Direction = direction,
		CreatedAt = tick(),
		ServerResult = serverResult,
	}

	task.delay(Config.BulletLifetime, function()
		if ActiveBullets[bulletId] then
			ActiveBullets[bulletId] = nil
			if PlayerBulletCount[userId] then
				PlayerBulletCount[userId] = math.max(0, PlayerBulletCount[userId] - 1)
			end
		end
	end)

	return true, bulletId, serverResult, serverOrigin
end

function ProjectileSystem:ProcessHit(bulletId, hitPlayer)
	local bulletData = ActiveBullets[bulletId]
	if not bulletData then
		warn("invalid bullet id " .. tostring(bulletId))
		return false, "InvalidBulletId"
	end

	local bulletAge = tick() - bulletData.CreatedAt
	if bulletAge > Config.BulletLifetime then
		warn("bullet expired " .. bulletId)
		return false, "BulletExpired"
	end

	if not hitPlayer or not hitPlayer:IsA("Player") then
		return false, "InvalidTarget"
	end

	if hitPlayer == bulletData.Player then
		return false, "SelfDamage"
	end

	if bulletData.ServerResult then
		local hitModel = bulletData.ServerResult.Instance:FindFirstAncestorOfClass("Model")
		local targetCharacter = hitPlayer.Character

		if hitModel ~= targetCharacter then
			warn("target not same as raycast hit")
			return false, "TargetMismatch"
		end
	end

	ActiveBullets[bulletId] = nil
	local userId = bulletData.Player.UserId
	if PlayerBulletCount[userId] then
		PlayerBulletCount[userId] = math.max(0, PlayerBulletCount[userId] - 1)
	end

	return true, bulletData
end

function ProjectileSystem:CleanupPlayer(player)
	local userId = player.UserId
	LastFireTime[userId] = nil
	PlayerBulletCount[userId] = nil

	for bulletId, data in pairs(ActiveBullets) do
		if data.Player == player then
			ActiveBullets[bulletId] = nil
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	ProjectileSystem:CleanupPlayer(player)
end)

return ProjectileSystem