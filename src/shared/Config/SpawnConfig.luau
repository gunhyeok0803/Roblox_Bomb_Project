--!strict
-- 스폰 위치 fallback. 맵의 Workspace.SpawnPoints 마커가 있으면 그것을 우선 사용하므로 평소엔 미사용.
local SpawnConfig = {}
SpawnConfig.Points = {
	Vector3.new(289, 0, 116),
	Vector3.new(16, 0, 294),
	Vector3.new(-256, 19, 116),
	Vector3.new(-256, 0, -240),
	Vector3.new(16, 0, -418),
	Vector3.new(289, 0, -240),
}
table.freeze(SpawnConfig)
return SpawnConfig
