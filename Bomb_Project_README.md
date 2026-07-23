# 💣 폭탄 돌리기 (Bomb Pass) — 프로젝트 README

> 최대 6인 멀티플레이 "핫 포테이토(폭탄 돌리기)" 게임. Roblox Studio / Luau 기반.
> 이 문서는 프로젝트에 처음 참여하는 팀원이 전체 구조와 로직을 빠르게 이해하도록 작성되었습니다.

---

## 1. 프로젝트 소개

플레이어들이 **폭탄을 서로에게 던지며** 폭발을 피하는 파티 게임입니다.

- 최대 **6명**, 최소 **2명**으로 시작
- **총 5라운드** 진행, 각 라운드 생존 시 점수 획득
- 라운드마다 랜덤한 시점에 폭탄이 폭발 → 당시 폭탄 소유자 탈락
- 5라운드 누적 점수로 **최종 승자** 결정

**설계 철학**

- **서버 권한(Server Authority)**: 모든 게임 판정(폭탄 소유·폭발·탈락·버프·랜덤)은 서버가 결정. 클라이언트는 입력·UI·연출·사운드만 담당.
- **확장 가능한 모듈 구조**: 매니저 단위 책임 분리 + 의존성 주입.
- **데이터/스타일 분리**: UI·사운드는 코드가 아닌 **Studio에서 편집 가능한 에셋**으로 관리.

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
| 투척 사거리    | 45 studs         | `BombConfig.THROW_RANGE`         |
| 투척 쿨다운    | 1.0초             | `BombConfig.THROW_COOLDOWN`      |
| 점수        | 생존 라운드당 +1       | `GameConfig.SCORE_PER_SURVIVAL`  |


**폭탄 규칙**

- 라운드 시작 시 랜덤한 1명이 폭탄 소유
- 폭탄은 **항상 한 명만** 소유
- 소유자는 다른 플레이어를 조준해 폭탄을 던짐 → 맞으면 소유권 이전
- **60초 이후 랜덤 시점**에 폭발 (오래 들고 있을수록 위험)
- 폭발 시 소유자 탈락, 라운드 종료
- 생존자 1명만 남으면 라운드 즉시 종료

**버프 (3~5라운드, 생존자 전원 매 라운드 1개 추첨)** — 총 10종


| 분류  | 버프                        |
| --- | ------------------------- |
| 지속  | 신속(속도), 강견(사거리), 도약(점프)   |
| 일회성 | 순간이동(Q), 반사막(자동), 밀어내기(E) |
| 메타  | 재추첨, 이중 획득                |
| 디버프 | 둔화, 약한 팔                  |


---



## 3. 게임 전체 흐름

```
[Lobby] ──(2명 이상)──▶ [Waiting] ──(5초 카운트다운)──▶ 라운드 루프 시작
                                                             │
   ┌─────────────────────────────────────────────────────────┘
   ▼
[RoundStart] ─▶ [BombSpawn] ─▶ [Playing] ─▶ [BombExplode] ─▶ [RoundResult]
 (리스폰/버프)   (폭탄 무장)     (투척 반복)   (소유자 탈락)      (점수 표시)
                                                                  │
                             ┌────────────────────────────────────┤
                             ▼ (라운드 < 5)          (라운드 = 5) ▼
                        [NextRound] ─▶ RoundStart      [GameResult] ─▶ [Lobby]
                         (인터미션)                     (최종 랭킹)
```

