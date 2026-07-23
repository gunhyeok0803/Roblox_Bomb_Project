--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateMachine = require(ReplicatedStorage.Shared.Lib.StateMachine)
local S = require(ReplicatedStorage.Shared.Constants.StateConstants)

local StateManager = {}
local fsm = StateMachine.new()
local deps

function StateManager.init(injected)
	deps = injected
	fsm:define(S.LOBBY,        { allowed = { [S.WAITING] = true } })
	fsm:define(S.WAITING,      { allowed = { [S.ROUND_START] = true, [S.LOBBY] = true } })
	fsm:define(S.ROUND_START,  { allowed = { [S.BOMB_SPAWN] = true } })
	fsm:define(S.BOMB_SPAWN,   { allowed = { [S.PLAYING] = true } })
	fsm:define(S.PLAYING,      { allowed = { [S.BOMB_EXPLODE] = true, [S.ROUND_RESULT] = true } })
	fsm:define(S.BOMB_EXPLODE, { allowed = { [S.ROUND_RESULT] = true } })
	fsm:define(S.ROUND_RESULT, { allowed = { [S.NEXT_ROUND] = true, [S.GAME_RESULT] = true } })
	fsm:define(S.NEXT_ROUND,   { allowed = { [S.ROUND_START] = true } })
	fsm:define(S.GAME_RESULT,  { allowed = { [S.LOBBY] = true } })
end

function StateManager.to(name: string, payload: any?): boolean
	local ok = fsm:transition(name, payload)
	if ok then deps.network.broadcast("GameStateChanged", name, payload) end
	return ok
end
function StateManager.current(): string? return fsm.current end
return StateManager
