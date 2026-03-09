# SmoothSnap — Claude Code 운영 규칙

## 프로젝트 개요
- 앱명: SmoothSnap (macOS 윈도우 스냅 유틸리티)
- Bundle ID: `com.smoothmac.smoothsnap`
- 배포: Mac App Store (Sandbox + Accessibility 임시예외)
- 주요 경로: `SmoothSnap/` (소스), `SmoothSnap.xcodeproj` (xcodegen 생성)

---

## 에이전트 위임 규칙 (Agent Delegation Rules)

Claude Code는 아래 규칙에 따라 전문 에이전트에게 작업을 위임해야 한다.
Claude Code가 직접 처리하는 것은 **간단한 파일 읽기/탐색 및 에이전트 조율**에 한정한다.

| 작업 유형 | 담당 에이전트 | 직접 처리 금지 |
|-----------|-------------|--------------|
| Swift 코드 구현/수정/리팩토링 | `snapmaster-swift-engineer` | ✅ |
| 코드 리뷰 / 버그 수정 검증 | `snapmaster-qa-specialist` | ✅ |
| App Store 등록/메타데이터/리뷰 | `snapmaster-appstore-manager` | ✅ |
| 버전 기록 / CHANGELOG 관리 | `snapmaster-version-manager` | ✅ |
| 디자인 / 아이콘 / 스크린샷 | `snapmaster-senior-designer` | ✅ |
| 전체 조율 / 진행 보고 / 방향 결정 | `snapmaster-pm` | ✅ |

### 예외: 직접 처리 허용 범위
- `CLAUDE.md`, `project.yml`, agent 파일 자체 수정
- `git status`, `git log` 등 상태 조회
- 탐색/검색 (Glob, Grep, Read)
- xcodegen 재생성 (`xcodegen generate`)

---

## 에이전트 간 크로스 밸리데이션 프로토콜

### 파이프라인 1: 코드 변경 (일반)
```
snapmaster-swift-engineer (구현)
        ↓
snapmaster-qa-specialist (검증)
        ↓ [PASS 시]
snapmaster-version-manager (버전/CHANGELOG 기록)
```
- QA에서 **Critical/High** 이슈 발견 시 → swift-engineer에게 재위임, 재검증 필수
- QA **PASS** 없이 version-manager 기록 금지

### 파이프라인 2: App Store 제출
```
snapmaster-swift-engineer (기술 준비 확인)
        ↓
snapmaster-qa-specialist (출시 전 최종 검증)
        ↓ [PASS 시]
snapmaster-appstore-manager (메타데이터/제출)
        ↓
snapmaster-version-manager (릴리즈 기록)
```
- appstore-manager는 swift-engineer + QA 양쪽 **PASS 리포트** 없이 제출 진행 불가

### 파이프라인 3: 디자인 → 코드 통합
```
snapmaster-senior-designer (에셋 생성)
        ↓
snapmaster-swift-engineer (통합 가능성 검토 및 구현)
        ↓
snapmaster-qa-specialist (렌더링/UI 검증)
```

### 파이프라인 4: 긴급 버그 수정 (Hotfix)
```
snapmaster-swift-engineer (수정)
        ↓
snapmaster-qa-specialist (회귀 검증 — 간소화 허용)
        ↓ [PASS 시]
snapmaster-version-manager (patch 버전 기록)
```

---

## 크로스 밸리데이션 트리거 조건

다음 조건 중 하나라도 해당하면 교차 검증을 반드시 실행한다:

| 트리거 | 필수 검증 |
|--------|---------|
| Swift 파일 1개 이상 변경 | QA 검증 필수 |
| 아키텍처 변경 (새 클래스/모듈 추가) | PM 승인 + QA 검증 |
| App Store 제출 직전 | Swift Engineer 기술 확인 + QA PASS |
| CHANGELOG에 버전 추가 | QA PASS 리포트 첨부 필수 |
| QA에서 Critical 이슈 발견 | 수정 후 QA 재검증, PM에 에스컬레이션 |
| 에이전트 간 결과물 충돌 | PM이 중재 및 사용자에게 컨펌 요청 |

---

## PM 조율 규칙

`snapmaster-pm` 에이전트는 다음 상황에서 **반드시** 호출된다:
- 멀티 에이전트 파이프라인 시작 전 전체 계획 수립
- 에이전트 간 결과물 충돌 발생 시 중재
- 마일스톤 완료 후 사용자 컨펌 요청
- Critical 이슈 에스컬레이션

---

## 금지 사항

- Claude Code가 Swift 코드를 직접 수정하는 것 (**`snapmaster-swift-engineer` 위임 필수**)
- QA 검증 없이 버전 번호 부여
- 에이전트 결과물 미확인 상태로 다음 파이프라인 단계 진행
- 파이프라인을 생략한 직접 App Store 제출 진행
