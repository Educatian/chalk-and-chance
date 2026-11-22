# Korean hosted AI check (2026-11-22)

## What was run
- **Worker:** `chalk-and-chance-api`, version 132c992c, deployed by the owner from main 97dc64a.
- **Client:** a local **debug** web export of main 97dc64a, with two debug-only changes on branch `Educatian/korean-hosted-check`:
  - with `dev_*` **and** `?allow_hosted=1`, the students stay live while voice and every upload stay off;
  - the scripted noticing step picks the right read, so it can't swallow a scripted move.
- **Encounter:** `?dev_lang=ko&dev_win=<persona>&dev_moves=...&allow_hosted=1`, driven by `tools/qa/web_run.py` with
  `CC_ALLOW=https://chalk-and-chance-api.jewoong-moon.workers.dev/turn` and `CC_ALLOW_MAX=4` (2 for the English control).
- **Network:** that exact URL was the only non-local one allowed (POST, plus its CORS preflight). Everything else was aborted at the browser.
  - All three runs reported `NETWORK blocked=0`: no request to `/telemetry_anon`, `/tts` or any other host or path was even attempted.
- **Dry runs first:** with no allow-list, each run attempted exactly 4 `POST /turn` and nothing else.
- **Budget used:** 8 Korean calls (민호 × 4, 도윤 × 4) and 2 English calls, 10 in all. No retries.

## How "model" vs "fallback" is decided
The Worker answers with a fixed line when the model call fails or is rejected: `CANNED_STUDENT_KO` / `COACH_TIPS_KO` in `cloudflare/locale.js`, `cannedStudent` / `coachTip` in `cloudflare/turn.js`. A reply that exactly equals one of those lines is marked *fallback*; anything else came from the model. The Worker log for each time below shows the same thing (an OpenRouter error or a rejected reply).

> **Correction (read this first).** The first table below checks the **Worker's responses only**. In those 8 runs the game screen showed the client's local stub lines, not those responses.
> - **Cause:** the runner slept with `time.sleep`, so Playwright handed each request to the Worker only at the next step, about 18 s later, past the client's 12 s request timeout. The client then fell back to its stub. The `dialogue_tail` it sent on later calls therefore held stub lines.
> - **Fix:** the runner now waits with `page.wait_for_timeout`.
> - **In-game check:** the second table below (4 calls, approved as extra budget) checks that the line on screen equals the Worker's response for each call.

## Calls, first set: Worker responses only, not an in-game check (times are UTC, for the Worker logs)
| run | time (UTC) | locale sent | move | HTTP | student reply (verbatim) | student | coach tip (verbatim) | coach | latency |
|---|---|---|---|---|---|---|---|---|---|
| 민호 (diego_ell), ko #1 | 2026-11-22T09:57:24Z | `ko` | elicit | 200 | 선생님… 그림으로 먼저 보여줘도 돼요? | model | 학생의 생각을 물어보는 좋은 시작이에요! 다음에는 조금 더 기다려 주면 학생이 더 편안하게 답할 수 있을 거예요. | model | not measured (see note) |
| 민호 (diego_ell), ko #2 | 2026-11-22T09:57:42Z | `ko` | revoice | 200 | 아니 그게요… 제가 생각한 거랑 좀 다른데요. 음… 그림으로 그려볼게요. | model | 되말하기로 아이 생각이 모두에게 보이게 됐어요. | fallback | not measured (see note) |
| 민호 (diego_ell), ko #3 | 2026-11-22T09:58:00Z | `ko` | extend | 200 | 아니 그게요… 그림으로 먼저 보여줘도 돼요? 말로 설명하기가 좀 어려워서요. | model | 잘 더 물었어요. 아이가 스스로 따져 보고 있어요. | fallback | not measured (see note) |
| 민호 (diego_ell), ko #4 | 2026-11-22T09:58:18Z | `ko` | praise | 200 | 음… 제가 그림으로 보여드려도 돼요? 아직 한국어로 어떻게 설명해야 할지 잘 모르겠어요. | model | '잘했어'보다 무엇을 잘했는지 짚어 줘요. | fallback | not measured (see note) |
| 도윤 (noah_g5_fractions), ko #1 | 2026-11-22T09:58:56Z | `ko` | elicit | 200 | 8이 4보다 더 크니까 8분의 1이 더 커요. | model | 좋은 생각 묻기예요. 아이 생각에서 흔들리는 부분을 더 짚어 봐요. | fallback | not measured (see note) |
| 도윤 (noah_g5_fractions), ko #2 | 2026-11-22T09:59:14Z | `ko` | extend | 200 | 음… 8분의 1이 더 커요. 왜냐면 8이 4보다 더 크니까요. | model | 잘 더 물었어요. 아이가 스스로 따져 보고 있어요. | fallback | not measured (see note) |
| 도윤 (noah_g5_fractions), ko #3 | 2026-11-22T09:59:32Z | `ko` | revoice | 200 | 음… 선생님, 8분의 1이 더 큰 거 아니에요? 분모가 더 크면 더 큰 거 아닌가요? | model | 되말하기로 아이 생각이 모두에게 보이게 됐어요. | fallback | not measured (see note) |
| 도윤 (noah_g5_fractions), ko #4 | 2026-11-22T09:59:50Z | `ko` | praise | 200 | 아… 8분의 1이 더 커요. 왜냐면 8이 4보다 더 크니까요. | model | 지금 학생의 생각을 잘 되짚어 주셨어요. 다음엔 학생의 말을 되짚어 준 후에, 그 생각에 대해 더 깊이 탐색할 수 있도록 '더 묻기'를 활용해 보면 어떨까요? | model | not measured (see note) |
| Noah, en control #1 | 2026-11-22T10:00:55Z | `en` | elicit | 200 | Well, eight is a bigger number than four. So, I think one eighth is bigger. | model | You asked the student to explain their thinking, which is a great start for eliciting. What's one way you could encourage them to elaborate further on that initial thought? | model | 783 ms |
| Noah, en control #2 | 2026-11-22T10:01:13Z | `en` | extend | 200 | Wait... when you put it that way, I'm not so sure my first answer was right. | fallback | Nice press. He is reasoning it through himself. | fallback | 211 ms |

