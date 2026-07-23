--!strict
local Players = game:GetService("Players")
local GameConfig = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)

local PlayerManager = {}
local deps
local states: { [number]: any } = {}
local joinCounter = 0

local function ensure(p: Player)
	if not states[p.UserId] then
		joinCounter += 1
		states[p.UserId] = { player = p, alive = true, score = 0, activeBuffs = {}, joinOrder = joinCounter }
	end
end

function PlayerManager.init(injected)
	deps = injected
	for _, p in Players:GetPlayers() do ensure(p) end
	Players.PlayerAdded:Connect(ensure)
	Players.PlayerRemoving:Connect(function(p) states[p.UserId] = nil end)
end

function PlayerManager.getAll(): { Player }
	local t = {}
	for _, s in states do table.insert(t, s.player) end
	return t
end
-- 첫 입장자(호스트) 반환
function PlayerManager.getHost(): Player?
	local best
	for _, s in states do
		if not best or s.joinOrder < best.joinOrder then best = s end
	end
	return best and best.player
end
function PlayerManager.getAlivePlayers(): { Player }
	local t = {}
	for _, s in states do if s.alive then table.insert(t, s.player) end end
	return t
end
function PlayerManager.isAlive(p: Player): boolean
	local s = states[p.UserId]
	return s ~= nil and s.alive
end
function PlayerManager.eliminate(userId: number, round: number?)
	local s = states[userId]
	if s then s.alive = false; deps.network.broadcast("PlayerEliminated", userId, round) end
end
function PlayerManager.respawnAll()
	for _, s in states do
		s.alive = true
		s.activeBuffs = {}
		if s.player then s.player:LoadCharacter() end
	end
end
function PlayerManager.resetScores() for _, s in states do s.score = 0 end end
function PlayerManager.awardSurvivors(round: number)
	for _, s in states do if s.alive then s.score += GameConfig.SCORE_PER_SURVIVAL end end
end
function PlayerManager.getRoundSummary(round: number)
	local scores = {}
	for _, s in states do scores[s.player.Name] = s.score end
	return { round = round, scores = scores }
end
function PlayerManager.getRanking()
	local list = {}
	for _, s in states do table.insert(list, { name = s.player.Name, score = s.score }) end
	table.sort(list, function(a, b) return a.score > b.score end)
	return list
end
return PlayerManager
