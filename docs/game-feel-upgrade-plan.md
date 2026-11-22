# Chalk & Chance: 손맛(game feel) · 레이아웃 업그레이드 계획

작성 2026-11-20 · 조사 전용 (게임플레이 코드·씬·에셋 변경 없음) · 증거 스크린샷: [`Docs/feel-audit/`](feel-audit/)

---

## 0. 결론 먼저

**가장 큰 손맛 문제 3가지**

| # | 문제 | 한 줄 증거 |
|---|---|---|
| 1 | **핵심 동사(교수 move 선택)의 결과가 손에 안 느껴진다.** 누르면 click 음 → 좋음/나쁨 비프 1개 → 미터가 *즉시 점프* → 작은 노란 글씨 한 줄. 정답과 오답 화면이 거의 똑같아 보인다. | `Encounter.gd:1242` 미터 fill을 size로 바로 대입, `:1415` 결과는 Label.text 교체만. [web_05](feel-audit/web_05_encounter_after_wrong.png) vs [web_06](feel-audit/web_06_encounter_after_right.png) |
| 2 | **레이아웃이 화면마다 손으로 좌표를 찍은 구조라 위계·가독성이 흔들린다.** 교실 HUD 텍스트가 플레이필드 위에 판 없이 떠서 학생 이름을 가리고, 코치 문장이 잘리고, 결과 패널은 텍스트가 테두리를 넘는다. 폰 세로 화면에선 게임이 219px 높이로 줄어든다. | 폰트 크기 override 141곳(6–18pt 13종), `Hub.gd` 절대좌표 86곳. [web_02](feel-audit/web_02_overworld_hud.png), [web_07](feel-audit/web_07_session_complete.png), [web_08](feel-audit/web_08_aspect_portrait_landscape_4x3.png) |
| 3 | **입력/포커스 경로에 구멍이 있다.** 타이틀(Login)은 키보드 포커스가 없어 Enter·방향키·Tab 모두 무반응, 허브는 포커스가 화면 밖 카드로 가도 스크롤이 안 따라가고, 대사 스킵은 마우스만, 교실에서 Esc 한 번이면 확인 없이 수업이 끝난다. | 관찰 로그 + `Login.gd`(grab_focus 없음), `Hub.gd:174`(follow_focus 없음), `Encounter.gd:1421`, `Overworld.gd:1154` |

**가장 가치 높은 업그레이드 3가지**

| # | 업그레이드 | 왜 |
|---|---|---|
| 1 | **"턴 해소 비트(Turn Resolution Beat)" + 공용 `Juice` 오토로드** — 커밋(버튼 눌림) → 학생 반응(초상·이모트) → 미터 트윈 + 증감 숫자 → 코치 한 줄, 0.6–0.9초 순서 연출. Encounter/Lecture/Gym 공용. | 게임의 99%가 이 순간이다. 수치가 *어디서 왜* 움직였는지 보이게 하면 학습 피드백도 같이 선명해진다. |
| 2 | **Theme 타입 변형 + HUD 판(plate) + 반응형 스트레치** — 폰트 스케일 토큰 5단계, `Overworld._hud_plate()`(이미 있음) 재사용, `aspect=expand` + 앵커. | 141개 산발 override를 한 곳에서 다루게 되고, 웹/모바일 화면이 살아난다. |
| 3 | **입력 패스** — Login 기본 포커스, 허브 follow_focus, 키보드/패드 대사 스킵, move 단축키 1–8, 교실 이동 입력 버퍼·부딪힘 피드백, Esc 확인. | 몇 시간짜리 작업들이지만 "손이 막히는" 순간을 전부 없앤다. |

**학습 목적과의 원칙 (모든 항목에 적용)**: 연출은 결과를 *과장하지 않는다*. 오답에는 축하성 연출을 쓰지 않고, "맞는 생각인데 이르다(early)"는 오답 소리와 구분하며, 승리 연출 강도는 랭크/증거 품질에 비례시킨다. (현재 위반 사례 2건 → §4 참고)

---

## 1. 현재 상태 (현재 상태)

### 1.1 어떻게 관찰했나 (출처 정직성)

| 경로 | 무엇을 봤나 | 한계 |
|---|---|---|
| **A. 로컬 Godot 4.7.2, 워크트리에서 스크립트 구동** (커스텀 user dir로 소유자 세이브 격리) | 타이틀, 허브, 포커스 이동, 브리핑 팝인, 미션 시네마틱, 렉처 씬 + 프레임 스트립(`strip_*.png`) | 실행 도중 소유자 지시("화면에 창 띄우지 말 것")로 **즉시 중단**. 이후 로컬 실행 없음. 파일명 `00_`–`06_`, `strip_*` |
| **B. 공개 웹 빌드, 헤드리스 Chromium(화면 없음)** `educatian.github.io/chalk-and-chance-play/?public_demo=1` | 허브 포커스, 브리핑→교실, 교실 HUD, 돌발 이벤트 모달, 1:1 인카운터 8턴(오답 Tell → Revoice/Extend 경로 → 승리), 세션 완료 패널, 4개 화면비 | SwiftShader 소프트웨어 렌더링이라 **프레임 타이밍은 신뢰 불가** → 모션 판단은 코드 + 경로 A의 스트립으로. 웹 빌드는 Godot 4.6.3(Compatibility)로 저장소 HEAD와 버전이 다를 수 있음. 학생 응답은 stub. 파일명 `web_*` |
| **C. 코드 리딩** | 아래 모든 file:line | — |

