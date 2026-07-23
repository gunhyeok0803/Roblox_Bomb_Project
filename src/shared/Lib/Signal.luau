--!strict
-- 가벼운 서버측 이벤트 (BindableEvent 래퍼)
local Signal = {}
Signal.__index = Signal
function Signal.new()
	local self = setmetatable({}, Signal)
	self._be = Instance.new("BindableEvent")
	return self
end
function Signal:Connect(fn) return self._be.Event:Connect(fn) end
function Signal:Fire(...) self._be:Fire(...) end
function Signal:Destroy() self._be:Destroy() end
return Signal
