# 💣 폭탄 돌리기 (Bomb Pass) — 프로젝트 README

> 최대 6인 멀티플레이 "핫 포테이토(폭탄 돌리기)" 게임. Roblox Studio / Luau 기반.
> 이 문서는 프로젝트에 처음 참여하는 팀원이 전체 구조와 로직을 빠르게 이해하도록 작성되었습니다.

---

## 1. 프로젝트 소개

플레이어들이 **폭탄을 서로에게 던지며** 폭발을 피하는 파티 게임입니다.

- 최대 **6명**, 최소 **2명**으로 시작
- 로비에서 **호스트 시작 / 나머지 Ready** 후 매치 시작
- **총 5라운드** 진행, 라운드마다 랜덤 시점에 폭탄이 폭발
- 폭발한 플레이어는 **그 라운드만** 탈락, 다음 라운드에 부활 → **전원이 5라운드를 끝까지 플레이**
- 라운드 생존 + 전달·클러치 등 **행동 점수를 합산**해 최종 순위 결정
- 매치 종료 시 순위·MVP·통계 표시 + **코인/XP 보상 지급(영속 저장)**

**설계 철학**

- **서버 권한(Server Authority)**: 모든 게임 판정(폭탄 소유·폭발·점수·보상·버프·랜덤)은 서버가 결정. 클라이언트는 입력·UI·연출·사운드만 담당.
- **확장 가능한 모듈 구조**: 매니저 단위 책임 분리 + 의존성 주입.
- **데이터/스타일 분리**: UI·사운드·이펙트는 코드가 아닌 **Studio에서 편집 가능한 에셋**으로 관리.

---

## 2. 게임 규칙

| 항목        | 값                | 정의 위치                            |
| --------- | ---------------- | -------------------------------- |
| 최대 인원     | 6명               | `GameConstants.MAX_PLAYERS`      |
| 최소 시작 인원  | 2명               | `GameConstants.MIN_PLAYERS`      |
| 총 라운드     | 5                | `GameConstants.TOTAL_ROUNDS`     |
| 라운드 제한시간  | 90초              | `GameConstants.ROUND_TIME`       |
| 폭발 안전 구간  | 0~60초 (폭발 없음)    | `GameConstants.BOMB_SAFE_TIME`   |
| 실제 폭발 시점  | **60~90초 사이 랜덤** | `BombManager.arm()`              |
| 버프 시작 라운드 | 3라운드부터           | `GameConstants.BUFF_START_ROUND` |
| 자동 시작 대기  | 전원 Ready 후 5초    | `GameConstants.LOBBY_COUNTDOWN`  |
| 투척 사거리    | 45 studs         | `BombConfig.THROW_RANGE`         |
| 투척 쿨다운    | 1.0초             | `BombConfig.THROW_COOLDOWN`      |

**로비 (매치 시작 조건)**

- **호스트 = 첫 입장 플레이어.** 호스트만 "게임 시작" 버튼 사용 가능
- 나머지 플레이어는 **"준비 완료" 토글**
- 전원 Ready(2명 이상) → 호스트가 시작하거나, **5초 후 자동 시작**

**폭탄 규칙**

- 라운드 시작 시 랜덤한 1명이 폭탄 소유 (스폰 6곳에 배치)
- 폭탄은 **항상 한 명만** 소유
- 소유자는 다른 플레이어를 조준해 폭탄을 던짐 → 맞으면 소유권 이전
- **60초 이후 랜덤 시점**에 폭발 (오래 들고 있을수록 위험)
- 폭발 시 소유자는 **그 라운드만 탈락** → 다음 라운드 부활 (영구 탈락 없음)
- 생존자 1명만 남으면 라운드 즉시 종료

**점수 (행동 기반, `ScoreConfig`)** — 최종 순위의 기준

| 행동                       | 점수     |
| ------------------------ | ------ |
| 라운드 생존                   | +100   |
| 폭탄 전달 성공                 | +15    |
| 클러치 전달 (위험 구간 danger>0)  | +40    |
| 막판 전달 (폭발 3초 이내)         | +60    |
| 연속 전달 스트릭 (n회째)          | +5 × n |
| 능동 버프 사용                 | +10    |
| 원거리 투척 (30 studs 이상)     | +20    |
| 라운드 최후 생존                | +50    |
| 폭발로 탈락                   | +0 (감점 없음) |

