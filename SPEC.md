# SpaceSwitcher 개발 명세서

> macOS 데스크탑(Spaces)에 이름을 붙이고, `Option+E`로 IntelliJ Switcher처럼 데스크탑을 골라 이동하는 메뉴바 유틸리티.
> 이 문서는 Claude Code가 단계별로 구현할 수 있도록 작성되었다. **Phase 순서대로 진행하고, 각 Phase의 완료 조건을 만족한 뒤 다음으로 넘어간다.**

---

## 1. 제품 개요

### 1.1 핵심 기능 (MVP)
| # | 기능 | 설명 |
|---|------|------|
| F1 | 데스크탑 이름 지정 | 각 데스크탑에 사용자 지정 이름을 붙이고 영구 저장 |
| F2 | 스위처 (팝업 모드) | `Option+E`를 짧게 누르고 떼면 목록 팝업이 열린 채 유지. 방향키/숫자키/Enter로 이동, Esc로 닫기 |
| F3 | 스위처 (순환 모드) | `Option`을 누른 채 `E`를 반복하면 선택이 순환하고, `Option`을 떼는 순간 선택된 데스크탑으로 이동 |
| F4 | 메뉴바 표시 | 메뉴바에 현재 데스크탑 이름 표시, 클릭 시 메뉴 |
| F5 | 단축키 변경 | 설정에서 스위처 단축키를 다른 조합으로 변경 |
| F6 | 로그인 시 자동 실행 | 설정에서 on/off |

### 1.2 범위 밖 (MVP 제외)
- 검색/타이핑 필터 (명시적으로 불필요)
- 다중 모니터별 데스크탑 구분 (MVP는 메인 디스플레이 기준)
- 전체화면 앱 Space 전환 (목록에서 제외)
- Mac App Store 배포

### 1.3 기술 결정
| 항목 | 결정 |
|------|------|
| 언어/UI | Swift 5.9+, AppKit(패널·메뉴바) + SwiftUI(설정 화면) |
| 최소 OS | macOS 14 Sonoma |
| 앱 형태 | 메뉴바 전용 에이전트 앱 (`LSUIElement = YES`, Dock 아이콘 없음) |
| 배포 | 직접 배포(DMG / GitHub Releases / Homebrew cask). **App Sandbox 비활성화**, Hardened Runtime + Developer ID 서명 + 공증 |
| 프로젝트 관리 | **XcodeGen**(`project.yml`)으로 Xcode 프로젝트 생성 → 텍스트로 관리 가능해 Claude Code 친화적 |
| 번들 ID | `com.<yourname>.SpaceSwitcher` (구현 시 사용자에게 확인) |
| 외부 의존성 | 없음이 원칙. 필요 시 SPM만 사용 |

---

## 2. 기술 배경 (구현 전 반드시 읽을 것)

macOS에는 Spaces를 다루는 **공개 API가 없다.** 아래 방식을 조합한다.

### 2.1 데스크탑 목록 / 현재 데스크탑 조회 — 비공개 CGS API
`SkyLight`(CoreGraphics) 비공개 함수를 `@_silgen_name`으로 선언해 사용한다.

```swift
typealias CGSConnectionID = Int32
@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID
@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ cid: CGSConnectionID) -> CFArray
@_silgen_name("CGSGetActiveSpace")
func CGSGetActiveSpace(_ cid: CGSConnectionID) -> Int
```

- `CGSCopyManagedDisplaySpaces` 결과: 디스플레이별 딕셔너리 배열. 각 항목에 `"Spaces"`(배열), `"Current Space"`, `"Display Identifier"` 등이 있다.
- 각 Space 딕셔너리의 주요 키: `"ManagedSpaceID"`/`"id64"`(런타임 ID), `"uuid"`(영속 식별자), `"type"`(0 = 일반 데스크탑, 4 = 전체화면 앱).
- **이름 저장 키는 `uuid`를 사용한다.** 재부팅·재배치 후에도 유지되는 것으로 알려져 있음. 단, 첫 번째 데스크탑의 `uuid`가 빈 문자열일 수 있으므로 이 경우 특수 키(`"__main__"`)로 매핑한다. → **Phase 0에서 실제 값 확인 필수.**
- 데스크탑 순서 = `Spaces` 배열 순서 중 `type == 0`만 필터링한 인덱스(1부터). 이것이 "Desktop N"의 N이다.
- 현재 데스크탑 변경 감지: `NSWorkspace.shared.notificationCenter`의 `NSWorkspace.activeSpaceDidChangeNotification`.

