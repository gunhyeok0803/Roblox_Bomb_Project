--!strict
-- UI 데이터 바인딩 전담. 레이아웃/스타일은 템플릿(ReplicatedStorage.Shared.Assets.BombGameUI)에 있음.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local UIConfig = require(ReplicatedStorage.Shared.Config.UIConfig)
local StateConstants = require(ReplicatedStorage.Shared.Constants.StateConstants)
local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)

local UIManager = {}
local BUFF_KEY_HINT = { blink = "  [Q]", repel = "  [E]", reflect = "  (자동)" }
-- 점수 팝업 문구
local REASON_LABEL = {
	survive = "생존", pass = "전달", clutch = "클러치!", lastSecond = "막판!",
	buff = "버프", longThrow = "원거리", lastSurvivor = "최후 생존", streak = "연속 전달!",
}

function UIManager.init(network)
	local player = Players.LocalPlayer
	if not player then return end
	local playerGui = player:WaitForChild("PlayerGui")

	local template = ReplicatedStorage.Shared.Assets:WaitForChild("BombGameUI")
	local gui = template:Clone()
	gui.Parent = playerGui

	local timerLabel = gui.TopBar.TimerLabel
	local roundLabel = gui.TopBar.RoundLabel
	local aliveLabel = gui.AliveBox.AliveLabel
	local ownerBanner = gui.BombOwnerBanner
	local ownerText = ownerBanner.OwnerText
	local buffContainer = gui.BuffContainer
	local chipTemplate = buffContainer.BuffChipTemplate
	local roundPanel = gui.RoundResultPanel
	local gamePanel = gui.GameResultPanel
	local specBanner = gui.SpectatorBanner
	local lobbyBanner = gui.LobbyBanner
	local lobbyText = lobbyBanner.LobbyText
	local startButton = lobbyBanner:FindFirstChild("StartButton")
	local readyButton = lobbyBanner:FindFirstChild("ReadyButton")
	local scorePopupTemplate = gui:FindFirstChild("ScorePopupTemplate")

	if startButton then
		startButton.Activated:Connect(function() network.send(RemoteNames.RequestStartGame) end)
	end
	if readyButton then
		readyButton.Activated:Connect(function() network.send(RemoteNames.RequestToggleReady) end)
	end

	local function nameOf(userId: number): string
		local p = Players:GetPlayerByUserId(userId)
		return p and p.DisplayName or ("플레이어 " .. tostring(userId))
	end
	local function clearBuffChips()
		for _, c in ipairs(buffContainer:GetChildren()) do
			if c:IsA("Frame") and c.Name == "BuffChip" then c:Destroy() end
		end
	end
	local function addBuffChip(meta)
		local chip = chipTemplate:Clone()
		chip.Name = "BuffChip"; chip.Visible = true
		chip.ChipText.Text = (meta.name or meta.id) .. (BUFF_KEY_HINT[meta.id] or "")
		if meta.kind == "debuff" then
			local s = chip:FindFirstChildOfClass("UIStroke")
			if s then s.Color = UIConfig.DANGER_COLOR end
		end
		chip.Parent = buffContainer
	end

	network.on("GameStateChanged", function(stateName)
		lobbyBanner.Visible = (stateName == StateConstants.LOBBY or stateName == StateConstants.WAITING)
	end)

	-- 로비: 호스트=시작버튼 / 비호스트=Ready버튼, 전원 Ready 시 카운트다운
	network.on("LobbyUpdate", function(data)
		if not data then return end
		lobbyBanner.Visible = true
		local me = player.UserId
		local isHost = (data.hostUserId == me)
		local myReady, readyCount, nonHost = false, 0, 0
		for _, e in ipairs(data.players or {}) do
			if not e.isHost then
				nonHost += 1
				if e.ready then readyCount += 1 end
			end
			if e.userId == me then myReady = e.ready end
		end

		if data.countingDown then
			lobbyText.Text = string.format("곧 시작!  %d", data.secondsLeft or 0)
		else
			lobbyText.Text = string.format("대기 중  %d / %d  ·  준비 %d / %d", data.count or 0, data.min or 2, readyCount, nonHost)
		end

		if startButton then
			startButton.Visible = isHost
			startButton.Active = (data.allReady == true)
			startButton.AutoButtonColor = (data.allReady == true)
			startButton.BackgroundColor3 = data.allReady and Color3.fromRGB(90, 200, 120) or Color3.fromRGB(110, 115, 125)
			startButton.Text = data.allReady and "게임 시작" or "다른 플레이어 준비 대기"
		end
		if readyButton then
			readyButton.Visible = not isHost
			readyButton.Text = myReady and "준비 취소" or "준비 완료"
			readyButton.BackgroundColor3 = myReady and Color3.fromRGB(90, 200, 120) or Color3.fromRGB(90, 160, 240)
		end
	end)

	network.on("RoundInfoUpdate", function(data)
		if not data then return end
		roundLabel.Text = string.format("라운드 %d / %d", data.round or 0, data.totalRounds or 0)
		aliveLabel.Text = "생존 " .. tostring(data.alive or 0)
		clearBuffChips()
		specBanner.Visible = false
		roundPanel.Visible = false
	end)

	network.on("TimerUpdate", function(data)
		if not data then return end
		local sec = data.secondsLeft or 0
		timerLabel.Text = string.format("%d:%02d", math.floor(sec / 60), sec % 60)
		local d = math.clamp(data.dangerLevel or 0, 0, 1)
		timerLabel.TextColor3 = UIConfig.SAFE_COLOR:Lerp(UIConfig.DANGER_COLOR, d)
	end)

	network.on("BombOwnerChanged", function(ownerUserId)
		if not ownerUserId then ownerBanner.Visible = false; return end
		ownerBanner.Visible = true
		if ownerUserId == player.UserId then
			ownerText.Text = "💣 당신이 폭탄을 가졌습니다! 던지세요!"
			ownerBanner.BackgroundColor3 = UIConfig.DANGER_COLOR
		else
			ownerText.Text = "💣 " .. nameOf(ownerUserId) .. " 님이 폭탄 보유"
			ownerBanner.BackgroundColor3 = Color3.fromRGB(200, 130, 50)
		end
	end)

	network.on("BuffGranted", function(userId, buffId, meta)
		if userId == player.UserId and meta then addBuffChip(meta) end
	end)

	network.on("PlayerEliminated", function(userId)
		if userId == player.UserId then specBanner.Visible = true end
	end)

	-- 점수 획득 플로팅 토스트 (+15 전달 …)
	network.on("ScorePopup", function(data)
		if not data or not scorePopupTemplate then return end
		local label = scorePopupTemplate:Clone()
		label.Name = "ScorePopup"
		label.Visible = true
		label.Text = string.format("+%d  %s", data.points or 0, REASON_LABEL[data.reason] or "")
		local xOff = math.random(-70, 70)
		label.Position = UDim2.new(0.5, xOff, 0.62, 0)
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0.4
		label.Parent = gui
		local up = UDim2.new(0.5, xOff, 0.5, 0)
		TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {
			Position = up, TextTransparency = 1, TextStrokeTransparency = 1,
		}):Play()
		Debris:AddItem(label, 1.0)
	end)

	network.on("RoundResult", function(data)
		if not data then return end
		local lines = {}
		if data.scores then
			local arr = {}
			for name, score in pairs(data.scores) do table.insert(arr, { name = name, score = score }) end
			table.sort(arr, function(a, b) return a.score > b.score end)
			for _, e in ipairs(arr) do table.insert(lines, string.format("%s : %d점", e.name, e.score)) end
		end
		roundPanel.ResultText.Text = table.concat(lines, "\n")
		roundPanel.Visible = true
		task.delay(3, function() roundPanel.Visible = false end)
	end)

	network.on("MatchResult", function(data)
		if not data then return end
		local medals = { "🥇", "🥈", "🥉" }
		local lines = {}
		if data.mvpName then
			table.insert(lines, "🏆 MVP  " .. data.mvpName .. "   " .. (data.mvpTitle or ""))
			table.insert(lines, "")
		end
		for i, e in ipairs(data.ranking or {}) do
			local prefix = medals[i] or ("  " .. i .. ".")
			table.insert(lines, string.format("%s %s — %d점", prefix, e.name, e.score))
		end
		local myReward = data.rewards and data.rewards[player.UserId]
		if myReward then
			table.insert(lines, "")
			table.insert(lines, string.format("보상  💰 +%d   ✨ +%d   (Lv.%d)", myReward.coins, myReward.xp, myReward.level))
		end
		gamePanel.RankingText.Text = table.concat(lines, "\n")
		gamePanel.Visible = true
		task.delay(8, function() gamePanel.Visible = false end)
	end)
end
return UIManager
