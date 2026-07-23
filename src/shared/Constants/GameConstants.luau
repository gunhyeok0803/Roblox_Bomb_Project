--!strict
local GameConstants = {}
GameConstants.MAX_PLAYERS = 6
GameConstants.MIN_PLAYERS = 2
GameConstants.TOTAL_ROUNDS = 5
GameConstants.BUFF_START_ROUND = 3
GameConstants.ROUND_TIME = 90
GameConstants.BOMB_SAFE_TIME = 60
GameConstants.LOBBY_COUNTDOWN = 5
GameConstants.RESULT_DISPLAY_TIME = 3
GameConstants.INTERMISSION_TIME = 2
table.freeze(GameConstants)
return GameConstants
