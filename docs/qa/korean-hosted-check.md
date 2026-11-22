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

## Calls (times are UTC, for the Worker logs)
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
