# SnapMaster Mac App Store 메타데이터 기록

## 작성일: 2026-03-07
## 상태: URL 확정 완료 / 스크린샷 + Apple Developer 등록 대기

---

## 앱 이름 & 부제목

| 필드 | 내용 | 문자 수 |
|---|---|---|
| App Name | SnapMaster | 10 / 30 |
| Subtitle | Window Manager for Power Users | 30 / 30 |

Subtitle 대안 (A/B 테스트용):
- "Snap Windows. Work Faster." (26자)

---

## 카테고리

- Primary: Productivity
- Secondary: Utilities (권장)

---

## 키워드 (100자 이내)

```
window manager,window snap,screen layout,productivity,multitasking,resize windows,split screen,organize windows,keyboard shortcut,multi monitor
```

문자 수: 99 / 100자

제외 원칙:
- 앱 이름("SnapMaster") 중복 금지
- 경쟁 앱명(Magnet, Moom, BetterSnapTool, Rectangle) 기재 금지
- "free", "best", "top" 등 허위/주관적 표현 금지

---

## What's New (v1.0 최초 출시용)

```
SnapMaster is here. Snap any window to 11 zones by drag or shortcut. Built for Mac power users.
```

문자 수: 92 / 100자

---

## 영문 설명 핵심 구조

1. 첫 문단 (255자 이내, "더 보기" 전 노출): 핵심 가치 명제
2. 섹션 헤더 ALL CAPS: "SNAP ZONES — 11 LAYOUTS, INFINITE PRODUCTIVITY"
3. 기능 bullet: 11개 존 나열
4. "TWO WAYS TO SNAP": 드래그 + 단축키 설명
5. "LIVES IN YOUR MENU BAR": 메뉴바 UX 설명
6. "FINE-GRAINED PREFERENCES": 환경설정 항목 bullet
7. "MULTI-MONITOR READY": 멀티 모니터 설명
8. "DESIGNED FOR MACOS": Swift/AppKit 네이티브, 다크모드, 구독 없음 강조
9. "REQUIREMENTS": macOS 13.0+, Accessibility 권한 이유 명기

Accessibility 권한 명기는 심사 통과율 향상에 실질적 효과 있음.

---

## 가격 (메타데이터 연동)

- 런치: Tier 5 ($4.99) — D+0 ~ D+60
- 정가: Tier 8 ($7.99) — D+60 이후
- Promotional Text에 "Launch Price — Regular Price $7.99" 기재

---

## URL (확정)

| 필드 | URL |
|---|---|
| Support URL | https://smoothmac.app/support.html |
| Privacy Policy URL | https://smoothmac.app/privacy.html |
| Marketing URL | https://smoothmac.app |

배포: GitHub Pages (smooth-mac/snapmaster) → smoothmac.app 커스텀 도메인
HTTPS: Let's Encrypt 인증서 자동 발급 (활성화 완료 예정)

---

## 연령 등급

- 등급: 4+
- 사유: 전 항목 해당 없음 (순수 유틸리티 앱)

---

## 심사 메모 (App Review Notes)

```
SnapMaster requires Accessibility permission to move and resize windows belonging to other applications. This is the only permission the app requests. The permission is granted by the user via System Settings > Privacy & Security > Accessibility and is not requested via an in-app popup on first launch.
```

---

## 제출 전 필수 확인 사항

- [x] CGEventTap → NSEvent 글로벌 모니터 교체 (샌드박스 호환 완료)
- [x] Bundle ID 확정: com.smoothmac.snapmaster
- [x] SKU 확정: SNAPMASTER-001
- [x] Support URL: https://smoothmac.app/support.html
- [x] Privacy Policy URL: https://smoothmac.app/privacy.html
- [ ] Apple Developer Program 등록 ($99/년)
- [ ] App Store Connect 앱 등록 (Bundle ID 입력)
- [ ] 스크린샷 캡처 1280x800 또는 1440x900 최소 1장
- [ ] 가격 티어 설정 및 D+60 변경 일정 등록
