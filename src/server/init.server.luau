--!strict
-- 폭탄 게임 서버 부트스트랩: 매니저 require + 의존성 주입 + 기동
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Managers = script:WaitForChild("Managers")

local NetworkManager = require(Managers.NetworkManager)
local PlayerManager  = require(Managers.PlayerManager)
local BuffManager    = require(Managers.BuffManager)
local BombManager    = require(Managers.BombManager)
local StateManager   = require(Managers.StateManager)
local RoundManager   = require(Managers.RoundManager)
local GameManager    = require(Managers.GameManager)

NetworkManager.init()

local deps = {
	network = NetworkManager,
	players = PlayerManager,
	buffs   = BuffManager,
	bomb    = BombManager,
	state   = StateManager,
}

PlayerManager.init(deps)
BuffManager.init(deps)
BombManager.init(deps)
StateManager.init(deps)
RoundManager.init(deps)
GameManager.init(deps)

-- 클라 -> 서버 요청 배선 (서버 권한 판정)
NetworkManager.onServerEvent("RequestThrowBomb", function(player, aimDir)
	BombManager.onThrowRequest(player, aimDir)
end)
NetworkManager.onServerEvent("RequestUseBuff", function(player, buffId)
	BuffManager.useActiveBuff(player, buffId)
end)

print("[BombGameServer] 기동 완료")
GameManager.start()
