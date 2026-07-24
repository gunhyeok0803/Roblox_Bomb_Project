--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local UIConfig = require(ReplicatedStorage.Shared.Config.UIConfig)
local StateConstants = require(ReplicatedStorage.Shared.Constants.StateConstants)
local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)

local UIManager = {}
local BUFF_KEY_HINT = { blink = "  [Q]", repel = "  [E]", reflect = "  (자동)" }
local REASON_LABEL = { survive="생존", pass="전달", clutch="클러치!", buff="버프", longThrow="원거리", streak="연속 전달!" }
local KIND_COLOR = {
	duration = Color3.fromRGB(80, 200, 160), oneshot = Color3.fromRGB(169, 123, 255),
	meta = Color3.fromRGB(255, 207, 92), debuff = Color3.fromRGB(255, 95, 109),
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
	local roundIntro = gui:FindFirstChild("RoundIntro")
	local passPopup = gui:FindFirstChild("PassPopup")
	local flash = gui:FindFirstChild("Flash")
	local vignette = gui:FindFirstChild("DangerVignette")
	local playAgain = gamePanel:FindFirstChild("PlayAgainButton")
	local leaveBtn = gamePanel:FindFirstChild("LeaveButton")
	-- 버프 카드
	local buffLayer = gui:FindFirstChild("BuffCardLayer")
	local buffHolder = buffLayer and buffLayer:FindFirstChild("Holder")
	local buffCardTemplate = buffHolder and buffHolder:FindFirstChild("BuffCardTemplate")

	if startButton then startButton.Activated:Connect(function() network.send(RemoteNames.RequestStartGame) end) end
	if readyButton then readyButton.Activated:Connect(function() network.send(RemoteNames.RequestToggleReady) end) end
	if playAgain then playAgain.Activated:Connect(function() gamePanel.Visible = false end) end
	if leaveBtn then leaveBtn.Activated:Connect(function() gamePanel.Visible = false end) end

	local function nameOf(userId: number): string
		local p = Players:GetPlayerByUserId(userId)
		return p and p.DisplayName or ("플레이어 " .. tostring(userId))
	end
	local oneChips: { [string]: { chip: any, max: number, name: string } } = {}  -- 오너샷 잔여횟수 칩(blink/reflect/repel)
	local currentDanger = 0   -- TimerUpdate 위험도 캐시(비네트 렌더 루프에서 사용)
	local iAmOwner = false    -- 내가 폭탄 보유 중이면 가장자리 상시 맥동

	-- 비네트: 위험도 기반 크기 + 폭탄 보유 시 은은한 상시 맥동(압박감)
	if vignette then
		RunService.RenderStepped:Connect(function()
			local t = 120 * currentDanger
			if iAmOwner then
				t = math.max(t, 20 + 12 * (0.5 + 0.5 * math.sin(os.clock() * 3.2)))
			end
			local ti = math.floor(t)
			for _, f in ipairs(vignette:GetChildren()) do
				if f:IsA("Frame") then
					if f.Name == "Top" or f.Name == "Bottom" then f.Size = UDim2.new(1, 0, 0, ti) else f.Size = UDim2.new(0, ti, 1, 0) end
				end
			end
		end)
	end
	local function oneLabel(id, name, rem, max): string
		return (name or id) .. (BUFF_KEY_HINT[id] or "") .. "  " .. tostring(rem) .. "/" .. tostring(max)
	end
	local function updateOneshot(id, rem)
		local rec = oneChips[id]
		if not rec then return end
		rec.chip.ChipText.Text = oneLabel(id, rec.name, rem, rec.max)
		if rem <= 0 then
			local s = rec.chip:FindFirstChildOfClass("UIStroke")
			if s then s.Color = Color3.fromRGB(120, 120, 120) end
			rec.chip.ChipText.TextTransparency = 0.45
		end
	end
	local function clearBuffChips()
		table.clear(oneChips)
		for _, c in ipairs(buffContainer:GetChildren()) do
			if c:IsA("Frame") and c.Name == "BuffChip" then c:Destroy() end
		end
	end
	local function addBuffChip(meta)
		local chip = chipTemplate:Clone()
		chip.Name = "BuffChip"; chip.Visible = true
		local uses = meta.params and meta.params.uses
		if uses then
			chip.ChipText.Text = oneLabel(meta.id, meta.name, uses, uses)
			oneChips[meta.id] = { chip = chip, max = uses, name = meta.name or meta.id }
		else
			chip.ChipText.Text = (meta.name or meta.id) .. (BUFF_KEY_HINT[meta.id] or "")
		end
		if meta.kind == "debuff" then
			local s = chip:FindFirstChildOfClass("UIStroke")
			if s then s.Color = UIConfig.DANGER_COLOR end
		end
		chip.Parent = buffContainer
	end

	local function showRoundIntro(round)
		if not roundIntro then return end
		roundIntro.Text = "ROUND " .. tostring(round or "")
		roundIntro.Visible = true; roundIntro.TextTransparency = 0
		roundIntro.Size = UDim2.fromOffset(400, 90)
		TweenService:Create(roundIntro, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(620, 90) }):Play()
		task.delay(1.1, function()
			TweenService:Create(roundIntro, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.delay(0.45, function() roundIntro.Visible = false end)
		end)
	end

	-- 버프 카드 오퍼
	local function clearBuffCards()
		if not buffHolder then return end
		for _, c in ipairs(buffHolder:GetChildren()) do
			if c:IsA("Frame") and c.Name == "BuffCard" then c:Destroy() end
		end
	end
	network.on("BuffOffer", function(data)
		if not data or not buffLayer or not buffCardTemplate then return end
		clearBuffCards()
		buffLayer.Visible = true
		for _, cd in ipairs(data.cards or {}) do
			local card = buffCardTemplate:Clone()
			card.Name = "BuffCard"; card.Visible = true
			card.Icon.Text = cd.icon or "?"
			card.NameLabel.Text = cd.name or ""
			card.Desc.Text = cd.desc or ""
			local col = KIND_COLOR[cd.kind] or KIND_COLOR.duration
			local accent = card:FindFirstChild("Accent")
			if accent then accent.Color = col end
			card.SelectBtn.BackgroundColor3 = col
			card.TimerBar.BackgroundColor3 = col
			if data.selectable then
				card.SelectBtn.Visible = true; card.TimerBar.Visible = true
				card.SelectBtn.Activated:Connect(function() network.send(RemoteNames.RequestSelectBuff) end)
				card.TimerBar.Size = UDim2.new(1, 0, 0, 3)
				TweenService:Create(card.TimerBar, TweenInfo.new(data.duration or 8, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 3) }):Play()
				card.Size = UDim2.fromOffset(180, 260)
				TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(200, 280) }):Play()
			else
				card.SelectBtn.Visible = false; card.TimerBar.Visible = false
			end
			card.Parent = buffHolder
		end
		if data.done then
			task.delay(1.4, function() if buffLayer then buffLayer.Visible = false end end)
		end
	end)

	network.on("GameStateChanged", function(stateName, payload)
		lobbyBanner.Visible = (stateName == StateConstants.LOBBY or stateName == StateConstants.WAITING)
		if stateName == StateConstants.ROUND_START then
			clearBuffChips()
			if buffLayer then buffLayer.Visible = false end
			clearBuffCards()
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
		-- 남은 시간 임계값 기반 색상: 초록 → 주황(≤30s) → 빨강(≤10s)
		if sec > UIConfig.TIMER_WARN_SECONDS then
			timerLabel.TextColor3 = UIConfig.SAFE_COLOR
		elseif sec > UIConfig.TIMER_CRIT_SECONDS then
			timerLabel.TextColor3 = UIConfig.WARN_COLOR
		else
			timerLabel.TextColor3 = UIConfig.DANGER_COLOR
		end
		currentDanger = d   -- 실제 비네트 크기는 렌더 루프에서 위험도 + 보유 맥동을 합쳐 처리
		-- 위험도 + 임박(≤10s) 시 강한 펄스: 임박 구간은 dangerLevel과 무관하게 크게 뜀
		local pulseAmt = d
		if sec <= UIConfig.TIMER_CRIT_SECONDS then pulseAmt = math.max(pulseAmt, 0.9) end
		if pulseAmt > 0 then
			local pulse = 1 + 0.18 * pulseAmt * (0.5 + 0.5 * math.sin(os.clock() * (4 + pulseAmt * 9)))
			timerLabel.TextSize = math.floor(30 * pulse)
		else
			timerLabel.TextSize = 30
		end
	end)

	network.on("BombOwnerChanged", function(ownerUserId)
		iAmOwner = (ownerUserId == player.UserId)
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
		label.Position = UDim2.new(0.5, xOff, 0.62, 0); label.TextTransparency = 0; label.TextStrokeTransparency = 0.4
		label.Parent = gui
		TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Position = UDim2.new(0.5, xOff, 0.5, 0), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		Debris:AddItem(label, 1.0)
	end)

	network.on("EffectTrigger", function(effectId, params)
		params = params or {}
		-- 폭탄을 받은 사람 화면에 짧은 붉은 플래시(전달/밀어내기 모두)
		if (effectId == "bombThrow" or effectId == "repel") and params.to == player.UserId and flash then
			flash.BackgroundColor3 = Color3.fromRGB(220, 45, 45)
			flash.BackgroundTransparency = 0.35
			TweenService:Create(flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		end
		if effectId == "bombThrow" and params.from == player.UserId and passPopup then
			passPopup.Visible = true; passPopup.TextTransparency = 0; passPopup.Size = UDim2.fromOffset(320, 80)
			TweenService:Create(passPopup, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(520, 80) }):Play()
			task.delay(0.5, function()
				TweenService:Create(passPopup, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
				task.delay(0.3, function() passPopup.Visible = false end)
			end)
		elseif effectId == "explosion" and flash then
			flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)   -- 폭발은 흰색(수신 붉은 플래시와 분리)
			flash.BackgroundTransparency = 0.2
			TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		elseif effectId == "blink" and params.userId == player.UserId then
			updateOneshot("blink", params.remaining or 0)   -- blink 은 VFX 겸용 이벤트
		elseif effectId == "buffUse" and params.userId == player.UserId then
			updateOneshot(params.id, params.remaining or 0)  -- reflect/repel 잔여 갱신
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
		gamePanel.Visible = true
		gamePanel.Size = UDim2.fromOffset(400, 330)
		TweenService:Create(gamePanel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(440, 360) }):Play()
	end)
end
return UIManager
