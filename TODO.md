# SpaceSwitcher TODO

> 표시: 👤 = 사용자가 직접 해야 함 (GUI 조작, 비밀번호, 권한 부여) · 🤖 = Claude가 함 · ⏱ = 예상 시간
> 한 Phase가 끝나면 커밋: `phaseN: <요약>`. 상세 동작은 `SPEC.md` 참고.

## 확정된 결정 (2026-09-29)

| 항목 | 결정 | SPEC과 차이 |
|------|------|-------------|
| 배포 범위 | 나 + 지인. GitHub Releases에 DMG 업로드 | SPEC은 Developer ID+공증 → **유료 계정 없이 진행, 공증 생략** |
| 서명 | 자체 서명 인증서 `SpaceSwitcher Signing` 하나로 개발·배포 모두 서명 | 빌드해도 손쉬운 사용 권한 유지 |
| 번들 ID | `io.github.unh6unh6.SpaceSwitcher` | — |
| 저장소 | GitHub 공개 저장소 `unh6unh6/SpaceSwitcher` | — |
| 업데이트 | 수동 재설치 (새 DMG로 덮어쓰기). 외부 의존성 0 | Homebrew cask 제외 |
| 초기 선택 | 직전 데스크탑 (MRU) | SPEC 기본값 그대로 |
| 대상 Mac | macOS 14+, Universal(Apple Silicon + Intel) | — |

---

## Phase S — 개발 환경 준비 ⏱ 약 1시간 (대부분 Xcode 다운로드 대기)

현재 상태: Xcode 없음, xcodegen 없음, 서명 인증서 0개, GitHub 원격 없음.

- [x] 👤 App Store에서 **Xcode** 설치 (약 10GB, 30~60분)
- [x] 👤 터미널: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- [x] 👤 터미널: `sudo xcodebuild -license accept` → Xcode 한 번 실행해 추가 구성요소 설치
- [x] 🤖 `brew install xcodegen`
- [x] 👤 자체 서명 인증서 만들기 (약 5분, Claude가 단계 안내)
  - 키체인 접근 → 메뉴 "인증서 지원" → "인증서 생성…"
  - 이름 `SpaceSwitcher Signing`, 신원 유형 "자체 서명 루트", 인증서 유형 "코드 서명"
- [ ] 🤖 `security find-identity -v -p codesigning`으로 인증서 인식 확인
- [ ] 👤 인증서를 `.p12`로 내보내 안전한 곳(비밀번호 관리자 등)에 백업
  - 잃어버리면 지인들이 업데이트할 때마다 권한을 다시 줘야 함
- [x] 👤 시스템 설정 → 키보드 → 키보드 단축키 → Mission Control → **"데스크탑 N으로 전환" 켜기** (데스크탑을 2개 이상 만들어 둔 상태에서)
- [x] 🤖 `.gitignore` 작성 (`*.xcodeproj`, `build/`, `DerivedData/`, `*.p12`, `.DS_Store`)
- [x] 🤖 첫 커밋: `SPEC.md`, `CLAUDE.md`, `TODO.md`, `.gitignore`
- [ ] 🤖 `gh repo create unh6unh6/SpaceSwitcher --public --source . --push` (실행 전 사용자 확인)

**완료 조건:** `xcodebuild -version`이 출력되고, 인증서가 1개 보이고, GitHub에 저장소가 생김.

---

## Phase 0 — 검증 스파이크 ⏱ 약 1~2시간 (수동 확인 포함)

SPEC §2의 가정이 실제 맥(macOS 27)에서 맞는지 확인. **틀린 게 나오면 여기서 멈추고 논의.**

