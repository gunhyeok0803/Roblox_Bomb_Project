--!strict
-- TODO(구현): 명명 타이머 중앙 관리. 현재는 os.clock 기반 헬퍼만.
local TimerManager = {}
function TimerManager.now(): number return os.clock() end
function TimerManager.elapsed(since: number): number return os.clock() - since end
return TimerManager
