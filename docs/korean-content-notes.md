# Korean data overlays: notes

## Files written (20, UTF-8 without BOM, all parse with `python -I`)
- data/persona_library/: noah_g5_fractions, talia_dominator, meilin_anxious, deshawn_offtask, diego_ell, jordan_skeptic, marcus_volatile, priya_quiet, riley_avoidant, sam_withdrawn (.json)
- data/scenarios/: culturally_responsive_intro, custom_comparing_decimals, discussion_fractions, group_work_fractions, gym_capstone, independent_fractions, lecture_fractions, reading_main_idea, science_force_motion (.json)
- data/narrative/chapters.json (cast names + all 9 chapters)

Generator scripts (they also check array lengths, placeholders and fallbacks against the source): ..\gen\personas.py, scenarios.py, chapters.py.

Left out on purpose: ids, enums, numbers, colours, paths[].steps, win_moves, `_doc`, `emotion_baseline`, `subject_context`, `behavior_tendencies.language_complexity` (these read as enums). `behavior_tendencies.default_response_length` was translated because the LLM reads it.

## Unsure / needs a decision
1. **Particles after {persona_id}.** Korean particles depend on the name's last syllable, so I wrote them for the fixed Korean names: `{riley_avoidant}이는` gives 유진이는, `{sam_withdrawn}는` gives 시우는, `{diego_ell}는` gives 민호는, `{marcus_volatile}이 의자` gives 태민이 의자. If a name can ever change (custom roster), these break.
2. **Narrator captions use -다 / noun endings** ("종이 울린다.", "교실 문에 처음 붙은 내 이름."), which is the normal Korean caption style. The brief says system sentences use 해요체. Change these if captions count as system text.
3. **Jordan decimals win_line:** Korea has no cents, so "fifty cents vs forty-five cents" became 1000원의 0.5 = 500원 vs 450원. The meaning holds, but the line is wordier.
4. **Tenths/hundredths wording:** Korean textbooks say "0.1이 5개", "0.01이 45개" and "소수 첫째/둘째 자리". Used in Talia, Diego and Priya's lines.
5. **Mr. Hollis (박 선생님) speech level:** a tired veteran talking to a first-year in 해요체 with a dry edge ("28년 차예요, 선생님. … 난 2009년에 접었어요."). He might sound more natural in half-반말.
6. **준서 says "쌤"** ("쌤은 저 좀 아시네요"). That's casual but common for a 5th grader. Swap it for 선생님 if you want it more formal.
7. **Region names:** Equity Caverns became 형평의 동굴 and Questioning Forest became 발문의 숲. Chapter titles are free rewrites (첫 종소리, 마주 보기, 길다고 큰 수는 아니에요, 제자리걸음).
8. **Title separator:** I kept the source's "  -  " and made the layouts into 배치 labels (ㄷ자 배치, 줄 배치, 모둠 배치).
9. **Brownie:** I kept 브라우니 for Noah (asset_hint + connect_line). A Korean-native choice would be 피자 or 케이크.

**A native Korean reader should spot-check the student dialogue** (opening_line, win_line, connect_line, persona_overrides, and the student lines in chapters.json) for kid voice and naturalness.
