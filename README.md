# SpaceSwitcher

macOS 데스크탑(Spaces)에 이름을 붙이고, **Option+E** 한 번으로 골라서 이동하는 메뉴바 앱.

- 메뉴바에 지금 있는 데스크탑 이름 표시 (예: `업무`)
- **Option+E 짧게** → 데스크탑 목록 창. ↑↓ / 숫자 / Enter로 이동
- **Option 누른 채 E 반복** → 선택이 한 칸씩 넘어가고, Option을 떼면 그 데스크탑으로 이동
- 이름은 데스크탑을 따라다님 (순서를 바꾸거나 재부팅해도 유지)

macOS 14 Sonoma 이상 · Apple Silicon / Intel 모두 지원

---

## 설치 (약 5분)

### 1. 다운로드

[**Releases**](https://github.com/unh6unh6/SpaceSwitcher/releases/latest)에서 `SpaceSwitcher-x.y.z.dmg`를 받아 엽니다.
창에 나오는 **SpaceSwitcher**를 옆의 **Applications** 폴더로 드래그합니다.

### 2. 처음 실행 허용

이 앱은 Apple 유료 개발자 계정 없이 배포해서, 처음 열 때 macOS가 막습니다. **한 번만** 허용하면 됩니다.

1. Applications 폴더에서 SpaceSwitcher를 엽니다 → "열 수 없음" 경고가 뜨면 **완료**를 누릅니다
2. **시스템 설정 → 개인정보 보호 및 보안**으로 갑니다
3. 아래쪽 "SpaceSwitcher이(가) 차단되었습니다" 옆의 **그래도 열기**를 누르고, 암호를 입력합니다

> 터미널이 익숙하다면 대신 이 한 줄로도 됩니다:
> `xattr -dr com.apple.quarantine /Applications/SpaceSwitcher.app`

### 3. 손쉬운 사용 권한 켜기

앱이 뜨면 안내 창이 나옵니다. **권한 요청** → 시스템 설정에서 **SpaceSwitcher** 스위치를 켭니다.
몇 초 안에 안내 창의 1번이 ✅로 바뀌면 끝입니다. (키 입력을 받고 데스크탑 전환 키를 보내는 데 필요합니다)

### 4. "데스크탑 N으로 전환" 단축키 켜기 (권장)

**시스템 설정 → 키보드 → 키보드 단축키… → Mission Control**에서 "데스크탑 1로 전환", "데스크탑 2로 전환" … 을 모두 체크합니다.

- 데스크탑이 여러 개 있어야 이 항목들이 보입니다 (`Ctrl+↑` → 화면 위 **+** 로 추가)
- 꺼져 있어도 동작하지만, 옆 데스크탑으로 한 칸씩 넘어가서 느립니다

### 5. 로그인 시 자동 실행 (선택)

메뉴바 → **설정…** → 일반 → **로그인 시 자동 실행** 켜기

---

## 사용법

| 동작 | 방법 |
|------|------|
| 목록 열기 | **Option+E** 짧게 |
| 선택 이동 | ↑ ↓ 또는 E / Shift+E |
| 이동 | **Enter** 또는 항목 클릭 |
| 번호로 바로 이동 | **1–9** |
| 빠르게 순환 | Option을 누른 채 E 반복 → Option 떼기 (Shift+E는 거꾸로) |
| 이름 바꾸기 | 목록에서 **R** 또는 더블클릭 · 메뉴바 → "현재 데스크탑 이름 변경…" |
| 닫기 | **Esc** 또는 창 밖 클릭 |

**설정** (메뉴바 → 설정… 또는 ⌘,): 단축키 변경 · 처음 선택(현재/직전 데스크탑) · 데스크탑 이름 일괄 편집 · 권한 상태.

전체화면 앱 화면은 목록에 나오지 않습니다 (위에서 목록을 띄우는 건 가능).

---

## 업데이트

새 버전 DMG를 받아 Applications 폴더에 **덮어쓰기** 하면 됩니다. 권한과 이름은 그대로 유지됩니다.
(덮어쓰기 전에 메뉴바 → SpaceSwitcher 종료)

## 삭제

1. 메뉴바 → **SpaceSwitcher 종료**
2. Applications 폴더에서 SpaceSwitcher를 휴지통으로
3. (선택) 저장된 이름 지우기: Finder → 이동 → 폴더로 이동 → `~/Library/Application Support/SpaceSwitcher` 삭제
4. (선택) 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용 목록에서 SpaceSwitcher 제거

## 문제 해결

- **Option+E를 눌러도 반응이 없음** → 메뉴바 이름 앞에 경고 표시가 있으면 손쉬운 사용 권한이 꺼진 것. 설정… → 권한 탭 확인
- **이동이 느림 / 한 칸씩 넘어감** → 위 4번 단축키가 꺼져 있음
- **업데이트 후 권한이 풀림** → 손쉬운 사용 목록에서 SpaceSwitcher를 −로 지우고 다시 추가

---

## 개발

Swift / AppKit + SwiftUI, 외부 의존성 없음. 설계는 [`SPEC.md`](SPEC.md), 진행 상황은 [`TODO.md`](TODO.md).

```sh
brew install xcodegen
xcodegen generate
xcodebuild test -scheme SpaceSwitcher -destination 'platform=macOS'
./scripts/install.sh            # Release 빌드 → /Applications 설치
./scripts/release.sh 0.2.0      # 버전 올리고 DMG 만들어 GitHub Release 게시
```

빌드는 키체인의 자체 서명 인증서 **SpaceSwitcher Signing**(코드 서명용)으로 서명합니다.
직접 빌드하려면 같은 이름의 인증서를 만들거나 `project.yml`의 `CODE_SIGN_IDENTITY`를 바꾸세요.
Spaces 조회에 macOS 비공개 API(`CGSCopyManagedDisplaySpaces`)를 사용하므로 App Store 배포는 불가합니다.
