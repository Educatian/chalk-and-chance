# ui_ko_b notes

447 rows in ui_ko_b.tsv. 27 input rows skipped as not shown to players: node names (CompletionBurst, TopBar, RankStamp, DebriefDim, DialogueBubble, DialogueText, ThinkRing, NoticePanel, SessionComplete, GroupComplete, GymComplete, LectureComplete, ReactionCue*, Hud), `{score}`, `Full` (scaffold dict seed), `what do you notice?` (a comment), `Content-Type`, `MISS` (objective_tags go to the leaderboard/telemetry, and its partner `OK` was never extracted), `Teacher` (speaker key in the LLM history), and the `_display_result` match prefixes (`Understanding `, `On a path`, `Not the move`, `Right idea`, Encounter.gd:1692/1697). The prefixes are covered in code change 1 below.

## Code changes needed for Korean

1. **Encounter.gd:1692-1697 `_display_result`** matches English prefixes (`begins_with("Understanding ")`, `"On a path"`, `"Not the move"`, `"Right idea"`) and checks for `+`/`-`. Once the result parts are translated these never match, so the verdict picks the wrong part and the running total stays visible. Match on a tag kept next to the text, not on the display string. (If tr() is applied to the prefixes, the Korean ones are `이해도 `, `통하는 길`, `아직 `, `맞는 방향`.)
2. **Move tags shown as `tag.capitalize()`** print English move names inside Korean lines: Encounter.gd:1038 (`%s, %s에게 맞는 방향이에요…`), :1172 (`%s부터`), :1343 (Turn line), :1400 (`%s로 인식`); GymEncounter.gd:475 (`%s부터`), :590; Overworld.gd:1477/1481 (Move lines). Map tag to the glossary label (생각 묻기, 더 묻기 …). Every Korean move label ends in a vowel, so `%s로` and `%s부터` read correctly.
3. **Plural suffix `%s` (`"" / "s"`)**: Encounter.gd:1297 `reached it in %d turn%s` and Overworld.gd:1485 `%d flare-up%s`. In Korean this prints `…도달s` / `…터짐s`. Pass `""` always for ko, or split the string per language. The Korean rows keep the `%s` at the end only so the placeholders still match.
4. **GroupCheckIn.gd:263** `Status: %s` puts the raw `collective_status` id (`shared_misconception`) on screen. It needs a display label (e.g. 다 같이 같은 오개념).
5. **Encounter.gd:1038 / GymEncounter.gd:590** use `trim_prefix("right idea, too early: ")` on the PathJudge note. If PathJudge notes are translated, the prefix must match the Korean note. I used `맞는 방향, 아직 일러요: `, so whoever translates PathJudge should use that exact prefix.
6. **Encounter.gd:976** lowercases the noticing chip with `.to_lower()`. That does nothing to Korean, so it's harmless, but the Korean line wraps the chip as `'%s'이에요`. That only works because every glossary chip (헷갈려 함, 이해함, 움츠러듦, 딴짓함) ends in a consonant. If the chips change, recheck this line.
7. **Overworld.gd:1296/1432**: `_objective_short_label` has only `voices heard` and `asset connect` extracted. `on-task`, `disruptions`, `composure`, `wait-time` and the `hide`/`show` toggle (Overworld.gd:970) are still English literals and show in `missed: …` and `[O] %s`.
8. **Names and particles**: student names are `%s` and the brief's names mix vowel and consonant endings (수아/도윤). I avoided 은/는, 이/가, 을/를 right after a name (I used `%s에게`, `%s 쪽은`, `%s 생각`, `%s:`). GymEncounter.gd:630/641 append to the name in code (`name + " shifts with the room."`), so the Korean starts with ` 학생은…` and gives `도윤 학생은 …`. If the fallback name `Student`/학생 is used, that reads `학생 학생은`. Rare, but a format string would fix it.
9. **GymEncounter.gd:23 `Redir.`**: the English is abbreviated, probably for width. The Korean `주의 돌리기` is 5 characters and may need a width check on the gym move row.

## Unsure / please check

- **Item names** aren't in the glossary and live in autoload/Items.gd (not in this batch). I used: Breathing Reset 심호흡, Student Profile Card 학생 카드, Noticing Lens 관찰 렌즈, Wait Meter Pin 기다림 핀, Lesson Map 수업 지도, Practice Goal 연습 목표, Quiet Signal 조용 신호, Equity Snapshot 발언 현황판. These need to match the Items.gd translation.
- **Group moves** (not in glossary): Observe 지켜보기, Probe 캐묻기, Press 파고들기, Redistribute 발언 넘기기, Move on 넘어가기. **Lecture moves**: Present 제시하기, Question 질문하기, Repair 다시 설명하기, Check 확인하기. I kept Present away from 설명하기 because that word is the Tell move.
- **"move" as a noun** is rendered `수` throughout (다음 수, 맞는 수, 기본 수 for `Core move`). That's consistent, but it's a game-ish word. 방법 is the alternative.
- **Participation** (group mode) is 참여, the same word as Engagement. The two never appear on the same screen.
- **Comprehension / Understanding** are both 이해도. `Comp` (short) is 이해.
- **Mode/title words**: 1:1 Encounter 1:1 지도, Gym/Capstone 종합 실전, Lecture 강의식 수업, Classroom 교실, hub 수업 목록, DEBRIEF 돌아보기, CLEARED 통과, TRY AGAIN 다시 도전.
- **Teacher speech** in the move glosses and interrupt options (`"자리에 앉자, 지금 4쪽이야"`, `"계산기는 하나니까 돌아가면서 써. {a}부터."`) uses warm 반말 to students, as Korean homeroom teachers commonly do. The brief doesn't set the teacher-to-student speech level. The glosses also feed the LLM transcript (Encounter.gd:878, Gym :640, Lecture :795).
- **Kid lines** with no persona (win/fallback lines: `아… 이제 알 것 같아요!`, `아! 알겠어요.`, `…아, 그러니까 좀 알겠어요.`, `음… 잠깐만요, 아직 잘 모르겠어요.`, `아… 네, 그런가 봐요.`, `어… 잠깐만요, 거기 잘 못 따라갔어요.`) are generic 존댓말. Any persona-specific override replaces them.
- **Overworld.gd:65 intercom**: changed to a Korean-school announcement (`담임 선생님들, 출석 현황 교무실로 보내 주세요.`).
- **Encounter.gd:216**: `%s(지난 기록 기준).` assumes the adaptive label (GameCoach.gd:77, e.g. `Starting harder`) comes back as a short phrase with no final period.
- **Overworld.gd:1342**: the `REFLECT 1/2` line was rendered as 돌아보기 1/2.