**버프 (3~5라운드, 생존자 전원 매 라운드 1개 추첨, `BuffConfig`)** — 총 10종

| 분류  | 버프                        |
| --- | ------------------------- |
| 지속  | 신속(속도), 강견(사거리), 도약(점프)   |
| 일회성 | 순간이동(Q), 반사막(자동), 밀어내기(E) |
| 메타  | 재추첨, 이중 획득                |
| 디버프 | 둔화, 약한 팔                  |

---

## 3. 게임 전체 흐름

```
[Lobby] ──(2명↑ · 전원 Ready · 호스트 시작 or 5초 자동)──▶ [Waiting]
                                                            │
   ┌────────────────────────────────────────────────────────┘
   ▼
[RoundStart] ─▶ [BombSpawn] ─▶ [Playing] ─▶ [BombExplode] ─▶ [RoundResult]
 (전원 부활      (폭탄 무장      (투척·점수     (소유자        (라운드 점수)
  ·스폰 배치      ·랜덤 소유자)    획득 반복)     그 라운드 탈락)
  ·버프 3R~)
                                                                  │
                             ┌────────────────────────────────────┤
                             ▼ (라운드 < 5)          (라운드 = 5) ▼
                        [NextRound] ─▶ RoundStart      [GameResult]
                         (인터미션)                     ├─ 점수 순위 산출
                                                        ├─ MVP·스타일 어워드
                                                        ├─ 코인/XP 지급(영속)
                                                        └─ MatchResult 방송 ─▶ [Lobby]
```

---

## 4. 프로젝트 구조

> **레포(git) ↔ 실행 place**: 코드는 `src/`에서 관리하며 Rojo로 동기화합니다.
> `src/shared`→`ReplicatedStorage.Shared`, `src/server`→`ServerScriptService.Server`, `src/client`→`StarterPlayerScripts.Client`.
> UI/사운드/이펙트/폭탄 모델 등 **인스턴스 에셋은 place 파일에만** 있고 레포엔 없습니다(코드가 아니라서).

```
ReplicatedStorage/
└─ Shared/
   ├─ Config/                  -- 튜닝 값 (자주 바꾸는 상수)
   │  ├─ GameConfig            -- 기본 이동 스탯 등
   │  ├─ BombConfig            -- 사거리/쿨다운/판정반경/부착 오프셋
   │  ├─ BuffConfig            -- ★ 버프 데이터 (10종)
   │  ├─ ScoreConfig           -- ★ 행동별 점수
   │  ├─ RewardConfig          -- ★ 순위별 코인/XP 보상
   │  ├─ SpawnConfig           -- ★ 스폰 위치 (맵 마커 없을 때 폴백)
   │  └─ UIConfig              -- UI 색상 상수
   ├─ Constants/               -- 고정 상수
   │  ├─ GameConstants         -- 인원/라운드/시간
   │  ├─ StateConstants        -- 상태 이름
   │  └─ RemoteNames           -- Remote 이름
   ├─ Types/Types              -- Luau 타입 정의
   ├─ Lib/                     -- 범용 도구 (StateMachine, Signal, Util)
   └─ Assets/                  -- ★ Studio에서 편집하는 에셋
      ├─ BombGameUI            -- ScreenGui 템플릿 (HUD/로비 버튼/결과/점수팝업)
      ├─ Sounds/               -- Sound 인스턴스 (SoundId는 Studio에서 지정)
      └─ Effects/              -- VFX 프리팹 (Explosion/ThrowTrail/Puff*/BombGlow)

ReplicatedStorage/Remotes/     -- 런타임에 NetworkManager가 생성

ServerScriptService/Server (부트스트랩 Script)
   └─ Managers/
      ├─ NetworkManager        -- Remote 생성/송수신
      ├─ RandomService         -- 모든 랜덤 (단일 시드)
      ├─ DataManager           -- ★ DataStore(코인/XP/레벨) + 메모리 폴백
      ├─ PlayerManager         -- 접속/생존/호스트/리스폰/leaderstats
      ├─ StatsManager          -- ★ 매치 통계 누적
      ├─ ScoreManager          -- ★ 행동→점수, leaderstats/ScorePopup
      ├─ BuffManager           -- 버프 추첨/적용/능동사용
      ├─ SpawnManager          -- ★ 스폰 6곳 셔플 배정
      ├─ BombManager           -- ★ 폭탄 상태/투척 판정/부착/점수 훅
      ├─ ProgressionManager    -- ★ 매치 순위·MVP·보상 산출/지급
      ├─ StateManager          -- FSM 구동
      ├─ RoundManager          -- 라운드 타이머/폭발 판정
      ├─ GameManager           -- 전체 게임 루프 + 로비 Ready
      └─ TimerManager          -- 타이머 헬퍼 (※ 현재 스텁, 미사용)

ServerStorage/
└─ BombTemplate  (Model)       -- 폭탄 3D 모델 원본

StarterPlayer/StarterPlayerScripts/Client (부트스트랩 LocalScript)
   └─ Controllers/
      ├─ NetworkController     -- Remote 수신 배분/서버 요청
      ├─ InputController       -- 조준/투척/능동버프 입력
      ├─ UIManager             -- UI 데이터 바인딩 (로비/HUD/결과/점수팝업)
      ├─ EffectController      -- Effects 프리팹 재생 + 위험도 글로우
      └─ SoundController       -- 사운드 재생
```

