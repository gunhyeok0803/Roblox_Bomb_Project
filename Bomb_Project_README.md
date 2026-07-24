# 💣 폭탄 돌리기 (Bomb Pass) — 프로젝트 README

> 최대 6인 멀티플레이 "핫 포테이토(폭탄 돌리기)" 게임. Roblox Studio / Luau 기반.
> 처음 참여하는 팀원이 전체 구조와 로직, 그리고 "무엇을 어디서 고치는지"를 빠르게 파악하도록 작성했습니다.

---

## 1. 프로젝트 소개

플레이어들이 **폭탄을 서로에게 던지며** 폭발을 피하는 파티 게임입니다.

- 로비에서 **호스트 시작 / 나머지 Ready** 후 매치 시작 (최대 6명, 최소 2명)
- **총 5라운드**, 라운드마다 랜덤 시점에 폭탄 폭발
- 폭발한 플레이어는 **그 라운드만** 탈락, 다음 라운드 부활 → **전원이 5라운드 완주**
- **행동 점수**(생존·전달·클러치 등) 합산으로 최종 순위 결정
- 3라운드부터 라운드 시작 시 **버프 카드 1장 선택**
- 매치 종료 시 순위·MVP·통계 + **코인/XP 보상**(영속 저장)

**설계 철학**
- **서버 권한**: 모든 판정(폭탄·폭발·점수·보상·버프·랜덤)은 서버. 클라는 입력·UI·연출·사운드만.
- **모듈 + 의존성 주입**: 매니저 단위 책임 분리.
- **데이터/스타일 분리**: UI·사운드·이펙트는 코드가 아닌 **Studio 편집 에셋**으로.

---

## 2. 게임 규칙

| 항목 | 값 | 정의 위치 |
| --- | --- | --- |
| 최대 / 최소 인원 | 6 / 2 | `GameConstants.MAX_PLAYERS` / `MIN_PLAYERS` |
| 총 라운드 | 5 | `GameConstants.TOTAL_ROUNDS` |
| 라운드 제한시간 | 90초 | `GameConstants.ROUND_TIME` |
| 폭발 안전 구간 | 0~60초 | `GameConstants.BOMB_SAFE_TIME` |
| 실제 폭발 | **60~90초 랜덤** | `BombManager.arm()` |
| 버프 시작 라운드 | 3 | `GameConstants.BUFF_START_ROUND` |
| 버프 선택 제한시간 | 8초(초과 시 자동) | `GameConstants.BUFF_SELECT_TIME` |
| 자동 시작 대기 | 전원 Ready 후 5초 | `GameConstants.LOBBY_COUNTDOWN` |
| 투척 사거리 | 80 studs | `BombConfig.THROW_RANGE` |
| 투척 쿨다운 | 1.0초 | `BombConfig.THROW_COOLDOWN` |

**로비:** 호스트(첫 입장자)만 시작 버튼, 나머지는 준비 완료 토글. 전원 Ready → 호스트 시작 or 5초 자동.

**폭탄:** 라운드 시작 시 랜덤 1명 소유(스폰 6곳 배치) → 조준해 던지면 소유권 이전 → 60초 이후 랜덤 폭발 → 소유자 그 라운드 탈락.

### 점수 (`ScoreConfig`) — 최종 순위 기준
| 행동 | 점수 |
| --- | --- |
| 라운드 생존 | +100 |
| 폭탄 전달 | +15 |
| 클러치 전달 (60초 이후) | +40 |
| 연속 전달 스트릭 (n회째) | +5 × n |
| 원거리 투척 (30 studs↑) | +20 |
| 능동 버프 사용 | +10 |

### 버프 (3~5라운드, 카드 선택, `BuffConfig`) — 총 10종
| id | 이름 | 분류 | 효과 | 발동 |
| --- | --- | --- | --- | --- |
| `swift` ⚡ | 신속 | 지속 | 이동속도 ×1.30 | 자동 |
| `strongArm` 🎯 | 강견 | 지속 | 투척 거리 ×1.45 | 자동 |
| `highJump` ⏫ | 도약 | 지속 | 점프력 ×1.5 | 자동 |
| `blink` ✨ | 순간이동 | 일회성 | 16 studs 대시 · **3회** | **Q** |
| `reflect` 🛡️ | 반사막 | 일회성 | 다음 폭탄 반사 · **1회** | 자동 |
| `repel` ✋ | 밀어내기 | 일회성 | 폭탄 즉시 넘김 · **1회** | **E** |
| `reroll` 🎲 | 재추첨 | 메타 | 선택 시 새 카드로 교체 | 즉시 |
| `doubleDraw` ✖️ | 이중 획득 | 메타 | 선택 시 2장 지급 | 즉시 |
| `sluggish` 🐌 | 둔화 | 디버프 | 이동속도 ×0.80 | 자동 |
| `weakArm` 🔻 | 약한 팔 | 디버프 | 투척 거리 ×0.72 | 자동 |

