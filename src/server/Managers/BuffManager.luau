--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuffConfig = require(ReplicatedStorage.Shared.Config.BuffConfig)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Util = require(ReplicatedStorage.Shared.Lib.Util)
local RandomService = require(script.Parent.RandomService)

local BuffManager = {}
local deps

-- 기본 배수 (1.0 = 변화 없음)
local function defaultMods()
	return {
		walkSpeedMult = 1, jumpMult = 1, rangeMult = 1,
		hitRadiusMult = 1, targetRadiusMult = 1, cooldownMult = 1, homingStrength = 0,
	}
end

local mods = {}       -- [userId] = mods 테이블
local oneshots = {}   -- [userId] = { blink=n, reflect=bool, repel=bool }
local grantedList = {} -- [userId] = { buffId, ... }

function BuffManager.init(injected) deps = injected end

local function getById(id)
	for _, b in BuffConfig.List do
		if b.id == id then return b end
	end
	return nil
end

-- 캐릭터 이동 스탯 반영
local function applyMovement(player)
	local m = mods[player.UserId]
	local char = player.Character
	local hum = char and char:FindFirstChildWhichIsA("Humanoid")
	if hum and m then
		hum.WalkSpeed = GameConfig.BASE_WALK_SPEED * m.walkSpeedMult
		hum.JumpPower = GameConfig.BASE_JUMP_POWER * m.jumpMult
	end
end

-- 버프 1개 적용
local function applyBuff(player, def)
	local uid = player.UserId
	mods[uid] = mods[uid] or defaultMods()
	oneshots[uid] = oneshots[uid] or {}
	grantedList[uid] = grantedList[uid] or {}
	table.insert(grantedList[uid], def.id)

	local p = def.params
	local m = mods[uid]
	if def.kind == "duration" or def.kind == "debuff" then
		if p.walkSpeedMult then m.walkSpeedMult *= p.walkSpeedMult end
		if p.jumpMult then m.jumpMult *= p.jumpMult end
		if p.rangeMult then m.rangeMult *= p.rangeMult end
		if p.hitRadiusMult then m.hitRadiusMult *= p.hitRadiusMult end
		if p.targetRadiusMult then m.targetRadiusMult *= p.targetRadiusMult end
		if p.cooldownMult then m.cooldownMult *= p.cooldownMult end
		if p.homingStrength then m.homingStrength += p.homingStrength end
		applyMovement(player)
	elseif def.kind == "oneshot" then
		if def.id == "blink" then oneshots[uid].blink = (oneshots[uid].blink or 0) + 1 end
		if def.id == "reflect" then oneshots[uid].reflect = true end
		if def.id == "repel" then oneshots[uid].repel = true end
	end
	deps.network.broadcast("BuffGranted", uid, def.id, def)
end

local function draw()
	return Util.weightedPick(BuffConfig.List, function(b) return b.weight end, RandomService:raw())
end

-- 라운드 시작 시 전체 초기화
function BuffManager.resetRound()
	table.clear(mods)
	table.clear(oneshots)
	table.clear(grantedList)
end

-- 생존 플레이어에게 라운드 버프 지급 (meta 처리 포함)
function BuffManager.grantRoundBuffs(players, round)
	BuffManager.resetRound()
	for _, player in players do
		local def = draw()
		if def.id == "reroll" then
			-- 재추첨: 한 번 다시 뽑음 (meta 중복 방지)
			def = draw()
			if def.kind == "meta" then def = getById("swift") end
			applyBuff(player, def)
		elseif def.id == "doubleDraw" then
			-- 이중 획득: 2개 지급
			local a, b = draw(), draw()
			if a.kind ~= "meta" then applyBuff(player, a) end
			if b.kind ~= "meta" then applyBuff(player, b) end
		else
			applyBuff(player, def)
		end
	end
end

-- BombManager가 조회하는 배수 (없으면 기본값)
function BuffManager.getModifiers(userId)
	return mods[userId] or defaultMods()
end

-- 반사막 소비: 발동 시 true
function BuffManager.consumeReflect(userId): boolean
	local o = oneshots[userId]
	if o and o.reflect then
		o.reflect = false
		return true
	end
	return false
end

-- 능동 버프 사용 (Client -> Server)
function BuffManager.useActiveBuff(player, buffId)
	local uid = player.UserId
	local o = oneshots[uid]
	if not o then return end

	if buffId == "blink" and (o.blink or 0) > 0 then
		o.blink -= 1
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local def = getById("blink")
			local dist = (def and def.params.dashStuds) or 8
			root.CFrame = root.CFrame + root.CFrame.LookVector * dist
			deps.network.broadcast("EffectTrigger", "blink", { userId = uid })
			if deps.score then deps.score.award(uid, "buff") end
		end
	elseif buffId == "repel" and o.repel then
		o.repel = false
		if deps.score then deps.score.award(uid, "buff") end
		deps.bomb.forcePassRandom(uid)
	end
end

return BuffManager
