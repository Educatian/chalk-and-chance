# Copy pass: making the English game sound like people

Branch `Educatian/copy-pass`, from `2f97352`. This pass changes wording only. Meaning, pedagogy, which move is right or wrong, scoring, and every id, key, tag and telemetry name are the same as before.

## How it was done

1. `tools/copy/extract_strings.py` (`python -I tools/copy/extract_strings.py out.tsv`) pulls every player-facing string into one sheet. GDScript literals are located as `file:line` and data strings as `file#json.path`. It skips `scenes/dev`, dev logs, dictionary keys, ids and paths, the LLM-prompt-only persona fields (`hidden_need`, `knowledge_state`, `escalation_triggers`, `deescalation_moves`, `answer_flip_policy`, `behavior_tendencies`, `traits`), and `LLMClient._classify_stub_text`.
2. Each line was marked keep or rewrite, and the rewrites were made in place. No lines were added or removed, so the locations stay stable.
3. Second cold read. After the first pass, "kid" appeared 56 times (it was 5 before). About 20 of those were changed back to "student", "everyone" or "them" so that Vee and the UI don't all sound the same. One label was reverted (Talia's path "Acknowledge, then share the floor").
4. `tools/copy/diff_sheet.py` pairs `tools/copy/strings_before.tsv` with `tools/copy/strings_after.tsv` by location and produces the table below.
5. The lint is `_banned_copy_issues()` in `scenes/dev/ProductContentAudit.gd`. It fails with file and line on any of these: "Great job", "Let's dive", "dive in", "It's important to", "Remember,", "evidence-rich", "competency estimate", an em dash, "Not only", "In conclusion", "unlock your".
   - It scans `data/**/*.json`, skipping `_doc` lines and `judge_rubric.json`.
   - It scans string literals in `scenes/`, `scripts/` and `autoload/`, skipping `scenes/dev`, comments, `print`/`push_*` lines, `_classify_stub_text`, and a literal that is only a dash (the parser separator in `LessonImport`).
   - It reports zero hits on the final text. A planted "Great job â€” dive in!" was caught three times.

**Counts:** 1,830 strings scanned and 544 rewritten. The other 1,286 were kept. Many of those are node names, move-button names, ids or numbers that the scanner can't tell from copy.

## Not rewritten, on purpose

- **The instructor and research report panels** in `scenes/ui/HubReports.gd` and `InstructorAnalyticsText.gd` (Quality Report, TeacherSim Delta, Cloud Log, Instructor Dashboard). They are internal product self-assessment ("Remaining 95-point priorities", "Novelty claim") and not in-fiction text, and the tests pin about 40 of their phrases. Rewording them would only polish a status report. My suggestion is to hide them from learner accounts rather than rewrite them.
- **Move names, skill names and citation chips** (Elicit, Revoice, "Status treatment", "Funds of knowledge", "Withitness", "Rowe 1986"). These are the vocabulary the game teaches. The exception is "Mgmt (least-intrusive)", which became "Low-key redirects".
- **`lecture_focus`, `collective_reasoning`** and the persona prompt fields. These go only to the model and are never shown.
- **"Good job!"** in `Encounter._move_gloss`. It is the deliberately generic praise that the game marks as a miss.

## Unsure (please check)

- **Content fix, not only wording.** `noah_g5_fractions.json#paths[0].why` said "his 4 > 3 theory", which doesn't match his misconception (1/8 > 1/4). It now says "his 8 > 4 rule".
- **Diego's ELL voice** ("I not sure", "Same like fifty hundredths", "they are different, no?"). These are meant to sound like real English-learner grammar. A reviewer who knows the population should confirm it reads as respectful and not as caricature.
- **Marcus `connect_line`** now ends "Whatever, we can do it." It is grudging on purpose because `connect_resolves` is false. Check that it still reads as calmed down.
- **Sam's decimals win line** ends as a question ("So 0.50 is more than 0.45?"). That fits his tentative voice, but it is the win line.
- **ch3 `outro_retry`** now names Talia. That is correct for the stock roster but would be wrong if a custom roster dropped her.
- **Gym praise gloss.** "I name what you did well." became "I like how you explained that step." It is more specific, and the model sees it, so check that the LLM's reaction to menu praise doesn't shift.
- **Terms dropped from labels.** The culturally responsive objective no longer says "funds of knowledge" ("Tie the lesson to 3+ students' own lives"), and the science Deshawn label paraphrases "least-intrusive" as "Quietest redirect that works". The meaning is the same, but the textbook terms are gone from the HUD.
- **Objective labels** now read "60%+" instead of ">= 60%". The numbers are unchanged.
- **Hub renames that players will notice:**
  - Evidence -> Skills
  - EVIDENCE JOURNAL -> SKILL NOTEBOOK
  - Briefing headers EVIDENCE -> SCORED ON and ADAPTIVE START -> DIFFICULTY
  - "Adaptive: scaffold start" -> "Starting with extra help"
  - Trace "Signal:" -> "Why:"
  - Transcript "Decision signal" -> "How it went"

  Run records saved before this change still show the old trace wording ("evidence gained", "fit signal: ...").
- **Lowercase one-word outcomes** ("evidence gained" -> "worked", "missed evidence" -> "missed" in `GameCoach.gd:112`) are filtered out by the scanner, so they are listed here instead of in the table.
- **`TTSClient.gd:98`** "Use a voice passcode to turn it on" assumes players know the voice token as a passcode.

## The tagline

"Practice the moments you can't plan." works. It is concrete, a teacher would say it, and it names the real promise (rehearsing the unplannable parts of a lesson) without the usual "unlock / empower / transform" words. Two cautions:

- "the moments" leans a little toward slogan. "Practice the parts of teaching you can't plan for" is plainer but flatter, so I'd keep the original.
- The login screen currently says "Teach. Listen. Adapt." That is exactly the tidy three-beat slogan this pass removes elsewhere. I'd replace it with the tagline if it fits the layout (it is about 15 characters longer). I left it alone because the brand call isn't mine.

## Known issue found along the way