---

## 5. 데이터 구조

### PlayerManager — 플레이어 상태 (서버)

```lua
states[userId] = {
    player = Player,
    alive = boolean,          -- 현재 라운드 생존 여부
    score = number,           -- (레거시) PlayerManager 자체 점수
    activeBuffs = { string },
    joinOrder = number,       -- 입장 순서 (호스트 판정용, 작을수록 먼저)
}
-- 접속 시 player.leaderstats(점수/코인) IntValue 자동 생성 → 실시간 갱신
```

### BombManager — 폭탄 상태 (서버, 단일 소스)

```lua
bombState = {
    ownerUserId = number?,    -- 현재 폭탄 소유자 (nil = 없음)
    explodeAt = number?,      -- ★ 폭발 예정 시각(os.clock) — 서버 전용, 절대 클라 미전송
    lastThrowAt = number,     -- 마지막 투척 시각(쿨다운)
    ownerSince = number,      -- 현재 소유 시작 시각(보유시간 통계)
    danger = 0..1,            -- RoundManager가 매 틱 갱신(클러치 판정용)
}
bombInstance = Model?         -- workspace 의 폭탄 실물
```

### ScoreManager / StatsManager — 매치 단위 (라운드/매치 초기화)

```lua
-- ScoreManager
scores[userId] = number       -- 매치 누적 점수 (최종 순위 기준)
streak[userId] = number       -- 연속 전달 스트릭

-- StatsManager
stats[userId] = {
    passes, totalHoldTime, survivedRounds,
    explodedCount, farthestThrow, matchScore,
}
```

### DataManager — 영속 프로필 (DataStore, 계정 단위)

```lua
profiles[userId] = {
    coins, xp, level, wins, matches,
    equippedSkin = "Default", unlockedSkins = { Default = true },
}
-- DataStore 접근 불가(Studio API off 등) 시 자동으로 메모리 모드 폴백
```

### 주요 Config

```lua
-- ScoreConfig: 행동별 점수값 (SURVIVE_ROUND, PASS, CLUTCH_PASS, ...)
-- RewardConfig: PLACEMENT[1..3], DEFAULT, PARTICIPATION, MVP_BONUS, XP_PER_LEVEL=500
-- SpawnConfig: Points = { Vector3, ... } (맵 마커 없을 때 폴백)
-- BuffConfig: { id, name, kind, rarity, weight, params }
```

---

## 6. 시스템별 로직 설명

### GameManager (전체 루프 + 로비)

- **로비**: 매 틱 `LobbyUpdate` 방송(인원·호스트·Ready 상태). 전원 Ready + (호스트 시작 or 5초 자동) → 매치 시작.
- **매치**: 5라운드 반복. 각 라운드 `respawnAll`(전원 부활) → `SpawnManager` 배치 → (3R~)버프 → `RoundManager.run`.
- **종료**: `ProgressionManager.buildResults()`로 순위·MVP·보상 산출·지급 → `MatchResult` 방송.
- `requestStart`(호스트만), `toggleReady`(비호스트만) — 서버 검증.

### StateManager (상태 기계)

`Lib/StateMachine`으로 9개 상태 정의 + **허용된 전이만** 검증. 전이 시 `GameStateChanged` 방송.

### RoundManager (라운드 진행)

