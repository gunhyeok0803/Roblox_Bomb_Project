--!strict
-- 스폰 위치 (임시 placeholder). 맵 완성 후 팀원이 Workspace.SpawnPoints 마커를 만들면
-- SpawnManager가 그것을 우선 사용하고, 없을 때만 이 값을 쓴다. (맵을 코드가 건드리지 않음)
local SpawnConfig = {}
SpawnConfig.Points = {
	Vector3.new(30, 5, 0),
	Vector3.new(15, 5, 26),
	Vector3.new(-15, 5, 26),
	Vector3.new(-30, 5, 0),
	Vector3.new(-15, 5, -26),
	Vector3.new(15, 5, -26),
}
table.freeze(SpawnConfig)
return SpawnConfig
