--!strict
local StatsManager = {}
local stats: { [number]: any } = {}

local function ensure(uid: number)
	if not stats[uid] then
		stats[uid] = { passes = 0, totalHoldTime = 0, survivedRounds = 0, explodedCount = 0, farthestThrow = 0, matchScore = 0 }
	end
	return stats[uid]
end

function StatsManager.init() end
function StatsManager.reset() table.clear(stats) end
function StatsManager.add(uid: number, key: string, amt: number)
	local s = ensure(uid); s[key] = (s[key] or 0) + amt
end
function StatsManager.max(uid: number, key: string, val: number)
	local s = ensure(uid); if val > (s[key] or 0) then s[key] = val end
end
function StatsManager.get(uid: number) return ensure(uid) end
function StatsManager.getAll() return stats end
return StatsManager
