# Changelog

All notable changes to SnapMaster will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v1.1.0] - 2026-03-06

Phase 1 고도화: 스냅존 확장 및 버그 수정

### Added
- 스냅존 4개 추가: `leftThird` (좌측 1/3), `centerThird` (가운데 1/3), `rightThird` (우측 1/3), `bottom` (하단 절반)
- 신규 존 기본 단축키 추가: `⌃⌥↓` (bottom), `⌃⌥D` (leftThird), `⌃⌥F` (centerThird), `⌃⌥G` (rightThird)
- 하단 가장자리 드래그 시 X 위치에 따라 5개 구간으로 존 자동 감지 (bottom / leftThird / centerThird / rightThird / 기존 코너)

### Fixed
- `OverlayWindowManager`: 동일 존 재진입 시 `hide()` 대신 `return` 처리하여 불필요한 오버레이 깜빡임 제거
- `OverlayView`: `zone.previewColor`를 실제 적용 (기존 `systemBlue` 하드코딩 제거)
- `HotkeyManager`: `rebind()`에서 `persistBindings()` 중복 호출 제거
- `SnapZoneDetector`: `!inCornerVB` 조건이 `nearBottom`과 논리적으로 항상 `false`가 되는 버그 수정 → 신규 4개 존 드래그 감지 정상화

### Changed
- `SnapZoneDetector`: dead code 정리 — 도달 불가한 코너 감지 코드 제거
- `HotkeyBinding` ID 범위 확장: 기존 1–7 → 1–11 (8=bottom, 9=leftThird, 10=centerThird, 11=rightThird)

---

## [v1.0.0] - 2026-03-06

최초 릴리스

### Added
- CGEventTap 기반 전역 마우스 드래그 감지
- AXUIElement 기반 창 위치/크기 제어
- 스냅존 7개: `left`, `right`, `top` (maximize), `topLeft`, `topRight`, `bottomLeft`, `bottomRight`
- 기본 단축키 7개 (⌃⌥ 수식키 기반): `←`, `→`, `↑`, `U`, `I`, `J`, `K`
- 드래그 미리보기 오버레이 (반투명 NSWindow)
- 메뉴바 아이콘 및 활성화/비활성화 토글
- 단축키 설정 UI (`ShortcutsWindowController`)
- Carbon HIToolbox 기반 전역 단축키 등록/해제
- UserDefaults 기반 단축키 바인딩 영속화

---

<!-- Version Index -->
<!-- v1.1.0 | 2026-03-06 | Phase 1 고도화 (스냅존 4개 추가, 버그 수정 4건) -->
<!-- v1.0.0 | 2026-03-06 | 최초 릴리스 -->