수업 종료 디브리프 화면은 교실 시계가 돌발 모달마다 멈춰 헤드리스 실행 시간 안에 도달하지 못했다(§1.7). 디브리프에 대한 평가는 코드(`Overworld.gd:783–`)와 `CompletionFx.gd` 기준이다.

### 1.2 화면별 스크린샷

| 화면 | 파일 |
|---|---|
| 타이틀/로그인 | [00_title](feel-audit/00_title.png) |
| 허브(미션 선택) | [01_hub](feel-audit/01_hub.png), [02_hub_focus_down](feel-audit/02_hub_focus_down.png), [web_01_hub_focus_offscreen](feel-audit/web_01_hub_focus_offscreen.png) |
| 미션 브리핑 | [03_briefing](feel-audit/03_briefing.png), [strip_briefing_popin](feel-audit/strip_briefing_popin.png) |
| 미션 시네마틱 | [04_cinematic_open](feel-audit/04_cinematic_open.png), [05_cinematic_mid](feel-audit/05_cinematic_mid.png), [strip_hub_to_next](feel-audit/strip_hub_to_next.png) |
| 렉처 씬 | [06_lecture](feel-audit/06_lecture.png) |
| 교실(오버월드) | [web_02_overworld_hud](feel-audit/web_02_overworld_hud.png), [web_03_interrupt_modal](feel-audit/web_03_interrupt_modal.png), [web_strip_briefing_to_overworld](feel-audit/web_strip_briefing_to_overworld.png) |
| 1:1 인카운터 | [web_04_encounter_focus](feel-audit/web_04_encounter_focus.png), [web_05_after_wrong](feel-audit/web_05_encounter_after_wrong.png), [web_06_after_right](feel-audit/web_06_encounter_after_right.png), [web_strip_encounter_turns](feel-audit/web_strip_encounter_turns.png) |
| 결과(세션 완료) | [web_07_session_complete](feel-audit/web_07_session_complete.png) |
| 화면비 | [web_08_aspect_portrait_landscape_4x3](feel-audit/web_08_aspect_portrait_landscape_4x3.png) (390×844 / 844×390 / 1024×768) |
| 부트·씬 전환 | [strip_boot_wipe](feel-audit/strip_boot_wipe.png), [strip_login_to_hub](feel-audit/strip_login_to_hub.png) |

### 1.3 입력 반응

| 항목 | 현재 | 증거 | 판정 |
|---|---|---|---|
| 타이틀 키보드 조작 | Enter·↓·Tab 모두 포커스 없음. 마우스/터치만 가능 | 관찰 로그(`focus=none` 3회), `Login.gd:93–101`에 `grab_focus` 없음 | ❌ |
| 허브 포커스 | 첫 카드 Start에 자동 포커스 ✓. ↓ 누르면 다음 카드로 가지만 **스크롤이 안 따라가 포커스가 화면 밖** | [web_01](feel-audit/web_01_hub_focus_offscreen.png), `Hub.gd:174` ScrollContainer에 `follow_focus` 없음 | ⚠️ |
| 포커스 가시성 | 테마에 focus StyleBox 있음. 인카운터 move 버튼은 얇은 청록 테두리라 약함 | `ui/theme.tres:67,104`, [web_04](feel-audit/web_04_encounter_focus.png) | ⚠️ |
| 교실 이동 | 누르고 있으면 연속 이동(입력 폴링) ✓. 한 칸 0.12s **선형** 트윈, 이동 중 입력 무시(버퍼 없음), 탭으로 제자리 회전 불가, 벽에 부딪혀도 무반응 | `Player.gd:7,90–103,142,172` | ⚠️ |
| 인카운터 move | 키보드 포커스+Enter ✓, 마우스 ✓. 단축키 없음(8개를 방향키로 순회). 3초 대기 게이트(교육 메커닉) | `Encounter.gd:23,695–716` | ⚠️ |
| 대사 스킵 | 시네마틱은 Enter/클릭으로 스킵 ✓. 인카운터 타자기 스킵은 **마우스 클릭만** | `MissionCinematic.gd:392–396`, `Encounter.gd:1421–1434` | ❌ |
| 뒤로/취소 | 허브 Esc로 최상위 오버레이 닫기 ✓. 교실 Esc/Backspace = **확인 없이 허브로**(관찰: 실수 한 번에 수업 이탈) | `Hub.gd:230`, `Overworld.gd:1154–1159` | ❌ |
| 게임패드 | `ui_*` 기본 매핑만 사용, 패드 전용 프롬프트/글리프 없음. 화면 안내문은 "Z/Enter/Space" 고정 | `Hub.gd:217`, 교실 HUD 문구 | ⚠️ |
| 터치 | 버튼 클릭은 됨. 교실 이동은 키 폴링뿐이라 **모바일에선 교실 이동 불가로 추정**(미검증) | `Player.gd:90–103` | ❌(코드 기준) |

