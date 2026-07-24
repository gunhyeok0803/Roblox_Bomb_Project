--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Managers = script:WaitForChild("Managers")

local NetworkManager     = require(Managers.NetworkManager)
local DataManager        = require(Managers.DataManager)
local PlayerManager      = require(Managers.PlayerManager)
local StatsManager       = require(Managers.StatsManager)
local ScoreManager       = require(Managers.ScoreManager)
local BuffManager        = require(Managers.BuffManager)
local SpawnManager       = require(Managers.SpawnManager)
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
	spawn       = SpawnManager,
	bomb        = BombManager,
	progression = ProgressionManager,
	state       = StateManager,
	game        = GameManager,
}

-- PlayerManager 를 먼저 init (leaderstats 선생성) → DataManager 가 코인 값 반영 가능
PlayerManager.init(deps)
DataManager.init(deps)
StatsManager.init(deps)
ScoreManager.init(deps)
BuffManager.init(deps)
SpawnManager.init(deps)
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
NetworkManager.onServerEvent("RequestStartGame", function(player)
	GameManager.requestStart(player)
end)
NetworkManager.onServerEvent("RequestToggleReady", function(player)
	GameManager.toggleReady(player)
end)
NetworkManager.onServerEvent("RequestSelectBuff", function(player, index)
	BuffManager.selectBuff(player, index)
end)

print("[BombGameServer] 기동 완료")
GameManager.start()
