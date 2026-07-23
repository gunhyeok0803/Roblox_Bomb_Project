--!strict
local StateMachine = {}
StateMachine.__index = StateMachine
export type StateDef = { onEnter: ((payload: any?) -> ())?, onExit: (() -> ())?, allowed: { [string]: boolean }? }

function StateMachine.new()
	local self = setmetatable({}, StateMachine)
	self._states = {}
	self.current = nil
	return self
end
function StateMachine:define(name: string, def: StateDef)
	self._states[name] = def
end
function StateMachine:transition(name: string, payload: any?): boolean
	local target = self._states[name]
	assert(target, "정의되지 않은 상태: " .. tostring(name))
	if self.current then
		local cur = self._states[self.current]
		if cur.allowed and not cur.allowed[name] then
			warn("허용되지 않은 전이: " .. tostring(self.current) .. " -> " .. tostring(name))
			return false
		end
		if cur.onExit then cur.onExit() end
	end
	self.current = name
	if target.onEnter then target.onEnter(payload) end
	return true
end
function StateMachine:is(name: string): boolean
	return self.current == name
end
return StateMachine
