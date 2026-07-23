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
	while true do
		StateManager.to(S.LOBBY)
		repeat task.wait(0.5) until #deps.players.getAll() >= GameConstants.MIN_PLAYERS
		StateManager.to(S.WAITING)
		task.wait(GameConstants.LOBBY_COUNTDOWN)
		if #deps.players.getAll() < GameConstants.MIN_PLAYERS then continue end

		deps.players.resetScores()

		for round = 1, GameConstants.TOTAL_ROUNDS do
			StateManager.to(S.ROUND_START, { round = round })
			deps.players.respawnAll()
			task.wait(1) -- 캐릭터 리스폰 여유
			if round >= GameConstants.BUFF_START_ROUND then
				deps.buffs.grantRoundBuffs(deps.players.getAlivePlayers(), round)
			end

			StateManager.to(S.BOMB_SPAWN)
			StateManager.to(S.PLAYING)

			local victimUserId = RoundManager.run(round)

			StateManager.to(S.BOMB_EXPLODE, { victim = victimUserId })
			if victimUserId then deps.players.eliminate(victimUserId, round) end
			deps.players.awardSurvivors(round)

			StateManager.to(S.ROUND_RESULT, deps.players.getRoundSummary(round))
			task.wait(GameConstants.RESULT_DISPLAY_TIME)

			if round < GameConstants.TOTAL_ROUNDS then
				StateManager.to(S.NEXT_ROUND)
				task.wait(GameConstants.INTERMISSION_TIME)
			end
		end

		StateManager.to(S.GAME_RESULT, { ranking = deps.players.getRanking() })
		task.wait(GameConstants.RESULT_DISPLAY_TIME * 2)
	end
end
return GameManager
