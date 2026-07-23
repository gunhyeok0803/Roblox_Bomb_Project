--!strict
local Players = game:GetService("Players")
local ScoreConfig = require(game:GetService("ReplicatedStorage").Shared.Config.ScoreConfig)

local ScoreManager = {}
local deps
local scores: { [number]: number } = {}
local streak: { [number]: number } = {}

local REASON = {
	survive = "SURVIVE_ROUND", pass = "PASS", clutch = "CLUTCH_PASS",
	buff = "BUFF_USE", longThrow = "LONG_THROW",
}

function ScoreManager.init(injected) deps = injected end
function ScoreManager.reset()
	table.clear(scores); table.clear(streak)
	-- leaderstats 점수 0으로
	for _, p in deps.players.getAll() do deps.players.setStat(p.UserId, "점수", 0) end
end

function ScoreManager._add(userId: number, pts: number, reason: string)
	scores[userId] = (scores[userId] or 0) + pts
	if deps and deps.stats then deps.stats.add(userId, "matchScore", pts) end
	deps.players.setStat(userId, "점수", scores[userId]) -- 실시간 leaderstats
	local player = Players:GetPlayerByUserId(userId)
	if player and deps then
		deps.network.fireTo("ScorePopup", player, { reason = reason, points = pts, total = scores[userId] })
	end
end

function ScoreManager.award(userId: number, reason: string)
	local field = REASON[reason]
	if not field then return end
	ScoreManager._add(userId, ScoreConfig[field] or 0, reason)
end

function ScoreManager.bumpStreak(userId: number)
	streak[userId] = (streak[userId] or 0) + 1
	if streak[userId] >= 2 then
		ScoreManager._add(userId, ScoreConfig.STREAK_PER * streak[userId], "streak")
	end
end
function ScoreManager.resetStreak(userId: number) streak[userId] = 0 end

function ScoreManager.getScores() return scores end
function ScoreManager.getScore(userId: number): number return scores[userId] or 0 end
return ScoreManager
