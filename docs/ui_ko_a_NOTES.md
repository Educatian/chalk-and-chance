# ui_ko_a.tsv notes

520 rows. Checked with `python -I _check.py`: same placeholder sequence in every row, same `\n` count, no tabs, no duplicate keys, no BOM. Trailing spaces on prefix labels ("Coach Vee:  ", "Focus: ", "Why: " and so on) are kept, because code appends text after them.

## Skipped on purpose
- Node, overlay and bus names (Kicker, CoachCard, *Overlay, Voice, Master, SFX), JS snippets, regexes, format-only strings (`%d / %d XP`, `[center][i]%s[/i][/center]`), backend error strings, the "still here" heartbeat.
- Instructor and analytics panels: all of HubReports, InstructorAnalyticsText, the Class/Quality/TeacherSim/Cloud Log buttons and their overlays (COMMERCIAL READINESS, TEACHERSIM DELTA, CLOUD LOG CHECK, D1 lines, INSTRUCTOR DASHBOARD, cloud dashboard status lines).
- Value-compared strings, which have to stay English: `Core move` (CoachFeedback.gd:120, PathJudge.gd:30), `1:1 Encounter` (Tuning.gd:64, the mode key), `first ` (CoachFeedback.gd:179 parse token), `lesson plan` / `practice set` / `individual work` / `direct instruction` / `number talk` / `place value` / `main idea` (LessonImport keyword matching).
- Citation shorts with no words to translate (`Jacobs et al. 2010`, `Rowe 1986`, `Hattie & Timperley 2007`, `Reinke et al. 2008`), and the `Chalk & Chance` hub wordmark (Hub.gd:35). The brand guide has a Korean lockup; this text label needs the owner's decision.

## Code changes needed for Korean
1. **Hub.gd:61** `"   %d upgrade point%s"` and **Hub.gd:926** `"RECENT RUNS: %d saved run%s..."`: the `%s` is filled with the English plural "s". Korean shows "성장 포인트 2s". Pass `""` when the locale is Korean, or drop the plural argument.
2. **PathJudge.gd:98 + CoachFeedback.gd:179**: the note "right idea, too early: first %s" is parsed with `get_slice("first ", 1)` to recover the move tag. With the Korean note ("방향은 맞는데 너무 일러요. 먼저: %s") the parse returns "", and the "try X first" coaching goes blank. Store the tag in its own field (e.g. `res["next_tag"]`) and stop parsing display text. Also, `_step_hint` (PathJudge.gd:140) fills `%s` with `tag.capitalize()`, so it shows English tags ("Elicit 또는 Wait"). Map the tags through the move labels.
3. **GameCoach.gd:162**: `text.find("not sure")` / `"confused"` look at the student's reply. With Korean replies ("음… 잠깐만요. 이제 잘 모르겠어요.") the "mix-up came out" signal never fires. Check a reaction flag, or also look for "모르겠" / "헷갈".
4. **Hub.gd:1165** `text != "Close"`: decides the footer button style. With "닫기" every Close button gets the primary style. Compare an id, not the label.
5. **Hub.gd:571** (mission meta) and **PreviewScenario.gd:148** (Format / Seating / Badge): these show raw ids through `capitalize()` (`Group Work`, `ushape`, `echo`). Map them to 모둠 활동 / ㄷ자 배치 / the Korean badge name.
6. **Hub.gd:1590 `_badge_name` = `id.capitalize()`** and **ResultsCard.gd:134 `badge.capitalize() + " badge"`**: badge names stay English ("Echo 배지"), and `" badge"` is not in this batch. They need a Korean name table.
7. **ResultsCard.gd:223-226 `weak.capitalize()`**: harmless for Korean text, but `weak` has to arrive already in Korean.
8. **CoachFeedback.gd:139 / :170 `who`** and **LessonImport.gd:8 NAMES**: I gave the NAMES table the Korean names. `_persona_paths` (CoachFeedback.gd:145) matches `student_name.to_lower()` against the persona file's `display_name` or a file-name prefix. If the persona JSON display names become Korean too, they still match, but the file-prefix fallback (`noah...`) no longer will. Keep the display names in step.
9. **ImportLesson.gd:53 placeholder** (now a Korean example: 학년/과목/수업 시간/45분) together with **LessonImport.gd:83 and :91**: the offline parser only reads English (`subject:`, `\d+ min`, `discussion`, `group` and so on). A Korean plan works through the AI path, but offline it falls back to a 2-minute discussion with the title "가져온 수업". Add Korean keywords (과목/주제, `(\d+)\s*분`, 토의/모둠/개별/강의).
10. **Hub.gd leaderboard header** `"등급   점수   수업 ..."`: the columns are lined up with spaces. Hangul is wider in Galmuri, so the alignment needs to be checked on screen.

## Fragments and how they join
- `%s badge: %s%s` + `  (not earned yet)` → "Echo 배지: 아이들이 직접 설명하게 하기  (아직 못 받았어요)". The badge descriptions are written as -기 noun phrases, so they also read right in "(연습할 것: %s)" (Hub.gd MISSION LOCKED).
- CoachCard `%s  ·  %s  ->  try %s`: I used "추천: %s". `better_label + " first"` becomes "기다려 주기" + "부터" ("추천: 기다려 주기부터"). The Korean value has no leading space on purpose.
- `Turn %d` + `, with %s` → "3턴, 상대: 도윤". I avoided a particle (와/과) after the name.
- Telemetry `Teacher` + ` move (%s)` → "교사 행동 (elicit)". The `%s` is the raw tag.
- GameCoach practice lines take the -기 phrases after "해 볼 것: %s." The compact versions sit after "->".
- `%s` + `부터 시작해요` and `%s한테`: both work after any title or name, with or without a final consonant. I avoided 은/는/이/가 after placeholders everywhere.

## Unsure (tone, terms, maths)
- Moves that are not in the glossary (lecture/group modes): Present 제시하기, Question 질문하기, Repair 다시 설명하기, Check 확인하기, Observe 지켜보기, Probe 근거 묻기, Press 더 파고들기, Redistribute 발언 넘기기. These should match the move buttons in the other batch.
- `Trace` / `TRACE` became 기록. Board is also 기록판, so "기록" now covers both. 수업 기록 is the detail title.
- Upgrade names (흔들림 없는 존재감, 기다림 달인, 관계 감각), profile names (차분한 리더 / 차분, 잘 듣는 교사 / 경청, 고른 발언 지킴이), and item names (관찰 돋보기, 발언 현황, 기다림 타이머) are my coinage.
- "number talk" → 수 이야기 (in the placeholder). There is no settled Korean term; 수 감각 토의 is an alternative.
- Coach starter "Who can explain why the denominator names the parts?" became "분모를 보면 전체를 몇 조각으로 나눴는지 알 수 있지? 왜 그런지 설명해 볼 사람?" Please check this is still the same question.
- Thumbs poll: "자신 있으면 엄지 위, 애매하면 옆, 모르겠으면 아래". The English is a plain up/sideways/down vote; I added what each position means.
- The LLMClient offline replies have no persona, so they are one generic, slightly hesitant student voice. They can't be told apart by speaker.
- `The test:` → 관건:, `Scored:` → 채점:, CASE/SUCCESS/SCORED ON → 상황/성공 조건/채점 기준.
- "Play" on the login screen (guest start) → 바로 하기.