- [ ] 🤖 `spike/` 폴더에 Swift CLI 스크립트 작성 (앱 본체와 분리, 나중에 삭제 가능)
- [ ] 🤖 `CGSCopyManagedDisplaySpaces` 결과를 JSON 출력 → `uuid`, `type`, 첫 데스크탑 uuid 값 확인
- [ ] 👤 데스크탑 순서를 바꾸고 재부팅 → 🤖 uuid가 유지되는지 다시 출력해 비교
- [ ] 🤖 `defaults export com.apple.symbolichotkeys -`로 ID 118~133 구조 확인
- [ ] 👤 터미널에 손쉬운 사용 권한 부여 → 🤖 합성한 `Ctrl+2` 이벤트로 데스크탑 2 전환 확인
- [ ] 🤖 CGEventTap으로 `Option+E` 소비 + `flagsChanged`로 Option 뗌 감지 확인
- [ ] 🤖 결과를 `docs/phase0-findings.md`에 기록하고 요약 보고

**완료 조건:** findings 문서 작성, 가정이 모두 맞거나 대안에 합의.

---

## Phase 1 — 앱 골격 + 메뉴바 ⏱ 약 2시간

- [ ] 🤖 `project.yml` 작성: 번들 ID, macOS 14, `LSUIElement`, 샌드박스 끔, 서명 `SpaceSwitcher Signing` (Manual)
- [ ] 🤖 `xcodegen generate` → 빈 앱 빌드 성공
- [ ] 🤖 `CGSPrivate.swift`, `Space` 모델, `SpaceProvider`
- [ ] 🤖 `activeSpaceDidChangeNotification` 구독
- [ ] 🤖 메뉴바에 `데스크탑 N` 표시 + 목록 메뉴 (전환은 아직 없음) + 종료 메뉴
- [ ] 👤 앱 실행 → 데스크탑 바꿔서 메뉴바 표시가 바뀌는지 확인 (SPEC §7 Spaces/메뉴바 항목)

**완료 조건:** 데스크탑을 바꾸면 메뉴바 표시가 즉시 바뀐다.

---

## Phase 2 — 전환 + 권한 ⏱ 약 3시간

- [ ] 🤖 `SymbolicHotKeys` (plist에서 키코드/수식키 읽기)
- [ ] 🤖 `SpaceSwitcherService`: Ctrl+N 경로
- [ ] 🤖 `SpaceSwitcherService`: Ctrl+←/→ 대체 경로 (단축키 꺼짐 / 17번 이후)
- [ ] 🤖 온보딩 창: 손쉬운 사용 권한 요청 + 폴링, 단축키 꺼짐 안내
- [ ] 🤖 권한 없을 때 메뉴바 아이콘 경고
- [ ] 🤖 메뉴 항목 클릭 → 전환
- [ ] 👤 수동 확인: 메뉴로 전환 / 단축키를 끈 상태로 전환 / 권한 없이 첫 실행 → 온보딩

**완료 조건:** 메뉴에서 아무 데스크탑이나 골라 이동. 단축키가 꺼져 있어도 대체 경로로 이동.

---

## Phase 3 — 이름 ⏱ 약 2시간

- [ ] 🤖 `NameStoreTests` 먼저 작성 (30자 제한, 공백 제거, 빈 문자열=삭제, `__main__`, 사라진 uuid 보관)
- [ ] 🤖 `NameStore` 구현 → 테스트 통과 (`names.json`)
- [ ] 🤖 메뉴 "현재 데스크탑 이름 변경…" 입력 창
- [ ] 🤖 메뉴바/메뉴 목록에 이름 반영
- [ ] 👤 수동 확인: 이름 붙이고 앱 재시작 → 유지 / 재부팅 → 유지

**완료 조건:** 이름이 재시작·재부팅 후에도 유지된다.

---

## Phase 4 — 스위처 ⏱ 약 반나절~하루 (가장 큼)