- **Latency (Korean runs):** not measured. The runner slept between steps with `time.sleep`, so Playwright handled each request only at the next step, and the recorded ~15–18 s is the step spacing, not the Worker.
- **Latency (English control):** measured properly after the runner was fixed to wait with `page.wait_for_timeout`: 783 ms for a model reply, 211 ms for a fallback reply.

## Calls, second set: in-game check (2026-11-22, 4 calls, UTC)
- **Same setup:** the allow-list was only `/turn` (`CC_ALLOW_MAX=2` per run), and both runs reported `NETWORK blocked=0`. No `/telemetry_anon` or other request was attempted, and there were no retries.
- **How the screen was checked:** the debug probe (`window.__cc_state`) was read every 2 s. A call passes only if, after it and before the next one, a visible line equals `<name>: "<the Worker's student_utterance.text>"` exactly. The polled lines are in `korean-hosted/ko2_*_screen_log.txt`.

| run | time (UTC) | locale sent | move | latency | Worker student line (verbatim) | student | shown on screen, exact | coach tip (verbatim) | coach |
|---|---|---|---|---|---|---|---|---|---|
| 민호 (diego_ell), ko #1 | 2026-11-22T10:14:12Z | `ko` | elicit | 883 ms | 아니 그게요… 그림으로 먼저 보여줘도 돼요? | model | yes: `민호: "아니 그게요… 그림으로 먼저 보여줘도 돼요?"` | 학생의 생각을 묻는 좋은 시작이에요. 다음에는 조금 더 기다려 주면서 학생이 답을 생각해 볼 시간을 더 주는 건 어떨까요? | model |
| 민호 (diego_ell), ko #2 | 2026-11-22T10:14:32Z | `ko` | revoice | 828 ms | 아니 그게요… 그림으로 먼저 보여줘도 돼요? | model | yes: `민호: "아니 그게요… 그림으로 먼저 보여줘도 돼요?"` | 되말하기로 아이 생각이 모두에게 보이게 됐어요. | fallback |
| 도윤 (noah_g5_fractions), ko #1 | 2026-11-22T10:15:01Z | `ko` | elicit | 607 ms | 음… 8이 4보다 크니까 8분의 1이 더 큰 거 아니에요? | model | yes: `도윤: "음… 8이 4보다 크니까 8분의 1이 더 큰 거 아니에요?"` | 학생의 생각을 잘 이끌어냈어요. 다음엔 조금 더 기다려 줄까요? | model |
| 도윤 (noah_g5_fractions), ko #2 | 2026-11-22T10:15:21Z | `ko` | extend | 901 ms | 8이 4보다 더 크니까 8분의 1이 더 큰 거 아니에요? | model | yes: `도윤: "8이 4보다 더 크니까 8분의 1이 더 큰 거 아니에요?"` | 잘 더 물었어요. 아이가 스스로 따져 보고 있어요. | fallback |

**Result:** 4 of 4 Korean model replies appeared on screen exactly as the Worker sent them, in 607–901 ms. Korean in game is confirmed.

**Repetition with real history.** On each second call the model had its own first reply in `dialogue_tail`, and it still repeated itself:
- 민호 #2 is word for word the same as #1 ("아니 그게요… 그림으로 먼저 보여줘도 돼요?");
- 도윤 #2 differs only by "더".

