--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local BombManager = require(script.Parent.BombManager)

local RoundManager = {}
local deps
function RoundManager.init(injected) deps = injected end

-- 한 라운드 실행(블로킹). 탈락자 userId(없으면 nil) 반환.
function RoundManager.run(roundNumber: number): number?
	local alive = deps.players.getAlivePlayers()
	if #alive == 0 then return nil end

	local roundStart = os.clock()
	BombManager.arm(roundStart)
	BombManager.assignInitialOwner(alive)

	deps.network.broadcast("RoundInfoUpdate", {
		round = roundNumber, totalRounds = GameConstants.TOTAL_ROUNDS, alive = #alive,
	})

	while true do
		RunService.Heartbeat:Wait()
		local now = os.clock()
		local elapsed = now - roundStart
		local secondsLeft = math.max(0, GameConstants.ROUND_TIME - elapsed)

		local danger = 0
		if elapsed > GameConstants.BOMB_SAFE_TIME then
			danger = (elapsed - GameConstants.BOMB_SAFE_TIME)
				/ (GameConstants.ROUND_TIME - GameConstants.BOMB_SAFE_TIME)
		end
		deps.network.broadcast("TimerUpdate", {
			phase = "playing", secondsLeft = math.floor(secondsLeft), dangerLevel = danger,
		})

		local explodeAt = BombManager.getExplodeAt()
		if explodeAt and now >= explodeAt then
			return BombManager.explode()
		end
		if #deps.players.getAlivePlayers() <= 1 then
			return nil
		end
	end
end
return RoundManager
