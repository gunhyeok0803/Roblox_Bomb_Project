--!strict
local SpawnConfig = require(game:GetService("ReplicatedStorage").Shared.Config.SpawnConfig)
local RandomService = require(script.Parent.RandomService)

local SpawnManager = {}
local deps
local roundAssign: { [number]: CFrame } = {}
function SpawnManager.init(injected) deps = injected end

-- 스폰 CFrame 목록: 맵의 Workspace.SpawnPoints(BasePart) 우선, 없으면 SpawnConfig(중심 바라봄)
local function getSpawnCFrames(): { CFrame }
	local folder = workspace:FindFirstChild("SpawnPoints")
	if folder then
		local parts = {}
		for _, c in ipairs(folder:GetChildren()) do
			if c:IsA("BasePart") then table.insert(parts, c) end
		end
		table.sort(parts, function(a, b) return a.Name < b.Name end)
		if #parts > 0 then
			local out = {}
			for _, p in ipairs(parts) do table.insert(out, p.CFrame) end
			return out
		end
	end
	local pts = SpawnConfig.Points
	local center = Vector3.zero
	for _, v in ipairs(pts) do center += v end
	center /= #pts
	local out = {}
	for _, v in ipairs(pts) do
		local look = Vector3.new(center.X, v.Y, center.Z)
		if (look - v).Magnitude < 0.1 then
			table.insert(out, CFrame.new(v))
		else
			table.insert(out, CFrame.lookAt(v, look))
		end
	end
	return out
end

-- 라운드 시작 시 플레이어→스폰 셔플 배정 (각자 다른 위치)
function SpawnManager.assignRound(players: { Player })
	roundAssign = {}
	local cframes = getSpawnCFrames()
	if #cframes == 0 then return end
	local order = {}
	for i = 1, #cframes do order[i] = i end
	for i = #order, 2, -1 do
		local j = RandomService:integer(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for i, plr in ipairs(players) do
		roundAssign[plr.UserId] = cframes[order[((i - 1) % #cframes) + 1]]
	end
end

function SpawnManager.place(player: Player)
	local cf = roundAssign[player.UserId]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if cf and hrp then hrp.CFrame = cf + Vector3.new(0, 3, 0) end
end
function SpawnManager.placeAll(players: { Player })
	for _, p in ipairs(players) do SpawnManager.place(p) end
end
return SpawnManager
