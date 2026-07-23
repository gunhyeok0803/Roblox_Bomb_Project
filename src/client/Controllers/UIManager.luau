--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local UIConfig = require(ReplicatedStorage.Shared.Config.UIConfig)
local StateConstants = require(ReplicatedStorage.Shared.Constants.StateConstants)
local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)

local UIManager = {}
local BUFF_KEY_HINT = { blink = "  [Q]", repel = "  [E]", reflect = "  (자동)" }
local REASON_LABEL = {
	survive = "생존", pass = "전달", clutch = "클러치!", buff = "버프", longThrow = "원거리", streak = "연속 전달!",
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
	-- QA 요소
	local roundIntro = gui:FindFirstChild("RoundIntro")
	local passPopup = gui:FindFirstChild("PassPopup")
	local flash = gui:FindFirstChild("Flash")
	local vignette = gui:FindFirstChild("DangerVignette")
	local playAgain = gamePanel:FindFirstChild("PlayAgainButton")
	local leaveBtn = gamePanel:FindFirstChild("LeaveButton")

	if startButton then startButton.Activated:Connect(function() network.send(RemoteNames.RequestStartGame) end) end
	if readyButton then readyButton.Activated:Connect(function() network.send(RemoteNames.RequestToggleReady) end) end
	if playAgain then playAgain.Activated:Connect(function() gamePanel.Visible = false end) end
	if leaveBtn then leaveBtn.Activated:Connect(function() gamePanel.Visible = false end) end

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

	-- QA-02 라운드 인트로
	local function showRoundIntro(round)
		if not roundIntro then return end
		roundIntro.Text = "ROUND " .. tostring(round or "")
		roundIntro.Visible = true; roundIntro.TextTransparency = 0
		roundIntro.Size = UDim2.fromOffset(400, 90)
		TweenService:Create(roundIntro, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(620, 90) }):Play()
		task.delay(1.1, function()
			TweenService:Create(roundIntro, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.delay(0.45, function() roundIntro.Visible = false end)
		end)
	end

	network.on("GameStateChanged", function(stateName, payload)
		lobbyBanner.Visible = (stateName == StateConstants.LOBBY or stateName == StateConstants.WAITING)
		if stateName == StateConstants.ROUND_START then
			clearBuffChips()          -- 버프 지급(BuffGranted) 전에 초기화 (버그 수정)
			specBanner.Visible = false
			roundPanel.Visible = false
			showRoundIntro(payload and payload.round)
		end
	end)

	network.on("LobbyUpdate", function(data)
		if not data then return end
		lobbyBanner.Visible = true
		local me = player.UserId
		local isHost = (data.hostUserId == me)
		local myReady, readyCount, nonHost = false, 0, 0
		for _, e in ipairs(data.players or {}) do
			if not e.isHost then nonHost += 1; if e.ready then readyCount += 1 end end
			if e.userId == me then myReady = e.ready end
		end
		if data.countingDown then
			lobbyText.Text = string.format("곧 시작!  %d", data.secondsLeft or 0)
		else
			lobbyText.Text = string.format("대기 중  %d / %d  ·  준비 %d / %d", data.count or 0, data.max or 6, readyCount, nonHost)
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

	-- 라운드 정보 (버프 칩은 여기서 지우지 않음 — 버그 수정)
	network.on("RoundInfoUpdate", function(data)
		if not data then return end
		roundLabel.Text = string.format("라운드 %d / %d", data.round or 0, data.totalRounds or 0)
		aliveLabel.Text = "생존 " .. tostring(data.alive or 0)
	end)

	network.on("TimerUpdate", function(data)
		if not data then return end
		local sec = data.secondsLeft or 0
		timerLabel.Text = string.format("%d:%02d", math.floor(sec / 60), sec % 60)
		local d = math.clamp(data.dangerLevel or 0, 0, 1)
		timerLabel.TextColor3 = UIConfig.SAFE_COLOR:Lerp(UIConfig.DANGER_COLOR, d)
		-- QA-03 위험 가장자리
		if vignette then
			local t = math.floor(120 * d)
			for _, f in ipairs(vignette:GetChildren()) do
				if f:IsA("Frame") then
					if f.Name == "Top" or f.Name == "Bottom" then f.Size = UDim2.new(1, 0, 0, t)
					else f.Size = UDim2.new(0, t, 1, 0) end
				end
			end
		end
		-- QA-03 타이머 펄스
		if d > 0 then
			local pulse = 1 + 0.14 * d * (0.5 + 0.5 * math.sin(os.clock() * (4 + d * 9)))
			timerLabel.TextSize = math.floor(30 * pulse)
		else
			timerLabel.TextSize = 30
		end
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

	network.on("ScorePopup", function(data)
		if not data or not scorePopupTemplate then return end
		local label = scorePopupTemplate:Clone()
		label.Name = "ScorePopup"; label.Visible = true
		label.Text = string.format("+%d  %s", data.points or 0, REASON_LABEL[data.reason] or "")
		local xOff = math.random(-70, 70)
		label.Position = UDim2.new(0.5, xOff, 0.62, 0)
		label.TextTransparency = 0; label.TextStrokeTransparency = 0.4
		label.Parent = gui
		TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {
			Position = UDim2.new(0.5, xOff, 0.5, 0), TextTransparency = 1, TextStrokeTransparency = 1,
		}):Play()
		Debris:AddItem(label, 1.0)
	end)

	network.on("EffectTrigger", function(effectId, params)
		params = params or {}
		if effectId == "bombThrow" and params.from == player.UserId and passPopup then
			-- QA-06 던진 사람 PASS!
			passPopup.Visible = true; passPopup.TextTransparency = 0
			passPopup.Size = UDim2.fromOffset(320, 80)
			TweenService:Create(passPopup, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Size = UDim2.fromOffset(520, 80) }):Play()
			task.delay(0.5, function()
				TweenService:Create(passPopup, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
				task.delay(0.3, function() passPopup.Visible = false end)
			end)
		elseif effectId == "explosion" and flash then
			-- QA-04 화면 플래시
			flash.BackgroundTransparency = 0.2
			TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		end
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

	-- QA-05 최종 결과 (버튼으로 닫음, 등장 연출)
	network.on("MatchResult", function(data)
		if not data then return end
		local medals = { "🥇", "🥈", "🥉" }
		local lines = {}
		if data.mvpName then
			table.insert(lines, "🏆 승자  " .. data.mvpName .. "   " .. (data.mvpTitle or ""))
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
		-- 등장 연출
		gamePanel.Visible = true
		gamePanel.Size = UDim2.fromOffset(400, 330)
		TweenService:Create(gamePanel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(440, 360) }):Play()
		-- 자동 숨김 없음 — 버튼으로 닫음
	end)
end
return UIManager
