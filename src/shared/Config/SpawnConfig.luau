--!strict
-- 스폰 위치 (맵 가장자리로 분산). 맵에 Workspace.SpawnPoints 마커가 생기면 그것을 우선 사용.
local SpawnConfig = {}
SpawnConfig.Points = {
	Vector3.new(141, 2, 76),
	Vector3.new(-6, 3, 160),
	Vector3.new(-153, 2, 76),
	Vector3.new(-153, 5, -94),
	Vector3.new(-6, 2, -178),
	Vector3.new(141, 5, -94),
}
table.freeze(SpawnConfig)
return SpawnConfig