### 1.4 동사별 피드백

| 동사 | 보이는 것 | 들리는 것 | 판정 |
|---|---|---|---|
| 호버/포커스 | 테마 hover 스타일 | `hover` 틱(자동 연결) | ✅ `Sfx.gd:60–70` |
| 선택(확인) | pressed 스타일 | `click` | ✅ |
| 모달 열기 | 0.18s 페이드+스케일 BACK | `open` | ✅ `HubUi.gd:124–134` |
| **교수 move 결과(정답)** | 초상 교체 + 0.22s 바운스, 미터 **즉시 점프**, 결과 한 줄(작은 노란 글씨), 코치 타자기 | `good` 3음 | ⚠️ 약함 `Encounter.gd:783–815,1345` |
| **교수 move 결과(오답)** | 위와 동일 구조, 색/모션 차이 없음 | `bad` 하강음 | ❌ 정답과 구분 약함 |
| "맞지만 이르다(early)" | 코치 문구만 다름 | **`bad`와 동일** | ❌ 학습 정직성 문제 `Encounter.gd:808–815` |
| 렉처 move | 학생 반응 아이콘·텍스트 | `click`만, 턴별 good/bad 없음 | ⚠️ `LectureScene.gd:570` |
| 교실 걷기 | 걷기 애니 ✓ | 없음(발소리 없음) | ⚠️ |
| 벽/책상 충돌 | 없음 | 없음 | ❌ `Player.gd:142` |
| 돌발 이벤트 | 모달(본문 1줄에 큰 빈 패널) | `interrupt` | ⚠️ [web_03](feel-audit/web_03_interrupt_modal.png) |
| 승리/세션 완료 | 패널 진입, 컨페티, 랭크 도장 + 흔들림, 점수 카운트업 | `whoosh`→`stamp`→`badge` | ✅ 단, 컨페티가 텍스트 위에 겹침([web_07](feel-audit/web_07_session_complete.png)) · **랭크 D에도 동일 컨페티** |
| 레벨업 | 배지 카드 0.16s 스케일 | `levelup` 큐는 있으나 인카운터에선 `badge`만 | ⚠️ `Encounter.gd:1142–1162` |
| 씬 전환 | 브랜드 와이프 0.28s(모든 전환 동일) | 없음 | ⚠️ `SceneRouter.gd:37–99` |

### 1.5 모션

| 요소 | 현재 | 판정 |
|---|---|---|
| 트윈 사용처 | 11개 파일, 대부분 `CompletionFx`/`MissionCinematic`에 집중. 인카운터 3개 | 편중 |
| 이징 | 모달·도장·바운스는 BACK/QUAD/CUBIC로 좋음. **이동·미터는 선형 또는 없음** | ⚠️ |
| 예비동작/후속동작 | 결과 패널 도장(2.6배→1배, 회전)만 존재 | ⚠️ |
| 화면 흔들림 | 도장 착지 1곳(`CompletionFx.gd:141`) — 적절히 절제됨 | ✅ |
| 히트스톱 | 없음 (이 장르에선 "판정 직전 0.1–0.15s 정지"로 번역 가능) | — |
| 파티클 | ColorRect 컨페티 24개, 파티클 노드 없음 | ✅(충분) |
| 텍스트 출현 | 인카운터 타자기 72자/s, 최대 1.8s, **블립 없음**. 시네마틱은 블립 있음 | ⚠️ 불일치 `Encounter.gd:1398` vs `MissionCinematic.gd:258` |
| 씬 전환 | 이전 씬 즉시 제거 → 와이프가 새 씬을 드러냄. 동기 `load()` | ⚠️ 맥락 없는 단일 전환 |
| 모션 감소 설정 | `reduced_motion`, `text_reveal`, `large_text` 존중 | ✅ 유지할 것 |

### 1.6 오디오

| 항목 | 현재 | 판정 |
|---|---|---|
| SFX | 런타임 합성 13종(웹에서도 동작), 10보이스 풀, 35ms 중복 억제, 버튼 자동 연결 | ✅ 영리한 구조 |
| 변주 | 타자기·틱만 피치 랜덤. click/good/bad는 매번 동일 | ⚠️ 반복 피로 |
| 음악 | 4트랙, 씬별 1.2s 크로스페이드, 독립 버스 | ✅ |
| 음악 레이어링 | 없음 (교실 긴장도와 무관하게 동일 루프) | — |
| 버스/믹스 | `SFX`(−6dB)·`Music` 버스를 코드로 생성, `default_bus_layout.tres` 없음. TTS는 **Master 직결**, 덕킹/리미터 없음 | ⚠️ `TTSClient.gd:23`, `Sfx.gd:163` |

### 1.7 레이아웃

