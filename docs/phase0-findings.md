# Phase 0 검증 결과

- 환경: macOS 27.0.1 (Apple Silicon), Xcode 27.0, 메인 디스플레이 1개, 데스크탑 2개
- 스크립트: `spike/spaces.swift`, `spike/switch.swift`, `spike/eventtap.swift` (`swift spike/<파일>`로 실행)
- 날짜: 2026-09-30

## 요약

| # | SPEC §2 가정 | 결과 |
|---|--------------|------|
| 1 | `CGSCopyManagedDisplaySpaces`로 Space 목록, `uuid`, `type` 조회 | ✅ 일치 |
| 2 | 첫 데스크탑 `uuid`가 빈 문자열일 수 있음 | ⚠️ 이 맥에서는 **비어 있지 않음**. `__main__` 매핑은 방어 코드로 유지 |
| 3 | 재배치·재부팅 후 `uuid` 유지 | ✅ 유지됨. 반면 `ManagedSpaceID`는 **바뀜** |
| 4 | `com.apple.symbolichotkeys` ID 118~133 = "데스크탑 N으로 전환" | ✅ 일치 (단, 존재하는 데스크탑 수만큼만 항목이 있음) |
| 5 | 합성 이벤트로 전환 | ✅ Ctrl+2, Ctrl+← 모두 동작 |
| 6 | CGEventTap으로 Option+E 소비, `flagsChanged`로 Option 뗌 감지 | ✅ 일치 |

## 1. Space 목록 (`spike/spaces.swift`)

```json
{
  "activeSpace": 3,
  "displays": [{
    "Current Space": { "id64": 3, "ManagedSpaceID": 3, "type": 0, "uuid": "276CC097-…" },
    "Display Identifier": "C811FC88-…",
    "Spaces": [
      { "id64": 3, "ManagedSpaceID": 3, "type": 0, "uuid": "276CC097-9F18-4FDA-BDCB-EDC5B1744BD0" },
      { "id64": 4, "ManagedSpaceID": 4, "type": 0, "uuid": "F19E4877-50CC-4C08-AEB0-0EDD56A35D93" }
    ]
  }]
}
```

- 키 구성은 SPEC 그대로: `ManagedSpaceID`/`id64`, `uuid`, `type`.
- `CGSGetActiveSpace` 값은 `ManagedSpaceID`와 같은 체계 (3, 4).
- 재부팅 비교용 스냅샷: `spike/spaces-before.json`.

## 3. 재배치 + 재부팅 후

데스크탑 2를 1 앞으로 드래그한 뒤 재부팅 (`spike/spaces-after.json`):

| | 1번 자리 | 2번 자리 |
|---|---|---|
| 전 | ID 3, `276CC097…` | ID 4, `F19E4877…` |
| 후 | ID 4, `F19E4877…` | ID 5, `276CC097…` |

- `uuid`는 데스크탑을 따라 이동하며 유지됨 → **이름 저장 키로 적합** ✅
- `ManagedSpaceID`는 재부팅 후 재할당됨 (`276CC097`: 3 → 5) → 런타임 전용. 저장하면 안 됨.
- 배열 순서가 새 배치를 반영 → "Desktop N" 산출 방식 그대로 유효.

## 결론

SPEC §2의 가정은 모두 성립. 설계 변경 없이 Phase 1 진행 가능. 구현 시 반영할 점:

1. symbolichotkeys에 항목이 없으면 꺼짐으로 간주 → Ctrl+←/→ 대체 경로 (79/81도 plist에서 읽기)
2. 전환·탭 모두 `AXIsProcessTrusted()` 사전 확인 (권한 없으면 조용히 실패하므로)
3. 이벤트 탭: autorepeat 구분, "Option 뗌"은 `maskAlternate` true→false 전이로 판정
4. `ManagedSpaceID`는 절대 저장하지 않음. 저장 키는 `uuid` (빈 값이면 `__main__`)

## 4. symbolichotkeys

```
118 {"enabled": true, "value": {"parameters": [65535, 18, 262144]}}   # Ctrl+1
119 {"enabled": true, "value": {"parameters": [65535, 19, 262144]}}   # Ctrl+2
120~133 (absent)
79  {"enabled": true, "value": {"parameters": [65535, 123, 8650752]}} # Ctrl+←
81  {"enabled": true, "value": {"parameters": [65535, 124, 8650752]}} # Ctrl+→
```