`Heartbeat` 루프: 남은시간·`dangerLevel` 계산 → `TimerUpdate` 방송 + `BombManager.updateDanger`. `explodeAt` 도달 시 `explode()`.
> **폭발 시각은 서버만 보관.** 클라엔 `dangerLevel`(근사값)만 전송.

### BombManager (폭탄 핵심)

- `_setOwner()`: 소유권 갱신 + 이전 소유자 **보유시간 통계** + 폭탄 모델 재용접 + `BombOwnerChanged` 방송.
- `onThrowRequest()` (서버 권한): 소유자/쿨다운/사거리 검증 → `_findTarget`(투영+반경+벽 레이캐스트) → 반사막 체크 → **점수 처리(전달/클러치/막판/원거리/스트릭)** → 소유권 이전.
- `explode()`: 소유자 폭발 통계 + 폭탄 제거 + `EffectTrigger("explosion")`.

### ScoreManager (점수)

`award(userId, reason)` → `ScoreConfig` 값 가산 → **leaderstats "점수" 실시간 갱신** + 해당 플레이어에게 `ScorePopup` 전송. `bumpStreak`로 연속 전달 보너스.

### StatsManager (통계)

`add/max`로 매치 통계 누적. `ProgressionManager`의 MVP·스타일 어워드 산정에 사용.

### ProgressionManager (결과·보상)

`buildResults()`: 점수 정렬 → 순위/MVP → **스타일 어워드**(전달왕/생존왕/스나이퍼/불운왕, 통계 1위) → `RewardConfig` 순위별 코인/XP 계산 → `DataManager.addCurrency`로 **영속 지급** → 결과 payload 반환.

### DataManager (영속 저장)

`PlayerAdded` 시 프로필 로드, 이탈/종료 시 저장. `addCurrency`로 코인/XP 갱신 → **leaderstats "코인" + `CurrencyUpdate` 전송**. DataStore 불가 시 메모리 모드.

### PlayerManager (플레이어)

접속/이탈, **호스트 판정(`getHost`, 입장 순서)**, 라운드마다 전원 리스폰, **leaderstats 생성·갱신(`setStat`)**.

### SpawnManager (스폰)

`Workspace.SpawnPoints`(BasePart들)가 있으면 우선 사용, 없으면 `SpawnConfig.Points`. 라운드 시작 시 셔플 배정 → 캐릭터 HRP 이동.

### BuffManager (버프)

`grantRoundBuffs`(가중치 추첨 + 메타 처리), `applyBuff`(배수 누적/일회성 충전), `getModifiers`, `useActiveBuff`(순간이동/밀어내기, +버프 점수).

### 클라이언트 컨트롤러

- **NetworkController**: Remote 수신 배분(`on`) / 서버 요청(`send`).
- **InputController**: 좌클릭·터치=투척, Q=순간이동, E=밀어내기.
- **UIManager**: 템플릿 clone 후 **속성만 갱신**. 로비(호스트 시작/Ready), HUD(타이머 `mm:ss`·소유자·버프칩), 결과(MatchResult 순위·MVP·보상), **ScorePopup 플로팅 토스트**.
- **EffectController**: `Assets.Effects` 프리팹 clone 재생(`PlayMode`: emit/expand/travel) + 폭탄 위험도 글로우(초록→빨강).
- **SoundController**: `Assets.Sounds` 이름 재생 + 위험도 심박. SoundId 미지정 시 무음.

---

## 7. 이벤트 흐름

**로비 시작**
```
[클라] 호스트=게임시작 / 비호스트=준비완료 버튼
  └─ RequestStartGame / RequestToggleReady
       └─ [서버] GameManager: 전원 Ready + (시작 or 5초 자동) → 매치
```

**투척 + 점수**
```
[클라] 좌클릭 → RequestThrowBomb(aimDir)
  └─ [서버] BombManager.onThrowRequest() (판정 서버 재계산)
       ├─ _findTarget → _setOwner(target) → BombOwnerChanged
       ├─ ScoreManager.award(전달/클러치/막판/원거리/스트릭)
       │     └─ leaderstats "점수" 갱신 + ScorePopup(본인) 전송
       └─ EffectTrigger("bombThrow") → 궤적/사운드
```

