--!strict
local Players = game:GetService("Players")
local RewardConfig = require(game:GetService("ReplicatedStorage").Shared.Config.RewardConfig)

local ProgressionManager = {}
local deps
function ProgressionManager.init(injected) deps = injected end

local STYLE = {
	{ title = "🤾 폭탄 전달왕", key = "passes" },
	{ title = "🛡️ 생존왕", key = "survivedRounds" },
	{ title = "🎯 스나이퍼", key = "farthestThrow" },
	{ title = "🧨 불운왕", key = "explodedCount" },
}

-- 매치 종료 결과 산출 + 보상 지급 (영속 저장)
function ProgressionManager.buildResults()
	local scoreMap = deps.score.getScores()
	local statsMap = deps.stats.getAll()
	for _, p in deps.players.getAll() do
		if scoreMap[p.UserId] == nil then scoreMap[p.UserId] = 0 end
	end

	local list = {}
	for uid, sc in scoreMap do
		local plr = Players:GetPlayerByUserId(uid)
		table.insert(list, { userId = uid, name = plr and plr.DisplayName or ("플레이어 " .. uid), score = sc })
	end
	table.sort(list, function(a, b) return a.score > b.score end)
	for i, e in ipairs(list) do e.placement = i end
	local mvpUserId = list[1] and list[1].userId

	local awards = {}
	local function topBy(key)
		local best, bestV
		for uid, s in statsMap do
			local v = s[key] or 0
			if v > 0 and (not bestV or v > bestV) then best = uid; bestV = v end
		end
		return best
	end
	for _, d in ipairs(STYLE) do
		local uid = topBy(d.key)
		if uid then table.insert(awards, { userId = uid, title = d.title }) end
	end

	local mvpTitle = "🏆 MVP"
	for _, a in ipairs(awards) do
		if a.userId == mvpUserId then mvpTitle = a.title; break end
	end

	local rewards = {}
	for _, e in ipairs(list) do
		local rc = RewardConfig.PLACEMENT[e.placement] or RewardConfig.DEFAULT
		local coins = rc.coins + RewardConfig.PARTICIPATION.coins
		local xp = rc.xp + RewardConfig.PARTICIPATION.xp
		if e.userId == mvpUserId then
			coins += RewardConfig.MVP_BONUS.coins
			xp += RewardConfig.MVP_BONUS.xp
		end
		local profile = deps.data.addCurrency(e.userId, coins, xp)
		deps.data.addMatch(e.userId)
		if e.placement == 1 then deps.data.addWin(e.userId) end
		rewards[e.userId] = { coins = coins, xp = xp, totalCoins = profile.coins, level = profile.level }
	end

	return {
		ranking = list,
		mvpUserId = mvpUserId,
		mvpName = list[1] and list[1].name,
		mvpTitle = mvpTitle,
		awards = awards,
		rewards = rewards,
		stats = statsMap,
	}
end
return ProgressionManager