### 2.2 데스크탑 전환 — 시스템 단축키 이벤트 합성
비공개 API로 Space를 직접 바꾸는 방법(`CGSManagedDisplaySetCurrentSpace`)은 창/Dock 상태가 어긋나는 문제가 있고, yabai식 스크립팅 애드온은 SIP 해제가 필요하므로 **사용하지 않는다.**

대신 macOS 기본 단축키 **"데스크탑 N으로 전환"**(시스템 설정 → 키보드 → 키보드 단축키 → Mission Control, 기본 `Ctrl+1…`)을 `CGEvent`로 합성해 전송한다.

- 이 단축키들은 **기본값이 꺼져 있는 경우가 많다.** 온보딩에서 켜도록 안내한다.
- 활성화 여부와 실제 키 조합은 `com.apple.symbolichotkeys` 도메인의 `AppleSymbolicHotKeys`에서 읽을 수 있다. "데스크탑 1~16으로 전환"은 ID `118`~`133`으로 알려져 있음(각 항목의 `enabled`, `value.parameters` = [문자코드, 키코드, 수식키 플래그]). → **Phase 0에서 검증.**
- 사용자가 키 조합을 바꿔뒀어도 동작하도록, 하드코딩하지 말고 plist에서 읽은 키코드/수식키로 이벤트를 만든다.
- **대체 경로:** 해당 단축키가 꺼져 있거나 17번째 이후 데스크탑이면 `Ctrl+←/→`를 필요한 횟수만큼 전송한다(애니메이션 때문에 느림; "동작 줄이기" 설정 시 빨라짐).
- 이벤트 합성에는 **손쉬운 사용(Accessibility) 권한**이 필요하다.

### 2.3 전역 단축키 — CGEventTap
- `Option+E`처럼 **Option만 쓰는 조합은 macOS 15부터 Carbon `RegisterEventHotKey`에서 막힌 것으로 알려져 있다.** 또 순환 모드는 Option **키를 뗀 순간**을 감지해야 한다.
- 따라서 전역 단축키는 **`CGEvent.tapCreate`(세션 이벤트 탭, `keyDown` + `flagsChanged`)** 로 구현한다. 권한은 2.2와 같은 손쉬운 사용 권한으로 해결(환경에 따라 "입력 모니터링"이 추가로 요구될 수 있으니 온보딩에서 둘 다 확인).
- 단축키에 매칭된 `keyDown`은 탭에서 `nil`을 반환해 **소비**한다. (US 배열에서 Option+E는 악센트 데드키라 소비하지 않으면 ´ 가 입력됨)
- 탭이 시스템에 의해 비활성화되면(`tapDisabledByTimeout` / `tapDisabledByUserInput`) 즉시 재활성화한다.
- 탭 콜백은 가볍게 유지하고 UI 작업은 메인 스레드로 넘긴다.

---

## 3. 상세 동작 명세

### 3.1 스위처 상태 머신 (F2, F3)

용어: `M` = 단축키의 수식키(기본 Option), `K` = 단축키의 키(기본 E).

```
[Idle]
  └─ M+K 누름 ─────────────► [Holding]  패널 표시, 초기 선택 = 직전 데스크탑(MRU 2번째)
                               pressCount = 1

[Holding]  (M을 누르고 있는 상태)
  ├─ K 누름 ───────────────► 선택 다음 항목으로 (끝이면 처음으로), pressCount += 1
  ├─ Shift+K 누름 ─────────► 선택 이전 항목으로
  ├─ M 뗌 & pressCount >= 2 ► 선택된 데스크탑으로 전환 → [Idle]      ← 순환 모드
  ├─ M 뗌 & pressCount == 1 ► [Sticky]                              ← 팝업 모드
  └─ Esc ──────────────────► 패널 닫기 → [Idle]

[Sticky]  (패널이 열린 채 유지)
  ├─ ↑/↓, K, Shift+K ──────► 선택 이동
  ├─ 1~9 ──────────────────► 해당 번호 데스크탑으로 즉시 전환 → [Idle]
  ├─ Enter / 항목 클릭 ────► 선택된 데스크탑으로 전환 → [Idle]
  ├─ R (또는 더블클릭) ─────► 선택 항목 이름 인라인 편집
  ├─ M+K 다시 누름 ─────────► 선택 다음 항목으로
  └─ Esc / 패널 밖 클릭 ────► 닫기 → [Idle]
```

