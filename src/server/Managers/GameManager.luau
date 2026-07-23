--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local S = require(ReplicatedStorage.Shared.Constants.StateConstants)
local StateManager = require(script.Parent.StateManager)
local RoundManager = require(script.Parent.RoundManager)

local GameManager = {}
local deps
function GameManager.init(injected) deps = injected end

function GameManager.start()
	local function roundSummary()
		local t = {}
		for _, p in deps.players.getAll() do t[p.DisplayName] = deps.score.getScore(p.UserId) end
		return t
	end

	while true do
		StateManager.to(S.LOBBY)
		repeat task.wait(0.5) until #deps.players.getAll() >= GameConstants.MIN_PLAYERS
		StateManager.to(S.WAITING)
		task.wait(GameConstants.LOBBY_COUNTDOWN)
		if #deps.players.getAll() < GameConstants.MIN_PLAYERS then continue end

		-- 매치 초기화
		deps.players.resetScores()
		deps.stats.reset()
		deps.score.reset()

		for round = 1, GameConstants.TOTAL_ROUNDS do
			StateManager.to(S.ROUND_START, { round = round })
			deps.players.respawnAll()
			task.wait(1)
			if round >= GameConstants.BUFF_START_ROUND then
				deps.buffs.grantRoundBuffs(deps.players.getAlivePlayers(), round)
			end

			StateManager.to(S.BOMB_SPAWN)
			StateManager.to(S.PLAYING)

			local victimUserId = RoundManager.run(round)

			StateManager.to(S.BOMB_EXPLODE, { victim = victimUserId })
			if victimUserId then deps.players.eliminate(victimUserId, round) end

			-- 생존자 점수
			local survivors = deps.players.getAlivePlayers()
			for _, p in survivors do
				deps.score.award(p.UserId, "survive")
				deps.stats.add(p.UserId, "survivedRounds", 1)
			end
			if #survivors == 1 then deps.score.award(survivors[1].UserId, "lastSurvivor") end

			StateManager.to(S.ROUND_RESULT, { round = round, scores = roundSummary() })
			task.wait(GameConstants.RESULT_DISPLAY_TIME)

			if round < GameConstants.TOTAL_ROUNDS then
				StateManager.to(S.NEXT_ROUND)
				task.wait(GameConstants.INTERMISSION_TIME)
			end
		end

		-- 매치 종료: 결과 산출 + 보상 지급 + 방송
		local result = deps.progression.buildResults()
		StateManager.to(S.GAME_RESULT)
		deps.network.broadcast("MatchResult", result)
		task.wait(GameConstants.RESULT_DISPLAY_TIME * 2)
	end
end
return GameManager