**매치 종료**
```
[서버] 5라운드 종료 → ProgressionManager.buildResults()
  ├─ 점수 순위 + MVP + 스타일 어워드
  ├─ DataManager.addCurrency (코인/XP 영속 + CurrencyUpdate + leaderstats "코인")
  └─ MatchResult 방송 → [클라] 결과 화면(순위·MVP·내 보상)
```

---

## 8. 네트워크 (Server / Client)

**Remote 이름은 `Constants/RemoteNames`에 정의. 하드코딩 금지.**

### Client → Server (RemoteEvent)

| 이름                   | 인자                      | 서버 검증               |
| -------------------- | ----------------------- | ------------------- |
| `RequestThrowBomb`   | `aimDirection: Vector3` | 소유자 본인·쿨다운·사거리 재계산  |
| `RequestUseBuff`     | `buffId: string`        | 해당 능동 버프 보유 여부      |
| `RequestStartGame`   | (없음)                    | **호스트만** + 전원 Ready |
| `RequestToggleReady` | (없음)                    | **비호스트만**           |

### Server → Client (RemoteEvent)

| 이름                 | 인자                                              | 대상        |
| ------------------ | ----------------------------------------------- | --------- |
| `GameStateChanged` | `stateName, payload`                            | Broadcast |
| `LobbyUpdate`      | `{ hostUserId, min, count, players[], allReady, countingDown, secondsLeft }` | Broadcast |
| `RoundInfoUpdate`  | `{ round, totalRounds, alive }`                 | Broadcast |
| `TimerUpdate`      | `{ phase, secondsLeft, dangerLevel }`           | Broadcast |
| `BombOwnerChanged` | `ownerUserId, previousOwnerUserId`              | Broadcast |
| `BuffGranted`      | `userId, buffId, buffMeta`                      | Broadcast |
| `PlayerEliminated` | `userId, round`                                 | Broadcast |
| `RoundResult`      | `{ round, scores }`                             | Broadcast |
| `ScorePopup`       | `{ reason, points, total }`                     | **fireTo(본인)** |
| `CurrencyUpdate`   | `{ coins, xp, level }`                          | **fireTo(본인)** |
| `MatchResult`      | `{ ranking, mvpUserId, mvpName, mvpTitle, awards, rewards, stats }` | Broadcast |
| `EffectTrigger`    | `effectId, params`                              | Broadcast |

### RemoteFunction

| 이름            | 용도                      |
| ------------- | ----------------------- |
| `GetSnapshot` | (예약) 접속/재접속 시 상태 동기화    |

**서버 권한 원칙** — 폭탄 소유·폭발·점수·보상·라운드/승패·버프·랜덤은 서버에서만. 클라는 입력 전송 + UI/이펙트/사운드만.

---

## 9. 파일 수정 가이드

| 하고 싶은 것                | 수정할 곳                                                        |
| ---------------------- | ------------------------------------------------------------ |
| 라운드 수·시간·인원·자동시작 지연    | `Shared/Constants/GameConstants`                             |
| 행동별 점수                 | `Shared/Config/ScoreConfig`                                  |
| 순위별 코인/XP 보상           | `Shared/Config/RewardConfig`                                 |
| 폭탄 사거리·쿨다운·판정반경        | `Shared/Config/BombConfig`                                   |
| 버프 추가/삭제/확률            | `Shared/Config/BuffConfig` (+ 새 효과면 `BuffManager.applyBuff`) |
| 스폰 위치(폴백)              | `Shared/Config/SpawnConfig` (또는 맵에 `Workspace.SpawnPoints`)  |
| **UI 디자인(색/크기/폰트/배치)** | **Studio에서** `Assets/BombGameUI` **편집**                      |
| **이펙트(색/파티클/강도)**      | **Studio에서** `Assets/Effects` **프리팹 편집** (Attribute 포함)      |
| **사운드(SoundId/볼륨)**    | **Studio에서** `Assets/Sounds` **각 Sound 편집**                  |
| 폭탄 모델 외형               | Studio에서 `ServerStorage/BombTemplate` 편집                     |
| 새 게임 상태                | `Constants/StateConstants` + `StateManager` + `GameManager`  |
| 새 Remote               | `Constants/RemoteNames` + 송수신 코드                             |

**스폰 마커 규격 (맵 담당자용)**: `Workspace/SpawnPoints` 폴더에 `Spawn1`~`Spawn6` **BasePart** 6개를 두면 SpawnManager가 이름순으로 자동 사용합니다(없으면 `SpawnConfig` 사용).