> **카드 선택 흐름:** 각 플레이어에게 랜덤 카드 1장 오퍼 → 선택. **재추첨은 선택 시 새 버프 카드로 교체**(다시 선택), **이중 획득은 선택 시 2장 나란히**. 8초 초과 시 자동 확정.
>
> **오너샷 사용 횟수(blink 3 / reflect·repel 1):** `BuffConfig` 각 버프 `params.uses` 로 지정. HUD 칩에 잔여 횟수(`3/3 → 2/3 …`, `1/1 → 0/1`) 표시, 소진 시 칩이 회색+반투명 처리되고 자동 비활성화. **이중 획득으로도 최대치 초과 불가**(하드 캡), 라운드 종료 시 초기화.
>
> **도약(highJump):** R15 캐릭터는 기본이 `JumpHeight`(=`UseJumpPower false`)라 `JumpPower` 설정이 무시됨 → `BuffManager.applyMovement`에서 `UseJumpPower=true`로 강제해 실제 반영. 값(×1.5)이 과해 벽을 넘으면 `BuffConfig`에서 `jumpMult`를 1.35~1.4로 낮출 것.

---

## 3. 게임 전체 흐름

```
[Lobby] ──(전원 Ready · 호스트 시작 or 5초)──▶ [Waiting]
   │
   ▼
[RoundStart] ─▶ (버프 선택 3R~) ─▶ [BombSpawn] ─▶ [Playing] ─▶ [BombExplode] ─▶ [RoundResult]
 (전원 부활·스폰)   (카드 오퍼→선택        (폭탄 무장)   (투척·점수)   (소유자 탈락)   (라운드 점수)
                   ·8초 or 전원선택)
   │                                                                              │
   └──────────────── 5R 반복 ────────────────▶ [GameResult] (순위·MVP·코인/XP) ─▶ [Lobby]
```

---

## 4. 프로젝트 구조

> **레포 ↔ 실행 place**: 코드는 `src/`(Rojo). `src/shared`→`Shared`, `src/server`→`Server`, `src/client`→`Client`.
> **인스턴스 에셋(UI/사운드/이펙트/폭탄모델/스폰마커/맵)은 place 파일에만** 있고 레포엔 없음 → **작업 후 반드시 Ctrl+S 저장.**

```
ReplicatedStorage/Shared/
├─ Config/     GameConfig · BombConfig · BuffConfig · ScoreConfig · RewardConfig · SpawnConfig · UIConfig
├─ Constants/  GameConstants · StateConstants · RemoteNames
├─ Types/Types · Lib/(StateMachine, Signal, Util)
└─ Assets/     ★ Studio 편집 에셋
   ├─ BombGameUI   -- HUD + 로비버튼 + RoundIntro/PassPopup/Flash/DangerVignette/ScorePopup + 결과버튼 + BuffCardLayer
   ├─ Sounds/      -- 효과음 7종(SoundId 지정됨) + Bgm(루프)
   └─ Effects/     -- VFX 프리팹(Explosion/ThrowTrail/Puff*/BombGlow)

ServerScriptService/Server (부트스트랩)
└─ Managers/  NetworkManager · RandomService · DataManager · PlayerManager · StatsManager ·
              ScoreManager · BuffManager · SpawnManager · BombManager · ProgressionManager ·
              StateManager · RoundManager · GameManager · (TimerManager: 스텁·미사용)

ServerStorage/BombTemplate (폭탄 모델)
Workspace/BombPassArena (맵) · Workspace/SpawnPoints (Spawn1~6 마커, 투명)

StarterPlayer/StarterPlayerScripts/Client (부트스트랩)
└─ Controllers/  NetworkController · InputController · UIManager · EffectController · SoundController
```

---

## 5. 데이터 구조 (서버)

```lua
-- PlayerManager: states[userId] = { player, alive, score, activeBuffs, joinOrder(호스트 판정) }
--   + player.leaderstats(점수/코인) IntValue 자동 생성·실시간 갱신
-- BombManager: bombState = { ownerUserId, explodeAt(서버 전용), lastThrowAt, ownerSince, danger }
-- ScoreManager: scores[uid], streak[uid]        StatsManager: stats[uid]={passes,totalHoldTime,...}
-- BuffManager: mods[uid], oneshots[uid], pending[uid], selected[uid], roster[uid]
-- DataManager: profiles[uid]={coins,xp,level,wins,matches,...}  (DataStore, 없으면 메모리 폴백)
```