- [ ] 🤖 `SwitcherStateMachineTests` 먼저 작성 (SPEC §3.1 모든 전이)
- [ ] 🤖 `SwitcherStateMachine` 구현 → 테스트 통과
- [ ] 🤖 `MRUTrackerTests` → `MRUTracker` 구현
- [ ] 🤖 `EventTap` (Option+E 하드코딩, 재활성화 처리)
- [ ] 🤖 `SwitcherPanel` + `SwitcherView` (중앙, 반투명, 모든 Space에 표시)
- [ ] 🤖 팝업 모드 · 순환 모드 연결
- [ ] 🤖 숫자키 즉시 전환, R/더블클릭 인라인 이름 편집
- [ ] 👤 SPEC §7 "스위처" 항목 8개 전부 수동 확인

**완료 조건:** SPEC §7 스위처 항목 전부 통과.

---

## Phase 5 — 설정 ⏱ 약 3~4시간

- [ ] 🤖 설정 창 골격 (일반 / 단축키 / 데스크탑 / 권한 탭)
- [ ] 🤖 단축키 레코더 + 저장 + 이벤트 탭 즉시 반영 + 기본값 복원
- [ ] 🤖 로그인 시 자동 실행 (`SMAppService`)
- [ ] 🤖 데스크탑 탭: 이름 편집 + 사용하지 않는 이름 정리
- [ ] 🤖 권한 탭: 상태 표시 + 시스템 설정 열기 버튼
- [ ] 👤 수동 확인: 단축키를 `Ctrl+Option+Space`로 변경 후 동작 / 자동 실행 on→로그아웃→로그인

**완료 조건:** 단축키를 바꿔도 스위처가 똑같이 동작. 로그인 후 자동 실행됨.

---

## Phase 6 — 내 맥에 설치 ⏱ 약 30분

- [ ] 🤖 `scripts/install.sh`: Release 빌드 → `/Applications/SpaceSwitcher.app`에 복사 → 실행
- [ ] 👤 `./scripts/install.sh` 실행 → 손쉬운 사용 권한 부여
- [ ] 👤 설정에서 "로그인 시 자동 실행" 켜기
- [ ] 👤 하루 실사용하며 불편한 점 메모 → 다음 작업으로 등록

**완료 조건:** 재부팅 후 앱이 자동으로 뜨고 Option+E가 동작.

---

## Phase 7 — 지인 배포 ⏱ 약 2시간 (최초), 이후 릴리스마다 약 5분

- [ ] 🤖 `project.yml`에 버전 필드 정리 (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`)
- [ ] 🤖 `scripts/release.sh <버전>`:
  - Universal(arm64+x86_64) Release 빌드
  - `SpaceSwitcher Signing`으로 서명 + `codesign --verify` 검사
  - `hdiutil`로 DMG 생성 (앱 + Applications 바로가기)
  - `gh release create v<버전> SpaceSwitcher.dmg`
- [ ] 🤖 `README.md` (한국어): 기능 소개, 스크린샷 자리, **지인용 설치 방법**
  - DMG 열기 → Applications로 드래그
  - 첫 실행 차단 시: 시스템 설정 → 개인정보 보호 및 보안 → "그래도 열기"
  - 손쉬운 사용 권한 부여
  - "데스크탑 N으로 전환" 단축키 켜기
  - 업데이트: 새 DMG로 덮어쓰기 (권한 유지됨)
- [ ] 👤 `./scripts/release.sh 0.1.0` 실행 → GitHub Releases 페이지 확인
- [ ] 👤 지인 1명에게 링크 전달 → README대로 설치되는지 확인 (가능하면 Intel 맥도)
- [ ] 🤖 지인 피드백 반영해 README 보완

**완료 조건:** 지인이 README만 보고 설치해 Option+E를 사용.

---

## 나중에 (MVP 이후, 지금은 안 함)

- [ ] 다중 모니터 지원 (SPEC §8-3)
- [ ] 전체화면 앱 Space 목록 포함 (SPEC §8-4)
- [ ] 앱 아이콘 / 메뉴바 아이콘 디자인 (SPEC §8-5)
- [ ] 새 버전 알림 또는 Sparkle 자동 업데이트
- [ ] Apple Developer Program 가입 → 공증 (지인이 "그래도 열기"를 안 해도 되게)
