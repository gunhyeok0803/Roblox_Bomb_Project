--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local BuffConfig = require(ReplicatedStorage.Shared.Config.BuffConfig)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local Util = require(ReplicatedStorage.Shared.Lib.Util)
local RandomService = require(script.Parent.RandomService)

local BuffManager = {}
local deps

local function defaultMods()
	return { walkSpeedMult=1, jumpMult=1, rangeMult=1, hitRadiusMult=1, targetRadiusMult=1, cooldownMult=1, homingStrength=0 }
end

local mods = {}
local oneshots = {}
local grantedList = {}
-- 선택 상태
local pending: { [number]: any } = {}
local selected: { [number]: boolean } = {}
local roster: { [number]: boolean } = {}

function BuffManager.init(injected) deps = injected end

local function getById(id)
	for _, b in BuffConfig.List do if b.id == id then return b end end
	return nil
end
local function applyMovement(player)
	local m = mods[player.UserId]
	local char = player.Character
	local hum = char and char:FindFirstChildWhichIsA("Humanoid")
	if hum and m then
		hum.WalkSpeed = GameConfig.BASE_WALK_SPEED * m.walkSpeedMult
		-- R15 기본은 JumpHeight 사용(UseJumpPower=false)이라 JumpPower 설정이 무시됨 → 강제로 켜서 반영
		hum.UseJumpPower = true
		hum.JumpPower = GameConfig.BASE_JUMP_POWER * m.jumpMult
	end
end
local function applyBuff(player, def)
	local uid = player.UserId
	mods[uid] = mods[uid] or defaultMods()
	oneshots[uid] = oneshots[uid] or {}
	grantedList[uid] = grantedList[uid] or {}
	table.insert(grantedList[uid], def.id)
	local p = def.params; local m = mods[uid]
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
		-- 오너샷은 params.uses 로 사용 횟수 지정. 하드 캡: 이중획득으로도 최대치 초과 불가
		local n = p.uses or 1
		oneshots[uid][def.id] = math.max(oneshots[uid][def.id] or 0, n)
	end
	deps.network.broadcast("BuffGranted", uid, def.id, def)
end

local function draw()
	return Util.weightedPick(BuffConfig.List, function(b) return b.weight end, RandomService:raw())
end
local function drawNonMeta()
	for _ = 1, 20 do local d = draw(); if d.kind ~= "meta" then return d end end
	return getById("swift")
end
-- 서로 다른 버프 n장 (카드 3장 오퍼용)
local function drawDistinct(n)
	local out, seen = {}, {}
	for _ = 1, 200 do
		if #out >= n then break end
		local d = drawNonMeta()
		if not seen[d.id] then seen[d.id] = true; out[#out + 1] = d end
	end
	return out
end
local function cardOf(def)
	return { id = def.id, name = def.name, desc = def.desc, icon = def.icon, kind = def.kind }
end

function BuffManager.resetRound()
	table.clear(mods); table.clear(oneshots); table.clear(grantedList)
	table.clear(pending); table.clear(selected); table.clear(roster)
end

-- 라운드 시작: 각 플레이어에게 서로 다른 카드 3장 오퍼 (하나 선택)
function BuffManager.offerRoundBuffs(players, round)
	BuffManager.resetRound()
	for _, p in players do
		roster[p.UserId] = true
		selected[p.UserId] = false
		local defs = drawDistinct(3)
		pending[p.UserId] = defs
		local cards = {}
		for i, d in ipairs(defs) do cards[i] = cardOf(d) end
		deps.network.fireTo("BuffOffer", p, { cards = cards, selectable = true, duration = GameConstants.BUFF_SELECT_TIME })
	end
end

local function finish(player, cards)
	selected[player.UserId] = true
	deps.network.fireTo("BuffOffer", player, { cards = cards, selectable = false, done = true })
end
-- 3장 중 선택한 카드(index) 적용
local function applyChoice(player, index)
	local defs = pending[player.UserId]
	if not defs then return end
	local def = defs[tonumber(index) or 1] or defs[1]
	if not def then return end
	applyBuff(player, def)
	finish(player, { cardOf(def) })
end

-- 클라 선택 요청 (선택한 카드 인덱스)
function BuffManager.selectBuff(player, index)
	local uid = player.UserId
	if selected[uid] == nil or selected[uid] then return end
	applyChoice(player, index)
end

function BuffManager.allSelected()
	for uid in roster do if not selected[uid] then return false end end
	return true
end
function BuffManager.autoResolveRemaining()
	for uid in roster do
		if not selected[uid] then
			local p = Players:GetPlayerByUserId(uid)
			if p then
				local defs = pending[uid]
				applyChoice(p, defs and math.random(1, #defs) or 1)
			else
				selected[uid] = true
			end
		end
	end
end

function BuffManager.getModifiers(userId)
	return mods[userId] or defaultMods()
end
function BuffManager.consumeReflect(userId): boolean
	local o = oneshots[userId]
	if o and (o.reflect or 0) > 0 then
		o.reflect -= 1
		deps.network.broadcast("EffectTrigger", "buffUse", { userId = userId, id = "reflect", remaining = o.reflect })
		return true
	end
	return false
end
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
			deps.network.broadcast("EffectTrigger", "blink", { userId = uid, remaining = o.blink })
			if deps.score then deps.score.award(uid, "buff") end
		end
	elseif buffId == "repel" and (o.repel or 0) > 0 then
		o.repel -= 1
		if deps.score then deps.score.award(uid, "buff") end
		deps.network.broadcast("EffectTrigger", "buffUse", { userId = uid, id = "repel", remaining = o.repel })
		deps.bomb.forcePassRandom(uid)
	end
end
return BuffManager
