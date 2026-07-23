# Roblox_Project

Rojo 기반 Roblox 프로젝트입니다. 코드는 `.luau` 파일로 관리하고 Roblox Studio와 실시간 동기화합니다.

## 툴체인

이 프로젝트의 도구는 [Rokit](https://github.com/rojo-rbx/rokit)으로 관리됩니다 (`rokit.toml`).

- **rojo** — 파일 ↔ Studio 동기화
- **stylua** — Luau 코드 포매터

새 PC에서 클론했다면 프로젝트 폴더에서 `rokit install`을 실행하면 동일한 버전의 도구가 설치됩니다.

## 폴더 구조

```
src/
  server/   → ServerScriptService.Server   (서버 전용 스크립트)
  client/   → StarterPlayerScripts.Client   (클라이언트 전용 스크립트)
  shared/   → ReplicatedStorage.Shared      (공유 모듈)
default.project.json   → DataModel ↔ 파일 매핑 정의
```

파일 이름 규칙:
- `*.server.luau` → `Script` (서버)
- `*.client.luau` → `LocalScript` (클라이언트)
- `*.luau` → `ModuleScript`
- `init.*.luau` → 상위 폴더 자체가 해당 스크립트가 됨

## 개발 시작하기

1. **Studio 플러그인 설치** (최초 1회):
   ```
   rojo plugin install
   ```
   그러면 Studio에 Rojo 플러그인이 설치됩니다.

2. **동기화 서버 실행**:
   ```
   rojo serve
   ```

3. Roblox Studio에서 새 베이스플레이트를 열고, Rojo 플러그인 → **Connect** 클릭.

4. 이제 `src/` 안의 파일을 수정하면 Studio에 실시간 반영됩니다.

## 유용한 명령어

| 명령 | 설명 |
|------|------|
| `rojo serve` | 실시간 동기화 서버 시작 |
| `rojo build -o game.rbxl` | 프로젝트를 `.rbxl` 파일로 빌드 |
| `stylua src` | `src` 폴더 코드 포맷 |
