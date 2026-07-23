--!strict
-- 순위별 보상 (튜닝 지점)
local RewardConfig = {}
RewardConfig.PLACEMENT = {
	[1] = { coins = 200, xp = 300 },
	[2] = { coins = 150, xp = 220 },
	[3] = { coins = 120, xp = 180 },
}
RewardConfig.DEFAULT = { coins = 80, xp = 120 }        -- 4위 이하
RewardConfig.PARTICIPATION = { coins = 50, xp = 80 }   -- 전원 참가 보상
RewardConfig.MVP_BONUS = { coins = 50, xp = 50 }       -- MVP 추가
RewardConfig.XP_PER_LEVEL = 500
table.freeze(RewardConfig)
return RewardConfig