| 항목 | 현재 | 판정 |
|---|---|---|
| 기반 해상도 | 960×540, `canvas_items` + `fractional`, aspect 기본값(keep) | 폰 세로 = 390×219로 축소 [web_08](feel-audit/web_08_aspect_portrait_landscape_4x3.png) ❌ |
| 구조 | 컨테이너보다 절대좌표(Hub 86, Overworld 35, Encounter 26곳), 인카운터 계열은 960 좌표로 그린 뒤 `PixelUi.scale_tree(×2)` | 유지보수·반응형 모두 불리 |
| 타이포 | 테마 1개 + override 141곳, 크기 6–18 사이 13종. 픽셀 폰트는 제목·와이프에만 | 위계가 화면마다 다름 |
| 허브 | 상단에 6줄의 메타 정보 후 첫 카드. 우상단 버튼 패널이 헤드라인 영역과 겹침 | ⚠️ [01_hub](feel-audit/01_hub.png) |
| 교실 HUD | 제목·조작법·주의도·방해·룸 큐·참여·목표 4줄·코치·안내가 **판 없이 바닥 위에** 떠 있음, 학생 이름 가림 | ❌ [web_02](feel-audit/web_02_overworld_hud.png) |
| 인카운터 | 미터 4개 + 대기바 + 초상 + 말풍선 + 결과줄 + 코치줄 + 8버튼 + Type. 결과/코치 줄이 가장 작고 잘림 | ⚠️ [web_05](feel-audit/web_05_encounter_after_wrong.png) |
| 렉처 | 상단 제목줄과 작은 라벨이 겹침 | ⚠️ [06_lecture](feel-audit/06_lecture.png) |
| 결과 패널 | 정보 밀도 높음, 하단 텍스트가 바/테두리와 겹침, 바 위 "n=3" 대비 낮음 | ⚠️ [web_07](feel-audit/web_07_session_complete.png) |
| 모달 | 돌발 이벤트 본문 1줄에 고정 높이 360 패널 | ⚠️ `Overworld.gd:1085–1090` |

### 1.8 페이싱

| 구간 | 관찰값 | 메모 |
|---|---|---|
| 허브 → 브리핑 | 즉시 (0.18s 팝인) | ✅ |
| 시네마틱 | Enter 16회(빠르게 눌러 ~8s) | 스킵 버튼·Esc 있음 ✅ |
| 인카운터 1턴 | 3.0s 대기 게이트 + stub 응답 즉시 + 타자기 ≤1.8s | 대기는 *교육 메커닉* — 유지하되 "기다림이 행동"처럼 느껴지게 |
| Jordan 해소 | 8턴(오답 1 포함) ≈ 40–60s | 같은 학생 대사가 반복됨(stub) → 반복감 큼 |
| 교실 시계 | 돌발 모달·인카운터 동안 정지 | 의도된 것으로 보임, 단 체감 시간 예측이 어려움 |
| 화면당 텍스트 | 브리핑 8블록, 교실 HUD 12줄 상시 | ❌ 과다 |

### 1.9 이미 좋은 것 — 지킬 것

- **합성 SFX 라이브러리 + 버튼 자동 연결**(`Sfx.gd`): 웹 호환, 에셋 0개. 확장만 하면 된다.
- **씬별 음악 크로스페이드**(`Music.gd`).
- **결과 연출 모듈 `CompletionFx`**: 도장·컨페티·카운트업·절제된 흔들림 — 공용 Juice의 씨앗.
- **시네마틱 타자기 + 블립 + 스킵**, **12감정 초상 + 폴백 + 바운스**.
- **접근성 설정**(reduced_motion / text_reveal / large_text)이 실제로 코드 전반에서 존중됨.
- **Theme 리소스와 focus 스타일이 이미 존재**, 모든 씬 전환이 `SceneRouter` 한 곳을 지남 → 공용 시스템을 꽂을 자리가 이미 있다.
- **3초 Wait-time 게이트**: 손맛을 위해 없애면 안 되는 핵심 교육 메커닉.

---

## 2. 좋은 예시 분석 (좋은 예시 분석)

원칙과 기법만 가져온다. 외형·캐릭터·레이아웃·콘텐츠는 차용하지 않는다.