`SmokeTest` prints `SMOKE TEST: FAIL` (Noah's elicit/extend loop never raises understanding) on the untouched baseline `2f97352` too, so this pass did not cause it. `DIFFERENTIATION: PASS` still holds. It needs a separate look at the encounter grading change in `2f97352`.

## Every changed line

| Location | Before | After |
|---|---|---|
| `scenes/cinematic/MissionCinematic.gd:421` | Replay the chapter when you're ready. Coach Vee will be there. | Run it again when you're ready. Vee will be there. |
| `scenes/encounter/Encounter.gd:48` | Revoice: restate their thinking so it is public and checkable. | Revoice: say their idea back so everyone can check it. |
| `scenes/encounter/Encounter.gd:49` | Tell: explain it directly. Useful sometimes, but it can take over their thinking. | Tell: explain it yourself. Sometimes you have to. Often it does their thinking for them. |
| `scenes/encounter/Encounter.gd:50` | Praise: name a specific useful behavior, not just 'good job'. | Praise: say exactly what they did. 'Good job' doesn't count. |
| `scenes/encounter/Encounter.gd:51` | Connect: notice the student's world, then bridge the content to it. | Connect: find out what they're into, then hook the lesson to it. |
| `scenes/encounter/Encounter.gd:52` | Redirect: bring attention back with the least-intrusive move that works. | Redirect: get them back on task with the smallest move that works. |
| `scenes/encounter/Encounter.gd:53` | Wait: hold silence until the Wait-Time bar turns green, then choose a move. | Wait: stay quiet until the Wait-Time bar goes green. Then pick a move. |
| `scenes/encounter/Encounter.gd:152` | Read the student. Surface reasoning before correcting. After you ask, let the ring on them fill: that is their thinking time. | Look at them first. Find out what they think before you correct it. After you ask, let the ring fill. That's their thinking time. |
| `scenes/encounter/Encounter.gd:216` | %s from saved evidence. Read the student, then choose the fit move. | %s, based on your past rounds. Read them, then pick the move that fits. |
| `scenes/encounter/Encounter.gd:321` | Type teacher talk... | Type what you'd say... |
| `scenes/encounter/Encounter.gd:329` | Read the student. | Watch them first. |
| `scenes/encounter/Encounter.gd:404` | Need: surface the student's reasoning | Need: find out how they're thinking |
| `scenes/encounter/Encounter.gd:515` | Type teacher talk... | Type what you'd say... |
| `scenes/encounter/Encounter.gd:610` | Item unavailable. | You can't use that right now. |
| `scenes/encounter/Encounter.gd:617` | Coach Vee: regulated first. Now choose a smaller, cleaner next move. | Coach Vee: good, you breathed first. Now try something smaller. |
| `scenes/encounter/Encounter.gd:622` | %s needs you to learn their thinking before correcting it. | %s needs you to hear their thinking before you correct it. |
| `scenes/encounter/Encounter.gd:625` | Student Profile Card used  \|  Asset cue revealed  \|  Rapport +%d | Student Profile Card used  \|  New cue  \|  Rapport +%d |
| `scenes/encounter/Encounter.gd:626` | Coach Vee: profile cue: %s | Coach Vee: worth knowing. %s |
| `scenes/encounter/Encounter.gd:633` | Coach Vee: more than one approach works for %s: %s. Pick one and follow it through. | Coach Vee: a few things could work with %s: %s. Pick one and stick with it. |
| `scenes/encounter/Encounter.gd:636` | Wait Meter Pin used  \|  next move gets full wait-time credit | Wait Meter Pin used  \|  next move counts as a full pause |
| `scenes/encounter/Encounter.gd:637` | Coach Vee: next move gets full think-time credit. | Coach Vee: your next move counts as if you waited. |
| `scenes/encounter/Encounter.gd:642` | Coach Vee: lesson path checked. Now choose the learner-fit move. | Coach Vee: map checked. Now, what does this student need? |
| `scenes/encounter/Encounter.gd:645` | Practice Goal set  \|  clear this encounter for bonus XP | Practice Goal set  \|  finish this one for bonus XP |
| `scenes/encounter/Encounter.gd:646` | Coach Vee: focus goal: make one evidence-rich move before resolving the misconception. | Coach Vee: goal. Get them to show their thinking once before you fix the mistake. |
| `scenes/encounter/Encounter.gd:648` | %s cannot be used in this encounter. | %s doesn't work here. |
| `scenes/encounter/Encounter.gd:670` | Type mode: the offline demo classifies common teacher moves locally. | Type it out. Offline, the game guesses which move you meant. |
| `scenes/encounter/Encounter.gd:676` | Listening... speak your teacher talk. | Listening... go ahead. |
| `scenes/encounter/Encounter.gd:678` | Voice input is not available in this browser. | This browser can't use the mic. |
| `scenes/encounter/Encounter.gd:796` | You spoke into their thinking time, so %s dropped the thought. After a question, let the ring fill. | You talked into their thinking time and %s lost the thought. After you ask, let the ring fill. |
| `scenes/encounter/Encounter.gd:972` | You read them right. Your next move that lands counts a little more. | You read them right. If your next move lands, it counts a bit more. |
| `scenes/encounter/Encounter.gd:976` | Look again: their face and posture say %s. Pick the move that answers that. | Look again. Their face and posture say %s. Answer that. |
| `scenes/encounter/Encounter.gd:984` | generic: nothing to name yet | nothing to name yet |
| `scenes/encounter/Encounter.gd:1001` | That was generic praise: there was nothing specific to name yet. Praise right after they show their thinking, and say what they did. | That praise was generic. They hadn't done anything yet to name. Praise right after they show their thinking, and say what they did. |
| `scenes/encounter/Encounter.gd:1024` | generic praise names nothing they did | the praise named nothing they did |
| `scenes/encounter/Encounter.gd:1113` | You pause to learn what %s cares about beyond this task. | You ask %s what they're into outside of class. |
| `scenes/encounter/Encounter.gd:1114` | You take a beat to notice %s, not just the task. | You stop and actually look at %s. |
| `scenes/encounter/Encounter.gd:1115` | Coach Vee (notice): %s  Press Connect again to bridge the content to it. | Coach Vee: %s  Press Connect again to tie the lesson to it. |
| `scenes/encounter/Encounter.gd:1149` | Coach Vee: you connected it to %s's world (funds of knowledge). Keep going, they are with you. | Coach Vee: you hooked it to something %s cares about. They're with you now. Keep going. |
| `scenes/encounter/Encounter.gd:1151` | Coach Vee: connecting built real trust (bond up). For %s the academic unlock is still the right move, but now they will let you lead. | Coach Vee: that built some trust. %s still needs the lesson move, but now they'll let you lead. |
| `scenes/encounter/Encounter.gd:1224` | Coach Vee: you reached %s through their own world, not by telling. Funds of knowledge in action. Badge: %s. | Coach Vee: you got to %s through something they already know. You never had to tell them. Badge: %s. |
| `scenes/encounter/Encounter.gd:1229` | Coach Vee: warmth AND high expectations. You held the bar and they trusted you to. Warm demander. Badge: %s. | Coach Vee: you were kind and you didn't lower the bar. They trusted you to hold it. Badge: %s. |
| `scenes/encounter/Encounter.gd:1231` | Coach Vee: they reasoned to it themselves, you did not tell them. Solid. (Build the relationship too; connection makes the next period easier.) Badge: %s. | Coach Vee: they got there on their own. Solid. Get to know them a bit next time, it makes tomorrow easier. Badge: %s. |
| `scenes/encounter/Encounter.gd:1259` | Session complete with %s  ·  score %d | Done with %s  ·  score %d |
| `scenes/encounter/Encounter.gd:1265` | %s badge already earned on an earlier clear. | You already have the %s badge. |
| `scenes/encounter/Encounter.gd:1280` | Read the Need line and choose the move it points to: fewer detours, fewer turns. | Read the Need line and pick the move it points to. You'll get there in fewer turns. |
| `scenes/encounter/Encounter.gd:1281` | Connect to something from their world, and keep the bar high with warmth. | Hook it to something they care about. Stay warm and keep the bar high. |
| `scenes/encounter/Encounter.gd:1299` | trust grew from connecting and warm pressing | they trust you more now |
| `scenes/encounter/Encounter.gd:1299` | little warmth or connection yet | not much connection yet |
| `scenes/encounter/Encounter.gd:1334` | it met them where they were | it fit where they were |
| `scenes/encounter/Encounter.gd:1340` | it did not answer what they needed | it wasn't what they needed |
| `scenes/encounter/Encounter.gd:1370` | Coach Vee: Composure bottomed out. Take a breath. This is data, not failure. Re-attempt the segment. | Coach Vee: you're running on empty. Breathe. It happens to everyone. Try that part again. |
| `scenes/encounter/Encounter.gd:1389` | Too soon: hold the pause longer | Too soon. Hold the pause longer |
| `scenes/encounter/Encounter.gd:1392` | This addressed %s's need | That's what %s needed |
| `scenes/encounter/Encounter.gd:1400` | classified as %s | read as %s |
| `scenes/encounter/Encounter.gd:1512` | Okay, and what happens if you push that idea further? | Okay. And what if you take that one step further? |
| `scenes/encounter/Encounter.gd:1514` | Here's how it actually works: let me show you. | Here, let me just show you how it works. |
| `scenes/encounter/Encounter.gd:1515` | You just walked me through how you got that. That is the thinking I want to see. | You walked me through how you got that. That's what I want to see. |
| `scenes/encounter/Encounter.gd:1516` | Let's bring our focus back to the problem. | Hey, eyes back on the problem. |
| `scenes/encounter/Encounter.gd:1517` | (waits quietly, giving you time to think) | (waits quietly) |
| `scenes/encounter/Encounter.gd:1518` | Tell me about something you're really good at outside class. | What are you really good at outside of school? |
| `scenes/encounter/GroupCheckIn.gd:64` | You crouch by the table. The group is mid-task. Sample them: observe first, then surface their thinking. | You crouch by the table. They're mid-task. Watch first, then ask how they're thinking. |
| `scenes/encounter/GroupCheckIn.gd:65` | Coach Vee: button order: Observe/Probe to reveal, Press after the error is visible, Redistribute when one voice dominates. | Coach Vee: Observe or Probe to see their thinking. Press once the mistake is out. Redistribute if one kid won't stop talking. |
| `scenes/encounter/GroupCheckIn.gd:196` | Next: press Observe or Probe before Press. | Next: Observe or Probe before you Press. |
| `scenes/encounter/GroupCheckIn.gd:198` | Next: press Redistribute if participation is low, otherwise Press again. | Next: Redistribute if one kid is doing the talking. If not, Press again. |
| `scenes/encounter/GroupCheckIn.gd:200` | Next: press Redistribute to balance airtime. | Next: Redistribute so someone else talks. |
| `scenes/encounter/GroupCheckIn.gd:202` | Next: press Press to work the shared error. | Next: Press on the mistake they share. |
| `scenes/encounter/GroupCheckIn.gd:210` | This pod is on track - they reasoned past their shared error AND everyone is in it. | This table's got it. They talked their way past the mistake, and everyone joined in. |
| `scenes/encounter/GroupCheckIn.gd:211` | Coach Vee: you surfaced their thinking, pressed the crack, and rebalanced the talk. That is monitoring done right. | Coach Vee: you got their thinking out and pushed on the weak spot. Then you let the quiet ones talk. That's the job. |
| `scenes/encounter/GroupCheckIn.gd:263` | Status: %s  (concept: %s)  \|  Next: press Press or Redistribute | Status: %s  (%s)  \|  Next: Press or Redistribute |
| `scenes/encounter/GroupCheckIn.gd:263` | Status: hidden  \|  Next: press Observe or Probe | Status: can't tell yet  \|  Next: Observe or Probe |
| `scenes/encounter/GroupCheckInUi.gd:30` | Status: hidden (observe or probe to surface it) | Status: can't tell yet. Observe or Probe to find out. |
| `scenes/encounter/GroupCheckInUi.gd:35` | Participation balance | Who's talking |
| `scenes/encounter/GroupDebriefPanel.gd:25` | Focus: sample reasoning, press the shared error, rebalance airtime. | Focus: listen first. Press on the shared mistake. Get the quiet kids talking. |
| `scenes/encounter/GymEncounter.gd:134` | Oh, I get it now! | Oh! Okay, I get it. |
| `scenes/encounter/GymEncounter.gd:241` | Button guide: select the highest-need student, then match their Need line; avoid Tell unless stuck. | Pick the student who needs you most, then use the move on their Need line. Tell only if stuck. |
| `scenes/encounter/GymEncounter.gd:244` | Coach Vee: Need shows the likely button. Use Profile/Noticing items when the right move is unclear. | Coach Vee: the Need line tells you which button. Not sure? Use a Profile or Noticing item. |
| `scenes/encounter/GymEncounter.gd:272` | Type what you would say to the selected student. | Type what you'd say to this student. |
| `scenes/encounter/GymEncounter.gd:348` | Item unavailable. | You can't use that right now. |
| `scenes/encounter/GymEncounter.gd:355` | Coach Vee: you regulated while managing the room. Now pick the highest-need student. | Coach Vee: good, you breathed. Now, who needs you most? |
| `scenes/encounter/GymEncounter.gd:362` | Coach Vee: a known signal lowered noise without shaming any student. | Coach Vee: they know that signal. Quieter, and nobody got called out. |
| `scenes/encounter/GymEncounter.gd:368` | Student Profile Card  \|  %s need revealed%s | Student Profile Card  \|  you know what %s needs%s |
| `scenes/encounter/GymEncounter.gd:372` | Coach Vee: %s's need is %s. Ways in: %s. | Coach Vee: %s needs %s. Ways in: %s. |
| `scenes/encounter/GymEncounter.gd:375` | Noticing Lens  \|  inspect target cue | Noticing Lens  \|  look closer at them |
| `scenes/encounter/GymEncounter.gd:376` | Coach Vee: %s is at %d%% understanding and %d%% restless. Choose a move that fits that state. | Coach Vee: %s is about %d%% there and %d%% restless. Pick a move for that. |
| `scenes/encounter/GymEncounter.gd:390` | Equity Snapshot  \|  highlighted the most at-risk unresolved student%s | Equity Snapshot  \|  marked who you haven't reached%s |
| `scenes/encounter/GymEncounter.gd:391` | Coach Vee: this is participation monitoring. Use it before the room drifts. | Coach Vee: check who you've missed before the room drifts. |
| `scenes/encounter/GymEncounter.gd:394` | Wait Meter Pin  \|  next move gets full wait-time credit | Wait Meter Pin  \|  next move counts as a full pause |
| `scenes/encounter/GymEncounter.gd:395` | Coach Vee: use the guaranteed pause before pressing a learner under load. | Coach Vee: use that pause before you push someone who's struggling. |
| `scenes/encounter/GymEncounter.gd:400` | Lesson Map  \|  room drift reduced | Lesson Map  \|  the room settles a bit |
| `scenes/encounter/GymEncounter.gd:401` | Coach Vee: you re-centered the task structure. Now target one learner deliberately. | Coach Vee: the task's clear again. Now pick one student and go to them. |
| `scenes/encounter/GymEncounter.gd:404` | Practice Goal set  \|  clear the capstone for bonus XP | Practice Goal set  \|  finish the capstone for bonus XP |
| `scenes/encounter/GymEncounter.gd:405` | Coach Vee: goal focus: reach every student without overusing Tell. | Coach Vee: goal. Reach everyone, and go easy on Tell. |
| `scenes/encounter/GymEncounter.gd:458` | Select a student, then choose a move. | Pick a student, then a move. |
| `scenes/encounter/GymEncounter.gd:458` | Button guide: select the highest-need student, then match their Need line; avoid Tell unless stuck. | Pick the student who needs you most, then use the move on their Need line. Tell only if stuck. |
| `scenes/encounter/GymEncounter.gd:460` | Coach Vee: Need shows the likely button. Use Profile/Noticing items when the right move is unclear. | Coach Vee: the Need line tells you which button. Not sure? Use a Profile or Noticing item. |
| `scenes/encounter/GymEncounter.gd:489` | Current target: %s. Need: %s. | With %s. Need: %s. |
| `scenes/encounter/GymEncounter.gd:489` | Current target: %s. Read the cues. | With %s. Watch them first. |
| `scenes/encounter/GymEncounter.gd:504` | Type mode: write teacher talk to the selected student. | Type what you'd say to this student. |
| `scenes/encounter/GymEncounter.gd:513` | Listening... speak your teacher talk. | Listening... go ahead. |
| `scenes/encounter/GymEncounter.gd:515` | Voice input is not available in this browser. | This browser can't use the mic. |
| `scenes/encounter/GymEncounter.gd:557` | %s is already resolved. Pick another student. | %s is already with you. Pick someone else. |
| `scenes/encounter/GymEncounter.gd:558` | Coach Vee: %s is already with you. Turn to someone who needs you. | Coach Vee: %s is fine. Who else needs you? |
| `scenes/encounter/GymEncounter.gd:585` | Coach Vee: that fits %s. Keep following it through. | Coach Vee: that works for %s. Stay with it. |
| `scenes/encounter/GymEncounter.gd:588` | %s: \"Hm... I'm not there yet.\" | %s: \"Hm... wait, I don't get it yet.\" |
| `scenes/encounter/GymEncounter.gd:595` | Composure -4  \|  telling did not build %s's reasoning | Composure -4  \|  you told %s instead of asking |
| `scenes/encounter/GymEncounter.gd:596` | Coach Vee: telling took over %s's thinking. | Coach Vee: you did the thinking for %s. |
| `scenes/encounter/GymEncounter.gd:601` | Coach Vee: that is not the move %s needs (try: %s). | Coach Vee: not what %s needs. Try %s. |
| `scenes/encounter/GymEncounter.gd:772` | What happens if you push that idea one step further? | What if you take that one step further? |
| `scenes/encounter/GymEncounter.gd:776` | Let me show you the answer directly. | Here, let me just show you. |
| `scenes/encounter/GymEncounter.gd:778` | I name what you did well. | I like how you explained that step. |
| `scenes/encounter/GymEncounter.gd:780` | Let's bring our focus back to the task. | Okay, eyes back on the task. |
| `scenes/encounter/GymEncounter.gd:843` | Coach Vee: you held the whole room and reached every student. Capstone cleared! | Coach Vee: you kept the whole room and got to every kid. That's the capstone. |
| `scenes/encounter/GymEncounter.gd:846` | Coach Vee: the room got away from you (%d/%d reached). Circulate faster next time. | Coach Vee: the room got away from you. %d of %d reached. Move around faster. |
| `scenes/encounter/LectureScene.gd:130` | Guide: Present -> Wait -> Question/Check. Repair when comprehension lags. | Present, wait, then Question or Check. Repair if they fall behind. |
| `scenes/encounter/LectureScene.gd:299` | Guide: Present -> Wait -> Question/Check. Repair when comprehension lags. | Present, wait, then Question or Check. Repair if they fall behind. |
| `scenes/encounter/LectureScene.gd:303` | Coach Vee: Repair when progress outruns comprehension; otherwise Check. | Coach Vee: if you're ahead of them, Repair. If not, Check. |
| `scenes/encounter/LectureScene.gd:329` | Type what you would say to the class. | Type what you'd say to the class. |
| `scenes/encounter/LectureScene.gd:404` | Item unavailable. | You can't use that right now. |
| `scenes/encounter/LectureScene.gd:411` | Coach Vee: you reset before continuing. Now choose a smaller, more diagnostic next move. | Coach Vee: good reset. Next, something small that shows you what they know. |
| `scenes/encounter/LectureScene.gd:416` | Coach Vee: a practiced attention signal restores the room without escalating. | Coach Vee: they know that signal. Room's back, and nobody had to get loud. |
| `scenes/encounter/LectureScene.gd:420` | Noticing Lens  \|  check the highlighted learner | Noticing Lens  \|  check the highlighted student |
| `scenes/encounter/LectureScene.gd:421` | Coach Vee: look at %s. If progress is ahead of comprehension, repair before asking harder questions. | Coach Vee: look at %s. If you've gotten ahead of them, re-explain before you ask anything harder. |
| `scenes/encounter/LectureScene.gd:429` | Equity Snapshot  \|  highlighted a student who has not spoken%s | Equity Snapshot  \|  marked someone who hasn't talked yet%s |
| `scenes/encounter/LectureScene.gd:430` | Coach Vee: equitable participation is a design move, not just a fairness slogan. Ask the highlighted student next. | Coach Vee: they haven't said a word yet. Ask them next. |
| `scenes/encounter/LectureScene.gd:433` | Wait Meter Pin  \|  next move gets full wait-time credit | Wait Meter Pin  \|  next move counts as a full pause |
| `scenes/encounter/LectureScene.gd:434` | Coach Vee: use this pause before asking so more students can enter the question. | Coach Vee: pause before you ask. More of them get a chance to think. |
| `scenes/encounter/LectureScene.gd:439` | Coach Vee: you realigned the chunk with the objective. Now check before advancing. | Coach Vee: back on the goal. Check before you go on. |
| `scenes/encounter/LectureScene.gd:442` | Practice Goal set  \|  clear this lecture for bonus XP | Practice Goal set  \|  finish this lecture for bonus XP |
| `scenes/encounter/LectureScene.gd:443` | Coach Vee: goal focus: check understanding before presenting two more chunks. | Coach Vee: goal. Check in before you present two more chunks. |
| `scenes/encounter/LectureScene.gd:547` | Type mode: write your teacher talk; the game maps it to a lecture move. | Type what you'd say. The game picks the closest lecture move. |
| `scenes/encounter/LectureScene.gd:556` | Listening... speak your teacher talk. | Listening... go ahead. |
| `scenes/encounter/LectureScene.gd:558` | Voice input is not available in this browser. | This browser can't use the mic. |
| `scenes/encounter/LectureScene.gd:617` | Coach Vee: that's a lot of talking. They're tuning out, ask a question. | Coach Vee: that's a lot of talking. They're drifting. Ask something. |
| `scenes/encounter/LectureScene.gd:620` | Coach Vee: good chunk. Check in before moving on. | Coach Vee: good chunk. Now check in. |
| `scenes/encounter/LectureScene.gd:625` | No student selected to call on. | Nobody's highlighted to call on. |
| `scenes/encounter/LectureScene.gd:626` | Coach Vee: there's no one highlighted, run a whole-class Check instead. | Coach Vee: nobody's highlighted. Do a whole-class Check. |
| `scenes/encounter/LectureScene.gd:651` | %s answers, and it shows they're with you. | %s answers. They're with you. |
| `scenes/encounter/LectureScene.gd:652` |  (good wait time) |  (and you waited) |
| `scenes/encounter/LectureScene.gd:657` | Wait-Time ready: ask a question after the pause. | Pause done. Ask your question. |
| `scenes/encounter/LectureScene.gd:658` | Coach Vee: wait time lets more of them think. Now pose a question. | Coach Vee: more of them are thinking now. Ask. |
| `scenes/encounter/LectureScene.gd:666` | Comprehension %s  \|  responsive repair | Comprehension %s  \|  you caught it |
| `scenes/encounter/LectureScene.gd:667` | Coach Vee: closing the gap. That's responsive teaching. | Coach Vee: you saw they were lost and fixed it. |
| `scenes/encounter/LectureScene.gd:675` | Whole-class check  \|  Comprehension %s  \|  everyone accountable | Whole-class check  \|  Comprehension %s  \|  everyone answers |
| `scenes/encounter/LectureScene.gd:676` | Coach Vee: a whole-class check holds everyone accountable at once. | Coach Vee: everybody answered. Now you know where the room is. |
| `scenes/encounter/LectureScene.gd:965` | Coach Vee: you delivered the lesson AND kept them with you. Comprehension %d%%. Well paced! | Coach Vee: you got through it and kept them with you. Comprehension %d%%. Good pacing. |
| `scenes/encounter/LectureScene.gd:974` | Coach Vee: the lesson ended but comprehension was low (%d%%). Check understanding as you go. | Coach Vee: you finished, but comprehension was only %d%%. Check in as you go. |
| `scenes/encounter/ReactionCue.gd:58` | Read the table: hidden group state | Read the table first. Can't tell yet |
| `scenes/encounter/ReactionCue.gd:60` | Airtime imbalance: invite a quieter voice | One voice is taking over. Ask a quiet kid |
| `scenes/encounter/ReactionCue.gd:62` | Shared misconception: press for reasoning | They share a mistake. Press on it |
| `scenes/encounter/ReactionCue.gd:63` | Group momentum: ready to consolidate | They're rolling. Time to wrap it up |
| `scenes/overworld/Overworld.gd:65` | The intercom crackles: \"Please send attendance to the office.\" | The intercom crackles. \"Attendance to the office, please.\" |
| `scenes/overworld/Overworld.gd:67` | Give the class a 30s task, then handle it | Give them a 30-second task, then do it |
| `scenes/overworld/Overworld.gd:68` | Good. A holding task keeps momentum while you deal with the interruption. | Good. They had something to do while you dealt with it. |
| `scenes/overworld/Overworld.gd:74` | A knock at the door: another teacher needs a quick word. | Knock at the door. Another teacher needs a quick word. |
| `scenes/overworld/Overworld.gd:76` | Set a task, step to the door, stay facing in | Set a task, go to the door, keep facing in |
| `scenes/overworld/Overworld.gd:77` | Withitness preserved. You stayed aware of the room while at the door. | You could still see the whole room from the door. That's the move. |
| `scenes/overworld/Overworld.gd:78` | Step fully into the hall | Step out into the hall |
| `scenes/overworld/Overworld.gd:79` | Out of sight, out of control. Off-task spiked while your back was turned. | The second you left, they were off. Stay where you can see them. |
| `scenes/overworld/Overworld.gd:86` | Nonverbal nod to an open seat, keep going | Nod at an open seat, keep going |
| `scenes/overworld/Overworld.gd:87` | Least-intrusive. You kept the lesson's momentum. | Just a nod. The lesson never stopped. |
| `scenes/overworld/Overworld.gd:89` | Walking over pulled you away from the board; a nod from where you stand was enough here. | You left the board for that. A nod from where you stood would have done it. |
| `scenes/overworld/Overworld.gd:93` | Public call-out cost momentum and rapport. Handle it privately later. | Doing that in front of everyone cost you, and them. Talk to them after class. |
| `scenes/overworld/Overworld.gd:97` | Two students start a loud side-conversation. | Two students start a loud side conversation. |
| `scenes/overworld/Overworld.gd:101` | Move toward them (proximity), keep talking | Walk toward them, keep talking |
| `scenes/overworld/Overworld.gd:102` | Proximity control. Quietest effective move. | You walked over and they stopped. Can't get quieter than that. |
| `scenes/overworld/Overworld.gd:104` | The look works, but walking over would have cost nothing at all. | The look worked. Walking over would have cost you nothing, though. |
| `scenes/overworld/Overworld.gd:106` | It worked, and it used words where moving closer would have been enough. | It worked. You didn't need words, though. Walking closer would have done it. |
| `scenes/overworld/Overworld.gd:108` | Shouting across the room escalates and pulls everyone off task. | Yelling across the room just pulled everybody else off task too. |
| `scenes/overworld/Overworld.gd:117` | Proximity alone did not stop an argument already under way; a brief word was the smallest step that works here. | Standing close won't stop a fight that's already going. They needed a quick word. |
| `scenes/overworld/Overworld.gd:119` | A look does not settle a dispute over a tool; tell them how to share it, briefly. | A look won't settle who gets the calculator. Tell them how to share it, quick. |
| `scenes/overworld/Overworld.gd:121` | Right-sized: the smallest step that actually solves this one. | That's it. Smallest thing that actually fixed it. |
| `scenes/overworld/Overworld.gd:123` | It stopped the argument and the lesson. A brief private word would have done it. | Stopped the argument. Stopped the lesson too. A quick quiet word would have done it. |
| `scenes/overworld/Overworld.gd:1049` | Room cue: read the room. Postures show who is drifting. | Watch how they're sitting. That tells you who's drifting. |
| `scenes/overworld/Overworld.gd:1051` | Hot spot: %s is at %d%% drift. Move close now. | %s is drifting (%d%%). Get over there now. |
| `scenes/overworld/Overworld.gd:1053` | Room cue: %s is starting to drift (%d%%). | %s is starting to drift (%d%%). |
| `scenes/overworld/Overworld.gd:1055` | Room cue: settled. Green bars = focused; red = drifting. | Room's settled. Green bar is focused, red is drifting. |
| `scenes/overworld/Overworld.gd:1084` | Coach Vee: eyes on the room. Turning your back lets them drift. | Coach Vee: turn around. They drift when your back is to them. |
| `scenes/overworld/Overworld.gd:1086` | Coach Vee: someone is drifting. Scan, then move closer. | Coach Vee: someone's drifting. Look around, then walk over. |
| `scenes/overworld/Overworld.gd:1088` | Coach Vee: %s is drifting. Move closer (proximity) or scan the room. | Coach Vee: %s is drifting. Go stand near them. |
| `scenes/overworld/Overworld.gd:1090` | Coach Vee: a little restlessness building. Keep circulating. | Coach Vee: getting a bit restless in here. Keep moving. |
| `scenes/overworld/Overworld.gd:1092` | Coach Vee: room is settled. Circulate and scan as you teach. | Coach Vee: they're with you. Keep walking the room. |
| `scenes/overworld/Overworld.gd:1317` | +%d XP retry focus met | +%d XP, retry goal met |
| `scenes/overworld/Overworld.gd:1342` | REFLECT 1/2\n\nBefore the score: what stays with you from this period? Naming it is where the practice sticks. | REFLECT 1/2\n\nBefore you see the score. What's sticking with you from that period? |
| `scenes/overworld/Overworld.gd:1405` | Choose another mission | Pick another mission |
| `scenes/overworld/Overworld.gd:1413` | Circulate: stand near drifting students and face the room while you talk. | Keep walking. Stand near whoever's drifting, and face the room when you talk. |
| `scenes/overworld/Overworld.gd:1414` | Handle interruptions with the smallest move that works (a look, moving closer) before stopping the class. | Try the small stuff first, a look or walking closer, before you stop the class. |
| `scenes/overworld/Overworld.gd:1415` | Keep corrections small and private; public escalations cost you composure. | Correct quietly, one on one. Public blowups wear you down. |
| `scenes/overworld/Overworld.gd:1416` | Get every student to explain their thinking (Elicit or Revoice), not only the ones who call out. | Get everyone explaining, including the ones who never call out. Try Elicit or Revoice. |
| `scenes/overworld/Overworld.gd:1418` | Notice a student's interest first, then bridge it to the lesson (Connect twice). | Find something a student cares about and tie it to the lesson. Use Connect twice. |
| `scenes/overworld/Overworld.gd:1434` | you kept facing and circulating the room | you kept moving and kept facing them |
| `scenes/overworld/Overworld.gd:1436` | you heard the thinking of %d of %d students | you heard %d of %d students explain their thinking |
| `scenes/overworld/Overworld.gd:1444` |   ·  replay #%d (the room drifts faster each attempt) |   ·  replay #%d (they drift faster each time) |
| `scenes/overworld/Overworld.gd:1445` | Stretch: reach every student and keep attention above 90%. | Want more? Hear from every student and keep attention over 90%. |
| `scenes/overworld/Overworld.gd:1447` | Try again with this objective in mind. | Go again with this one in mind. |
| `scenes/overworld/Overworld.gd:1447` | It leads your next try (+%d XP). | It goes first on your list next time (+%d XP). |
| `scenes/overworld/Overworld.gd:1454` | First clear reward | First clear |
| `scenes/overworld/Overworld.gd:1457` | %s badge already earned on an earlier clear. | You already have the %s badge. |
| `scenes/overworld/Overworld.gd:1458` | No badge in this mission. | This mission has no badge. |
| `scenes/overworld/Overworld.gd:1475` | No conferences  ->  no student's thinking was heard  ->  ask at least one student to explain. | No conferences  ->  you never heard anyone's thinking  ->  get at least one to explain. |
| `scenes/overworld/Overworld.gd:1477` | Move %d  %s  ->  it landed on what the student needed  ->  their understanding moved. | Move %d  %s  ->  it was what they needed  ->  they got further. |
| `scenes/overworld/Overworld.gd:1479` | it came before three seconds of think time | you didn't give them three seconds first |
| `scenes/overworld/Overworld.gd:1479` | it did not answer what they needed yet | it wasn't what they needed yet |
| `scenes/overworld/Overworld.gd:1481` | Move %d  %s  ->  it did not land  ->  %s. | Move %d  %s  ->  didn't land  ->  %s. |
| `scenes/overworld/Overworld.gd:1483` | %ds facing the board  ->  drift rose about twice as fast  ->  scan the room as you write. | %ds facing the board  ->  they drifted twice as fast  ->  look back as you write. |
| `scenes/overworld/Overworld.gd:1485` | %d flare-up%s  ->  a drifting student boiled over  ->  get there before the bar turns red. | %d flare-up%s  ->  someone who'd drifted blew up  ->  get there before the bar goes red. |
| `scenes/overworld/Overworld.gd:1495` | Whose thinking I did not hear | Whose thinking I didn't hear |
| `scenes/overworld/Overworld.gd:1499` | Where I rushed wait time | Where I didn't wait long enough |
| `scenes/overworld/Overworld.gd:1501` | An asset I could connect to | A kid's interest I could have used |
| `scenes/overworld/Overworld.gd:1503` | A disruption I would handle smaller | A disruption I'd handle smaller |
| `scenes/overworld/Overworld.gd:1505` | A moment I would reframe | A moment I'd see differently now |
| `scenes/overworld/Overworld.gd:1509` | An asset I connected to | A kid's interest I used |
| `scenes/overworld/Overworld.gd:1510` | One stretch goal next time | Something to push for next time |
| `scenes/overworld/Overworld.gd:1513` | One moment to replay | A moment I'd replay |
| `scenes/overworld/Overworld.gd:1758` | Leave to the mission hub | Back to the mission hub |
| `scenes/overworld/Overworld.gd:1829` | The pod is working on %s, but their reasoning has not been surfaced yet. | This pod is working on %s. Nobody has asked how they're thinking yet. |
| `scenes/ui/CoachCard.gd:123` | No moves were recorded this round. Next time, try one move that asks for a student's thinking. | You didn't make any moves this round. Next time, try one that asks a student how they're thinking. |
| `scenes/ui/CoachCard.gd:160` | Repeat what worked, on purpose. | Do what worked again, on purpose. |
| `scenes/ui/CoachCard.gd:167` | Rehearse with this focus | Try again with this focus |
| `scenes/ui/Hub.gd:45` | Teacher level. Next +1 upgrade point in %d XP. | Your level. %d more XP to the next upgrade point. |
| `scenes/ui/Hub.gd:108` | Evidence | Skills |
| `scenes/ui/Hub.gd:108` | Your evidence journal: skill estimates from the moves you used. | How each skill is going, from the moves you've made. |
| `scenes/ui/Hub.gd:109` | Spend upgrade points earned from level-ups. | Spend the points you get when you level up. |
| `scenes/ui/Hub.gd:111` | Equip classroom items. | Pick what to bring to class. |
| `scenes/ui/Hub.gd:112` | Run history and reports. | Past runs and reports. |
| `scenes/ui/Hub.gd:348` | EVIDENCE | SCORED ON |
| `scenes/ui/Hub.gd:349` | ADAPTIVE START | DIFFICULTY |
| `scenes/ui/Hub.gd:405` | Resolve every learner while class order stays intact. | Reach every student without losing the room. |
| `scenes/ui/Hub.gd:416` | Present briefly, wait, then Question a highlighted learner before moving on. | Present a short chunk. Pause. Then Question a highlighted student before going on. |
| `scenes/ui/Hub.gd:418` | Visit one pod, surface shared reasoning, then redistribute airtime. | Sit with one table and hear what they think. Then get a quiet kid talking. |
| `scenes/ui/Hub.gd:420` | Circulate first, use proximity, then confer with a drifting learner. | Get up and walk. Stand near whoever's drifting, then talk to them quietly. |
| `scenes/ui/Hub.gd:421` | Elicit reasoning, use wait-time, then press or revoice without taking over. | Ask how they got it. Wait. Then push, or say it back, but don't take over. |
| `scenes/ui/Hub.gd:441` | %s \| saved evidence %d \| mastery signal %d%% \| opening pressure tuned. | %s, from %d past moves. You're at %d%%. |
| `scenes/ui/Hub.gd:584` | Focus: resolve every learner while class order stays intact. | Focus: reach everyone without losing the room. |
| `scenes/ui/Hub.gd:593` | Reward: practice data and competency evidence | Reward: practice (no badge here) |
| `scenes/ui/Hub.gd:609` | Level up by clearing missions. Each level-up grants one upgrade point for steadier presence, better wait-time, or stronger relationship sense. | Level up by clearing missions. Each level gives you one point to put into presence, wait time, or how well you read a room. |
| `scenes/ui/Hub.gd:610` | Play the NEXT mission, earn XP, then come back to spend the point. | Play the next mission to earn XP, then come back and spend the point. |
| `scenes/ui/Hub.gd:618` | Clear the earlier mission that practices %s, then this classroom becomes available. | Clear the earlier mission first (the one where you %s). |
| `scenes/ui/Hub.gd:703` | Click Voice status if spoken lines are silent. | No voices? Click Voice status. |
| `scenes/ui/Hub.gd:874` | EVIDENCE JOURNAL | SKILL NOTEBOOK |
| `scenes/ui/Hub.gd:882` | Live ECD model: each turn updates a competency estimate, evidence count, and uncertainty. | Every move you make nudges these bars. More moves, steadier numbers. |
| `scenes/ui/Hub.gd:905` | session evidence model | from your play |
| `scenes/ui/Hub.gd:910` | RECENT RUN EVIDENCE — %d saved run%s; open Board for details. | RECENT RUNS: %d saved run%s. Open Board for more. |
| `scenes/ui/Hub.gd:928` | Save this session's teacher moves and simulated learner responses as Markdown. | Save what you said and what the students said back, as Markdown. |
| `scenes/ui/Hub.gd:930` | Complete at least one dialogue turn first. | Talk to a student first. Nothing to save yet. |
| `scenes/ui/Hub.gd:988` | %3d%%  ev %02d  unc %.2f | %3d%%  %02d moves  +-%.2f |
| `scenes/ui/Hub.gd:1044` | Formative evidence | Formative checks |
| `scenes/ui/Hub.gd:1047` | Evidence model | From your play |
| `scenes/ui/Hub.gd:1052` | No posted run yet. Clear a lesson to turn moves into evidence. | No runs yet. Finish a lesson and it shows up here. |
| `scenes/ui/Hub.gd:1478` | Base starts empty. Items are earned from mission rewards. | Nothing here yet. You earn items by clearing missions. |
| `scenes/ui/Hub.gd:1573` | surface reasoning | get kids explaining |
| `scenes/ui/Hub.gd:1575` | share airtime | share the talking |
| `scenes/ui/HubTraceText.gd:22` | Turn %d \| Move %s \| Evidence %s \| %s | Turn %d \| Move %s \| Skill %s \| %s |
| `scenes/ui/HubTraceText.gd:30` | Signal:  | Why:  |
| `scenes/ui/HubTraceText.gd:42` | No saved trace detail for this older run. | This run is too old to have turn-by-turn notes. |
| `scenes/ui/ImportLesson.gd:42` | Paste your plan (or load a .txt/.md). Activity format sets seating; duration sets the period.\nObjectives become goals, and 'AI' rewrites student dialogue to match your content. | Paste a plan or load a .txt/.md. The format picks the seating, the duration sets the period.\nObjectives become goals. With AI, the students talk about your content. |
| `scenes/ui/ImportLesson.gd:132` | Contacting AI backend... | Asking the AI... |
| `scenes/ui/ImportLesson.gd:141` | Backend unreachable; using offline conversion. | Couldn't reach the AI. Building it offline. |
| `scenes/ui/ImportLesson.gd:148` | AI scenario ready. | Done. Your lesson is ready. |
| `scenes/ui/ImportLesson.gd:151` | Backend unavailable; used offline conversion. | Couldn't reach the AI, so it was built offline. |
| `scenes/ui/Login.gd:108` | Demo path: choose a mission, rehearse teacher moves, then review evidence. | Pick a mission, teach the class, then see how it went. |
| `scenes/ui/Login.gd:110` | %s course access: enter your name and the course passcode to save progress and evidence. | %s: enter your name and the course passcode so your progress saves. |
| `scenes/ui/Login.gd:125` | Class sign in keeps progress tied to a course account. | Sign in with your class so your progress follows you. |
| `scenes/ui/Login.gd:127` | The %s class code is already loaded. Students only need their own name and the course passcode. | The %s class code is already filled in. Just add your name and the course passcode. |
| `scenes/ui/Login.gd:150` | Join %s / Continue | Sign in to %s |
| `scenes/ui/Login.gd:179` | Offline mode is ready. | Playing offline. |
| `scenes/ui/Login.gd:181` | %s ready. Enter your name + course passcode. | %s is ready. Enter your name and the course passcode. |
| `scenes/ui/Login.gd:183` | Public demo ready. Voice is off to prevent ElevenLabs overuse. | Public demo. Voice is off here to keep costs down. |
| `scenes/ui/Login.gd:278` | Enter class code, name, and password. | Enter your class code, name, and passcode. |
| `scenes/ui/PreviewScenario.gd:140` | AI (content-specific) | AI (fits your content) |
| `scenes/ui/PreviewScenario.gd:140` | offline (format + objectives) | offline (from format and objectives) |
| `scenes/ui/PreviewScenario.gd:143` | %s\n\nYour class: %d students (%s)\nYour challenge: keep the room with you while every learner contributes.\nWin condition: meet the objective checklist before the period ends.\nFirst recommended move: %s\n%s\n%s\n\nFormat: %s     Seating: %s     Period: %ds     Badge: %s\nConversion: %s\n\nObjectives:\n%s | %s\n\nYour class: %d students (%s)\nThe job: keep the room with you and hear from everyone.\nTo win: check off every objective before the period ends.\nTry first: %s\n%s\n%s\n\nFormat: %s     Seating: %s     Period: %ds     Badge: %s\nBuilt: %s\n\nObjectives:\n%s |
| `scenes/ui/PreviewScenario.gd:153` | Scenario check passed. | Looks good. Ready to play. |
| `scenes/ui/PreviewScenario.gd:175` | Circulate first, then confer with a student who is drifting. | Walk the room first, then confer with whoever's drifting. |
| `scenes/ui/PreviewScenario.gd:176` | Talk to one student, Elicit their reasoning, then use Wait before pressing further. | Talk to one student, Elicit their thinking, then Wait before you push. |
| `scripts/CoachFeedback.gd:11` | You asked for their reasoning instead of supplying it. Now their thinking is visible, and you can teach to it. | You asked instead of telling. Now you can see their thinking and teach to it. |
| `scripts/CoachFeedback.gd:24` | The praise was about the person, not about what they did, so it doesn't tell them anything. | That praise was about them, not what they did. It doesn't tell them anything. |
| `scripts/CoachFeedback.gd:25` | \"You checked your answer against the picture. That's what careful mathematicians do.\" | \"You checked your answer against the picture. That's exactly what I want to see.\" |
| `scripts/CoachFeedback.gd:26` | You tied the lesson to something they already know from their own life. That's a strength to build on. | You tied the lesson to something from their own life. Now you have something to build on. |
| `scripts/CoachFeedback.gd:29` | You redirected the behavior quietly and in proportion, and the lesson kept going. | Quiet redirect, right size. The lesson kept going. |
| `scripts/CoachFeedback.gd:40` | The question came while the room was still confused, so it only exposed that confusion without fixing it. | You asked while they were still confused. It showed the confusion but didn't fix it. |
| `scripts/CoachFeedback.gd:45` | You checked the whole room, and now you have evidence instead of a guess. | You checked the whole room. Now you know instead of guessing. |
| `scripts/CoachFeedback.gd:52` | Your probe brought the group's hidden misconception out into the open. | Your question got the group's mistake out where you could see it. |
| `scripts/CoachFeedback.gd:98` | You used %s %d times and it didn't land. It's not the move, it's how you're using it. See the example below. | You used %s %d times and it didn't land. The move's fine. It's how you're using it. Look at the example below. |
| `scripts/LessonImport.gd:38` | Keep class attention >= 65% | Keep attention at 65%+ |
| `scripts/LessonImport.gd:39` | Finish with composure >= 50% | Finish with composure at 50%+ |
| `scripts/LessonImport.gd:149` | A compact mini-lesson is about to drift unless checks for understanding keep every learner visible. | A short mini-lesson. Easy to lose them unless you keep checking who's still with you. |
| `scripts/LessonImport.gd:151` | Clusters are active, materials are moving, and the teacher has to surface shared reasoning before airtime narrows. | Groups are working and materials are everywhere. Find out what each group thinks before one kid takes over. |
| `scripts/LessonImport.gd:153` | The room looks quiet, but the real work is circulation: catch confusion early without breaking momentum. | It looks quiet. Walk the room anyway and catch the confusion early. |
| `scripts/LessonImport.gd:155` | A discussion around %s is open, but the teacher must turn scattered student ideas into public reasoning. | Everyone has an idea about %s. Get those ideas out where the class can test them. |
| `scripts/ResultsCard.gd:113` | No turning points yet: the period ended before a move landed. | Nothing landed before the bell. |
| `scripts/ResultsCard.gd:213` | Excellent work: every part of this held up. | Clean run. Nothing to fix. |
| `scripts/ResultsCard.gd:215` | Strong session. Small gains left in %s. | Really good. A little room left in %s. |
| `scripts/ResultsCard.gd:219` | You got there, with detours. %s is the part to practise. | You got there the long way. %s is the thing to practice. |
| `scripts/ResultsCard.gd:220` | %s held the score down. That is the place to start. | %s pulled the score down. Start there. |
| `scripts/Scaffold.gd:43` | Not enough evidence yet, so full support is on | You're new to this, so all the help is on |
| `scripts/Scaffold.gd:45` | Estimate %d%%, so full support is on | Still learning this (%d%%), so all the help is on |
| `scripts/Scaffold.gd:48` | Estimate %d%%, so some supports are gone | Getting there (%d%%), so some help is off |
| `scripts/Scaffold.gd:51` | Estimate %d%%, so you read the student yourself | Pretty solid (%d%%), so you read the student yourself |
| `scripts/Scaffold.gd:54` | Estimate %d%% across %d events, so all supports are off | Solid (%d%% over %d moves), so the help is off |
| `autoload/Auth.gd:33` | login not set up yet | Sign-in isn't set up yet. |
| `autoload/Auth.gd:47` | login failed | Sign-in didn't work. Check your name and passcode. |
| `autoload/Competency.gd:16` | Mgmt (least-intrusive) | Low-key redirects |
| `autoload/GameCoach.gd:7` | Signature: simultaneous learner triage + competing classroom demands. | The test: several kids need you at once, and the room won't wait. |
| `autoload/GameCoach.gd:10` | Signature: pacing, checks for understanding, wait-time, and equity evidence. | The test: keep the talking short and keep checking who's with you. |
| `autoload/GameCoach.gd:12` | Signature: pod monitoring, shared reasoning, and participation balance. | The test: read each table, and don't let one kid do all the talking. |
| `autoload/GameCoach.gd:14` | Signature: circulation, proximity control, and quiet individual conferences. | The test: get up, walk the rows, talk to kids one at a time. |
| `autoload/GameCoach.gd:15` | Signature: whole-room orchestration plus differentiated student reasoning. | The test: run the room and still hear each student's thinking. |
| `autoload/GameCoach.gd:29` | Research edge: not one scripted avatar, but a live multi-student capstone. | Scored: the whole class at once, all of them live. |
| `autoload/GameCoach.gd:31` | Research edge: group-level reasoning and airtime are scored, not just talk quality. | Scored: how each group reasons, and who gets to talk. |
| `autoload/GameCoach.gd:33` | Research edge: lecture rhythm becomes measurable practice, not a monologue. | Scored: how often you stop talking and check. |
| `autoload/GameCoach.gd:35` | Research edge: wait-time, equity, and withitness are measured together. | Scored: how long you wait, who you call on, what you catch. |
| `autoload/GameCoach.gd:36` | Research edge: every move leaves a construct-level evidence trace. | Scored: each move, against the skill it practices. |
| `autoload/GameCoach.gd:42` | Adaptive coach: start with %s. First target: generate evidence for wait-time, equity, and reasoning moves. | Start with %s. Wait longer than feels normal, and get everyone talking. |
| `autoload/GameCoach.gd:43` | Adaptive coach: next play %s. Focus on %s; current estimate %d%% from %d evidence events. | Try %s next. Work on %s. You're at %d%% after %d moves. |
| `autoload/GameCoach.gd:45` | practice focus | your weak spot |
| `autoload/GameCoach.gd:80` | Adaptive: scaffold start | Starting with extra help |
| `autoload/GameCoach.gd:82` | Adaptive: challenge start | Starting harder |
| `autoload/GameCoach.gd:83` | Adaptive: standard start | Starting at normal |
| `autoload/GameCoach.gd:112` | evidence gained |  |
| `autoload/GameCoach.gd:112` | missed evidence |  |
| `autoload/GameCoach.gd:132` | Practice target: clear a mission to convert choices into evidence-backed coaching. | Practice target: finish one mission first. Then you'll get a real one. |
| `autoload/GameCoach.gd:138` | Practice target: collect first evidence for %s. Try: %s. | Practice target: you haven't tried %s yet. Try: %s. |
| `autoload/GameCoach.gd:141` | Practice target: %s is the growth edge (%d%%, %d events). Try: %s. | Practice target: %s is your weakest spot (%d%% after %d moves). Try: %s. |
| `autoload/GameCoach.gd:157` | productive pause: more learners can enter | the pause gave more kids a way in |
| `autoload/GameCoach.gd:159` | rapport bridge: learner trust becomes usable evidence | they trust you a little more now |
| `autoload/GameCoach.gd:161` | airtime balanced: quieter voices become visible | a quieter kid got the floor |
| `autoload/GameCoach.gd:163` | confusion surfaced: misconception is now teachable | the mix-up came out where you can teach it |
| `autoload/GameCoach.gd:164` | fit signal: the move matched the learning need | right move for what they needed |
| `autoload/GameCoach.gd:166` | takeover risk: answer-giving reduced learner reasoning | you gave the answer, so they stopped thinking |
| `autoload/GameCoach.gd:168` | pressure mistimed: press before shared reasoning stabilized | pushed before the group had settled on an idea |
| `autoload/GameCoach.gd:169` | mismatch signal: choose a smaller or better-timed move | didn't fit yet. Go smaller, or wait a beat |
| `autoload/GameCoach.gd:173` | The move fit the teaching need. | That one fit. |
| `autoload/GameCoach.gd:175` | Telling moved faster than the learner's reasoning. | You told them before they'd worked it out. |
| `autoload/GameCoach.gd:176` | The move did not match the strongest need yet. | Not what they needed most right then. |
| `autoload/GameCoach.gd:188` | ask the learner to explain their reasoning before you evaluate it | ask how they got it before you say if it's right |
| `autoload/GameCoach.gd:189` | press for a second representation or a why-because explanation | ask for another way to show it, or a 'because' |
| `autoload/GameCoach.gd:190` | make the student's idea public in your own words, then check it | say their idea back in your words, then check you got it |
| `autoload/GameCoach.gd:191` | pause before prompting again so the next response is earned | after you ask, wait. Longer than feels okay |
| `autoload/GameCoach.gd:192` | use proximity or a quiet redirect before escalating | walk over or give a quiet cue before anything louder |
| `autoload/GameCoach.gd:193` | avoid taking over; cue the next step instead of telling the answer | hold the answer back and hint at the next step |
| `autoload/GameCoach.gd:194` | name the exact productive behavior you want repeated | name exactly what they did that you want again |
| `autoload/GameCoach.gd:195` | connect the task to a learner asset or lived example | tie the task to something from their own life |
| `autoload/GameCoach.gd:196` | observe the pod before intervening so you know the shared error | watch the table first so you know where they're stuck |
| `autoload/GameCoach.gd:197` | ask for a quick sample of thinking, not a yes/no check | have a few students show their work. A thumbs-up won't tell you much |
| `autoload/GameCoach.gd:198` | redistribute airtime to a quieter learner with competence | hand the floor to a quiet student who knows their stuff |
| `autoload/GameCoach.gd:201` | new model | another way |
| `autoload/GameCoach.gd:202` | cue, do not tell | hint, don't tell |
| `autoload/GameCoach.gd:203` | asset link | their world |
| `autoload/GameCoach.gd:204` | quick sample | watch first |
| `autoload/GameCoach.gd:204` | rebalance airtime | show me |
| `autoload/GameCoach.gd:204` |  | share the floor |
| `autoload/GameCoach.gd:206` | produce visible evidence | make one move that fits |
| `autoload/GameCoach.gd:211` | Mgmt | Redirects |
| `autoload/GameCoach.gd:228` | the capstone replay | the capstone again |
| `autoload/GameState.gd:27` | Baseline rehearsal with no profile bonus. | No bonus. Just you and the class. |
| `autoload/GameState.gd:35` | Safer recovery and order tools. | Extra composure, plus tools for keeping order. |
| `autoload/GameState.gd:43` | Starts with profile and noticing tools. | Starts with the profile card and noticing tools. |
| `autoload/GameState.gd:51` | Defaults toward airtime and wait-time control. | Geared for wait time and sharing the floor. |
| `autoload/GameState.gd:65` | Wait-time readiness is 0.25s faster each rank. | Wait time counts 0.25s sooner each rank. |
| `autoload/GameState.gd:70` | Start encounters with more rapport and engagement. | Kids start out a little warmer to you. |
| `autoload/GameState.gd:161` | Baseline: no bonus, no starter items | No bonus, no starting items |
| `autoload/GameState.gd:316` | Adaptive: standard start | Starting at normal |
| `autoload/GameState.gd:339` | Collect first evidence | Nothing yet |
| `autoload/GameState.gd:340` | Clear one mission to produce a coachable trace. | Clear a mission so Coach Vee has something to go on. |
| `autoload/Items.gd:10` | Preview the lesson flow. | See the lesson's steps. |
| `autoload/Items.gd:17` | Recover composure. | Breathe. Get composure back. |
| `autoload/Items.gd:24` | Reveal one learner need. | Learn what one student needs. |
| `autoload/Items.gd:31` | Restore order with a cue. | Settle the room with a cue. |
| `autoload/Items.gd:38` | Surface a cue to notice. | Points out what to notice. |
| `autoload/Items.gd:45` | Check unheard voices. | See who hasn't talked yet. |
| `autoload/Items.gd:52` | Guarantee deliberate wait. | Makes sure you really wait. |
| `autoload/Items.gd:59` | Set a focused XP goal. | Pick one goal for bonus XP. |
| `autoload/LLMClient.gd:104` | Okay... let me walk you through how I was thinking about it. | Okay, um... so how I was thinking was... |
| `autoload/LLMClient.gd:105` | Good eliciting move; you surfaced their reasoning instead of correcting it. Press on the crack. | You asked how they got it instead of fixing it. Now press on the weak spot. |
| `autoload/LLMClient.gd:109` | Hmm, now I'm not so sure about my first answer. | Hmm. Wait. Now I'm not sure. |
| `autoload/LLMClient.gd:110` | Nice press. They are reasoning it through themselves instead of being told. | Good push. They're working it out on their own. |
| `autoload/LLMClient.gd:113` | Yeah, that's what I meant. | Yeah. That's what I meant. |
| `autoload/LLMClient.gd:114` | Revoicing builds rapport and makes their thinking public. The move new teachers skip most. | Saying it back builds trust and puts their idea in the room. New teachers skip this one. |
| `autoload/LLMClient.gd:118` | You took over the thinking, so engagement dropped. Necessary sometimes, but try eliciting first. | You did the thinking for them, and they checked out. Sometimes you have to. Ask first. |
| `autoload/LLMClient.gd:122` | Make praise behavior-specific (name what they did), not 'good job'. Generic praise barely moves the needle. | Name what they actually did. Plain 'good job' barely moves anything. |
| `autoload/LLMClient.gd:126` | Use the least-intrusive redirect that works (proximity or nonverbal before a verbal correction). | Quietest fix first. Walk over, or give a look, before you say anything. |
| `autoload/LLMClient.gd:130` | ...oh, wait, maybe I had it backwards. | ...oh wait. Maybe I had it backwards? |
| `autoload/LLMClient.gd:131` | Wait time paid off. They filled the silence with their own reasoning. Three to five seconds is the sweet spot. | The wait worked. They filled the quiet with their own thinking. Three to five seconds. |
| `autoload/LLMClient.gd:135` | You broke the silence too early. Hold the pause at least three seconds. | You jumped in too soon. Hold it at least three seconds. |
| `autoload/LLMClient.gd:142` |   (For this student, that may not be the move that unlocks them - check the goal at the top.) |   (Maybe not the move this student needs. Check the goal up top.) |
| `autoload/TTSClient.gd:93` | Voice: Off (demo gate) | Voice: Off (demo) |
| `autoload/TTSClient.gd:98` | Voice is off in the public demo to prevent paid API usage. Use the passcode gate for voice. | Voice is off in the public demo. Use a voice passcode to turn it on. |
| `autoload/TTSClient.gd:100` | Voice is enabled. Sound toggles both SFX and spoken student lines. | Voice is on. The Sound switch mutes effects and student voices together. |
| `autoload/TTSClient.gd:101` | Voice is unavailable because no TTS endpoint is configured. | Voice isn't set up on this server. |
| `autoload/Telemetry.gd:335` | > This learner-owned file contains the current session's teacher moves and simulated learner responses. It excludes raw telemetry and account data. | > Your moves and the students' replies from this session. No telemetry or account data. |
| `autoload/Telemetry.gd:339` | No conversation turns have been recorded in this session yet. | Nothing recorded yet this session. |
| `autoload/Telemetry.gd:366` | **Decision signal:** %s | **How it went:** %s |
| `autoload/Telemetry.gd:366` | Move addressed the target. | That move fit. |
| `autoload/Telemetry.gd:366` | Reconsider or revise this move. | Worth trying a different move here. |
| `autoload/Telemetry.gd:377` | Complete at least one dialogue turn first. | Talk to a student first. Nothing to save yet. |
| `data/scenarios/culturally_responsive_intro.json#objectives[0].label` | Keep class attention >= 60% | Keep attention at 60%+ |
| `data/scenarios/culturally_responsive_intro.json#objectives[2].label` | Connect to >= 3 students' funds of knowledge | Tie the lesson to 3+ students' own lives |
| `data/scenarios/culturally_responsive_intro.json#objectives[3].label` | Finish with composure >= 50% | Finish with composure at 50%+ |
| `data/scenarios/culturally_responsive_intro.json#note` | Weinstein, Tomlinson-Clarke & Curran (2004): management is cultural. Use Connect to notice each student's assets (funds of knowledge) and check your assumption before you correct. | Weinstein, Tomlinson-Clarke & Curran (2004) argue management is cultural. Use Connect to find what each student brings, and check your assumption before you correct. |
| `data/scenarios/culturally_responsive_intro.json#story_hook` | Before correcting behavior, the teacher has to notice student assets and connect the lesson to lived knowledge. | You know these kids better since conferences. Find what each one already knows before you correct anything. |
| `data/scenarios/custom_comparing_decimals.json#objectives[0].label` | Keep class attention >= 65% | Keep attention at 65%+ |
| `data/scenarios/custom_comparing_decimals.json#objectives[1].label` | Finish with composure >= 50% | Finish with composure at 50%+ |
| `data/scenarios/custom_comparing_decimals.json#objectives[2].label` | Every student contributes once | Hear from every student |
| `data/scenarios/custom_comparing_decimals.json#persona_overrides.talia_dominator.target_label` | Revoice and redirect decimal reasoning | Revoice her idea, then redirect |
| `data/scenarios/custom_comparing_decimals.json#persona_overrides.talia_dominator.opening_line` | It is 0.45. Forty-five is bigger than five, so 0.45 has to be greater than 0.5. | It's 0.45! Forty-five is way bigger than five, so 0.45 wins. Easy. |
| `data/scenarios/custom_comparing_decimals.json#persona_overrides.talia_dominator.win_line` | I hear it now: 0.5 is 0.50, so five tenths is greater than forty-five hundredths. | Wait, 0.5 is the same as 0.50? Oh. So five tenths beats forty-five hundredths. |
| `data/scenarios/custom_comparing_decimals.json#persona_overrides.sam_withdrawn.opening_line` | I am not sure. The extra digit in 0.45 makes me think it might be bigger. | I don't know... 0.45 has more numbers in it. So maybe it's bigger? |
| `data/scenarios/custom_comparing_decimals.json#persona_overrides.sam_withdrawn.win_line` | When I line them up as hundredths, 0.50 is more than 0.45. | Oh... if I add a zero it's 0.50. So 0.50 is more than 0.45? |
| `data/scenarios/custom_comparing_decimals.json#persona_overrides.diego_ell.opening_line` | I think 0.45, because I see forty-five. But maybe tenths and hundredths are different. | I think 0.45, because forty-five. But tenths and hundredths... they are different, no? |
| `data/scenarios/custom_comparing_decimals.json#persona_overrides.diego_ell.win_line` | So 0.5 means five tenths, the same as fifty hundredths, and fifty hundredths is larger. | So 0.5 is five tenths. Same like fifty hundredths. And fifty is more than forty-five! |
| `data/scenarios/custom_comparing_decimals.json#persona_overrides.jordan_skeptic.opening_line` | This feels like a trick. If 45 is bigger than 5, why would 0.45 be smaller? | This is a trick question. 45 is bigger than 5, so how is 0.45 smaller? |
| `data/scenarios/custom_comparing_decimals.json#persona_overrides.jordan_skeptic.win_line` | Okay, like money: 50 cents is more than 45 cents, so 0.50 is greater than 0.45. | Oh, it's money. Fifty cents beats forty-five cents. Okay, fine, 0.50 is bigger. |
| `data/scenarios/custom_comparing_decimals.json#persona_overrides.priya_quiet.opening_line` | I was thinking 0.5, but I do not want to say it wrong. | I think it's 0.5? I just didn't want to say it wrong. |
| `data/scenarios/custom_comparing_decimals.json#persona_overrides.priya_quiet.win_line` | 0.5 is bigger because it is five tenths, and 0.45 is four tenths and five hundredths. | 0.5 is five tenths. 0.45 is only four tenths and five hundredths. So 0.5. |
| `data/scenarios/custom_comparing_decimals.json#persona_overrides.noah_g5_fractions.target_label` | Elicit and extend Noah's comparison model | Ask how Noah compared them, then push |
| `data/scenarios/custom_comparing_decimals.json#persona_overrides.noah_g5_fractions.opening_line` | I think 0.45 is greater because 45 is more than 5, but decimals confuse me. | 0.45 is bigger. 45 is more than 5. ...Right? Decimals are weird. |
| `data/scenarios/custom_comparing_decimals.json#persona_overrides.noah_g5_fractions.win_line` | If I write 0.5 as 0.50, then I can compare hundredths: 50 hundredths is greater than 45 hundredths. | Oh! If I write 0.5 as 0.50, they're both hundredths. 50 is more than 45. So 0.5 wins! |
| `data/scenarios/custom_comparing_decimals.json#story_hook` | A decimal comparison sounds simple until place-value intuition collides with whole-number thinking in public discussion. | Which is bigger, 0.45 or 0.5? Half the room will say 0.45, and they'll say it out loud. |
| `data/scenarios/discussion_fractions.json#objectives[0].label` | Keep class attention >= 65% | Keep attention at 65%+ |
| `data/scenarios/discussion_fractions.json#objectives[1].label` | Finish with composure >= 50% | Finish with composure at 50%+ |
| `data/scenarios/discussion_fractions.json#story_hook` | A U-shaped fraction talk invites public reasoning, but wait-time and equitable airtime determine whose ideas become visible. | Desks in a U, everyone can see everyone. Whose ideas get heard depends on how long you wait and who you call on. |
| `data/scenarios/group_work_fractions.json#objectives[0].label` | Keep attention >= 60% (groups drift faster) | Keep attention at 60%+ (groups drift fast) |
| `data/scenarios/group_work_fractions.json#objectives[2].label` | Composure >= 50% | Keep composure at 50%+ |
| `data/scenarios/group_work_fractions.json#story_hook` | Clusters are busy with fraction strips, and the teacher must balance collaboration, shared reasoning, and off-task drift. | Four clusters, a pile of fraction strips, and a lot of noise. Some of it is math. Some of it isn't. |
| `data/scenarios/gym_capstone.json#persona_overrides.noah_g5_fractions.target_label` | Elicit + extend (surface the reasoning) | Elicit, then extend his thinking |
| `data/scenarios/gym_capstone.json#persona_overrides.noah_g5_fractions.opening_line` | I think I messed up the example. I used the bigger number because it looked bigger, but now everyone is staring at me. | I think I messed it up. I picked the bigger number 'cause it looked bigger. Why is everyone looking at me? |
| `data/scenarios/gym_capstone.json#persona_overrides.noah_g5_fractions.win_line` | Oh, I see it now, I had the idea backwards! | Ohhh. Wait. I had it backwards! |
| `data/scenarios/gym_capstone.json#persona_overrides.deshawn_offtask.target_label` | Least-intrusive redirect + BSP | Quiet redirect, then specific praise |
| `data/scenarios/gym_capstone.json#persona_overrides.marcus_volatile.target_label` | Affect-first: revoice + wait | Calm him first: revoice, then wait |
| `data/scenarios/gym_capstone.json#persona_overrides.priya_quiet.target_label` | Deliberately invite + wait | Invite her by name, then wait |
| `data/scenarios/gym_capstone.json#persona_overrides.priya_quiet.opening_line` | (quietly has a useful idea written down, but keeps her hand low while louder students talk) | (has a good idea written down, but keeps her hand low while the loud kids talk) |
| `data/scenarios/gym_capstone.json#persona_overrides.priya_quiet.win_line` | Yes! I had that, thanks for asking me. | I had that one. ...Thanks for asking me. |
| `data/scenarios/gym_capstone.json#story_hook` | The lesson has gone sideways; the teacher must recover order, care, and reasoning across several students at once. | The projector's dead, a chair's on the floor, and four kids need you at once. Pick who goes first. |
| `data/scenarios/independent_fractions.json#objectives[0].label` | Hold on-task >= 70% (circulate and confer) | Keep 70%+ on task (walk and confer) |
| `data/scenarios/independent_fractions.json#objectives[2].label` | Composure >= 60% | Keep composure at 60%+ |
| `data/scenarios/independent_fractions.json#story_hook` | The room looks orderly, but quiet struggle is hidden in the rows; circulation and proximity decide the period. | The rows look calm. That doesn't mean anyone's working. You'll only find out by walking them. |
| `data/scenarios/lecture_fractions.json#objectives[0].label` | Hold attention >= 70% (rows favor on-task) | Keep attention at 70%+ (rows help) |
| `data/scenarios/lecture_fractions.json#objectives[2].label` | Composure >= 60% | Keep composure at 60%+ |
| `data/scenarios/lecture_fractions.json#story_hook` | A calm fraction mini-lesson can become a monologue unless the teacher checks understanding before confusion spreads. | Short fractions lesson, rows facing front. Easy to talk the whole time and miss who's lost. |
| `data/scenarios/reading_main_idea.json#objectives[0].label` | Keep class attention >= 65% | Keep attention at 65%+ |
| `data/scenarios/reading_main_idea.json#objectives[1].label` | Composure >= 50% | Keep composure at 50%+ |
| `data/scenarios/reading_main_idea.json#persona_overrides.noah_g5_fractions.target_label` | Elicit and extend Noah's idea of 'main idea' | Ask how Noah picked it, then push |
| `data/scenarios/reading_main_idea.json#persona_overrides.noah_g5_fractions.win_line` | Oh, the first sentence is just a detail. The main idea is what all the sentences are about together. | Ohh. The first sentence is just one detail. The main idea is what the whole thing's about. |
| `data/scenarios/reading_main_idea.json#persona_overrides.jordan_skeptic.target_label` | Acknowledge relevance, then press | Take his question seriously, then press |
| `data/scenarios/reading_main_idea.json#persona_overrides.jordan_skeptic.win_line` | Okay, finding the main idea is like the headline, it tells you the point fast. | Okay, so it's like the headline. Tells you the point fast. That's actually useful. |
| `data/scenarios/reading_main_idea.json#persona_overrides.diego_ell.win_line` | So the main idea is the whole thing together, not one line. The passage is mostly about bees helping plants. | So main idea is all of it together. Not one line. It's mostly about bees helping the plants. |
| `data/scenarios/reading_main_idea.json#persona_overrides.priya_quiet.target_label` | Deliberately invite Priya | Call on Priya on purpose |
| `data/scenarios/reading_main_idea.json#persona_overrides.priya_quiet.win_line` | The main idea is that bees and flowers help each other survive. | Um, I think it's that bees and flowers need each other to survive. |
| `data/scenarios/reading_main_idea.json#persona_overrides.talia_dominator.target_label` | Revoice, then redirect the turn | Revoice her, then pass the turn |
| `data/scenarios/reading_main_idea.json#persona_overrides.talia_dominator.win_line` | Right, and I'll let someone else add why that's the main idea. | Yeah! Okay... someone else can say why it's the main idea. |
| `data/scenarios/reading_main_idea.json#story_hook` | A literacy discussion about main idea asks the teacher to help students move from first details to the whole point. | A short article about honeybees. Most kids will grab the first detail and call it the main idea. |
| `data/scenarios/science_force_motion.json#objectives[0].label` | Keep attention >= 60% (groups drift faster) | Keep attention at 60%+ (groups drift fast) |
| `data/scenarios/science_force_motion.json#objectives[2].label` | Composure >= 50% | Keep composure at 50%+ |
| `data/scenarios/science_force_motion.json#persona_overrides.noah_g5_fractions.target_label` | Elicit and extend Noah's prediction | Ask about Noah's prediction, then push |
| `data/scenarios/science_force_motion.json#persona_overrides.marcus_volatile.target_label` | Affect-first, then re-engage | Calm him first, then back to the ramp |
| `data/scenarios/science_force_motion.json#persona_overrides.marcus_volatile.win_line` | ...fine. Maybe the ramp is too flat. Let me try raising it a little. | ...fine. Maybe the ramp's too flat. I'll put it up a little. |
| `data/scenarios/science_force_motion.json#persona_overrides.deshawn_offtask.target_label` | Least-intrusive redirect to the task | Quietest redirect that works |
| `data/scenarios/science_force_motion.json#persona_overrides.deshawn_offtask.win_line` | Alright, I'll record how far it rolls each push. On it. | Aight, aight. I'll write down how far it goes each push. |
| `data/scenarios/science_force_motion.json#persona_overrides.diego_ell.target_label` | Wait and revoice the force idea | Wait, then revoice his force idea |
| `data/scenarios/science_force_motion.json#persona_overrides.diego_ell.win_line` | So a push or a pull is a force, and a bigger push makes it go farther. | So a push or a pull, that's a force. Bigger push, it goes farther. |
| `data/scenarios/science_force_motion.json#persona_overrides.meilin_anxious.target_label` | Process feedback, not person-praise | Praise her method, not how smart she is |
| `data/scenarios/science_force_motion.json#persona_overrides.meilin_anxious.win_line` | Okay, measuring the distance three times and averaging is a good method. I can do that. | Okay... so measuring three times and taking the average is a good way. I can do that. |
| `data/scenarios/science_force_motion.json#persona_overrides.talia_dominator.win_line` | Okay, I'll push and let Sam record so everyone has a job. | Fine, I'll push. Sam can write it down. Everybody gets a job. |
| `data/scenarios/science_force_motion.json#persona_overrides.priya_quiet.target_label` | Deliberately invite Priya's data | Ask Priya for her data |
| `data/scenarios/science_force_motion.json#persona_overrides.priya_quiet.win_line` | Our cart went farther each time we pushed harder, here are the numbers. | Um, ours went farther every time we pushed harder. I wrote the numbers down. |
| `data/scenarios/science_force_motion.json#story_hook` | Ramps, carts, and confident misconceptions make this a live test of whether group data can change student thinking. | Ramps, carts, and a room full of kids who are sure heavy things go faster. Can their own data change that? |
| `data/persona_library/deshawn_offtask.json#win_line` | Alright, alright, I'm on it. Sorry. | Alright, alright, I'm on it. My bad. |
| `data/persona_library/deshawn_offtask.json#asset_hint` | Deshawn is off-task AND the natural leader the others follow. Build the relationship and channel that leadership - warm demander, not just redirect. | Deshawn's off task, and he's also the kid the others follow. Build the relationship and put that pull to work. Warm, and still hold the line. |
| `data/persona_library/deshawn_offtask.json#connect_line` | Aight, aight. You actually get me. ...Fine, I'll lead by getting MY work done first. | Aight, aight. You get me. ...Fine. I'll do MY work first, then they'll do theirs. |
| `data/persona_library/deshawn_offtask.json#paths[1].why` | Behavior-specific praise first builds the credit that makes the redirect work. | Catch him doing it right first. That credit is what makes the redirect land. |
| `data/persona_library/deshawn_offtask.json#paths[2].why` | Give him a reason to be in the task, then hold the line calmly. | Give him a reason to care about the task. Then hold the line, calmly. |
| `data/persona_library/diego_ell.json#win_line` | Oh! I can show it with the picture first, then say it. One fourth is bigger. | Oh! I show it with the picture first, then I say it. One fourth is bigger. |
| `data/persona_library/diego_ell.json#asset_hint` | Diego works it out in Spanish before he'll risk English. Letting him reason in his home language first is a resource, not a deficit (Moll's funds of knowledge). | Diego works it out in Spanish before he'll risk English. Let him think in Spanish first. That's a strength he brings (Moll, funds of knowledge). |
| `data/persona_library/diego_ell.json#connect_line` | Oh - 'lo explico en espanol primero'... yes. When I say it my way first, then I can tell you in English. It makes sense. | Ah, 'lo explico en espanol primero'... yes. I say it my way first, then I can tell you in English. Okay. That works. |
| `data/persona_library/diego_ell.json#paths[0].why` | Extended wait time lets him translate and compose his answer (Rowe, 1986). | A longer wait gives him time to translate and put his answer together (Rowe, 1986). |
| `data/persona_library/diego_ell.json#paths[1].why` | Restating shows you understood and models the academic language. | Saying it back shows him you got it, and gives him the math words. |
| `data/persona_library/jordan_skeptic.json#target_label` | Connect learning to the student's world | Connect the math to his world |
| `data/persona_library/jordan_skeptic.json#win_line` | Huh. Okay, splitting a bill or a recipe, that actually makes sense. | Huh. Okay. Splitting a bill, a recipe... yeah, fine, I'd use that. |
| `data/persona_library/jordan_skeptic.json#asset_hint` | Jordan keeps asking 'when do we use this?' He rebuilds bikes - gear ratios are exactly this math. The skepticism is a bid for relevance, not defiance. | Jordan keeps asking when he'll ever use this. He rebuilds bikes, and gear ratios are this exact math. He's asking for a reason. He isn't picking a fight. |
| `data/persona_library/jordan_skeptic.json#connect_line` | Wait, this is just gear ratios. I do this on the bike every weekend. Okay, NOW it's worth my time. | Wait. This is just gear ratios? I do that on the bike every weekend. Okay. NOW I'm listening. |
| `data/persona_library/jordan_skeptic.json#paths[0].why` | Treat his question as a real question, then press on the math. | His question is a real one. Answer it, then press on the math. |
| `data/persona_library/jordan_skeptic.json#paths[2].why` | Let him build the relevance himself, then build on his answer. | Let him come up with the reason himself, then work from what he says. |
| `data/persona_library/marcus_volatile.json#win_line` | ...fine. Okay. Maybe just the first step. Don't make a big thing of it. | ...fine. Just the first step. Don't make it a whole thing. |
| `data/persona_library/marcus_volatile.json#asset_hint` | Marcus is escalating. He grounds himself through music and rhythm. Connect to that to bring the temperature down before any academic demand. | Marcus is heating up. Music and rhythm are how he calms down. Start there, and cool things off before you ask for any math. |
| `data/persona_library/marcus_volatile.json#connect_line` | ...yeah. Music helps me chill. ...Okay. I'm good now. We can do the work. | ...yeah. Beats help me chill. ...Okay. I'm good. Whatever, we can do it. |
| `data/persona_library/marcus_volatile.json#paths[1].why` | A calm pause lowers the heat; then you reconnect. | A calm pause cools him down. Then you reconnect. |
| `data/persona_library/meilin_anxious.json#win_line` | Okay... so it's about the strategy I used, not whether I'm smart. I can try that. | Okay... so it's about what I tried. Not if I'm smart. I can... I can try that. |
| `data/persona_library/meilin_anxious.json#assets[0]` | meticulous illustrator who redraws until it's right | redraws her drawings until they're right |
| `data/persona_library/meilin_anxious.json#asset_hint` | Mei-Lin's perfectionism is the same care that makes her redraw art until it's right. Name the effort, not the result - that's what unlocks her. | Mei-Lin redraws her art until it's right, and that same care is what makes her a perfectionist here. Name the effort, not the result. That's what gets her moving. |
| `data/persona_library/meilin_anxious.json#connect_line` | ...you noticed how much I revised it? ...okay. Maybe the mistakes are part of getting it right. | ...you saw how many times I fixed it? ...okay. Maybe messing up is part of getting it right. |
| `data/persona_library/meilin_anxious.json#paths[1].why` | Time without judgment tells her a hard problem is normal. | Give her time, and no judgment. That tells her hard is normal. |
| `data/persona_library/meilin_anxious.json#paths[2].why` | Make her process visible so the feedback has something concrete to name. | Get her to say how she did it, so your feedback has something real to name. |
| `data/persona_library/noah_g5_fractions.json#opening_line` | Which is bigger, one eighth or one fourth? ...One eighth, because 8 is more than 4. | Which is bigger, one eighth or one fourth? ...One eighth. 'Cause eight's more than four. |
| `data/persona_library/noah_g5_fractions.json#win_line` | Oh! More pieces means each piece is smaller. One fourth IS bigger. I get it now! | Ohh. More pieces means each piece is smaller. So one fourth IS bigger. Okay. I get it. |
| `data/persona_library/noah_g5_fractions.json#asset_hint` | Noah is the one who splits the last brownie so his sister can't argue. He already reasons about equal shares - that's fractions in his own world. | Noah's the one who splits the last brownie so his sister can't argue. He already thinks in equal shares. That's fractions, in his world. |
| `data/persona_library/noah_g5_fractions.json#connect_line` | Oh - like splitting the brownie! More people means smaller pieces. So 1/8 is the smaller share. I actually get it now. | Wait, like the brownie. More people, smaller pieces. So 1/8 is the smaller share. ...Huh. Okay. |
| `data/persona_library/noah_g5_fractions.json#paths[0].why` | Surface his 4 > 3 theory first, then press on the crack in it (Jacobs et al., 2010). | Get his 8 > 4 rule out in the open, then press on the crack in it (Jacobs et al., 2010). |
| `data/persona_library/noah_g5_fractions.json#paths[2].why` | Restating his claim makes it an idea to test, not a mistake to hide. | Say his claim back. Now it's an idea to test instead of a mistake to hide. |
| `data/persona_library/priya_quiet.json#target_label` | Equitable participation (the easily-overlooked student) | Equitable participation (the overlooked kid) |
| `data/persona_library/priya_quiet.json#opening_line` | (has the right answer ready, but quietly waits and is rarely called on) | (has the answer ready, waits quietly, almost never gets called on) |
| `data/persona_library/priya_quiet.json#win_line` | Yes! I had that. Thanks for asking me. | Oh. Yeah, I had that one. ...Thanks for asking me. |
| `data/persona_library/priya_quiet.json#assets[1]` | writes long thoughtful book reviews | writes long book reviews |
| `data/persona_library/priya_quiet.json#asset_hint` | Priya rarely volunteers, but she catches details no one else does. The asset is there; she just needs to be invited into the air-time. | Priya almost never volunteers, but she catches details nobody else does. She needs you to hand her the floor. |
| `data/persona_library/priya_quiet.json#connect_line` | Oh - you actually want to hear what I thought? ...I did notice something nobody mentioned. | You want to hear what I thought? ...Um. I noticed something nobody said yet. |
| `data/persona_library/priya_quiet.json#paths[1].why` | Once she speaks, revoicing gives her idea status in the room. | Once she talks, say her idea back so the room takes it seriously. |
| `data/persona_library/riley_avoidant.json#win_line` | ...it's not that I won't. I didn't get the first part and I felt dumb. | ...it's not that I won't. I didn't get the first part. And I felt dumb. |
| `data/persona_library/riley_avoidant.json#asset_hint` | Riley shrugs at the worksheet, but builds intricate redstone logic at home. So this is avoidance / fear of being wrong, NOT a thinking gap. Read the FUNCTION before you respond. | Riley shrugs at the worksheet but builds complicated redstone circuits at home. This is fear of being wrong, not a thinking gap. Figure out what the refusal is for before you respond. |
| `data/persona_library/riley_avoidant.json#connect_line` | I mean... I do way harder logic in Minecraft. I guess I just didn't want to mess this up in front of everyone. | I mean... I build way harder stuff in Minecraft. I just didn't wanna mess up in front of everybody. |
| `data/persona_library/riley_avoidant.json#paths[0].why` | Find out what the avoidance is protecting before responding (Jacobs et al., 2010). | Find out what the refusal is protecting before you respond (Jacobs et al., 2010). |
| `data/persona_library/sam_withdrawn.json#win_line` | ...okay. I think... maybe it's the one with the smaller bottom number? | ...okay. Um. Maybe it's the one with the smaller bottom number? |
| `data/persona_library/sam_withdrawn.json#assets[1]` | knows every fact about deep-sea creatures | knows everything about deep-sea creatures |
| `data/persona_library/sam_withdrawn.json#asset_hint` | Sam has gone quiet, but the margins are full of drawings. There's a door in there - an interest you can open before you ask for thinking. | Sam's gone quiet, but his margins are full of drawings. Start there before you ask for his thinking. |
| `data/persona_library/sam_withdrawn.json#connect_line` | ...you saw my drawings? I could draw the problem instead of writing it... yeah. Okay. I can try that. | ...you saw my drawings? Could I draw it instead of writing it? ...Okay. I can try. |
| `data/persona_library/sam_withdrawn.json#paths[0].why` | Low pressure plus time makes it safe for him to be wrong in public (Fredricks et al., 2004). | Low pressure and some time make it safe for him to be wrong out loud (Fredricks et al., 2004). |
| `data/persona_library/sam_withdrawn.json#paths[1].why` | Start from something he already knows so entering the conversation costs less. | Start from something he already knows, so speaking up costs him less. |
| `data/persona_library/sam_withdrawn.json#paths[2].why` | Specific credit for effort signals he belongs in the discussion. | Specific credit for his effort tells him he belongs in the talk. |
| `data/persona_library/talia_dominator.json#opening_line` | Ooh, ooh, I know this one! Can I answer? I always know it! | Ooh, ooh, me! I know this one! Can I say it? I always know it! |
| `data/persona_library/talia_dominator.json#win_line` | ...oh. Yeah. I guess I could let someone else have a turn too. | ...oh. Yeah. I guess somebody else can have a turn. |
| `data/persona_library/talia_dominator.json#assets[0]` | genuinely loves the subject and helps peers | loves math and helps classmates |
| `data/persona_library/talia_dominator.json#asset_hint` | Talia dominates because she's eager, not selfish - she already helps peers and runs a club. Channel that energy into lifting others, don't just shut it down. | Talia takes over because she's eager. She already helps classmates and runs a club. Point that energy at getting others in instead of just shutting her down. |
| `data/persona_library/talia_dominator.json#connect_line` | Oh! I could help draw out the quieter folks instead of just answering? ...I'd actually love that. | Wait, so I could help get the quiet kids talking? Instead of just answering? ...Okay, I'd actually love that. |
| `data/persona_library/talia_dominator.json#paths[0].why` | Brief validation meets her need for recognition; then the turn moves on (Dallimore et al., 2012). | A quick nod gives her the credit she wants. Then pass the turn (Dallimore et al., 2012). |
| `data/persona_library/talia_dominator.json#paths[2].why` | Push her to justify, which slows the blurting and opens room for others. | Make her explain why. It slows the blurting and leaves room for everyone else. |
| `data/narrative/chapters.json#chapters.lecture_fractions.intro[3].text` | Here's the trap: a calm lecture feels like it's working. Then you look up, and half the room is gone. | A calm lecture feels like it's working. Then you look up and half the room is gone. |
| `data/narrative/chapters.json#chapters.lecture_fractions.intro[4].text` | Present a little. Pause. Check. If you only talk, you'll never know who's still with you. | Talk for a bit, then stop and check. If you only talk, you won't know who's still with you. |
| `data/narrative/chapters.json#chapters.independent_fractions.intro[2].text` | Quiet is not the same as working. Riley hasn't written a word. Marcus is one erased answer away from a meltdown. | Quiet doesn't mean working. Riley hasn't written a word. Marcus is one eraser away from a meltdown. |
| `data/narrative/chapters.json#chapters.independent_fractions.intro[3].text` | Get out from behind the desk. Walk the rows. Stand close. Confer with each of them. | Get out from behind the desk. Walk the rows, and sit down with each of them. |
| `data/narrative/chapters.json#chapters.independent_fractions.outro_win.text` | You found the struggle nobody said out loud. Being close did more than any warning. | You found the kids who were stuck and not saying so. Standing close did more than a warning would. |
| `data/narrative/chapters.json#chapters.discussion_fractions.intro[3].text` | Wait three seconds before you pick anyone. Then pick with purpose. The quiet thinkers need time before they'll talk. | Count three seconds before you call on anyone, and pick on purpose. Your quiet ones need the time. |
| `data/narrative/chapters.json#chapters.discussion_fractions.outro_retry.text` | The loudest voices set the direction today. Take the wait time back. That's your job. | Talia steered the whole thing today. Wait longer, and you decide who talks. |
| `data/narrative/chapters.json#chapters.reading_main_idea.intro[2].text` | Jordan's right about the detail and wrong about the point. That's where the teaching is. | Jordan's got a detail. He hasn't got the point yet. Start there. |
| `data/narrative/chapters.json#chapters.reading_main_idea.outro_win.text` | They built the main idea together. You held the question and gave them the thinking. | They got to the main idea on their own. You just kept asking. |
| `data/narrative/chapters.json#chapters.culturally_responsive_intro.intro[2].text` | Every kid walks in already knowing things. Your job is to find where the lesson connects to what they know. | Every kid walks in knowing stuff. Find where the lesson hooks into it. |
| `data/narrative/chapters.json#chapters.culturally_responsive_intro.intro[4].text` | Connect before you correct. See who they are, then teach. | Find out what they know before you correct anything. |
| `data/narrative/chapters.json#chapters.culturally_responsive_intro.outro_win.text` | You taught fractions with a food truck and a bike chain. They'll remember that lesson. | You taught fractions with a food truck and a bike chain. They'll remember that one. |
| `data/narrative/chapters.json#chapters.culturally_responsive_intro.outro_retry.text` | You corrected before you connected. Start with what each student already brings. | You went straight to correcting. Next time, start with what each of them already knows. |
| `data/narrative/chapters.json#chapters.custom_comparing_decimals.intro[2].text` | That's not a careless mistake. It's a theory, and it makes sense to him. Find out why before you fix it. | He's not being careless. He has a theory, and it makes sense to him. Find out why before you fix it. |
| `data/narrative/chapters.json#chapters.custom_comparing_decimals.intro[3].text` | Let every student put an idea on the table. The wrong ones teach the most. | Get an idea out of everyone. You'll learn the most from the wrong ones. |
| `data/narrative/chapters.json#chapters.group_work_fractions.intro[3].text` | Years of experience don't make you better on their own. Practice on purpose does. Hollis stopped practicing. | Years alone don't make you better. Practicing does, and Hollis quit a long time ago. |
| `data/narrative/chapters.json#chapters.group_work_fractions.outro_win.text` | Every group, every kid, a real turn. Hollis was watching from the door, by the way. | You got to every group and everybody talked. Hollis was watching from the door, by the way. |
| `data/narrative/chapters.json#chapters.science_force_motion.intro[3].text` | Don't argue with Marcus. Let the cart show him. Your job is to get them looking at the results together. | Don't argue with Marcus. Let the cart show him. Just get them looking at the results together. |
| `data/narrative/chapters.json#chapters.science_force_motion.outro_win.text` | The results changed their minds, not you. Hollis asked to borrow your ramps. | Their own results changed their minds. Hollis asked to borrow your ramps. |
| `data/narrative/chapters.json#chapters.gym_capstone.intro[4].text` | You've been rehearsing it all year. Order, care, reasoning. One student at a time. | You've been rehearsing this all year. One student at a time. |
| `data/narrative/chapters.json#chapters.gym_capstone.intro[5].text` | Breathe. Choose. Go. | Breathe. Then pick one. |