- 상태 머신은 **UI·시스템 이벤트와 분리된 순수 Swift 타입**으로 작성하고 단위 테스트한다. (입력: 이벤트 enum, 출력: 액션 enum)
- 데스크탑이 1개뿐이면 패널만 표시하고 전환은 no-op.
- 현재 데스크탑도 목록에 표시하되 "현재" 표시를 붙인다.

### 3.2 스위처 패널 UI
- `NSPanel`, 화면 중앙(메인 디스플레이), 그림자 + 반투명 배경(`NSVisualEffectView`).
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]` → 어느 데스크탑에서든 그 자리에 뜨고, 패널 때문에 Space가 바뀌지 않게 한다.
- 항목 행: `번호 · 이름 · (현재)`. 이름이 없으면 `데스크탑 N`을 흐리게 표시.
- 선택 항목 하이라이트. 최대 16개 항목까지 스크롤 없이 표시되도록 행 높이 조정.
- 키 입력은 Holding 상태에서는 이벤트 탭으로, Sticky 상태에서는 패널이 key window가 되어 받는다(또는 계속 이벤트 탭으로 받는다 — 구현 시 더 안정적인 쪽 선택하고 근거를 주석으로 남길 것).
- 패널 표시까지 체감 지연 < 100ms 목표.

### 3.3 MRU(최근 사용 순서)
- `activeSpaceDidChangeNotification`마다 현재 데스크탑 `uuid`를 MRU 목록 맨 앞으로 이동.
- 목록 **표시 순서는 데스크탑 순서(1, 2, 3…)**, **초기 선택만 MRU 기준**(직전 데스크탑). 순환 모드의 "다음 항목"도 표시 순서 기준.
- MRU는 메모리 + 앱 종료 시 저장(선택).

### 3.4 이름 저장 (F1)
- 저장소: `~/Library/Application Support/SpaceSwitcher/names.json`
  ```json
  { "version": 1, "names": { "<uuid>": "업무", "__main__": "메인" } }
  ```
- 사라진 uuid의 이름은 즉시 지우지 않고 보관(데스크탑이 일시적으로 조회 안 되는 경우 대비). 설정 화면에 "사용하지 않는 이름 정리" 버튼 제공.
- 이름 편집 진입점 3곳: 스위처 패널(R/더블클릭), 메뉴바 메뉴 "현재 데스크탑 이름 변경…", 설정 화면 목록.
- 이름 최대 30자, 앞뒤 공백 제거, 빈 문자열이면 이름 삭제.

### 3.5 메뉴바 (F4)
- `NSStatusItem`에 현재 데스크탑 이름 표시(없으면 `데스크탑 N`). 너무 길면 말줄임.
- 메뉴 구성:
  ```
  ✓ 1  업무
    2  개인
    3  데스크탑 3
  ─────────
  현재 데스크탑 이름 변경…
  설정…
  ─────────
  SpaceSwitcher 종료
  ```
- 메뉴 항목 클릭 시 해당 데스크탑으로 전환.
- 데스크탑 추가/삭제/재배치는 알림이 없으므로, 메뉴·패널을 열 때마다 목록을 다시 조회한다.

### 3.6 설정 화면 (F5, F6) — SwiftUI `Settings` 창
- **일반**: 로그인 시 자동 실행 토글 (`SMAppService.mainApp.register()/unregister()`, 상태는 `SMAppService.mainApp.status`로 읽음).
- **단축키**: 직접 만든 단축키 레코더. 수식키 1개 이상 + 일반 키 1개 필수. 저장 형식 `{keyCode, modifiers}`. 변경 즉시 이벤트 탭에 반영. "기본값(Option+E)으로 복원" 버튼.
- **데스크탑**: 현재 데스크탑 목록 + 이름 편집 + 사용하지 않는 이름 정리.
- **권한**: 손쉬운 사용/입력 모니터링 상태 표시 및 시스템 설정 열기 버튼, "데스크탑 N으로 전환" 단축키 활성화 여부 표시.

### 3.7 온보딩 / 권한
최초 실행 또는 권한 누락 시 작은 안내 창:
1. 손쉬운 사용 권한 요청 (`AXIsProcessTrustedWithOptions` 프롬프트) → 부여될 때까지 폴링하며 상태 갱신.
2. "데스크탑 N으로 전환" 단축키가 꺼져 있으면 켜는 방법 안내 + 시스템 설정 열기 버튼. (꺼져 있어도 Ctrl+←/→ 대체 경로로 동작은 하지만 느리다는 점 명시)
3. 권한이 없으면 메뉴바 아이콘에 경고 표시.

---

## 4. 프로젝트 구조

```
SpaceSwitcher/
├── project.yml                  # XcodeGen
├── SPEC.md                      # 이 문서
├── CLAUDE.md                    # Claude Code 작업 규칙 (5장 내용)
├── SpaceSwitcher/
│   ├── App/
│   │   ├── SpaceSwitcherApp.swift     # @main, Settings scene
│   │   └── AppDelegate.swift          # 초기화, 컴포넌트 조립
│   ├── Spaces/
│   │   ├── CGSPrivate.swift           # 비공개 API 선언 (이 파일에만 격리)
│   │   ├── SpaceProvider.swift        # 목록/현재 조회 → [Space]
│   │   ├── SpaceSwitcherService.swift # 전환 (Ctrl+N / Ctrl+화살표 대체)
│   │   └── SymbolicHotKeys.swift      # com.apple.symbolichotkeys 읽기
│   ├── Hotkey/
│   │   ├── EventTap.swift             # CGEventTap 관리, 재활성화
│   │   └── Shortcut.swift             # 단축키 모델, 저장/로드
│   ├── Switcher/
│   │   ├── SwitcherStateMachine.swift # 순수 로직 (테스트 대상)
│   │   ├── SwitcherPanel.swift        # NSPanel
│   │   └── SwitcherView.swift
│   ├── Store/
│   │   ├── NameStore.swift            # names.json
│   │   └── MRUTracker.swift
│   ├── MenuBar/
│   │   └── StatusItemController.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── ShortcutRecorderView.swift
│   ├── Onboarding/
│   │   └── PermissionsView.swift
│   └── Resources/
│       ├── Info.plist                 # LSUIElement = YES
│       └── SpaceSwitcher.entitlements # sandbox 없음
└── SpaceSwitcherTests/
    ├── SwitcherStateMachineTests.swift
    ├── NameStoreTests.swift
    └── MRUTrackerTests.swift
