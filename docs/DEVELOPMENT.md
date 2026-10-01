# 개발 환경 · 작업 루프

새 맥(또는 새 세션)에서 이 프로젝트를 이어서 개발할 때 필요한 모든 것.

## 1. 새 맥 준비 (약 1시간, 대부분 Xcode 다운로드)

| 단계 | 명령 / 방법 | 확인 |
|------|-------------|------|
| Xcode | App Store에서 설치 후 `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer && sudo xcodebuild -license accept` (sudo는 Claude의 `!`에서 불가 → 터미널 앱에서) | `xcodebuild -version` |
| XcodeGen | `brew install xcodegen` | `xcodegen --version` |
| GitHub CLI | `brew install gh && gh auth login` | `gh api user --jq .login` → `unh6unh6` |
| 서명 인증서 | 아래 §2 | `security find-identity -v -p codesigning`에 `SpaceSwitcher Signing` |
| 데스크탑 단축키 | 시스템 설정 → 키보드 → 키보드 단축키 → Mission Control → "데스크탑 N으로 전환" 모두 켜기 (데스크탑 2개 이상일 때 보임) | `defaults export com.apple.symbolichotkeys -`에 118, 119… `enabled = 1` |
| 터미널 권한 | 스파이크·`scripts/smoke.swift`를 돌리는 터미널 앱(예: Warp)에 **손쉬운 사용** 허용 → 앱 재시작 | 권한 없으면 합성 키가 에러 없이 무시됨 |

## 2. 서명 인증서 `SpaceSwitcher Signing`

모든 빌드(Debug·Release·DMG)를 이 인증서 하나로 서명한다 (`project.yml`의 `CODE_SIGN_IDENTITY`). 이유는 [DECISIONS.md](DECISIONS.md).

- **이미 있는 인증서를 새 맥으로:** 사용자가 비밀번호 관리자 등에 보관한 `.p12` 백업을 더블클릭해 로그인 키체인에 가져오기 → 인증서 더블클릭 → 신뢰 → 코드 서명: **항상 신뢰**.
  `.p12`와 그 암호는 **절대 저장소에 넣지 않는다** (`.gitignore`가 `*.p12`, `*.cer` 차단).
- **처음 만들 때:** 키체인 접근(`open "/System/Library/CoreServices/Applications/Keychain Access.app"`) → 인증서 지원 → 인증서 생성 → 이름 `SpaceSwitcher Signing`, 자체 서명 루트, 코드 서명 → 신뢰에서 코드 서명 "항상 신뢰" → `.p12`로 내보내 백업.
- **백업을 잃고 새로 만들면:** 앱은 계속 빌드되지만 서명 주체가 바뀌어 **모든 사용자(지인 포함)가 손쉬운 사용 권한을 한 번 다시 줘야 한다.** 릴리스 노트에 명시할 것.
- 신뢰 설정 전에는 `find-identity -v`에 안 보임(`CSSMERR_TP_NOT_TRUSTED`) → Xcode가 인증서를 못 찾음.

## 3. 작업 루프

```sh
xcodegen generate                                   # 파일 추가/삭제 후 필수 (.xcodeproj는 git에 없음)
xcodebuild test -scheme SpaceSwitcher -destination 'platform=macOS' -derivedDataPath build/DerivedData 2>&1 \
  | grep -E "error:|failed|TEST (SUCCEEDED|FAILED)|Executed [0-9]+ tests" | grep -v Connection | sort -u | tail
xcodebuild -scheme SpaceSwitcher -configuration Debug -derivedDataPath build/DerivedData build
pkill -x SpaceSwitcher; open build/DerivedData/Build/Products/Debug/SpaceSwitcher.app
swift scripts/smoke.swift                           # 패널 열림/Sticky/Esc 자동 점검 (<100ms 목표)
./scripts/install.sh                                # Release 빌드 → /Applications 교체 → 실행
```

- 테스트 한 개: `-only-testing:SpaceSwitcherTests/<클래스>/<메서드>`
- 유닛 테스트는 앱을 호스트로 실행한다. 테스트 중에는 `AppDelegate`가 이벤트 탭·온보딩을 건너뜀(`isRunningTests`).
- 수동 확인이 필요한 변경(권한·단축키·Spaces)은 [MANUAL_TESTS.md](MANUAL_TESTS.md)에서 해당 항목을 골라 사용자에게 제시.

## 4. 알려진 잡음 · 함정

| 증상 | 의미 |
|------|------|
| 에디터 진단 `No such module 'XCTest'`, `Cannot find type 'Space' in scope` 등 | SourceKit 인덱싱 문제. **xcodebuild 결과가 기준.** 무시 |
| 테스트 로그의 `com.apple.linkd.autoShortcut ... 4097` | 시스템 로그 잡음. 무시 |
| `xcodebuild: WARNING: Using the first of multiple matching destinations` | 무해. release.sh는 `arch=$(uname -m)` 지정 |
| 합성 키가 아무 효과 없음 | 보내는 프로세스(터미널 앱 또는 SpaceSwitcher)에 손쉬운 사용 권한 없음. 에러는 안 남 |
| 스위처로 이동 직후 Option+E에서 "삑" | 합성 Ctrl이 시스템 수식키 상태에 남는 문제. `ModifierRelease`로 해결됨 — 키 합성 코드를 바꿀 때 key-up 전송 유지 ([phase0-findings.md](phase0-findings.md) 후속 발견) |
| Debug 빌드와 `/Applications` 설치본이 공존 | 번들 ID가 같음. "로그인 시 자동 실행"은 마지막으로 켠 쪽 경로를 가리킴 → 설치본에서 껐다 켜기 |
| **`com.apple.symbolichotkeys`를 `defaults import`/`write`로 건드리지 말 것** | 2026-09-30 #8 측정 때 임시로 바꿨다 되돌린 뒤 "데스크탑 N으로 전환"(Ctrl+숫자)이 시스템 전체에서 먹통이 됨 (파일 내용은 원래대로, 앱 종료·설정 토글·`activateSettings -u`로도 복구 안 됨). 대체 경로를 시험하려면 앱 쪽 테스트 훅을 만들거나 사용자에게 시스템 설정에서 직접 끄게 할 것 |
| `brew style`이 Sorbet/frozen string 경고 | cask 파일이 `Casks/` 폴더 밖에 있을 때만. release.sh는 `build/release/Casks/`에 생성 |

## 5. 데이터 위치 (디버깅용)

| 무엇 | 어디 |
|------|------|
| 데스크탑 이름 | `~/Library/Application Support/SpaceSwitcher/names.json` (`{version:1, names:{uuid: 이름}}`, 깨지면 `.corrupt`로 보관) |
| 설정 | `defaults read io.github.unh6unh6.SpaceSwitcher` — `switcherShortcut`(JSON Data), `initialSelection`(`current`/`previous`), `didShowOnboarding` |
| 시스템 단축키 | `defaults export com.apple.symbolichotkeys -` (118+N-1 = 데스크탑 N, 79/81 = Ctrl+←/→) |
| Space 원본 데이터 | `swift spike/spaces.swift` |

## 6. spike/ 스크립트

Phase 0에서 macOS 동작을 검증한 CLI. 새 macOS에서 가정이 깨졌는지 확인할 때 재사용.
`spaces.swift`(Space 목록 JSON) · `switch.swift <N|left|right>`(단축키 합성 전환) · `eventtap.swift [초]`(Option+E 가로채기 로그) · `arrows.swift`(화살표 연타 누락 측정).
