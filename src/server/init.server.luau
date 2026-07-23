--!strict
-- 폭탄 게임 서버 부트스트랩: 매니저 require + 의존성 주입 + 기동
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Managers = script:WaitForChild("Managers")

local NetworkManager     = require(Managers.NetworkManager)
local DataManager        = require(Managers.DataManager)
local PlayerManager      = require(Managers.PlayerManager)
local StatsManager       = require(Managers.StatsManager)
local ScoreManager       = require(Managers.ScoreManager)
local BuffManager        = require(Managers.BuffManager)
local BombManager        = require(Managers.BombManager)
local ProgressionManager = require(Managers.ProgressionManager)
local StateManager       = require(Managers.StateManager)
local RoundManager       = require(Managers.RoundManager)
local GameManager        = require(Managers.GameManager)

NetworkManager.init()

local deps = {
	network     = NetworkManager,
	data        = DataManager,
	players     = PlayerManager,
	stats       = StatsManager,
	score       = ScoreManager,
	buffs       = BuffManager,
	bomb        = BombManager,
	progression = ProgressionManager,
	state       = StateManager,
}

DataManager.init(deps)
PlayerManager.init(deps)
StatsManager.init(deps)
ScoreManager.init(deps)
BuffManager.init(deps)
BombManager.init(deps)
ProgressionManager.init(deps)
StateManager.init(deps)
RoundManager.init(deps)
GameManager.init(deps)

NetworkManager.onServerEvent("RequestThrowBomb", function(player, aimDir)
	BombManager.onThrowRequest(player, aimDir)
end)
NetworkManager.onServerEvent("RequestUseBuff", function(player, buffId)
	BuffManager.useActiveBuff(player, buffId)
end)

print("[BombGameServer] 기동 완료")
GameManager.start()