---

## 6. 시스템별 로직

- **GameManager** — 로비(Ready/시작) → 5라운드(부활·스폰·**버프 선택 단계**·플레이·점수) → 결과.
- **StateManager** — 9상태 FSM, 허용 전이 검증, `GameStateChanged` 방송.
- **RoundManager** — 라운드 타이머·`dangerLevel` 방송·랜덤 폭발 판정. (폭발 시각은 서버만 보관)
- **BombManager** — 소유권/부착(용접), **서버 권한 투척 판정**(투영+반경+벽 레이캐스트), 점수 훅.
- **BuffManager** — `offerRoundBuffs`(카드 오퍼) → `selectBuff`(재추첨=교체 / 이중획득=2장 / 그 외=적용) → `autoResolveRemaining`(타임아웃). 효과는 배수 누적/일회성 충전.
- **ScoreManager / StatsManager / ProgressionManager** — 점수·통계 누적, 매치 종료 시 순위·MVP·스타일 어워드·보상 산출·지급(영속).
- **PlayerManager / SpawnManager / DataManager** — 접속·호스트·leaderstats / 스폰 배정 / DataStore.
- **클라 컨트롤러** — NetworkController(배분/전송), InputController(투척·Q/E·카드선택), **UIManager**(HUD·로비·버프카드·결과·연출), **EffectController**(폭탄 글로우·투척궤적·폭발·**카메라 셰이크**·**소유자 외곽선**), **SoundController**(효과음·BGM·심박).

---

## 7. 이벤트 흐름 (요약)

```
[버프] ROUND_START(3R~) → BuffOffer(카드) → [클라 선택] RequestSelectBuff
       → 재추첨=새 BuffOffer / 이중획득=2장 done / 그외=적용+done → BuffGranted(HUD 칩)
[투척] 좌클릭 → RequestThrowBomb → BombManager(판정) → BombOwnerChanged + ScoreManager.award
       → ScorePopup / EffectTrigger(궤적·사운드) / 소유자 외곽선
[폭발] explodeAt 도달 → explode → EffectTrigger("explosion")(플래시·셰이크·폭발음) → RoundResult
[종료] 5R 후 buildResults → 코인/XP 영속 + MatchResult(순위·MVP·보상·Victory 사운드)
```

---

## 8. 네트워크 (Remote는 `Constants/RemoteNames`, 하드코딩 금지)

**Client → Server:** `RequestThrowBomb(aimDir)` · `RequestUseBuff(buffId)` · `RequestStartGame` · `RequestToggleReady` · `RequestSelectBuff`

**Server → Client:** `GameStateChanged` · `LobbyUpdate` · `RoundInfoUpdate` · `TimerUpdate` · `BombOwnerChanged` · `BuffGranted` · `BuffOffer`(fireTo, 카드) · `PlayerEliminated` · `RoundResult` · `ScorePopup`(fireTo) · `CurrencyUpdate`(fireTo) · `MatchResult` · `EffectTrigger`

---

## 9. 파일 수정 가이드 ★

> "무엇을 바꾸려면 어디를 만지는가". 대부분 **수치=Config**, **디자인=Studio 에셋**.

### 게임플레이 밸런스
| 하고 싶은 것 | 수정할 곳 |
| --- | --- |
| 라운드 수·시간·인원·자동시작·**버프 선택 8초** | `Shared/Constants/GameConstants` |
| **폭탄 사거리(80)**·쿨다운·판정반경 | `Shared/Config/BombConfig` |
| **행동 점수** (생존/전달/클러치/원거리…) | `Shared/Config/ScoreConfig` |
| **순위 보상** (코인/XP, MVP) | `Shared/Config/RewardConfig` |
| 기본 이동속도/점프력 | `Shared/Config/GameConfig` |

### 버프
| 하고 싶은 것 | 수정할 곳 |
| --- | --- |
| **버프 수치(세기)** | `BuffConfig` → 각 버프 `params`(예: `walkSpeedMult`, `rangeMult`, `dashStuds`) |
| 버프 **설명·아이콘(이모지)** | `BuffConfig` → `desc` / `icon` |
| 버프 **등장 확률** | `BuffConfig` → `weight` (클수록 자주) |
| 버프 추가/삭제 | `BuffConfig.List` (새 효과면 `BuffManager.applyBuff`) |
| **버프 카드 디자인** | Studio `Assets/BombGameUI/BuffCardLayer` (색은 UIManager `KIND_COLOR`) |

