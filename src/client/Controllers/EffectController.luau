--!strict
-- 클라이언트 연출 전담 (판정 없음). 폭탄 위험도 글로우 + 이벤트별 이펙트.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local UIConfig = require(game:GetService("ReplicatedStorage").Shared.Config.UIConfig)

local EffectController = {}

local function getBomb(): Model?
	return workspace:FindFirstChild("Bomb") :: Model?
end

local function getCharByUserId(userId: number): Model?
	local plr = Players:GetPlayerByUserId(userId)
	return plr and plr.Character
end

local function getHead(userId: number): BasePart?
	local char = getCharByUserId(userId)
	return char and char:FindFirstChild("Head") :: BasePart?
end

-- 폭탄에 로컬 Highlight 부착 (위험도 색상 표시용)
local function ensureHighlight(): Highlight?
	local bomb = getBomb()
	if not bomb then return nil end
	local hl = bomb:FindFirstChild("DangerGlow") :: Highlight?
	if not hl then
		hl = Instance.new("Highlight")
		hl.Name = "DangerGlow"
		hl.FillTransparency = 0.4
		hl.OutlineTransparency = 0
		hl.Adornee = bomb
		hl.Parent = bomb
	end
	return hl
end

-- ===== 개별 이펙트 =====
local function spawnExplosion(userId: number)
	local head = getHead(userId)
	local pos = head and head.Position or Vector3.new(0, 5, 0)
	local ex = Instance.new("Explosion")
	ex.Position = pos
	ex.BlastRadius = 8
	ex.BlastPressure = 0          -- 물리 충격 없음(연출만)
	ex.DestroyJointRadiusPercent = 0 -- 캐릭터 부서짐 방지
	ex.Parent = workspace
end

-- 던진 사람 -> 맞은 사람 사이에 스파크 궤적
local function spawnThrowTrail(fromUserId: number, toUserId: number)
	local a, b = getHead(fromUserId), getHead(toUserId)
	if not (a and b) then return end
	local orb = Instance.new("Part")
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(0.8, 0.8, 0.8)
	orb.Color = Color3.fromRGB(255, 160, 60)
	orb.Material = Enum.Material.Neon
	orb.Anchored = true
	orb.CanCollide = false
	orb.CFrame = a.CFrame
	orb.Parent = workspace
	Debris:AddItem(orb, 0.3)
	TweenService:Create(orb, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { CFrame = b.CFrame }):Play()
end

local function spawnPuff(userId: number, color: Color3)
	local head = getHead(userId)
	if not head then return end
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(1, 1, 1)
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Transparency = 0.2
	p.Anchored = true
	p.CanCollide = false
	p.CFrame = head.CFrame
	p.Parent = workspace
	Debris:AddItem(p, 0.4)
	TweenService:Create(p, TweenInfo.new(0.35), { Size = Vector3.new(6, 6, 6), Transparency = 1 }):Play()
end

-- ===== 초기화 =====
function EffectController.init(network)
	-- 위험도 글로우: dangerLevel 0(안전 초록) -> 1(위험 빨강)
	network.on("TimerUpdate", function(data)
		local hl = ensureHighlight()
		if hl and data then
			local d = math.clamp(data.dangerLevel or 0, 0, 1)
			hl.FillColor = UIConfig.SAFE_COLOR:Lerp(UIConfig.DANGER_COLOR, d)
			hl.OutlineColor = hl.FillColor
			hl.FillTransparency = 0.55 - d * 0.25 -- 위험할수록 진하게
		end
	end)

	-- 소유자 변경 시 글로우 재확보(새 라운드 폭탄 대응)
	network.on("BombOwnerChanged", function()
		ensureHighlight()
	end)

	-- 이벤트별 연출
	network.on("EffectTrigger", function(effectId, params)
		params = params or {}
		if effectId == "bombThrow" then
			spawnThrowTrail(params.from, params.to)
		elseif effectId == "bombThrowMiss" then
			spawnPuff(params.from, Color3.fromRGB(200, 200, 200))
		elseif effectId == "explosion" then
			spawnExplosion(params.userId)
		elseif effectId == "blink" then
			spawnPuff(params.userId, Color3.fromRGB(120, 180, 255))
		elseif effectId == "reflect" then
			spawnPuff(params.by, Color3.fromRGB(120, 255, 200))
		elseif effectId == "repel" then
			spawnThrowTrail(params.from, params.to)
		end
	end)
end
return EffectController