| 게임 | 기법 | 왜 통하나 | 여기서 적용할 곳 | 출처 |
|---|---|---|---|---|
| **Into the Breach** | 커밋 전 **결과 미리보기/텔레그래프**, "멋진 아이디어보다 명료함" 원칙 | 선택 전 정보가 완전하면 결과가 공정하게 느껴지고 실패가 학습이 된다 | move 버튼 포커스 시 "이 move가 겨냥하는 구성요소(예: 추론 드러내기)"를 미리 보여주기 — **결과(정답 여부)는 숨긴 채** | [Game Developer: UI 명료함 인터뷰](https://gamedeveloper.com/design/-i-into-the-breach-i-dev-on-ui-design-sacrifice-cool-ideas-for-the-sake-of-clarity-every-time-), [GDC 2019 Design Postmortem](https://www.gdcvault.com/play/1026333/contactUs) (세션 본문은 Vault 유료, 세부 미검증) |
| **Slay the Spire** | 카드 호버 시 들어올림·확대, 적 **의도(intent) 아이콘**, 수치 변화의 즉시 시각화 | 손에 든 선택지가 "물건"처럼 반응하고, 상대의 다음 반응을 예측하게 해 결정에 무게가 생긴다 | 8개 move를 "손패"처럼: 포커스 시 들어올림 + 짧은 설명. 학생 초상 옆에 현재 상태 아이콘(혼란/몰입) | [GDC 2019 Metrics Driven Design 소개](https://gdconf.com/news/learn-slay-spires-successful-metrics-driven-approach-game-balancing-gdc-2019) — 이 출처는 밸런싱 얘기이며 **UI 기법 자체는 게임 플레이 관찰 기반(개발자 출처 미검증)** |
| **Disco Elysium** | 판정의 종류를 색으로 구분(재시도 가능 vs 1회성), **실패를 흥미로운 결과로 작성** | 실패해도 이야기가 앞으로 가니 플레이어가 위험한 선택을 시도한다 | 오답 피드백을 "벌점"이 아니라 학생의 *다른 반응*으로: 오답 시에도 새 정보(학생의 오개념 단서)를 준다. "early"는 별도 색·음 | [공식 devblog: Active skill checks](https://discoelysium.com/devblog/2016/10/06/active-skill-checks), [PC Gamer: Why I love failing](https://www.pcgamer.com/why-i-love-failing-in-disco-elysium) |
| **Papers, Please** | **촉감 있는 데스크 동사**(도장 찍기, 셔터), 정보 밀도 높은 화면을 물리적 배치로 정리 | 반복 동작 하나하나가 묵직해서 지루한 반복이 리듬이 된다 | 결과 패널 도장은 이미 이 방향 ✅. 인카운터 "커밋" 순간에도 작은 착지감(버튼 눌림 60ms 유지 + 저음 탁) | [Lucas Pope TIGSource devlog 미러](https://dukope.com/devlogs/papers-please/tig-00), [Game Developer: Designing the bleak genius](https://www.gamedeveloper.com/design/designing-the-bleak-genius-of-i-papers-please-i-) |
| **Celeste** | **입력 버퍼·코요테 타임** 등 보이지 않는 관용 | 어려운 게임이 "공정하고 친절하게" 느껴진다 | 교실 이동: 한 칸 이동 중 들어온 방향 입력을 버퍼링(~100ms), 탭 = 제자리 회전, 대사 출력 중 누른 Enter는 "스킵 후 다음 입력"으로 소비 | [Maddy Thorson, Celeste & Forgiveness](https://maddymakesgames.com/articles/celeste_and_forgiveness/) |
| **Hades** | 대량의 **반응형 대사**로 반복 플레이가 매번 새롭게 느껴짐, 음성과 대사 구현 파이프라인 | 같은 행동을 반복해도 세계가 "나를 알아본다" | 같은 학생에게 같은 move를 반복할 때 대사 변주(현재 stub은 동일 문장 반복). 이전 턴을 언급하는 짧은 반응 | [GDC 2021 Breathing Life into Greek Myth (Vault 개요)](https://www.gdcvault.com/play/1026975/contactUs), [GDC 뉴스](https://gdconf.com/news/dive-dialogue-hades-gdc-2021) (세부 내용 미검증) |
| **Citizen Sleeper** | 주사위 = 시스템에 개입하는 **물리적 자원**, 텍스트 중심 UI를 절제된 패널로 | 추상 수치를 "손에 쥔 것"으로 바꾸면 선택의 비용이 보인다 | Composure/Wait 아이템을 화면에 보이는 "토큰"으로. 스트레스로 손상되는 모습이 기록으로 남는 개념은 Composure 표현에 참고 | [Game Developer 인터뷰](https://www.gamedeveloper.com/business/how-citizen-sleeper-was-inspired-by-tabletop-rpgs-and-gig-work), [Rascal 인터뷰](https://www.rascal.news/tracing-citizen-sleepers-circuitous-vector-from-tabletop-to-hit-video-game/) |

**공통 원리 출처**: Jonasson & Purho, ["Juice It or Lose It"](https://gdcvault.com/play/1016487/Juice-It-or-Lose) (GDC Europe 2012); Jan Willem Nijman, "The Art of Screenshake" (INDIGO 2013, 개최지 표기는 2차 출처 기준·미검증); Steve Swink, *Game Feel* (2009). 이 셋은 학술 문헌에서도 game feel의 1차 출처로 취급된다([Game feel – Wikipedia](https://Www.wikipedia.org/wiki/Game_feel)).

**이 게임에 맞는 번역 규칙**: "타격감"이 아니라 **"관찰감"** — 학생이 무엇을 *보였는지*를 무게 있게 보여주는 것이 손맛이다. 흔들림·히트스톱은 학생 반응을 *강조*하는 데만 쓰고, 정답을 *보상*하는 데 쓰지 않는다.

---

## 3. 갭 표

갭: 🔴 큼 · 🟠 중간 · 🟢 작음

| 차원 | 현재 | 최고 수준의 기준 | 갭 | 증거 |
|---|---|---|---|---|
| 핵심 동사 결과 연출 | 비프 1개 + 즉시 점프 + 텍스트 1줄 | 커밋→반응→수치→해설의 0.5–1s 순서 비트, 정/오답이 실루엣만으로 구분 | 🔴 | `Encounter.gd:783–815,1242,1415` |
| 피드백 정직성 | early=bad 동일음, 랭크 D에도 동일 컨페티 | 결과 종류마다 고유 큐, 축하 강도 ∝ 성과 | 🟠 | `Encounter.gd:815`, `CompletionFx.gd:98` |
| 입력 완결성(키보드/패드/터치) | 타이틀 포커스 없음, 스킵 마우스 전용, 모바일 이동 없음 | 모든 화면을 한 가지 입력장치로 끝까지 | 🔴 | §1.3 |
| 입력 관용(버퍼) | 없음 | 이동·대사 스킵 버퍼 | 🟠 | `Player.gd:85–103` |
| 모션 언어 | 결과 패널에만 풍부, 나머지 선형/없음 | 화면 전체에 일관된 이징 어휘(진입/퇴장/강조 3종) | 🟠 | 트윈 분포 §1.5 |
| 씬 전환 | 단일 와이프, 동기 로드 | 맥락별 전환(인카운터 진입 = 학생에게 초점), 비동기 로드 | 🟠 | `SceneRouter.gd:12–99` |
| 텍스트 출현 | 인카운터 블립 없음, 스킵 마우스 전용 | 화자별 블립 음색, 모든 입력으로 스킵 | 🟢 | `Encounter.gd:1398` |
| SFX 변주/레이어 | 고정 피치 | 피치·음량 랜덤 ±, 결과별 2레이어 | 🟢 | `Sfx.gd:39` |
| 음악 반응성 | 씬 단위 교체 | 상태(주의도·긴장) 따라 스템 레이어 | 🟠 | `Music.gd` |
| 믹스 | 코드 생성 버스, TTS Master 직결 | 버스 레이아웃 파일, 음성 덕킹, 리미터 | 🟠 | `TTSClient.gd:23` |
| 타이포/위계 | override 141곳, 13개 크기 | 4–5단 타입 스케일, 테마 변형 | 🔴 | grep 결과 §1.7 |
| HUD 밀도 | 교실 12줄 상시, 판 없음 | 핵심 2–3개 상시, 나머지 맥락형 | 🔴 | [web_02](feel-audit/web_02_overworld_hud.png) |
| 반응형 | keep 레터박스, 폰 세로 사용 불가 | 16:9~20:9 확장, 세로는 회전 안내 또는 전용 배치 | 🔴 | [web_08](feel-audit/web_08_aspect_portrait_landscape_4x3.png) |
| 페이싱/반복감 | 동일 대사 반복, 턴당 ~5–7s | 반복 시 변주, 결과 확인 즉시 다음 입력 가능 | 🟠 | [web_strip_encounter_turns](feel-audit/web_strip_encounter_turns.png) |

---

## 4. 업그레이드 방안 (업그레이드 방안)

공용 시스템 3개를 축으로 한다: **`Juice` 오토로드**(모션·피드백), **Theme 타입 변형**(레이아웃), **`SceneRouter` 전환 단계화**(전환). 모든 연출은 `reduced_motion`을 먼저 확인한다(기존 규칙 유지). 시각 변경 후엔 기존 스크린샷 QA(`scenes/dev/UILayoutShots.tscn`, `scripts/validate_screenshots.ps1`)를 반드시 돌린다(AGENTS.md 규칙).

### 4.1 Quick wins (각 몇 시간)

| ID | 플레이어가 느끼는 변화 | 건드리는 곳 | 공수 | 위험 | 검증 |
|---|---|---|---|---|---|
| Q1 | 타이틀에서 Enter로 바로 데모 시작, 허브에서 ↓하면 카드가 따라 스크롤 | `Login.gd:~101` `demo.grab_focus()`, `Hub.gd:174` `scroll.follow_focus = true` | 0.5h | 낮음 | 키보드만으로 타이틀→허브→2번째 카드 진입 |
| Q2 | 인카운터 대사를 Enter/Space/패드 A로 스킵 + 학생 대사에 블립 | `Encounter.gd:1398–1434` (시네마틱 `_type_into` 패턴 재사용), Lecture/Gym 동일 위치 | 2h | 낮음: 스킵 Enter가 move 버튼까지 눌리지 않게 `set_input_as_handled` | 스킵 중 move 오발 0회 |
| Q3 | move 단축키 1–8, 버튼에 숫자 표시 | `Encounter.gd:_build_ui`, `LectureScene`, `GymEncounter` | 2h | 낮음 | 단축키로 8턴 해소 |
| Q4 | 미터가 0.25s 동안 차오르고 옆에 "+12/−10" 숫자가 떠올랐다 사라짐 | `Encounter.gd:1242` `_set_meter_fill`을 tween으로, Lecture/Gym 동일 | 3h | 낮음 | 스트립 캡처에서 3프레임 이상 중간값 |
| Q5 | "맞지만 이르다"가 오답 버저와 다른 소리·색 | `Encounter.gd:808–815` 분기 + `Sfx` 큐 `early` 추가 | 1h | 낮음 (**정직성 개선**) | early 판정 시 큐 로그 |
| Q6 | 교실 이동이 부드럽게 감속, 벽에 부딪히면 2px 밀림+둔탁음, 탭=제자리 회전, 이동 중 다음 방향 버퍼 | `Player.gd:85–175` (SINE ease, 100ms 버퍼) | 3h | 중간: 텔레메트리 `step_*` 이벤트 순서 유지 | 이동 텔레메트리 회귀 테스트(`OverworldTest`) |
| Q7 | 교실 Esc는 "허브로 나갈까요?" 확인 | `Overworld.gd:1154` → 기존 `_show_overlay` 재사용 | 1h | 낮음 | Esc 1회로 수업이 끝나지 않음 |
| Q8 | 교실 HUD 텍스트가 반투명 판 위에, 학생 이름 안 가림 | `Overworld._build_hud` — 이미 있는 `_hud_plate()`(`Overworld.gd:496`) 적용 | 3h | 낮음 | 스크린샷 QA |
| Q9 | SFX 반복 피로 감소 | `Sfx.play`에 기본 피치 ±4%, 음량 ±1.5dB 랜덤(블립 제외 옵트아웃) | 1h | 낮음 | 같은 큐 연속 10회 청취 |
| Q10 | 결과 패널 넘침·코치줄 잘림 해소, 돌발 모달 높이를 내용에 맞춤 | `Encounter.gd:992–1070`, `Overworld.gd:1085` | 3h | 낮음 | 스크린샷 QA (large_text 포함) |

### 4.2 Core upgrades (각 며칠)

| ID | 플레이어가 느끼는 변화 | 건드리는 곳 | 공수 | 위험 | 검증 |
|---|---|---|---|---|---|
| C1 | 화면 전체가 같은 모션 언어(진입·퇴장·강조·착지) | **새 오토로드 `Juice`**: `pop_in`, `punch_scale`, `flash`, `float_text`, `count_to`, `shake(intensity)`, `beat(seq)`; `HubUi.pop_in`, `CompletionFx`, `ReactionCue`, `Encounter._bounce_portrait` 이관 | 2–3d | 중간: 기존 연출 회귀 | 기존 dev 씬 스트립 비교, reduced_motion에서 모든 트윈 0 |
| C2 | **턴 해소 비트**: 버튼 눌림 유지(60ms) → 학생 초상 반응·이모트 팝 → 미터 트윈+증감 숫자 → 결과 배지("추론 드러남 +" / "주도권 가져감 −") → 코치 줄. 총 0.6–0.9s, 아무 입력이나 누르면 즉시 끝으로 | `Encounter._on_reply`, `LectureScene._on_move`, `GymEncounter` 결과부 → `Juice.beat()` | 2d | 중간: 3초 대기 타이머(`_arm_turn`)는 **비트 종료 후** 시작해야 공정 | 턴당 입력→첫 반응 ≤100ms, 비트 스킵 가능, 대기 측정값 불변 |
| C3 | 글자 크기·위계가 모든 화면에서 일관 | `ui/theme.tres`에 타입 변형 `Title/Heading/Body/Caption/HudValue` + large_text 대응. override 141곳 중 인카운터·교실 HUD부터 이관 | 3–4d | 중간: 레이아웃 밀림 → 스크린샷 QA 필수 | override 수 감소 추적, `UILayoutAudit` 통과 |
| C4 | 교실 HUD: 상시 3개(시계·주의도·Composure) + 맥락 정보는 이벤트 시 토스트. 목표 4줄은 접이식 | `Overworld._build_hud`, `_process`의 라벨 갱신부 | 2d | 중간: 목표 가시성 저하 → 설계 의도 확인 필요(결정 §5-1) | 첫 플레이 사용자가 목표를 말할 수 있는지 |
| C5 | 씬 전환이 맥락을 가짐: 인카운터 진입 = 학생 쪽으로 좁혀지는 아이리스, 복귀 = 역방향, 허브↔미션 = 현재 와이프. 로딩 히치 제거 | `SceneRouter.change_scene`을 out→load(threaded)→in 단계로, `transition` 파라미터 추가 | 2d | 중간: `setup()` deferred 호출 순서 | 전환 중 프레임 드롭 측정, 모든 dev 테스트 통과 |
| C6 | 화면비 대응: 16:9~20:9는 배경 확장, 폰 세로는 "가로로 돌려주세요" 안내 | `project.godot` `window/stretch/aspect="expand"`, 최상위 UI 앵커 정리, 회전 안내 오버레이 | 2–3d | 높음: 절대좌표 UI가 많아 넓은 화면에서 쏠림 → C3와 함께 | 4개 화면비 헤드리스 캡처 |
| C7 | 믹스 정돈: 음성이 나오면 음악 −8dB 덕킹, 마스터 리미터 | `default_bus_layout.tres`(Master/Music/SFX/UI/Voice), `TTSClient.gd:23` bus 변경, `Music`에 duck API | 1d | 낮음 | 음성 재생 중 버스 레벨 로그 |
| C8 | 모바일 교실 이동(탭한 타일로 걷기 또는 가상 패드) | `Player.gd`에 경로 이동 입력 추가, `Overworld` 탭 처리 | 2d | 중간 | 터치 에뮬레이션으로 학생에게 도달 |

### 4.3 Ambitious (1주 이상)

| ID | 플레이어가 느끼는 변화 | 건드리는 곳 | 공수 | 위험 | 검증 |
|---|---|---|---|---|---|
| A1 | 교실 음악이 주의도·방해에 따라 층이 쌓이고 빠짐 | `tools/compose_bgm.py`로 스템 렌더, `Music`에 레이어 볼륨 API, `Overworld._process`에서 매핑 | 1–1.5w | 중간: 웹 오디오 동시 재생 수 | 주의도 변화 시 레이어 볼륨 로그 |
| A2 | 인카운터를 "대화 무대"로 재배치: 학생 초상을 크게, 대사는 말풍선, move는 손패처럼 포커스 시 들어올림 + **겨냥하는 구성요소 미리보기(정답 여부는 비공개)** | `Encounter.gd` 화면 구성부 분리(AGENTS.md: 대형 스크립트는 분할 계획 먼저) | 1.5–2w | 높음: 대형 파일, 텔레메트리·QA 씬 의존 | 스크린샷 QA, 사용자 테스트(첫 턴까지 시간) |
| A3 | 교실이 살아 있음: 학생 드리프트를 막대 대신 자세/이모트로, 교사 근접 반경 링, 카메라 미세 추종 | `Overworld._build_idle_anim`, `_process` 드리프트 표현 | 1–2w | 중간: 아트 추가 필요 가능 | 막대 없이 드리프트 학생을 식별하는지 |
| A4 | (개발자용) 손맛 회귀 테스트: 헤드리스 웹 빌드 캡처 + 타이밍 지표를 CI에서 | 이번 조사에 쓴 헤드리스 Chromium 드라이버를 `tools/`로 정식화 | 1w | 낮음 | PR마다 스트립 자동 생성 |

### 4.4 학습 목적과 충돌할 수 있는 것 (반드시 지킬 선)

| 위험 | 규칙 |
|---|---|
| 오답에 화려한 연출 → 오답이 "재밌는 버튼"이 됨 | 오답은 *정보량*은 늘리되(학생의 다른 반응, 오개념 단서) *보상감*(밝은 음계, 컨페티, 흔들림)은 쓰지 않는다 |
| early(맞지만 이름)를 오답처럼 처리 | 별도 큐(Q5). 현재 동일 버저는 학습 메시지를 왜곡함 |
| 랭크 D 승리에 S급 축하 | 컨페티 수·도장 흔들림·`badge` 음을 랭크에 비례(`CompletionFx.gd:98–117`) |
| 턴 해소 비트가 3초 대기 측정을 오염 | 대기 타이머는 비트가 끝난 시점부터(C2) |
| 미리보기가 정답을 누설 | 미리보기는 "이 move가 무엇을 하는가"만. 판정·예상 수치 금지 |
| 수치 팝업이 숫자 게임으로 만듦 | 증감 숫자 옆에 구성요소 이름을 같이(예: "추론 +12"), 점수보다 증거를 앞에 |

---

## 5. 소유자 결정 사항 (최대 5)

| # | 결정 | 선택지 | 추천 |
|---|---|---|---|
| 1 | 교실 HUD 목표 4줄을 상시 노출할 것인가 | (a) 상시 유지 (b) 접이식 + 진척 시 토스트 (c) 일시정지 메뉴로 이동 | **(b)** — 목표는 학습에 필요하지만 상시 12줄은 화면을 잠식 |
| 2 | 오답 피드백의 강도 | (a) 중립·정보형 (b) 분명한 부정(버저+흔들림) | **(a)** + 고유 큐. 흔들림은 교실 방해 같은 *사건*에만 |
| 3 | 모바일 세로 화면 | (a) 회전 안내 (b) 세로 전용 레이아웃 (c) 모바일 비지원 명시 | **(a)** 지금, (b)는 A2 이후 재검토 |
| 4 | 1차 성능·연출 기준 플랫폼 | (a) 데스크톱 Forward+ (b) 웹 Compatibility | **(b)** — 학생이 실제로 쓰는 곳. 셰이더보다 트윈/Control 기반 연출로 |
| 5 | 사운드 방향 | (a) 합성 SFX 유지·확장 (b) 외부 SFX 팩 (c) 혼합(시그니처 3–5개만 제작) | **(c)** — 합성 구조를 지키고, 커밋·정답·early·오답·승리 5개만 고품질로 |

---

### 부록: 재현 방법
- 로컬 캡처(소유자 지시 전): Godot 4.7.2 `-s` 드라이버로 `Main.tscn` 부팅, `InputEventAction` 주입, 뷰포트 이미지를 저장. 프로젝트 설정에 임시 `use_custom_user_dir`로 세이브 격리(커밋하지 않음).
- 웹 캡처: Python Playwright 헤드리스 Chromium(`--use-angle=swiftshader`), 1280×720, `?public_demo=1`, 키보드/클릭 이벤트는 브라우저 내부에만 전달.
- 두 드라이버 모두 저장소 밖 스크래치에만 있음. A4에서 정식화 제안.
