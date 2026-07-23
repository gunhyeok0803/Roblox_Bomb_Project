--!strict
local RemoteNames = {
	RequestThrowBomb = "RequestThrowBomb",
	RequestUseBuff = "RequestUseBuff",
	RequestStartGame = "RequestStartGame",
	RequestToggleReady = "RequestToggleReady",
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
	MatchResult = "MatchResult",
	ScorePopup = "ScorePopup",
	CurrencyUpdate = "CurrencyUpdate",
	LobbyUpdate = "LobbyUpdate",
}
table.freeze(RemoteNames)
return RemoteNames