- `parameters` = [문자코드(65535=없음), 가상 키코드, 수식키 플래그]. 262144 = `0x40000` = `CGEventFlags.maskControl`.
- 화살표(79/81)는 플래그에 `0x800000`(`maskSecondaryFn`, 화살표 키 고유 플래그)이 더해진 `0x840000`.
- **구현 시사점:** 항목이 없으면(absent) "꺼짐"으로 보고 Ctrl+←/→ 대체 경로를 쓴다. 대체 경로도 79/81을 plist에서 읽는다.

## 5. 전환 (`spike/switch.swift`)

- 손쉬운 사용 권한 없이: 이벤트가 무시됨 (에러 없음, 전환 안 됨). → 앱은 `AXIsProcessTrusted()`로 사전 확인 필요.
- 권한 부여 후 Ctrl+2: `active before: 3 → after: 4` ✅
- Ctrl+← (ID 79, `swift spike/switch.swift left`): 왼쪽 데스크탑으로 이동 ✅
- 권한은 이벤트를 **보내는 프로세스의 책임 앱**(이번엔 Warp)에 부여해야 함.

## 6. 이벤트 탭 (`spike/eventtap.swift`)

TextEdit에서 Option+E 연타, Option+Shift+E 연타 후 Option 뗌:

```
890.372 flagsChanged option=true          # Option 누름
890.455 Option+E  -> CONSUMED             # ×4
891.877 flagsChanged option=true          # Shift 추가 (Option 유지)
892.027 Option+Shift+E  -> CONSUMED       # ×10
895.467 flagsChanged option=true          # Shift 뗌
895.488 flagsChanged option=false         # Option 뗌 → 순환 모드 확정 시점
```

- `.cgSessionEventTap` + `.defaultTap`으로 생성 성공. 손쉬운 사용 권한만으로 충분 (입력 모니터링 추가 요구 없음).
- `nil` 반환으로 소비 → TextEdit에 `´` 입력 안 됨 ✅
- 키를 누르고 있으면 autorepeat `keyDown`이 계속 들어옴 (Option+Shift+E ×10). **상태 머신 입력에서 autorepeat을 구분해야 함** → `.keyboardEventAutorepeat` 필드로 판별. 무시할지 순환에 포함할지는 Phase 4에서 결정.
- `flagsChanged`는 Shift, Cmd+Tab 등 다른 수식키 변화에도 옴 → "Option 뗌"은 `maskAlternate`가 true→false로 바뀐 순간으로 판정.
- 20초 동안 `tapDisabledBy*`는 발생하지 않음. 슬립/깨우기 후 재활성화는 Phase 4 수동 테스트에서 확인.

## 후속 발견 (Phase 4, 2026-09-30): 합성한 수식키가 눌린 채로 남음

- 증상: 스위처로 이동한 직후 Option+E를 누르면 가끔 "삑" 소리만 나고 패널이 안 뜸.
- 원인: flags에 Control을 넣은 keyDown을 `.cghidEventTap`에 보내면 시스템 수식키 상태에 Control이 **계속 남음**
  (3초 뒤에도 `0x040000`). event source(`hidSystemState`/`privateState`/nil)와 무관.
  → 다음 실제 Option+E가 Ctrl+Option+E로 도착 → 단축키 불일치로 통과 → 앱이 삑.
- 해결: 키를 보낸 뒤 해당 수식키의 key-up `flagsChanged` 이벤트(Control=59, Fn=63)를 추가로 전송
  (`Spaces/ModifierRelease.swift`). 앱 경유 전환 4회(Ctrl+N 3회, 화살표 1회) 모두 이후 상태 `0x000000` 확인.

## 후속 발견 (v0.2.0 스파이크, 2026-09-30): Mission Control은 AX로 조작 불가

- 목적: #1(데스크탑 추가), #9(제거)를 Mission Control의 "+" 버튼 / 제거 액션을 AX로 눌러 구현
- 결과: macOS 27.0.1에서 Dock AX 트리의 `AXGroup id=mc`("Mission Control")는 Mission Control이 열려 있어도
  **자식 요소 0개**. Ctrl+↑로 열기, `Mission Control.app` 실행, 화면 위쪽 호버로 데스크탑 줄 펼치기 모두 동일.
  Dock의 `AXWindows`도 0개. → 예전 macOS의 AppleScript 방식("Spaces Bar" 그룹의 버튼) 사용 불가.
- 스크립트: `spike/missioncontrol.swift`
