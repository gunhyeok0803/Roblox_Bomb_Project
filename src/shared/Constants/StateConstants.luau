--!strict
local StateConstants = {
	LOBBY = "Lobby",
	WAITING = "Waiting",
	ROUND_START = "RoundStart",
	BOMB_SPAWN = "BombSpawn",
	PLAYING = "Playing",
	BOMB_EXPLODE = "BombExplode",
	ROUND_RESULT = "RoundResult",
	NEXT_ROUND = "NextRound",
	GAME_RESULT = "GameResult",
}
table.freeze(StateConstants)
return StateConstants
