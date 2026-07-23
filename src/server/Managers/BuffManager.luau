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
		if def.id == "blink" then oneshots[uid].blink = (oneshots[uid].blink or 0) + 1 end
		if def.id == "reflect" then oneshots[uid].reflect = true end
		if def.id == "repel" then oneshots[uid].repel = true end
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
local function cardOf(def)
	return { id = def.id, name = def.name, desc = def.desc, icon = def.icon, kind = def.kind }
end

function BuffManager.resetRound()
	table.clear(mods); table.clear(oneshots); table.clear(grantedList)
	table.clear(pending); table.clear(selected); table.clear(roster)
end

-- 라운드 시작: 각 플레이어에게 카드 1장 오퍼 (선택 대기)
function BuffManager.offerRoundBuffs(players, round)
	BuffManager.resetRound()
	for _, p in players do
		roster[p.UserId] = true
		selected[p.UserId] = false
		local def = draw()
		pending[p.UserId] = def
		deps.network.fireTo("BuffOffer", p, { cards = { cardOf(def) }, selectable = true, duration = GameConstants.BUFF_SELECT_TIME })
	end
end

local function finish(player, cards)
	selected[player.UserId] = true
	deps.network.fireTo("BuffOffer", player, { cards = cards, selectable = false, done = true })
end
-- pending 을 최종 적용
local function resolve(player)
	local def = pending[player.UserId]
	if not def then return end
	if def.id == "reroll" then
		local nd = drawNonMeta(); applyBuff(player, nd); finish(player, { cardOf(nd) })
	elseif def.id == "doubleDraw" then
		local a, b = drawNonMeta(), drawNonMeta()
		applyBuff(player, a); applyBuff(player, b); finish(player, { cardOf(a), cardOf(b) })
	else
		applyBuff(player, def); finish(player, { cardOf(def) })
	end
end

-- 클라 선택 요청
function BuffManager.selectBuff(player)
	local uid = player.UserId
	if selected[uid] == nil or selected[uid] then return end
	local def = pending[uid]
	if def and def.id == "reroll" then
		-- 재추첨: 새 버프 카드로 교체 (다시 선택)
		local nd = drawNonMeta()
		pending[uid] = nd
		deps.network.fireTo("BuffOffer", player, { cards = { cardOf(nd) }, selectable = true, duration = GameConstants.BUFF_SELECT_TIME })
	else
		resolve(player)
	end
end

function BuffManager.allSelected()
	for uid in roster do if not selected[uid] then return false end end
	return true
end
function BuffManager.autoResolveRemaining()
	for uid in roster do
		if not selected[uid] then
			local p = Players:GetPlayerByUserId(uid)
			if p then resolve(p) else selected[uid] = true end
		end
	end
end

function BuffManager.getModifiers(userId)
	return mods[userId] or defaultMods()
end
function BuffManager.consumeReflect(userId): boolean
	local o = oneshots[userId]
	if o and o.reflect then o.reflect = false; return true end
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
