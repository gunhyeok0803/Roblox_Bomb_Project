--!strict
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RewardConfig = require(game:GetService("ReplicatedStorage").Shared.Config.RewardConfig)

local DataManager = {}
local deps
local profiles: { [number]: any } = {}
local STORE_NAME = "BombPass_Profile_v1"
local store
local useStore = false

local function defaultProfile()
	return { coins = 0, xp = 0, level = 1, wins = 0, matches = 0, equippedSkin = "Default", unlockedSkins = { Default = true } }
end
local function computeLevel(xp: number): number
	return math.floor(xp / RewardConfig.XP_PER_LEVEL) + 1
end

function DataManager._sync(player: Player)
	local p = profiles[player.UserId]
	if p and deps then
		deps.network.fireTo("CurrencyUpdate", player, { coins = p.coins, xp = p.xp, level = p.level })
	end
end

function DataManager._load(player: Player)
	local uid = player.UserId
	local data
	if useStore then
		local ok, res = pcall(function() return store:GetAsync("u_" .. uid) end)
		if ok and res then data = res end
	end
	profiles[uid] = data or defaultProfile()
	profiles[uid].level = computeLevel(profiles[uid].xp)
	DataManager._sync(player)
end

function DataManager._save(player: Player)
	local p = profiles[player.UserId]
	if not p or not useStore then return end
	pcall(function() store:SetAsync("u_" .. player.UserId, p) end)
end

function DataManager.init(injected)
	deps = injected
	local ok = pcall(function() store = DataStoreService:GetDataStore(STORE_NAME) end)
	if ok and store then
		local probeOk = pcall(function() store:GetAsync("__probe__") end)
		useStore = probeOk
	end
	warn("[DataManager] DataStore " .. (useStore and "활성" or "비활성 → 메모리 모드"))
	for _, p in Players:GetPlayers() do DataManager._load(p) end
	Players.PlayerAdded:Connect(function(p) DataManager._load(p) end)
	Players.PlayerRemoving:Connect(function(p) DataManager._save(p); profiles[p.UserId] = nil end)
	game:BindToClose(function()
		for _, p in Players:GetPlayers() do DataManager._save(p) end
	end)
end

function DataManager.get(userId: number) return profiles[userId] end
function DataManager.addCurrency(userId: number, coins: number, xp: number)
	local p = profiles[userId]
	if not p then p = defaultProfile(); profiles[userId] = p end
	p.coins += coins
	p.xp += xp
	p.level = computeLevel(p.xp)
	local player = Players:GetPlayerByUserId(userId)
	if player then DataManager._sync(player) end
	return p
end
function DataManager.addWin(userId: number) local p = profiles[userId]; if p then p.wins += 1 end end
function DataManager.addMatch(userId: number) local p = profiles[userId]; if p then p.matches += 1 end end
return DataManager