```

`Space` 모델:
```swift
struct Space: Identifiable, Equatable {
    let id: String        // uuid (빈 값이면 "__main__")
    let managedID: Int    // 런타임 ID
    let index: Int        // 1부터, 일반 데스크탑 순서
    let isCurrent: Bool
}
```

---

## 5. Claude Code 작업 규칙 (CLAUDE.md로 복사)

- 빌드: `xcodegen generate && xcodebuild -scheme SpaceSwitcher -configuration Debug build`
- 테스트: `xcodebuild test -scheme SpaceSwitcher -destination 'platform=macOS'`
- 파일을 추가/삭제하면 `project.yml` 기준으로 `xcodegen generate`를 다시 실행한다. `.xcodeproj`는 직접 수정하지 않는다.
- 비공개 API 선언은 `Spaces/CGSPrivate.swift`에만 둔다. 다른 파일에서 `@_silgen_name`을 쓰지 않는다.
- 상태 머신·저장소 같은 순수 로직은 AppKit을 import하지 않고, 테스트를 먼저 작성한다.
- 권한·단축키·Spaces 동작은 CI에서 검증할 수 없다. 해당 부분을 수정하면 **7장 수동 테스트 체크리스트 중 관련 항목**을 작업 결과에 명시해 사용자가 직접 확인하게 한다.
- 알려진 가정(2장의 "확인 필요" 항목)이 틀린 것으로 드러나면, 임의로 우회하지 말고 결과를 보고한 뒤 방향을 묻는다.
- Phase 하나가 끝날 때마다 커밋한다. 커밋 메시지: `phaseN: <요약>`.

---

## 6. 구현 단계

### Phase 0 — 검증 스파이크 (가장 먼저)
2장의 가정을 실제 맥에서 확인하는 작은 CLI/테스트 앱.
- [ ] `CGSCopyManagedDisplaySpaces` 결과를 JSON으로 출력 → `uuid`, `type`, 첫 데스크탑 uuid 값 확인
- [ ] 데스크탑을 재배치/재부팅한 뒤 uuid가 유지되는지 확인
- [ ] `com.apple.symbolichotkeys`에서 ID 118~133 구조 확인
- [ ] 합성한 `Ctrl+2` 이벤트로 데스크탑 2로 전환되는지 확인
- [ ] CGEventTap으로 `Option+E`를 가로채고 소비할 수 있는지, `flagsChanged`로 Option 뗌을 감지하는지 확인

**완료 조건:** 결과를 `docs/phase0-findings.md`에 기록하고 사용자에게 요약 보고. 가정과 다르면 여기서 멈추고 논의.

### Phase 1 — 앱 골격 + 메뉴바
- [ ] XcodeGen 프로젝트, `LSUIElement`, 샌드박스 비활성화
- [ ] `SpaceProvider`, `activeSpaceDidChange` 구독
- [ ] 메뉴바에 `데스크탑 N` 표시 및 목록 메뉴 (전환은 아직 없음)

**완료 조건:** 데스크탑을 바꾸면 메뉴바 표시가 즉시 바뀐다.

### Phase 2 — 전환 + 권한
- [ ] `SymbolicHotKeys`, `SpaceSwitcherService` (Ctrl+N + 화살표 대체 경로)
- [ ] 손쉬운 사용 권한 요청 및 온보딩 창
- [ ] 메뉴바 메뉴 항목 클릭 시 전환

**완료 조건:** 메뉴에서 임의 데스크탑 선택 시 이동. 단축키가 꺼진 상태에서도 대체 경로로 이동.

### Phase 3 — 이름
- [ ] `NameStore` + 테스트
- [ ] 메뉴바 "현재 데스크탑 이름 변경…" (간단한 입력 창)
- [ ] 메뉴바/메뉴 목록에 이름 반영

**완료 조건:** 이름을 붙이고 앱을 재시작·재부팅해도 유지된다.

### Phase 4 — 스위처
- [ ] `SwitcherStateMachine` + 테스트 (3.1의 모든 전이)
- [ ] `EventTap` (기본 단축키 Option+E 하드코딩으로 시작)
- [ ] `MRUTracker` + 테스트
- [ ] `SwitcherPanel` UI, 팝업 모드·순환 모드, 숫자키, 인라인 이름 편집

**완료 조건:** 7장 스위처 항목 전부 통과.

### Phase 5 — 설정
- [ ] 설정 창(일반/단축키/데스크탑/권한 탭)
- [ ] 단축키 레코더 + 즉시 반영
- [ ] 로그인 시 자동 실행

**완료 조건:** 단축키를 `Ctrl+Option+Space` 등으로 바꿔도 스위처가 동일하게 동작. 로그인 후 자동 실행 확인.

### Phase 6 — 배포 준비
- [ ] Hardened Runtime, Developer ID 서명, `notarytool` 공증 스크립트 (`scripts/release.sh`)
- [ ] DMG 생성
- [ ] README (설치, 권한 설정, 단축키 활성화 방법)

---

## 7. 수동 테스트 체크리스트

**Spaces / 메뉴바**
- [ ] 데스크탑 전환 시 메뉴바 이름이 1초 이내 갱신
- [ ] 데스크탑 추가/삭제/순서 변경 후 메뉴 목록이 올바름
- [ ] 전체화면 앱 Space는 목록에 없음

**스위처**
- [ ] Option+E 짧게 → 패널 유지(Sticky), 직전 데스크탑이 선택되어 있음
- [ ] Sticky에서 ↑/↓, E, Shift+E로 선택 이동 / Enter로 전환 / Esc로 닫기
- [ ] Sticky에서 숫자키 3 → 데스크탑 3으로 즉시 전환
- [ ] Option 누른 채 E 두 번 이상 → Option 떼면 선택 데스크탑으로 전환
- [ ] Option 누른 채 Shift+E → 역방향
- [ ] 텍스트 입력 중(Option+E)에 ´ 문자가 입력되지 않음
- [ ] 전체화면 앱 위에서도 패널이 뜨고, 패널 때문에 Space가 바뀌지 않음
- [ ] 패널에서 R로 이름 변경 → 메뉴바에 즉시 반영

**설정 / 권한**
- [ ] 권한 없는 상태로 첫 실행 → 온보딩 표시, 권한 부여 후 재시작 없이 동작
- [ ] 단축키 변경 즉시 반영, 기본값 복원 동작
- [ ] 로그인 시 자동 실행 on/off
- [ ] 슬립/깨우기 후에도 단축키 동작 (이벤트 탭 재활성화)

---

## 8. 열린 질문 (구현 중 사용자에게 확인)
1. 번들 ID / 개발자 이름
2. 초기 선택을 "직전 데스크탑"이 아닌 "다음 데스크탑"으로 할지
3. 다중 모니터 지원 시점과 방식(모니터별 섹션 vs 마우스가 있는 모니터만)
4. 전체화면 앱 Space를 (앱 이름으로) 목록에 넣을지
5. 앱 아이콘 / 메뉴바 아이콘 디자인
