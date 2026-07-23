--!strict
local GameConfig = {}
GameConfig.SCORE_PER_SURVIVAL = 1
GameConfig.SUDDEN_DEATH_ON_TIE = true
GameConfig.BASE_WALK_SPEED = 16
GameConfig.BASE_JUMP_POWER = 50
table.freeze(GameConfig)
return GameConfig
