--!strict
-- 사운드 재생 전담. 사운드 에셋/볼륨/SoundId는 템플릿(ReplicatedStorage.Shared.Assets.Sounds)에 있음.
-- 이 모듈은 "이름으로 재생만" 한다 (SoundId를 코드에 하드코딩하지 않음 → Studio에서 편집 가능).
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundController = {}

local sounds: { [string]: Sound } = {}
local container: Folder

local function play(name: string, pitch: number?)
	local template = sounds[name]
	if not template then return end
	if template.SoundId == "" then return end -- SoundId 미지정이면 무음(에러 없음)
	local s = template:Clone()
	s.PlaybackSpeed = pitch or 1
	s.Parent = container
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
	Debris:AddItem(s, 10) -- 안전 정리
end

local lastTick = 0
local warnedThisRound = false

function SoundController.init(network)
	local player = Players.LocalPlayer

	-- 로컬 재생 컨테이너 (2D 사운드)
	container = Instance.new("Folder")
	container.Name = "BombGameLocalSounds"
	container.Parent = SoundService

	local folder = ReplicatedStorage.Shared.Assets:WaitForChild("Sounds")
	for _, s in ipairs(folder:GetChildren()) do
		if s:IsA("Sound") then sounds[s.Name] = s end
	end

	-- 위험도 심박: 위험할수록 빠르고 높은 톤
	network.on("TimerUpdate", function(data)
		if not data then return end
		local d = math.clamp(data.dangerLevel or 0, 0, 1)
		if d <= 0 then return end
		if not warnedThisRound then
			warnedThisRound = true
			play("Warning")
		end
		local interval = 1.0 - d * 0.85 -- 1.0s(위험 시작) -> 0.15s(폭발 임박)
		local now = os.clock()
		if now - lastTick >= interval then
			lastTick = now
			play("Tick", 1 + d * 0.6) -- 피치 상승
		end
	end)

	network.on("RoundInfoUpdate", function()
		warnedThisRound = false
		play("RoundStart")
	end)

	network.on("EffectTrigger", function(effectId)
		if effectId == "explosion" then
			play("Explosion")
		elseif effectId == "bombThrow" or effectId == "repel" then
			play("Throw")
		end
	end)

	network.on("BuffGranted", function(userId)
		if player and userId == player.UserId then
			play("BuffGranted")
		end
	end)

	network.on("GameResult", function()
		play("Victory")
	end)
end
return SoundController
