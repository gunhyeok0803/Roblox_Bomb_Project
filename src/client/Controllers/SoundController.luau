--!strict
-- 사운드 재생 전담. SoundId/볼륨은 Assets.Sounds 에 있음 (Studio에서 편집).
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
	if template.SoundId == "" then return end
	local s = template:Clone()
	s.PlaybackSpeed = pitch or 1
	s.Parent = container
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
	Debris:AddItem(s, 10)
end

local lastTick = 0
local warnedThisRound = false

function SoundController.init(network)
	local player = Players.LocalPlayer
	container = Instance.new("Folder")
	container.Name = "BombGameLocalSounds"
	container.Parent = SoundService

	local folder = ReplicatedStorage.Shared.Assets:WaitForChild("Sounds")
	for _, s in ipairs(folder:GetChildren()) do
		if s:IsA("Sound") then sounds[s.Name] = s end
	end

	-- BGM (루프 재생)
	local bgmTemplate = folder:FindFirstChild("Bgm")
	if bgmTemplate and bgmTemplate.SoundId ~= "" then
		local bgm = bgmTemplate:Clone()
		bgm.Looped = true
		bgm.Parent = container
		bgm:Play()
	end

	network.on("TimerUpdate", function(data)
		if not data then return end
		local d = math.clamp(data.dangerLevel or 0, 0, 1)
		if d <= 0 then return end
		if not warnedThisRound then warnedThisRound = true; play("Warning") end
		local interval = 1.0 - d * 0.85
		local now = os.clock()
		if now - lastTick >= interval then
			lastTick = now
			play("Tick", 1 + d * 0.6)
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

	network.on("MatchResult", function()
		play("Victory")
	end)
end
return SoundController