So the repetition is real, not only an artifact of the first set. The teacher lines in the tail are also English glosses ("So what you're saying is...") in Korean mode. Both are addressed in the prompt-quality fixes.

## Verdict
**Students: the Korean path works.**
- All 8 Korean student replies came from the model, in Korean only, with 존댓말 to the teacher (…요, …돼요?, …아닌가요?).
- Each stays in persona and gives nothing away:
  - 도윤 holds his misconception throughout: "8이 4보다 더 크니까 8분의 1이 더 커요", "분모가 더 크면 더 큰 거 아닌가요?"
  - 민호 reads as a capable recent arrival, not a caricature: he asks to show his thinking with a picture and says plainly what is hard ("아직 한국어로 어떻게 설명해야 할지 잘 모르겠어요").
- No translationese and no English.

**English is unchanged.** Same Noah, same misconception, English coach.

**Flags:**
1. **Repetition.** 민호 says nearly the same thing three times: "선생님… 그림으로 먼저 보여줘도 돼요?" / "그림으로 먼저 보여줘도 돼요? 말로 설명하기가 좀 어려워서요." / "제가 그림으로 보여드려도 돼요?". 도윤 repeats "8이 4보다 더 크니까요" three times.
   - Turn-to-turn variety is weak. The same happens in English, so it is not the Korean path.
   - Next step to look at: whether `dialogue_tail` reaches the prompt.
