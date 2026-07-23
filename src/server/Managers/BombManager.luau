--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local BombConfig = require(ReplicatedStorage.Shared.Config.BombConfig)
local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RandomService = require(script.Parent.RandomService)

local BombManager = {}
local bombState = { ownerUserId = nil :: number?, explodeAt = nil :: number?, lastThrowAt = 0 }
local bombInstance: Model? = nil
local deps
function BombManager.init(injected) deps = injected end

-- ===== 폭탄 실물(Model) 관리 =====
local function ensureBomb(): Model
	if bombInstance and bombInstance.Parent then return bombInstance end
	local template = ServerStorage:WaitForChild("BombTemplate")
	bombInstance = template:Clone()
	bombInstance.Name = "Bomb"
	bombInstance.Parent = workspace
	return bombInstance
end

local function detachBomb()
	if bombInstance then
		bombInstance:Destroy()
		bombInstance = nil
	end
end

-- 소유자 캐릭터 머리 위에 폭탄 용접
local function attachToOwner(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	local char = player and player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not head then return end

	local bomb = ensureBomb()
	local bodyPart = bomb.PrimaryPart
	if not bodyPart then return end

	-- 기존 소유자 용접 제거
	local oldWeld = bodyPart:FindFirstChild("OwnerWeld")
	if oldWeld then oldWeld:Destroy() end

	-- 머리 위로 이동 후 용접
	bodyPart.CFrame = head.CFrame * CFrame.new(BombConfig.ATTACH_OFFSET)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "OwnerWeld"
	weld.Part0 = bodyPart
	weld.Part1 = head
	weld.Parent = bodyPart
end

-- ===== 폭탄 상태 로직 =====
function BombManager.arm(roundStartClock: number)
	local extra = RandomService:number(0, GameConstants.ROUND_TIME - GameConstants.BOMB_SAFE_TIME)
	bombState.explodeAt = roundStartClock + GameConstants.BOMB_SAFE_TIME + extra
end
function BombManager.assignInitialOwner(alivePlayers: { Player })
	local pick = alivePlayers[RandomService:integer(1, #alivePlayers)]
	BombManager._setOwner(pick.UserId, nil)
end
function BombManager.getOwnerUserId(): number? return bombState.ownerUserId end
function BombManager.getExplodeAt(): number? return bombState.explodeAt end

function BombManager._setOwner(newUserId: number?, previousUserId: number?)
	bombState.ownerUserId = newUserId
	if newUserId then attachToOwner(newUserId) end
	deps.network.broadcast("BombOwnerChanged", newUserId, previousUserId)
end

function BombManager._blocked(origin: Vector3, targetPos: Vector3, ignoreList: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList
	local res = workspace:Raycast(origin, targetPos - origin, params)
	return res ~= nil
end

function BombManager._findTarget(thrower: Player, origin: Vector3, dir: Vector3, range: number, hitRadiusMult: number): Player?
	local best, bestProj = nil, nil
	for _, p in deps.players.getAlivePlayers() do
		if p.UserId ~= thrower.UserId then
			local char = p.Character
			local pRoot = char and char:FindFirstChild("HumanoidRootPart")
			if pRoot then
				local to = pRoot.Position - origin
				local proj = to:Dot(dir)
				if proj > 0 and proj <= range then
					local closest = origin + dir * proj
					local dist = (pRoot.Position - closest).Magnitude
					local targetMod = deps.buffs.getModifiers(p.UserId)
					local effRadius = BombConfig.HIT_RADIUS * hitRadiusMult * targetMod.targetRadiusMult
					if dist <= effRadius and not BombManager._blocked(origin, pRoot.Position, { thrower.Character, char }) then
						if not bestProj or proj < bestProj then best, bestProj = p, proj end
					end
				end
			end
		end
	end
	return best
end

function BombManager.onThrowRequest(player: Player, aimDirection: Vector3)
	if bombState.ownerUserId ~= player.UserId then return end
	local now = os.clock()
	local mod = deps.buffs.getModifiers(player.UserId)
	local cooldown = BombConfig.THROW_COOLDOWN * mod.cooldownMult
	if now - bombState.lastThrowAt < cooldown then return end
	if typeof(aimDirection) ~= "Vector3" or aimDirection.Magnitude < 0.1 then return end
	local dir = aimDirection.Unit

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	bombState.lastThrowAt = now

	local range = BombConfig.THROW_RANGE * mod.rangeMult
	local target = BombManager._findTarget(player, root.Position, dir, range, mod.hitRadiusMult)
	if target then
		if deps.buffs.consumeReflect(target.UserId) then
			deps.network.broadcast("EffectTrigger", "reflect", { from = player.UserId, by = target.UserId })
			return
		end
		BombManager._setOwner(target.UserId, player.UserId)
		deps.network.broadcast("EffectTrigger", "bombThrow", { from = player.UserId, to = target.UserId })
		return
	end
	deps.network.broadcast("EffectTrigger", "bombThrowMiss", { from = player.UserId })
end

function BombManager.forcePassRandom(fromUserId: number)
	if bombState.ownerUserId ~= fromUserId then return end
	local candidates = {}
	for _, p in deps.players.getAlivePlayers() do
		if p.UserId ~= fromUserId then table.insert(candidates, p) end
	end
	if #candidates == 0 then return end
	local pick = candidates[RandomService:integer(1, #candidates)]
	BombManager._setOwner(pick.UserId, fromUserId)
	deps.network.broadcast("EffectTrigger", "repel", { from = fromUserId, to = pick.UserId })
end

function BombManager.explode(): number?
	local victim = bombState.ownerUserId
	bombState.explodeAt = nil
	bombState.ownerUserId = nil
	detachBomb()
	if victim then
		deps.network.broadcast("EffectTrigger", "explosion", { userId = victim })
	end
	return victim
end
return BombManager
