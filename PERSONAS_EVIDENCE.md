# Persona Selection and Design - Evidence Base

Every student persona is a *teaching context worth rehearsing*, chosen and designed from the
research. This document states (1) the selection criteria, (2) the high-impact anchor for
each persona's archetype and the teacher move that works, prioritized by citation impact.
Citation counts are from OpenAlex (verified this session where marked); others are canonical
works flagged `[refcheck]` to confirm exact DOI/counts before any publication-facing use.

## Selection criteria (why these ten)

1. **One distinct high-leverage practice per persona.** Each maps to a different
   TeachingWorks high-leverage practice / documented classroom demand, so the roster gives
   broad coverage rather than ten variants of one skill.
2. **Anchored to the highest-impact source available.** We prefer seminal or meta-analytic,
   most-cited works (impact = citation count + canonical status), so what the game trains is
   what the strongest evidence says matters.
3. **Spans the five badge regions** (Routine, Echo, Balance, Mirror, Insight): management,
   questioning, equity, feedback, diagnosis.
4. **Represents consequential, common realities** teachers report and research documents
   (disengagement, dominance, off-task, anxiety/mindset, language, avoidance-as-defiance,
   relevance, overlooked competence, volatility).

## Persona -> behavior -> high-impact anchor

| Persona | Archetype / context | Teacher move that works (target) | Primary high-impact anchor | Cites | Verify | Badge |
|---|---|---|---|---|---|---|
| **Mei-Lin** | Anxious, fixed-mindset; reads a mistake as "not smart" | Feedback about the **process/strategy**, not the person | Hattie & Timperley, *The Power of Feedback*, RER (2007), DOI 10.3102/003465430298487 | **11,896** | OpenAlex-verified | Mirror |
| | (mindset half) | Avoid person-praise; praise effort/strategy | Mueller & Dweck, *Praise for intelligence...*, JPSP (1998); Dweck, *Mindset* | high | [refcheck] | |
| **Sam** | Withdrawn / disengaged; stays silent to avoid being wrong | Warm invitation + advance notice + wait time (re-engage) | Fredricks, Blumenfeld & Paris, *School Engagement: Potential of the Concept...*, RER (2004), DOI 10.3102/00346543074001059 | **11,651** | OpenAlex-verified | Balance |
| **Riley** | Avoidance that reads as defiance (hidden skill gap) | Diagnose the **function** of the behavior before responding | Jacobs, Lamb & Philipp, *Professional Noticing of Children's Mathematical Thinking*, JRME (2010), DOI 10.5951/jresematheduc.41.2.0169 (attend-interpret-decide) | **1,359** | OpenAlex-verified | Insight |
| | (function of behavior) | Functional behavioral assessment lens | FBA literature (O'Neill et al.; Gresham) | high | [refcheck] | |
| **Deshawn** | Off-task disruptor | **Least-to-most intrusive** redirect; behavior-specific praise | Simonsen, Fairbanks, Briesch, Myers & Sugai, *Evidence-based Practices in Classroom Management*, ETC (2008), DOI 10.1353/etc.0.0007 | **926** | OpenAlex-verified | Routine |
| **Marcus** | Volatile / easily frustrated | Affect-first, calm, **private** de-escalation (not public power struggle) | Simonsen et al. 2008 (above) + Roorda et al., *The Influence of Affective Teacher-Student Relationships...*, RER (2011) | 926 / high | verified / [refcheck] | Routine |
| **Noah** | Holds a frozen misconception | **Elicit/extend** to surface reasoning; conceptual change (don't just tell) | Smith, diSessa & Roschelle, *Misconceptions Reconceived*, JLS (1994); + Jacobs 2010 | high | [refcheck] / verified | Echo |
| **Talia** | Dominates airtime | Validate briefly, then **redistribute the turn**; equitable participation | Dallimore, Hertenstein & Platt, *Impact of Cold-Calling...*, JME (2012), DOI 10.1177/1052562912446067; Kounin (1970) group alerting | mid / high | [refcheck] | Balance |
| **Priya** | Quiet but competent; easily overlooked | **Deliberate, equitable** attention distribution | Dallimore et al. 2012 (above); Cohen & Lotan, *Designing Groupwork / status* | mid / high | [refcheck] | Balance |
| **Diego** | English-language learner | Extended **wait time** + comprehension checks + allow representation first | Rowe, *Wait Time...*, JTE (1986), DOI 10.1177/002248718603700110; Echevarria, Vogt & Short (SIOP); Krashen input | high | verified / [refcheck] | Echo |
| **Jordan** | Relevance skeptic ("when will I use this?") | Acknowledge + make it **relevant (utility value)**, then press | Hulleman & Harackiewicz, *Promoting Interest and Performance...*, Science (2009); Eccles & Wigfield expectancy-value | high | [refcheck] | Echo |

## Impact note

The two load-bearing anchors are among the most-cited papers in all of education:
**Hattie & Timperley 2007 (~11.9k)** for feedback and **Fredricks et al. 2004 (~11.7k)** for
engagement. The management spine is **Simonsen et al. 2008** (the standard evidence-based
classroom-management review) and the diagnosis spine is **Jacobs et al. 2010** (the canonical
professional-noticing framework). These four are OpenAlex-verified here; the remaining
anchors are canonical works to confirm with the `refcheck` skill (exact DOI + current
counts) before any paper-facing claim.

## How this drives the game

- Each persona's `target_label`, `opening_line`, and `win_line` in
  `data/persona_library/*.json` encode the move-that-works above, so "solving" a student
  rehearses the evidence-based response (not a generic chat).
- Personas are distributed across scenes by fit (e.g., independent-work scene foregrounds
  Riley/Marcus/Deshawn; discussion foregrounds Noah/Jordan/Priya/Sam), so each scene
  rehearses a coherent cluster of practices.
- Badges map personas to the five competency regions, giving an evidence-aligned
  progression.
