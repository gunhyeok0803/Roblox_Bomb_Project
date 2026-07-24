--!strict
-- 클라이언트 연출 전담. VFX는 프리팹(Assets.Effects), 여기선 재생/카메라/하이라이트만.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIConfig = require(ReplicatedStorage.Shared.Config.UIConfig)
local StateConstants = require(ReplicatedStorage.Shared.Constants.StateConstants)

local EffectController = {}
local effectsFolder: Folder

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
		TweenService:Create(inst, TweenInfo.new(lifetime), { Size = Vector3.new(to, to, to), Transparency = 1 }):Play()
	end
	Debris:AddItem(inst, lifetime + 0.3)
end

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

-- 폭탄 위험도 글로우 (기존)
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

-- QA-07 소유자 캐릭터 외곽선 (채움 없이 윤곽만)
local ownerHL: Highlight? = nil
local function markOwner(userId: number?)
	if not ownerHL then
		ownerHL = Instance.new("Highlight")
		ownerHL.Name = "BombOwnerOutline"
		ownerHL.FillTransparency = 1
		ownerHL.OutlineColor = Color3.fromRGB(255, 60, 60)
		ownerHL.OutlineTransparency = 0
		ownerHL.DepthMode = Enum.HighlightDepthMode.Occluded
		ownerHL.Parent = workspace
	end
	ownerHL.Adornee = userId and getCharByUserId(userId) or nil
end

-- QA-06 받은 사람 짧은 피격 번쩍
local function hitFlash(userId: number)
	local char = getCharByUserId(userId)
	if not char then return end
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.fromRGB(255, 235, 235); hl.FillTransparency = 0.2
	hl.OutlineColor = Color3.fromRGB(255, 70, 70)
	hl.OutlineTransparency = 0; hl.Adornee = char; hl.Parent = char
	TweenService:Create(hl, TweenInfo.new(0.35), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	Debris:AddItem(hl, 0.4)
end

-- QA-03/04 카메라 셰이크 (연속 위험 + 폭발 버스트)
local currentDanger = 0
local shakeBurst = 0
RunService:BindToRenderStep("BombShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local intensity = 0
	-- 폭발이 가까울수록 예열되듯 점점 강해지는 미세 셰이크(제곱 커브 → 막판에 확 뜀)
	if currentDanger > 0.6 then
		local k = (currentDanger - 0.6) / 0.4
		intensity += k * k * 0.35
	end
	if shakeBurst > 0 then intensity += shakeBurst; shakeBurst = math.max(0, shakeBurst - dt * 4) end
	if intensity > 0.001 then
		local rx = (math.random() - 0.5) * intensity
		local ry = (math.random() - 0.5) * intensity
		cam.CFrame = cam.CFrame * CFrame.new(rx, ry, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * intensity * 0.04)
	end
end)

function EffectController.init(network)
	effectsFolder = ReplicatedStorage.Shared.Assets:WaitForChild("Effects")

	-- 플레이 외 상태에서는 위험도 셰이크/소유자 외곽선 잔상 제거 (폭발 후 결과·버프 화면까지 흔들리는 것 방지)
	network.on("GameStateChanged", function(stateName)
		if stateName ~= StateConstants.PLAYING then
			currentDanger = 0
			markOwner(nil)
		end
	end)

	network.on("TimerUpdate", function(data)
		local hl = ensureGlow()
		if data then
			local d = math.clamp(data.dangerLevel or 0, 0, 1)
			currentDanger = d
			if hl then
				hl.FillColor = UIConfig.SAFE_COLOR:Lerp(UIConfig.DANGER_COLOR, d)
				hl.OutlineColor = hl.FillColor
			end
		end
	end)

	network.on("BombOwnerChanged", function(ownerUserId)
		markOwner(ownerUserId)
		ensureGlow()
	end)

	network.on("EffectTrigger", function(effectId, params)
		params = params or {}
		if effectId == "bombThrow" or effectId == "repel" then
			local a, b = getHead(params.from), getHead(params.to)
			if a and b then playTravel("ThrowTrail", a.CFrame, b.CFrame) end
			if params.to then hitFlash(params.to) end
		elseif effectId == "bombThrowMiss" then
			local h = getHead(params.from); if h then playAt("PuffMiss", h.CFrame) end
		elseif effectId == "explosion" then
			local h = getHead(params.userId); if h then playAt("Explosion", h.CFrame) end
			shakeBurst = 1.0
		elseif effectId == "blink" then
			local h = getHead(params.userId); if h then playAt("PuffBlink", h.CFrame) end
		elseif effectId == "reflect" then
			local h = getHead(params.by); if h then playAt("PuffReflect", h.CFrame) end
		end
	end)
end
return EffectController
