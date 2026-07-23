--!strict
-- 행동별 점수 (튜닝 지점)
local ScoreConfig = {}
ScoreConfig.SURVIVE_ROUND = 100      -- 라운드 생존
ScoreConfig.PASS = 15                -- 폭탄 전달 성공
ScoreConfig.CLUTCH_PASS = 40         -- 위험 구간(danger>0)에서 전달
ScoreConfig.LAST_SECOND_PASS = 60    -- 폭발 임박(N초 이내)에 전달
ScoreConfig.STREAK_PER = 5           -- 연속 전달 스트릭 (스트릭수 * 이 값)
ScoreConfig.BUFF_USE = 10            -- 능동 버프 사용
ScoreConfig.LONG_THROW = 20          -- 원거리 투척 성공
ScoreConfig.LAST_SURVIVOR = 50       -- 라운드 최후 생존
ScoreConfig.LONG_THROW_DIST = 30     -- 원거리 기준(studs)
ScoreConfig.LAST_SECOND_WINDOW = 3   -- 막판 전달 기준(초)
table.freeze(ScoreConfig)
return ScoreConfig