2. **Prompt example copied.** "아니 그게요…" appears verbatim twice (민호 #2, #3). It is the example hesitation in `tools/student_prompt_ko.txt`, so the model is copying the example.
   - Suggest listing hesitations as kinds ("짧은 머뭇거림") rather than literal phrases.
3. **Coach falls back often.** 6 of 8 Korean coach tips are fixed fallback lines, and 1 of 2 in English (the English #2 student line is a fallback too, returned in 211 ms).
   - This looks like the model call failing intermittently, not the language.
   - The owner can confirm in the Worker logs at the times above (OpenRouter status or a JSON parse failure in `makeCoach`).
4. **Coach model lines.** Two flags:
   - "지금 학생의 생각을 잘 되짚어 주셨어요…" was the reply to a *praise* move, so it names the wrong move.
   - It also uses 주셨어요 / "학생" where the other tips use plain 해요체 and "아이".
   - Worth a native-reader look.

Screens: `docs/qa/korean-hosted/ko_diego_ell_m*.png`, `ko_noah_g5_fractions_m*.png`, `en_noah_m*.png`. Raw request and response bodies: `docs/qa/korean-hosted/*_calls.json`.

## Prompt-quality fixes after this check (PR #9, not deployed)
1. **Repetition.** `dialogue_tail` and `move_history` do reach the prompts in both languages.
   - The student prompt now requires moving on from its own previous line.
   - A reply too similar to that line is rejected and retried (bigram similarity ≥ 0.80).
   - The client now sends the teacher's lines in the player's language.
2. **Copied example.** The Korean rule describes hesitation instead of quoting "아니 그게요…", and a reply that opens with the previous line's first two words is rejected.
3. **Coach.** Model tips are given the move actually made (by its game name), the fixed tips' voice (아이, plain 해요체) and a limit of two short sentences. `validateCoach` enforces this with one retry, then the fixed tip.
4. **Fallback rate.** Causes found by reading the code, most plausible first:
   - **(a) Coach replies cut off at `max_tokens=120`.** A Korean tip of 60–90 syllables plus the JSON wrapper sits at or over the limit. A cut-off reply has no closing `}`, so `JSON.parse` throws and the fixed tip is returned silently. Reproduced with a stub; the limit is now 220 and `finish_reason: "length"` is logged.
   - **(b) Upstream errors.** OpenRouter 429 rate limits or provider 5xx errors fail fast. The English #2 call (211 ms, student and coach both fixed lines) looks like this.
   - **(c) Reject filters.** Before these fixes the coach had none, so this was not a cause then. The new voice filter will add some fallbacks; they are logged as `coach_rejected`.
   - **(d) Timeouts.** No explicit fetch timeout; the client gives up at 12 s. Not seen in the second set (607–901 ms).

   Every fallback point now logs one JSON line, `{"evt":"llm_fallback","where":...,"reason":...}` (student, student_rejected, coach, coach_rejected, classifier, openrouter-truncated). After the next deploy, `wrangler tail` or the Workers logs show the cause directly.

Stub tests: `node --test cloudflare/test/locale.test.mjs`, 18 cases, no network.


## Re-check after the fixes (Worker 78d6b250 from main fe9d6c5, 2026-11-22, 8 calls, UTC)
- **Setup:** same method and allow-list as before (`CC_ALLOW` = the Worker's `/turn` only, `CC_ALLOW_MAX=4` per student). Both runs reported `NETWORK blocked=0`; there were no retries. A dry run first confirmed exactly 4 `POST /turn` per sequence and nothing else.
- **On screen:** "shown" is checked exactly against the Worker's `student_utterance.text`, as in the second set.
- **Fallback detection:** a reply counts as a fallback if it equals one of the Worker's fixed lines, or matches the template `제 생각은요, ${opening line}`.

| run | time (UTC) | locale | move | latency | Worker student line (verbatim) | student | shown on screen, exact | coach tip (verbatim) | coach |
|---|---|---|---|---|---|---|---|---|---|
| 민호 (diego_ell), ko #1 | 2026-11-22T10:29:53Z | `ko` | elicit | 1156 ms | 제 생각은요, 답 알아요. 한국어로 말하는 데 시간이 조금 필요해요. | **fallback** (template `제 생각은요, ${opening line}`) | yes: `민호: "제 생각은요, 답 알아요. 한국어로 말하는 데 시간이 조금 필요해요."` | 좋은 생각 묻기예요. 아이 생각에서 흔들리는 부분을 더 짚어 봐요. | fallback |
| 민호 (diego_ell), ko #2 | 2026-11-22T10:30:13Z | `ko` | revoice | 1588 ms | 네, 맞아요. 그림으로 보여줘도 돼요? | model | yes: `민호: "네, 맞아요. 그림으로 보여줘도 돼요?"` | 되말하기로 아이 생각이 모두에게 보이게 됐어요. | fallback |
| 민호 (diego_ell), ko #3 | 2026-11-22T10:30:33Z | `ko` | extend | 1142 ms | 네, 그림으로 보여줄게요. 이걸로 설명할 수 있어요. | model | yes: `민호: "네, 그림으로 보여줄게요. 이걸로 설명할 수 있어요."` | 잘 더 물었어요. 아이가 스스로 따져 보고 있어요. | fallback |
| 민호 (diego_ell), ko #4 | 2026-11-22T10:30:53Z | `ko` | praise | 843 ms | 네, 이 그림으로 설명할 수 있어요. 이 조각이 더 커요. | model | yes: `민호: "네, 이 그림으로 설명할 수 있어요. 이 조각이 더 커요."` | '잘했어'보다 무엇을 잘했는지 짚어 줘요. | fallback |
| 도윤 (noah_g5_fractions), ko #1 | 2026-11-22T10:31:38Z | `ko` | elicit | 913 ms | 8분의 1이 4분의 1보다 더 커요. 분모가 더 크면 더 큰 거잖아요. | model | yes: `도윤: "8분의 1이 4분의 1보다 더 커요. 분모가 더 크면 더 큰 거잖아요."` | 아이의 생각을 묻는 발문 좋았어요. 다음엔 3-5초 정도 기다려 주면 아이가 더 깊이 생각할 시간을 줄 수 있을 거예요. | model |
| 도윤 (noah_g5_fractions), ko #2 | 2026-11-22T10:31:58Z | `ko` | extend | 634 ms | 더 크게 하려면 분모를 더 크게 해야 하는 거 아니에요? | model | yes: `도윤: "더 크게 하려면 분모를 더 크게 해야 하는 거 아니에요?"` | 아이의 생각을 더 깊게 탐색하기 위해 '더 묻기'를 사용했네요. 이제 아이가 스스로 답을 찾을 수 있도록 잠시 기다려 주는 건 어떨까요? | model |
| 도윤 (noah_g5_fractions), ko #3 | 2026-11-22T10:32:18Z | `ko` | revoice | 994 ms | 제 생각은요, 8분의 1이랑 4분의 1 중에 뭐가 더 크냐고요? …8분의 1이요. 8이 4보다 크잖아요. | **fallback** (template `제 생각은요, ${opening line}`) | yes: `도윤: "제 생각은요, 8분의 1이랑 4분의 1 중에 뭐가 더 크냐고요? …8분의 1이요. 8이 4보다 크잖아요."` | 되말하기로 아이 생각이 모두에게 보이게 됐어요. | fallback |
| 도윤 (noah_g5_fractions), ko #4 | 2026-11-22T10:32:38Z | `ko` | praise | 632 ms | 근데 8분의 1이 더 얇아 보이긴 해요. | model | yes: `도윤: "근데 8분의 1이 더 얇아 보이긴 해요."` | 아이의 생각을 칭찬으로 마무리했네요. 이제 아이의 생각을 더 깊게 탐색해 볼까요? | model |

**Result: worse for students, slightly better for the coach.** Not good enough; the owner may want to roll the Worker back.

| | before the fixes (first set) | after the fixes |
|---|---|---|
| student replies from the model | 8/8 | **6/8** (민호 #1 and 도윤 #3 are the fallback template) |
| coach tips from the model | 2/8 | **3/8** |
| all 8 replies on screen exactly as sent | | yes |
| latency | | 632–1588 ms |

**Likely cause of the student fallbacks: the new filters, not the network.** Both calls returned fast (1156 ms, 994 ms), which fits two rejected attempts and then the fallback.
- **민호 #1** is the first turn. His only previous line is his scripted opening line, and an "elicit" naturally asks him to restate that idea. The repeat or same-opening filter would reject it.
- **도윤 #3** (revoice) asks him to confirm what was said back, which again invites restating his idea.
- The Worker now logs every fallback with its reason (`{"evt":"llm_fallback","where":"student_rejected",...}`), so the logs at **10:29:53** and **10:32:18 UTC** will confirm which filter fired.
- **Suggested fix** (not applied; needs owner approval and a redeploy):
  - don't apply the repeat and opening filters against the scripted opening line;
  - on turn 1 and after a revoice, allow agreeing with or restating one's own idea;
  - when both attempts are rejected only for repetition, prefer the model's second attempt over the fixed line.

**What did improve:**
- **Repetition across turns:** where the model answered, each reply moves on.
  - 민호: "그림으로 보여줘도 돼요?" → "그림으로 보여줄게요. 이걸로 설명할 수 있어요." → "이 조각이 더 커요."
  - 도윤: "분모가 더 크면 더 큰 거잖아요" → "분모를 더 크게 해야 하는 거 아니에요?" → "근데 8분의 1이 더 얇아 보이긴 해요" (a first crack).
- **Copied opening:** gone; no "아니 그게요…" anywhere.
- **Coach:** the 3 model tips use 아이 and plain 해요체 and name the move made ("생각을 묻는 발문", "'더 묻기'를 사용했네요", "칭찬으로 마무리했네요"). But 5 of 8 are still fixed tips, all 4 of 민호's among them. Their logged reasons (`coach`, `coach_rejected`, `openrouter truncated`) are at the times above.

Screens: `docs/qa/korean-hosted/ko3_*_m0..m3.png`; raw bodies and polled screen lines: `ko3_*_calls.json`, `ko3_*_screen_log.txt`.


## Re-check 2 (Worker 58e871a9 from main 6f88913, after the filter calibration; 2026-11-22, 8 calls, UTC)
- **Setup:** same method and allow-list. Both runs reported `NETWORK blocked=0`, no retries. A dry run first confirmed 4 `POST /turn` per sequence and nothing else.

| run | time (UTC) | locale | move | latency | Worker student line (verbatim) | student | shown on screen, exact | coach tip (verbatim) | coach |
|---|---|---|---|---|---|---|---|---|---|
| 민호 (diego_ell), ko #1 | 2026-11-22T10:41:27Z | `ko` | elicit | 1368 ms | 제 생각은요, 답 알아요. 한국어로 말하는 데 시간이 조금 필요해요. | **fallback** (template) | yes: `민호: "제 생각은요, 답 알아요. 한국어로 말하는 데 시간이 조금 필요해요."` | 좋은 생각 묻기예요. 아이 생각에서 흔들리는 부분을 더 짚어 봐요. | fallback |
| 민호 (diego_ell), ko #2 | 2026-11-22T10:41:47Z | `ko` | revoice | 666 ms | 네, 선생님.  제 마음속으로는 알겠는데, 말로 설명하는 게 좀 어려워요. | model | yes: `민호: "네, 선생님.  제 마음속으로는 알겠는데, 말로 설명하는 게 좀 어려워요."` | 되말하기로 아이 생각이 모두에게 보이게 됐어요. | fallback |
| 민호 (diego_ell), ko #3 | 2026-11-22T10:42:07Z | `ko` | extend | 864 ms | 어… 그렇게 물어보시니까 제 처음 답이 맞는지 잘 모르겠어요. | **fallback** (fixed extend line) | yes: `민호: "어… 그렇게 물어보시니까 제 처음 답이 맞는지 잘 모르겠어요."` | 아이의 생각을 더 깊게 탐색하기 위해 '더 묻기'를 사용했어요. 이제 아이가 스스로 답을 찾도록 조금 더 기다려 주는 건 어떨까요? | model |
| 민호 (diego_ell), ko #4 | 2026-11-22T10:42:27Z | `ko` | praise | 562 ms | 선생님, 제가 생각한 거 그림으로 그려도 돼요? | model | yes: `민호: "선생님, 제가 생각한 거 그림으로 그려도 돼요?"` | 아이의 생각을 칭찬해 줬군요. 이제 아이가 스스로 더 깊이 생각할 수 있도록 어떻게 이끌어 줄 건가요? | model |
| 도윤 (noah_g5_fractions), ko #1 | 2026-11-22T10:43:11Z | `ko` | elicit | 839 ms | 8이 4보다 크니까 8분의 1이 더 커요. | model | yes: `도윤: "8이 4보다 크니까 8분의 1이 더 커요."` | 아이의 생각을 묻는 발문 좋았어요. 다음에는 3~5초 정도 기다려 주면 아이가 더 깊이 생각할 시간을 줄 수 있을 거예요. | model |
| 도윤 (noah_g5_fractions), ko #2 | 2026-11-22T10:43:31Z | `ko` | extend | 747 ms | 어… 그렇게 물어보시니까 제 처음 답이 맞는지 잘 모르겠어요. | **fallback** (fixed extend line) | yes: `도윤: "어… 그렇게 물어보시니까 제 처음 답이 맞는지 잘 모르겠어요."` | 아이의 생각을 더 깊게 파고드는 '더 묻기' 발문이 좋았어요. 다음에는 아이가 스스로 답을 찾도록 3~5초 정도 기다려 주는 연습을 해보면 어떨까요? | model |
| 도윤 (noah_g5_fractions), ko #3 | 2026-11-22T10:43:51Z | `ko` | revoice | 753 ms | 음… 8분의 1이랑 4분의 1이랑… 둘 다 분모가 1이니까… 8이 4보다 더 크니까 8분의 1이 더 큰 거 아니에요? | model | yes: `도윤: "음… 8분의 1이랑 4분의 1이랑… 둘 다 분모가 1이니까… 8이 4보다 더 크니까 8분의 1이 더 큰 거 아니에요?"` | 되말하기로 아이 생각이 모두에게 보이게 됐어요. | fallback |
| 도윤 (noah_g5_fractions), ko #4 | 2026-11-22T10:44:11Z | `ko` | praise | 717 ms | 8이 4보다 더 크니까 8분의 1이 더 큰 거 맞죠? | model | yes: `도윤: "8이 4보다 더 크니까 8분의 1이 더 큰 거 맞죠?"` | '잘했어'보다 무엇을 잘했는지 짚어 줘요. | fallback |

**Result: FAIL against the pass criteria.** Stopped before building.

| | requirement | result |
|---|---|---|
| student replies from the model | 8/8 | **5/8** |
| shown on screen as sent | all | all 8 |
| coach tips from the model | clearly better than 2–3 of 8 | **4/8** (민호 #3–#4, 도윤 #1–#2) |
| latency | | 562–1368 ms |

**The three student fallbacks:**
- 민호 #1 (10:41:27, elicit): the template `제 생각은요, ${opening line}`, the same as last time.
- 민호 #3 (10:42:07, extend) and 도윤 #2 (10:43:31, extend): the fixed Korean extend line.

**What this tells us.**
- Repetition is now soft, so these cannot be repetition fallbacks. They come from a hard rule (unparseable output, English letters, length, a generic leak) or from an upstream error.
- Both are extend moves, and in the same calls the coach model answered. So OpenRouter was reachable, and a hard rule rejecting the student's reply twice is the likelier cause.
- Plausible culprits, not testable without the model's rejected text:
  - the generic leak `/선생님 말이 맞/`, which an "extend" naturally invites ("선생님 말이 맞는 것 같기도 해요…");
  - the English-letters rule for 민호, whose persona is a Spanish-speaking recent arrival (a Spanish word or "OK");
  - the 3-sentence cap.
- **The Worker logs settle it.** Each fallback logged `{"evt":"llm_fallback","where":"student_rejected","reason":...}` at 10:41:27, 10:42:07 and 10:43:31 UTC, with the reason and the attempt. Please pull those lines; the fix depends on which rule fired.

**What is fine:**
- Where the model answered, replies move on: 민호 "마음속으로는 알겠는데, 말로 설명하는 게 좀 어려워요" → "제가 생각한 거 그림으로 그려도 돼요?"; 도윤 "분모가 1이니까…" (a new, wrong reason).
- There is no copied opening.
- Model coach tips use 아이 and 해요체 and name the move made ('더 묻기', '칭찬').
- One small flag: 도윤 #4 "8이 4보다 더 크니까 8분의 1이 더 큰 거 맞죠?" restates #1 in a new form (a question asking for confirmation). That is acceptable after praise.

## Re-check 3 with diag (Worker ae110882 from main 66cbd40; 2026-11-22, 8 calls, `CC_DIAG=1`, UTC)
Same allow-list. Both runs reported `NETWORK blocked=0`, with no retries by the runner. The dry run first confirmed 4 `POST /turn` per sequence. The "shown" column was checked exactly, as before. Full `diag`, including rejected texts, is in `korean-hosted/ko5_*_calls.json`.

| call | time (UTC) | move | latency | student line (verbatim) | student diag | shown | coach tip (verbatim) | coach diag |
|---|---|---|---|---|---|---|---|---|
| 민호 #1 | 2026-11-22T10:55:07Z | elicit | 1449 ms | 음... 그림으로 먼저 보여줘도 돼요? | model / repaired:too_long / attempts 1 | yes | 좋은 생각 묻기예요. 아이 생각에서 흔들리는 부분을 더 짚어 봐요. | fallback / parse_error / attempts 2 |
| 민호 #2 | 2026-11-22T10:55:27Z | revoice | 1194 ms | 네, 선생님. 그림으로 먼저 보여줄게요. 이게 더 쉬워요. | model / attempts 1 | yes | 되말하기로 아이 생각이 모두에게 보이게 됐어요. | fallback / parse_error / attempts 2 |
| 민호 #3 | 2026-11-22T10:55:47Z | extend | 1378 ms | 음... 그림으로 보여주면 더 쉬울 것 같아요. | model / repaired:too_long / attempts 1 | yes | 잘 더 물었어요. 아이가 스스로 따져 보고 있어요. | fallback / parse_error / attempts 2 |
| 민호 #4 | 2026-11-22T10:56:07Z | praise | 663 ms | 네... 그림으로 보여드리는 게 더 편해요. 말로 설명하려면 좀 어려워요. | model / repaired:too_long / attempts 1 | yes | 아이의 생각을 칭찬으로만 마무리하면, 더 깊은 생각을 이끌어내기 어려울 수 있어요. 다음에는 아이의 생각을 '더 묻기'로 연결해 보면 어떨까요? | model / attempts 1 |
| 도윤 #1 | 2026-11-22T10:56:54Z | elicit | 690 ms | 8이 4보다 더 크니까 8분의 1이 더 커요. | model / attempts 1 | yes | 아이의 생각을 물어봤어요. 이제 아이가 말할 시간을 충분히 줄까요? | model / attempts 1 |
| 도윤 #2 | 2026-11-22T10:57:14Z | extend | 588 ms | 근데... 8분의 1이랑 4분의 1이랑 똑같이 1인데, 왜 8분의 1이 더 커요? | model / repaired:too_long / attempts 1 | yes | 아이의 생각을 더 깊게 탐색하기 위해 '더 묻기'를 사용했네요. 이제 아이가 스스로 답을 찾도록 3~5초 정도 기다려 주는 건 어떨까요? | model / attempts 1 |
| 도윤 #3 | 2026-11-22T10:57:34Z | revoice | 615 ms | 음... 8이 4보다 더 크니까 8분의 1이 더 커요. | model / repaired:too_long / attempts 1 | yes | 되말하기로 아이의 생각이 모두에게 보이게 됐어요. 이제 아이가 스스로 답을 찾도록 3~5초 기다려 줘요. | model / attempts 1 |
| 도윤 #4 | 2026-11-22T10:57:54Z | praise | 1002 ms | 네, 8이 4보다 크니까 8분의 1이 더 커요. | retry / repeat / attempts 2 | yes | 아이의 생각을 다시 한번 되짚어 주는 건 어떨까요? 그러면 아이가 더 깊이 생각할 기회를 얻을 수 있을 거예요. | model / attempts 1 |

**Students pass.**
- 8/8 from the model: 7 first try, 1 `retry`.
- All shown on screen as sent. No rule fallbacks, and no upstream errors.
- 도윤 #4: the first attempt was a `parse_error` and the second was soft `repeat`, kept (rule working as designed).

**Coach fails on a bug of ours, not the model: 5/8.** All 3 fallbacks (민호 #1–#3) are `parse_error`.
- The rejected texts show good tips as valid JSON followed by trailing junk, e.g. `{"coach_tip": "아이에게 생각 묻기를 잘 했어요. 이제 3-5초 정도 기다려 주면서…"}
}`.
- Our parser slices from the first `{` to the **last** `}`, so the junk breaks it.
- The same happened to 도윤 #4's first student attempt.
- **Fix:** parse the first balanced JSON object and ignore what follows. That would have made all 3 coach tips model-written: 8/8 here.

**Second bug: `repaired: too_long` on short lines.** The sentence count treats "..." as three sentence ends, so 5 short replies were marked repaired. The lines shown are intact, but the count should treat an ellipsis as one mark (or none).

**Repetition.**
- 민호 moves on, though narrowly; every turn is about drawing.
- 도윤 states "8이 4보다 크니까 8분의 1이 더 커요" on #1, #3 (after a revoice, allowed) and #4 (kept after one retry). #2 is a real move ("왜 8분의 1이 더 커요?").
- The prompt rule alone does not stop 도윤 restating after a revoice or praise.


## Re-check 4 after the parser fix (Worker c6641bae from main cb5c3f6; 2026-11-22, 8 calls, `CC_DIAG=1`, UTC)
Same allow-list and the same check as re-check 3. Both runs reported `NETWORK blocked=0`, with no runner retries. The dry run first confirmed 4 `POST /turn` per sequence, all blocked. Full `diag` is in `korean-hosted/ko6_*_calls.json`.

| call | time (UTC) | move | latency | student line (verbatim) | student diag | shown | coach tip (verbatim) | coach diag |
|---|---|---|---|---|---|---|---|---|
| 민호 #1 | 2026-11-22T11:07:21Z | elicit | 2171 ms | 음... 그림으로 보여줘도 돼요? | model / attempts 1 | yes | 아이에게 생각 묻기를 잘 했어요. 이제 3-5초 정도 기다려 주면서 아이가 스스로 답을 구성할 시간을 더 줘 보세요. | model / attempts 1 |
| 민호 #2 | 2026-11-22T11:07:41Z | revoice | 1638 ms | 네, 그림으로 보여드릴게요. 좀만 기다려 주세요. | model / attempts 1 | yes | 되말하기로 아이 생각을 모두에게 보이게 했어요. 이제 아이가 더 설명할 수 있도록 3~5초 기다려 줘요. | model / attempts 1 |
| 민호 #3 | 2026-11-22T11:08:01Z | extend | 707 ms | 아, 네. 그림으로요. 제가 좀 더 생각해 볼게요. | model / attempts 1 | yes | 아이의 생각을 더 깊이 탐색하기 위해 '더 묻기'를 사용했어요. 다음에는 아이가 스스로 답을 찾도록 조금 더 기다려 주는 건 어떨까요? | model / attempts 1 |
| 민호 #4 | 2026-11-22T11:08:21Z | praise | 757 ms | 네, 그림으로 보여드릴게요. 좀만 기다려 주세요. | model / attempts 1 | yes | 아이의 생각을 칭찬으로만 마무리하면, 아이가 더 깊이 생각할 기회를 놓칠 수 있어요. 다음엔 아이의 말을 되짚어주거나 더 묻는 발문으로 이어가면 어떨까요? | model / attempts 1 |
| 도윤 #1 | 2026-11-22T11:09:06Z | elicit | 823 ms | 8분의 1이 더 커요. 분모가 더 크면 분수도 더 큰 거잖아요. | model / attempts 1 | yes | 아이의 생각을 물어봤어요. 이제 아이가 말할 수 있도록 3~5초 정도 기다려 줄까요? | model / attempts 1 |
| 도윤 #2 | 2026-11-22T11:09:26Z | extend | 682 ms | 음... 8분의 1이 더 커요. 분모가 더 크면 더 많은 조각으로 나눈 거니까 더 작아지는 거 아니에요? | model / attempts 1 | yes | 아이의 생각을 더 깊게 파고들기 위해 '더 묻기'를 사용했네요. 이제 아이가 그 생각을 더 발전시킬 수 있도록 기다려 주는 건 어떨까요? | model / attempts 1 |
| 도윤 #3 | 2026-11-22T11:09:46Z | revoice | 562 ms | 음... 8분의 1이 더 커요. 분모가 더 크면 더 많은 조각으로 나눈 거니까 더 작아지는 거 아니에요? | model / attempts 1 | yes | 되말하기로 아이 생각이 모두에게 보이게 됐어요. 이제 아이가 스스로 답을 찾도록 3~5초 기다려 줘요. | model / attempts 1 |
| 도윤 #4 | 2026-11-22T11:10:06Z | praise | 1049 ms | 음... 8분의 1이 더 커요. 분모가 더 크면 더 많은 조각으로 나눈 거니까 더 작아지는 거 아니에요? | retry / same_opening / attempts 2 | yes | 아이의 생각을 칭찬으로 마무리했네요. 이제 아이의 생각이 어떻게 더 발전할 수 있을지, '더 묻기'로 연결해 볼까요? | model / attempts 1 |

**Pass.**
- **Students: 8/8 from the model** (7 `model`, 1 `retry`). All were shown on screen exactly as sent, with no rule fallbacks and no upstream errors.
- **Coach: 8/8 from the model**, all on the first try. There are no `parse_error`s (re-check 3 had 5/8), and no `repaired` marks from "..." anymore.

**Quality notes. These do not block the pass.**
- **도윤 repeats one line:** #2–#4 are the same line ("…더 작아지는 거 아니에요?"). #3 follows a revoice, where a restate is allowed. #4 was a soft `same_opening`; the retry came back identical and was kept as designed. The line itself moves on from #1, because 도윤 starts to doubt the misconception.
- **민호 repeats too:** #4 repeats #2 ("네, 그림으로 보여드릴게요. 좀만 기다려 주세요."). The repeat check compares only with the previous line, so it does not catch this.
- **Possible follow-up, prompt only (no new filter):** give the model the student's last two lines with "do not reuse any of these".