---

## 10. 개발 규칙

- **Luau 타입 사용** (`--!strict`, `export type`)
- **ModuleScript 기반** + 매니저별 책임 분리(SRP) + **의존성 주입**(부트스트랩 `deps`)
- **Magic Number 금지**: 수치는 `Config`/`Constants`로 분리
- **Remote 이름 하드코딩 금지**: `RemoteNames` 사용
- **UI/사운드/이펙트는 코드가 아닌 에셋으로**: 레이아웃/스타일/SoundId/파티클을 코드에 넣지 않음
- **서버 권한 준수**: 판정은 서버, 클라는 요청·표현만
- **함수 분리 + 주석**, **네이밍**: `XxxManager` / `XxxController` / 상수 `UPPER_SNAKE`

---

## 11. 향후 개발 예정

| 항목                       | 상태     | 비고                                            |
| ------------------------ | ------ | --------------------------------------------- |
| 코인 사용처(폭탄 스킨 상점)         | ⬜      | 코인 소비 루프 완성 — `BombTemplate` 교체 방식으로 추가       |
| 일일 미션                    | ⬜      | 리텐션. `MissionConfig` 예정                       |
| 에셋 `.rbxmx` 내보내기         | ⬜      | UI/사운드/이펙트/폭탄모델을 레포에 포함(clone만으로 완전 재현)       |
| 맵/블록아웃 + 스폰 마커           | ⬜ 작업중  | 팀원 진행 중. `Workspace/SpawnPoints` 6개 두면 자동 적용  |
| SoundId 지정               | ⬜      | `Assets/Sounds`에 오디오 ID 입력 필요 (현재 무음)         |
| 동점 서든데스                  | ⬜      | `GameConfig.SUDDEN_DEATH_ON_TIE` 플래그만 존재      |
| `GetSnapshot` 재접속 동기화    | ⬜      | Remote만 정의됨                                   |
| TimerManager             | ⬜ 스텁   | 현재 각 매니저가 자체 타이밍. 미사용                         |
| 관전자 카메라                  | ⬜      | 현재 탈락 시 배너만 표시                                |
| ~~매치 점수제 / MVP / 보상~~    | ✅ 완료   | ScoreManager/ProgressionManager               |
| ~~DataStore 영속 저장~~      | ✅ 완료   | DataManager (메모리 폴백 포함)                       |
| ~~leaderstats / ScorePopup~~ | ✅ 완료 | 실시간 점수·코인 표시 + 점수 토스트                        |
| ~~로비 Ready / 호스트 시작~~    | ✅ 완료   | 전원 Ready 후 5초 자동 시작                           |

---

## 12. 최종 요약

- **장르**: 최대 6인 폭탄 돌리기 파티 게임 (5라운드, **행동 점수제 + 코인/XP 성장**)
- **아키텍처**: 서버 권한 + 매니저 모듈(FSM + 의존성 주입)
- **완성**: 로비 Ready · 5라운드 루프(전원 완주) · 폭탄/투척/폭발 · 10종 버프 · 3D 폭탄 · UI · 이펙트(프리팹) · 사운드 골격 · **점수/MVP/보상/영속저장 · leaderstats/ScorePopup · 스폰 배정**
- **핵심 분리 원칙**:
  - 판정 = **서버**, 표현 = **클라이언트**
  - 수치 = **Config/Constants**
  - UI/사운드/이펙트 = **Studio 에셋** (코드 무수정으로 변경)
- **바로 해야 할 것**: `Assets/Sounds` SoundId 지정, 맵 완성 후 `Workspace/SpawnPoints` 배치, 코인 상점(스킨)

**빠른 시작 (테스트)**

1. Studio **Test 탭 → Clients and Servers → 2 Players → Start**
2. 로비에서 호스트=게임 시작 / 나머지=준비 완료 (또는 전원 준비 후 5초 자동)
3. 좌클릭으로 상대 조준해 폭탄 투척 → 점수 획득(우측 leaderstats·화면 토스트), 60초 후 랜덤 폭발
4. 5라운드 후 순위·MVP·보상 결과 화면

> **DataStore 영속 저장**은 Studio **Game Settings → Security → "Enable Studio Access to API Services"**를 켜야 실제 저장됩니다(꺼져 있으면 메모리 모드).

---

*문서 최종 갱신: 2026-07-23*
