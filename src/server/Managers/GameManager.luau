--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local S = require(ReplicatedStorage.Shared.Constants.StateConstants)
local StateManager = require(script.Parent.StateManager)
local RoundManager = require(script.Parent.RoundManager)

local GameManager = {}
local deps
local startRequested = false
local ready: { [number]: boolean } = {}
function GameManager.init(injected) deps = injected end

-- 호스트만 시작 가능
function GameManager.requestStart(player)
	local host = deps.players.getHost()
	if host and player.UserId == host.UserId then startRequested = true end
end
-- 비호스트만 Ready 토글
function GameManager.toggleReady(player)
	local host = deps.players.getHost()
	if host and player.UserId == host.UserId then return end
	ready[player.UserId] = not ready[player.UserId]
end

function GameManager.start()
	local function roundSummary()
		local t = {}
		for _, p in deps.players.getAll() do t[p.DisplayName] = deps.score.getScore(p.UserId) end
		return t
	end

	while true do
		-- ===== 로비: 호스트 시작 / Ready / 자동시작 =====
		StateManager.to(S.LOBBY)
		startRequested = false
		table.clear(ready)
		local autoStartAt = nil

		while true do
			local players = deps.players.getAll()
			local count = #players
			local host = deps.players.getHost()
			local hostUserId = host and host.UserId

			local roster = {}
			local allReady = count >= GameConstants.MIN_PLAYERS
			for _, p in players do
				local isHost = hostUserId == p.UserId
				local r = isHost or (ready[p.UserId] == true)
				if not isHost and not (ready[p.UserId] == true) then allReady = false end
				table.insert(roster, { userId = p.UserId, name = p.DisplayName, ready = r, isHost = isHost })
			end

			local countingDown, secondsLeft = false, nil
			if allReady then
				autoStartAt = autoStartAt or (os.clock() + GameConstants.LOBBY_COUNTDOWN)
				secondsLeft = math.max(0, math.ceil(autoStartAt - os.clock()))
				countingDown = true
			else
				autoStartAt = nil
			end

			deps.network.broadcast("LobbyUpdate", {
				hostUserId = hostUserId, min = GameConstants.MIN_PLAYERS, count = count,
				players = roster, allReady = allReady, countingDown = countingDown, secondsLeft = secondsLeft,
			})

			-- 시작 조건: 전원 Ready + (호스트 시작 or 자동시작 시간 도달)
			if allReady and (startRequested or (autoStartAt and os.clock() >= autoStartAt)) then break end
			task.wait(0.3)
		end

		StateManager.to(S.WAITING)
		if #deps.players.getAll() < GameConstants.MIN_PLAYERS then continue end

		-- ===== 매치 =====
		deps.players.resetScores()
		deps.stats.reset()
		deps.score.reset()

		for round = 1, GameConstants.TOTAL_ROUNDS do
			StateManager.to(S.ROUND_START, { round = round })
			deps.players.respawnAll() -- 전원 부활 (폭발자 포함 → 5라운드 완주)
			task.wait(1)
			local rosterP = deps.players.getAlivePlayers()
			deps.spawn.assignRound(rosterP)
			deps.spawn.placeAll(rosterP)
			if round >= GameConstants.BUFF_START_ROUND then
				deps.buffs.grantRoundBuffs(rosterP, round)
			end

			StateManager.to(S.BOMB_SPAWN)
			StateManager.to(S.PLAYING)

			local victimUserId = RoundManager.run(round)

			StateManager.to(S.BOMB_EXPLODE, { victim = victimUserId })
			if victimUserId then deps.players.eliminate(victimUserId, round) end

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

		local result = deps.progression.buildResults()
		StateManager.to(S.GAME_RESULT)
		deps.network.broadcast("MatchResult", result)
		task.wait(GameConstants.RESULT_DISPLAY_TIME * 2)
	end
end
return GameManager
