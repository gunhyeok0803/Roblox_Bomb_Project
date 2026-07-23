--!strict
-- 스폰 위치 fallback (벽 안쪽 플레이 구역). 맵의 Workspace.SpawnPoints 마커가 있으면 우선 사용.
local SpawnConfig = {}
SpawnConfig.Points = {
	Vector3.new(100, 1, 44),
	Vector3.new(55, 1, 95),
	Vector3.new(-88, 1, 64),
	Vector3.new(-100, 1, -44),
	Vector3.new(-55, 1, -95),
	Vector3.new(55, 1, -95),
}
table.freeze(SpawnConfig)
return SpawnConfig
