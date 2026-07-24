--!strict
local UIConfig = {}
UIConfig.DANGER_COLOR = Color3.fromRGB(220, 60, 60)
UIConfig.WARN_COLOR = Color3.fromRGB(255, 170, 45)   -- 30초 이하 경고(주황)
UIConfig.SAFE_COLOR = Color3.fromRGB(90, 200, 120)
UIConfig.TIMER_FONT_SIZE = 32
UIConfig.TIMER_WARN_SECONDS = 30   -- 이하: 주황
UIConfig.TIMER_CRIT_SECONDS = 10   -- 이하: 빨강 + 강한 펄스
table.freeze(UIConfig)
return UIConfig