### UI / 연출 / 사운드 (전부 Studio 에셋)
| 하고 싶은 것 | 수정할 곳 |
| --- | --- |
| **HUD/로비/결과 UI 디자인** (색·크기·폰트·배치) | Studio `Assets/BombGameUI` (요소 이름은 유지) |
| UI 색상 상수 | `Shared/Config/UIConfig` |
| **효과음 (SoundId/볼륨)** | Studio `Assets/Sounds` 각 Sound |
| **BGM 트랙/볼륨** | Studio `Assets/Sounds/Bgm` (SoundId·Volume·Looped) |
| **이펙트 (색/파티클/모양)** | Studio `Assets/Effects` 프리팹 (Attribute 포함) |
| 폭발/위험 **카메라 셰이크 세기** | `Client/EffectController` (`shakeBurst`, danger 제곱커브 예열) |
| **타이머 색 임계값**(30초 주황/10초 빨강) | `Shared/Config/UIConfig` (`TIMER_WARN/CRIT_SECONDS`, `WARN_COLOR`) |
| **화면 가장자리 비네트**(위험 + 폭탄 보유 맥동) | `Client/UIManager` (`RenderStepped` 비네트 루프) |
| **폭탄 받을 때 붉은 화면 플래시** | `Client/UIManager` (`EffectTrigger` 수신 분기) |
| 폭탄 3D 모델 | Studio `ServerStorage/BombTemplate` |

### 맵 / 스폰
| 하고 싶은 것 | 수정할 곳 |
| --- | --- |
| **스폰 위치** | Studio `Workspace/SpawnPoints`의 `Spawn1~6` 드래그(방향=회전). 없으면 `SpawnConfig.Points` 사용 |
| 맵 | Studio `Workspace/BombPassArena` |

### 구조 확장
| 하고 싶은 것 | 수정할 곳 |
| --- | --- |
| 새 게임 상태 | `Constants/StateConstants` + `StateManager` + `GameManager` |
| 새 Remote | `Constants/RemoteNames` + 송수신 코드 (`NetworkManager`/`NetworkController`) |

---

## 10. 개발 규칙

- Luau 타입(`--!strict`) · ModuleScript · 매니저별 SRP · **의존성 주입**(부트스트랩 `deps`)
- **Magic Number 금지**(Config/Constants) · **Remote 이름 하드코딩 금지**(RemoteNames)
- **UI/사운드/이펙트는 코드가 아닌 에셋으로** · **서버 권한 준수**(판정=서버)
- 네이밍: `XxxManager` / `XxxController` / 상수 `UPPER_SNAKE`

---

## 11. 현재 상태 / 남은 것

**✅ 완료:** 로비 Ready · 5라운드 루프 · 폭탄/투척/폭발 · 버프 10종 + **선택 카드 UI**(재추첨·이중획득) · **순간이동 3회+잔여 카운터** · 점수/MVP/보상/leaderstats/ScorePopup · DataStore(메모리 폴백) · UX 연출(라운드 인트로·**타이머 3단계 색/펄스**·**폭탄 보유 비네트 맥동**·**폭발 예열 셰이크**·**수신 붉은 플래시**·소유자 외곽선) · **효과음 7종 + BGM** · 벽 안쪽 스폰 6곳 · 맵

**⬜ 남은 것 (2일 데모엔 선택):**
| 항목 | 비고 |
| --- | --- |
| place 저장 | **에셋이 place에만 있음 → Ctrl+S 필수** |
| DataStore 영속 | Studio "API 접근 허용" 켜야 실제 저장(현재 메모리) |
| 에셋 `.rbxmx` 레포 포함 / Rojo 이름 정합 | 레포 재현 계획 있을 때만 |
| 아이콘 PNG화 · 동점 서든데스 · 재접속 동기화 · 관전 카메라 | 여유 시 |

---

## 12. 빠른 시작 (테스트)

1. Studio **Test → Clients and Servers → 2 Players → Start**
2. 로비: 호스트=게임 시작 / 나머지=준비 완료 (또는 5초 자동)
3. 좌클릭으로 상대 조준해 폭탄 투척 → 점수(우측 leaderstats·화면 팝업)
4. 3라운드부터 **버프 카드 선택** (재추첨=새 카드, 이중획득=2장)
5. 60초 후 랜덤 폭발 → 5라운드 후 **결과(순위·MVP·코인/XP)**

> **DataStore 영속:** Game Settings → Security → "Enable Studio Access to API Services" ON (꺼져 있으면 메모리 모드).

---

*문서 최종 갱신: 2026-07-24*