각 상태의 역할은 [6. 시스템별 로직 설명](#6-시스템별-로직-설명)의 StateManager / GameManager 참고.

---



## 4. 프로젝트 구조

```
ReplicatedStorage/
└─ Shared/
   ├─ Config/                  -- 튜닝 값 (자주 바꾸는 상수)
   │  ├─ GameConfig            -- 점수/기본 이동 스탯
   │  ├─ BombConfig            -- 사거리/쿨다운/판정반경/부착 오프셋
   │  ├─ BuffConfig            -- ★ 버프 데이터 테이블 (10종)
   │  └─ UIConfig              -- UI 색상 상수
   ├─ Constants/               -- 고정 상수 (게임 규칙)
   │  ├─ GameConstants         -- 인원/라운드/시간
   │  ├─ StateConstants        -- 상태 이름
   │  └─ RemoteNames           -- Remote 이름
   ├─ Types/Types              -- Luau 타입 정의
   ├─ Lib/                     -- 범용 도구
   │  ├─ StateMachine          -- 재사용 가능한 FSM
   │  ├─ Signal                -- BindableEvent 래퍼
   │  └─ Util                  -- 유틸(가중치 추첨 등)
   └─ Assets/                  -- ★ Studio에서 편집하는 에셋
      ├─ BombGameUI            -- ScreenGui 템플릿 (8종 UI)
      └─ Sounds/               -- Sound 인스턴스 (SoundId는 Studio에서 지정)

ReplicatedStorage/Remotes/     -- 런타임에 NetworkManager가 생성

ServerScriptService/
└─ BombGameServer  (Script, 부트스트랩)
   └─ Managers/
      ├─ NetworkManager        -- Remote 생성/송수신
      ├─ RandomService         -- 모든 랜덤 (단일 시드)
      ├─ PlayerManager         -- 접속/생존/점수/리스폰
      ├─ BuffManager           -- 버프 추첨/적용/능동사용
      ├─ TimerManager          -- 타이머 헬퍼 (※ 현재 스텁)
      ├─ BombManager           -- ★ 폭탄 상태/투척 판정/부착
      ├─ StateManager          -- FSM 구동
      ├─ RoundManager          -- 라운드 타이머/폭발 판정
      └─ GameManager           -- 전체 게임 루프

ServerStorage/
└─ BombTemplate  (Model)       -- 폭탄 3D 모델 원본

StarterPlayer/StarterPlayerScripts/
└─ BombGameClient  (LocalScript, 부트스트랩)
   └─ Controllers/
      ├─ NetworkController     -- Remote 수신 배분/서버 요청
      ├─ InputController       -- 조준/투척/능동버프 입력
      ├─ UIManager             -- UI 데이터 바인딩 (레이아웃 X)
      ├─ EffectController      -- 폭탄 글로우/투척/폭발 연출
      └─ SoundController       -- 사운드 재생
```

**두 개의 부트스트랩**

- `BombGameServer` (Script): 매니저 require → 의존성 주입 → `GameManager.start()`
- `BombGameClient` (LocalScript): 컨트롤러 require → 각 `init(network)` 호출

---



## 5. 데이터 구조



### PlayerManager — 플레이어 상태 (서버)

```lua
states[userId] = {
    player = Player,        -- Player 인스턴스
    alive = boolean,        -- 현재 라운드 생존 여부
    score = number,         -- 누적 점수 (생존 라운드 수)
    activeBuffs = { string },-- 보유 버프 id 목록
}
```



### BombManager — 폭탄 상태 (서버, 단일 소스)

```lua
bombState = {
    ownerUserId = number?,   -- 현재 폭탄 소유자 (nil = 없음)
    explodeAt = number?,     -- ★ 폭발 예정 시각 (os.clock 절대값) — 서버 전용, 절대 클라 전송 금지
    lastThrowAt = number,    -- 마지막 투척 시각 (쿨다운 계산)
}
bombInstance = Model?        -- workspace 의 폭탄 실물
```



### BuffManager — 버프 상태 (서버, 라운드마다 초기화)

```lua
mods[userId] = {             -- 누적 배수 (1.0 = 변화 없음)
    walkSpeedMult, jumpMult, rangeMult,
    hitRadiusMult, targetRadiusMult, cooldownMult, homingStrength,
}
oneshots[userId] = { blink = n, reflect = bool, repel = bool }  -- 일회성 버프 충전
grantedList[userId] = { buffId, ... }                            -- 지급 이력 (UI용)
```



### BuffConfig — 버프 정의 (공유)

```lua
{ id="swift", name="신속", kind="duration", rarity="common",
  weight=100, params={ walkSpeedMult=1.18 } }
-- kind: "duration" | "oneshot" | "meta" | "debuff"
-- weight: 가중치 추첨 확률 (희귀할수록 작게)
```

---



## 6. 시스템별 로직 설명



### GameManager (전체 루프)

게임의 최상위 진행. `start()`가 무한 루프로 로비 대기 → 5라운드 반복 → 최종 결과 → 로비 복귀. 각 단계에서 `StateManager.to()`로 상태 전이하고 다른 매니저를 호출.

### StateManager (상태 기계)

`Lib/StateMachine`으로 9개 상태를 정의하고 **허용된 전이만** 검증(잘못된 흐름 조기 차단). 상태가 바뀌면 `GameStateChanged`를 전 클라에 방송.

### RoundManager (라운드 진행)

단일 라운드를 블로킹 실행. 폭탄 무장(`arm`) + 초기 소유자 지정 후 `Heartbeat` 루프에서:

- 남은 시간 + `dangerLevel`(0~1) 계산 → `TimerUpdate` 방송
- 서버 시각이 `explodeAt` 도달 → `BombManager.explode()` → 탈락자 반환
- 생존 1명 → 라운드 즉시 종료
  > **폭발 시각은 서버만 보관.** 클라에는 `dangerLevel`(연출용 근사값)만 보내므로 리버싱해도 정확한 폭발 시각을 알 수 없음.



### BombManager (폭탄 핵심)

- **소유권**: `_setOwner()`가 상태 갱신 + 폭탄 모델을 새 소유자 머리에 용접 + `BombOwnerChanged` 방송
- **투척 판정 (서버 권한)**: `onThrowRequest(player, aimDirection)`
  1. 소유자 본인 확인 → 쿨다운 확인(버프 반영) → 조준 벡터 정규화
  2. `_findTarget`: 조준선을 따라 각 생존자를 **투영 거리 + 타겟별 유효 반경**으로 검사, **벽 레이캐스트**로 차단 확인
  3. 유효 타겟 → 반사막 체크 → 소유권 이전
  4. 빗맞으면 폭탄 유지 (실력 요소)
- **폭탄 모델**: `ServerStorage.BombTemplate` clone → `WeldConstraint`로 머리 위(오프셋 `(0,2.5,0)`)에 부착. Massless라 물리 방해 없음, 위치 자동 복제.



### PlayerManager (플레이어)

접속/이탈 감지, 라운드마다 전원 리스폰(`respawnAll` → `LoadCharacter`), 생존자 점수 부여, 랭킹 산출.

### BuffManager (버프)

- `grantRoundBuffs`: 라운드 초기화 후 생존자마다 가중치 추첨. **메타 처리**(재추첨=다시 뽑기, 이중 획득=2개 지급).
- `applyBuff`: 지속/디버프는 배수 누적 + WalkSpeed/JumpPower 반영. 일회성은 충전.
- `getModifiers(userId)`: BombManager가 조회하는 배수 반환.
- `useActiveBuff`: 순간이동(HRP 이동), 밀어내기(랜덤 전달).



### 클라이언트 컨트롤러

- **NetworkController**: Remote 수신 → 구독자에 배분(`on`), 서버로 요청(`send`).
- **InputController**: 좌클릭/터치 = 투척(조준 방향 전송), Q = 순간이동, E = 밀어내기.
- **UIManager**: 템플릿 clone 후 **이름으로 요소 참조해 속성만 갱신** (레이아웃 생성 안 함). 타이머는 `mm:ss` 포맷.
- **EffectController**: 폭탄 위험도 글로우(초록→빨강 Highlight), 투척 궤적, 폭발(비살상 Explosion), 순간이동/반사 퍼프.
- **SoundController**: `Assets.Sounds`를 이름으로 재생. 위험도 심박(간격/피치 상승). SoundId 미지정 시 무음.

---



## 7. 이벤트 흐름

**투척 예시**

```
[클라] 좌클릭
  └─ InputController → NetworkController.send("RequestThrowBomb", aimDir)
       └─ [서버] BombManager.onThrowRequest()  ※ 모든 판정 서버 재계산
            ├─ 소유자/쿨다운/사거리 검증
            ├─ _findTarget (투영 + 반경 + 벽 레이캐스트)
            ├─ _setOwner(target)  → BombOwnerChanged 방송 + 폭탄 재용접
            └─ EffectTrigger("bombThrow") 방송
                 └─ [전 클라] EffectController 궤적, SoundController "Throw", UIManager 소유자 갱신
```

**폭발 예시**

```
[서버] RoundManager 루프: os.clock() >= explodeAt
  └─ BombManager.explode() → 탈락자 반환 + 폭탄 제거 + EffectTrigger("explosion")
       └─ [서버] GameManager: PlayerManager.eliminate() → PlayerEliminated 방송
            └─ StateManager.to(RoundResult) → RoundResult 방송
                 └─ [클라] UIManager 결과 패널, EffectController 폭발, SoundController "Explosion"
```

---



## 8. 네트워크 (Server / Client)

**Remote 이름은** `Constants/RemoteNames`**에 정의. 하드코딩 금지.**

### Client → Server (RemoteEvent)


| 이름                 | 인자                      | 서버 검증              |
| ------------------ | ----------------------- | ------------------ |
| `RequestThrowBomb` | `aimDirection: Vector3` | 소유자 본인·쿨다운·사거리 재계산 |
| `RequestUseBuff`   | `buffId: string`        | 해당 능동 버프 보유 여부     |




### Server → Client (RemoteEvent, 대부분 Broadcast)


| 이름                 | 인자                                    |
| ------------------ | ------------------------------------- |
| `GameStateChanged` | `stateName, payload`                  |
| `RoundInfoUpdate`  | `{ round, totalRounds, alive }`       |
| `TimerUpdate`      | `{ phase, secondsLeft, dangerLevel }` |
| `BombOwnerChanged` | `ownerUserId, previousOwnerUserId`    |
| `BuffGranted`      | `userId, buffId, buffMeta`            |
| `PlayerEliminated` | `userId, round`                       |
| `RoundResult`      | `{ round, scores }`                   |
| `GameResult`       | `{ ranking }`                         |
| `EffectTrigger`    | `effectId, params`                    |




### RemoteFunction


| 이름            | 용도                      |
| ------------- | ----------------------- |
| `GetSnapshot` | (예약) 접속/재접속 시 현재 상태 동기화 |


**서버 권한 원칙** — 다음은 반드시 서버에서만 결정:
폭탄 소유자 변경 · 폭발 판정 · 라운드 종료 · 승패 · 버프 지급 · 모든 랜덤.
클라이언트는 UI/이펙트/애니메이션/사운드/입력 전송만.

---



## 9. 파일 수정 가이드


| 하고 싶은 것                | 수정할 곳                                                        |
| ---------------------- | ------------------------------------------------------------ |
| 라운드 수·시간·인원 변경         | `Shared/Constants/GameConstants`                             |
| 폭탄 사거리·쿨다운·판정반경        | `Shared/Config/BombConfig`                                   |
| 버프 추가/삭제/확률 조정         | `Shared/Config/BuffConfig` (+ 새 효과면 `BuffManager.applyBuff`) |
| 기본 이동속도/점프력·점수         | `Shared/Config/GameConfig`                                   |
| **UI 디자인(색/크기/폰트/배치)** | **Studio에서** `Assets/BombGameUI` **편집**                      |
| UI 색상 상수               | `Shared/Config/UIConfig`                                     |
| **사운드(SoundId/볼륨)**    | **Studio에서** `Assets/Sounds` **각 Sound 편집**                  |
| 폭탄 모델 외형               | Studio에서 `ServerStorage/BombTemplate` 편집                     |
| 새 게임 상태 추가             | `Constants/StateConstants` + `StateManager` + `GameManager`  |
| 새 Remote 추가            | `Constants/RemoteNames` + 송수신 코드                             |


**버프 추가 예시**

1. `BuffConfig.List`에 항목 추가 (`id`, `name`, `kind`, `weight`, `params`)
2. 스탯 계열이면 `params`의 배수만으로 자동 반영 (walk/jump/range 등)
3. 새로운 효과면 `BuffManager.applyBuff`에 처리 추가

---



## 10. 개발 규칙

- **Luau 타입 사용** (`--!strict`, `export type`)
- **ModuleScript 기반** + 매니저별 책임 분리(SRP)
- **의존성 주입**: 매니저는 부트스트랩에서 `deps` 테이블로 주입받음 (순환 require 회피)
- **Magic Number 금지**: 모든 수치는 `Config`/`Constants`로 분리
- **Remote 이름 하드코딩 금지**: `RemoteNames` 사용
- **UI/사운드는 코드가 아닌 에셋으로**: 레이아웃/스타일/SoundId를 코드에 넣지 않음
- **서버 권한 준수**: 판정은 서버, 클라는 요청·표현만
- **함수 분리 + 주석**: 한 함수는 한 가지 일
- **네이밍**: 매니저=`XxxManager`, 컨트롤러=`XxxController`, 상수=`UPPER_SNAKE`

---



## 11. 향후 개발 예정


| 항목                    | 상태   | 비고                                               |
| --------------------- | ---- | ------------------------------------------------ |
| SoundId 지정            | ⬜    | `Assets/Sounds` 각 Sound에 오디오 ID 입력 필요 (현재 무음)    |
| TimerManager          | ⬜ 스텁 | 현재 RoundManager가 자체 타이밍. 다중 타이머 중앙화 시 확장         |
| 라운드별 랜덤 스폰 배치         | ⬜    | 현재 기본 SpawnLocation 사용                           |
| 동점 서든데스               | ⬜    | `GameConfig.SUDDEN_DEATH_ON_TIE` 플래그만 존재, 로직 미구현 |
| `GetSnapshot` 재접속 동기화 | ⬜    | Remote만 정의됨                                      |
| 유도탄(homing) 버프        | ⬜    | 정리 과정에서 제외됨. 필요 시 재추가                            |
| DataStore 영속 저장       | ⬜    | 현재 점수는 세션 메모리만                                   |
| 관전자 카메라               | ⬜    | 현재 탈락 시 배너만 표시                                   |
| 맵/블록아웃                | ⬜    | 전용 맵 제작 필요                                       |


---



## 12. 최종 요약

- **장르**: 최대 6인 폭탄 돌리기 파티 게임 (5라운드, 점수제)
- **아키텍처**: 서버 권한 + 매니저 모듈 + FSM + 의존성 주입
- **완성된 것**: 게임 루프 / 라운드·폭탄·폭발 / 10종 버프 / 폭탄 3D 부착 / 8종 UI / 연출 / 사운드 골격
- **핵심 분리 원칙**:
  - 판정 = **서버**, 표현 = **클라이언트**
  - 수치 = **Config/Constants**
  - UI/사운드 = **Studio 에셋** (코드 무수정으로 변경 가능)
- **바로 해야 할 것**: `Assets/Sounds`에 SoundId 지정, 2인 플레이 테스트

**빠른 시작 (테스트)**

1. Studio **Test 탭 → Clients and Servers → 2 Players → Start**
2. 2명 이상 접속 → 5초 후 라운드 시작
3. 좌클릭으로 상대 조준해 폭탄 투척, 60초 후부터 랜덤 폭발

---

*문서 최종 갱신: 2026-07-23*