## Follow-up, decided by default (owner to confirm)

- **Teaching terms kept where players meet them.** In the skill notebook, the Low-key redirects row cites "least-intrusive, Simonsen 2008" and the Asset connect row cites "funds of knowledge, Moll". Hovering either name gives a one-sentence plain gloss.
- **Story lines are roster-safe.** Chapter lines that name a student now say `{persona_id}`, filled from the lesson's roster. If that student isn't in the roster, the line's no-name `fallback` is used. This covers chapter 3's retry line plus seven other lines. FeelCheck covers it.
- **Diego rewritten as a capable student still acquiring English:** short accurate sentences, the odd Spanish-influenced structure, and maths as sharp as anyone's. No broken-English comedy. *Owner to read these:*

| where | before | after |
|---|---|---|
| diego_ell opening | I... I know it, but I not sure how to say it in English. | I know the answer. I need a second to say it in English. |
| diego_ell win | Oh! I show it with the picture first, then I say it. One fourth is bigger. | Let me draw it. See? Cut in four, the pieces are bigger than cut in eight. So one fourth is bigger. |
| diego_ell connect | Ah, 'lo explico en espanol primero'... yes. I say it my way first, then I can tell you in English. Okay. That works. | In Spanish first? Okay. Un cuarto es más grande... One fourth is bigger. And I can tell you why. |
| comparing decimals, Diego opening | I think 0.45, because forty-five. But tenths and hundredths... they are different, no? | Forty-five is more than five, so 0.45? But the places are not the same. Tenths, hundredths... wait. |
| comparing decimals, Diego win | So 0.5 is five tenths. Same like fifty hundredths. And fifty is more than forty-five! | 0.5 is five tenths. That is fifty hundredths. Fifty is more than forty-five, so 0.5 is bigger. |

- **Question for the owner, left as is:** should the instructor and report panels (Quality Report, TeacherSim Delta) be hidden from learner accounts?
