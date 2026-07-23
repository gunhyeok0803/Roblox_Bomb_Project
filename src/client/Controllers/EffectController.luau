--!strict
-- 클라이언트 연출 전담 (판정 없음).
-- VFX 모양/색/크기는 프리팹(ReplicatedStorage.Shared.Assets.Effects)에 있음.
-- 이 모듈은 프리팹을 clone 해서 "어디서/언제" 재생할지만 처리한다 (Instance.new 로 VFX를 만들지 않음).
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIConfig = require(ReplicatedStorage.Shared.Config.UIConfig)

local EffectController = {}
local effectsFolder: Folder

local function getBomb(): Model?
	return workspace:FindFirstChild("Bomb") :: Model?
end
local function getHead(userId: number): BasePart?
	local plr = Players:GetPlayerByUserId(userId)
	local char = plr and plr.Character
	return char and char:FindFirstChild("Head") :: BasePart?
end

-- 프리팹을 특정 위치에서 재생 (PlayMode: emit / expand)
local function playAt(name: string, cframe: CFrame)
	local prefab = effectsFolder:FindFirstChild(name)
	if not prefab then return end
	local inst = prefab:Clone() :: BasePart
	inst.CFrame = cframe
	inst.Parent = workspace

	local mode = inst:GetAttribute("PlayMode")
	local lifetime = (inst:GetAttribute("Lifetime") :: number?) or 1
	if mode == "emit" then
		local count = (inst:GetAttribute("EmitCount") :: number?) or 20
		for _, e in inst:GetDescendants() do
			if e:IsA("ParticleEmitter") then e:Emit(count) end
		end
	elseif mode == "expand" then
		local to = (inst:GetAttribute("ExpandTo") :: number?) or 6
		TweenService:Create(inst, TweenInfo.new(lifetime), {
			Size = Vector3.new(to, to, to), Transparency = 1,
		}):Play()
	end
	Debris:AddItem(inst, lifetime + 0.3)
end

-- 프리팹을 A -> B 로 이동 재생 (PlayMode: travel)
local function playTravel(name: string, fromCF: CFrame, toCF: CFrame)
	local prefab = effectsFolder:FindFirstChild(name)
	if not prefab then return end
	local inst = prefab:Clone() :: BasePart
	inst.CFrame = fromCF
	inst.Parent = workspace
	local t = (inst:GetAttribute("TravelTime") :: number?) or 0.18
	local lifetime = (inst:GetAttribute("Lifetime") :: number?) or (t + 0.1)
	TweenService:Create(inst, TweenInfo.new(t, Enum.EasingStyle.Quad), { CFrame = toCF }):Play()
	Debris:AddItem(inst, lifetime + 0.2)
end

-- 폭탄 위험도 글로우: 프리팹 Highlight를 폭탄에 부착, 색만 코드가 애니메이트
local function ensureGlow(): Highlight?
	local bomb = getBomb()
	if not bomb then return nil end
	local hl = bomb:FindFirstChild("BombGlow") :: Highlight?
	if not hl then
		local prefab = effectsFolder:FindFirstChild("BombGlow")
		if not prefab then return nil end
		hl = prefab:Clone()
		hl.Adornee = bomb
		hl.Parent = bomb
	end
	return hl
end

function EffectController.init(network)
	effectsFolder = ReplicatedStorage.Shared.Assets:WaitForChild("Effects")

	-- 위험도 글로우: dangerLevel 0(초록) -> 1(빨강)
	network.on("TimerUpdate", function(data)
		local hl = ensureGlow()
		if hl and data then
			local d = math.clamp(data.dangerLevel or 0, 0, 1)
			hl.FillColor = UIConfig.SAFE_COLOR:Lerp(UIConfig.DANGER_COLOR, d)
			hl.OutlineColor = hl.FillColor
		end
	end)

	network.on("BombOwnerChanged", function()
		ensureGlow()
	end)

	-- 이벤트별 연출 (프리팹 이름 매핑)
	network.on("EffectTrigger", function(effectId, params)
		params = params or {}
		if effectId == "bombThrow" or effectId == "repel" then
			local a, b = getHead(params.from), getHead(params.to)
			if a and b then playTravel("ThrowTrail", a.CFrame, b.CFrame) end
		elseif effectId == "bombThrowMiss" then
			local h = getHead(params.from)
			if h then playAt("PuffMiss", h.CFrame) end
		elseif effectId == "explosion" then
			local h = getHead(params.userId)
			if h then playAt("Explosion", h.CFrame) end
		elseif effectId == "blink" then
			local h = getHead(params.userId)
			if h then playAt("PuffBlink", h.CFrame) end
		elseif effectId == "reflect" then
			local h = getHead(params.by)
			if h then playAt("PuffReflect", h.CFrame) end
		end
	end)
end
return EffectController
