--!strict
local RemoteNames = {
	RequestThrowBomb = "RequestThrowBomb",
	RequestUseBuff = "RequestUseBuff",
	GameStateChanged = "GameStateChanged",
	RoundInfoUpdate = "RoundInfoUpdate",
	TimerUpdate = "TimerUpdate",
	BombOwnerChanged = "BombOwnerChanged",
	BuffGranted = "BuffGranted",
	PlayerEliminated = "PlayerEliminated",
	RoundResult = "RoundResult",
	GameResult = "GameResult",
	EffectTrigger = "EffectTrigger",
	GetSnapshot = "GetSnapshot",
}
table.freeze(RemoteNames)
return RemoteNames
