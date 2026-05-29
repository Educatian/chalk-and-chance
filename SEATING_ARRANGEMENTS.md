# Seating Arrangements (evidence-based)

The classroom layout is not cosmetic; in this sim it is a teaching decision the player
should learn to make. The core principle from the research is **let the task dictate the
arrangement** (Wannarka & Ruhl, 2008). So Chalk & Chance picks the arrangement per scenario
rather than using one generic grid.

## What the literature says

| Arrangement | Best for | Effect (evidence) |
|---|---|---|
| **Rows / columns** | Independent work, tests, direct instruction | Highest on-task behavior during individual tasks; disruptive students benefit most. Has a front-center "action zone" of higher participation. (Wannarka & Ruhl 2008; Marx, Fuhrer & Hartig 1999) |
| **U-shape / horseshoe (semicircle)** | Whole-class discussion, questioning | Students ask **more questions** than in rows; face-to-face contact promotes interaction; teacher reaches the center. (Marx, Fuhrer & Hartig 1999; Wannarka & Ruhl 2008) |
| **Clusters / pods (groups of 4-6)** | Collaborative / group work | More social interaction and active participation in discussion, but more off-task during individual work. (Wannarka & Ruhl 2008) |

Caveat (the honest version): effects are modest and task-dependent; rows are not "better"
universally, and groups are not "better" universally. The teaching skill is matching the
layout to the lesson. (See the Learning & the Brain summary, which stresses how limited the
causal evidence is.)

## How the game uses it

- The **Questioning Forest** scenario (eliciting and discussion) uses a **U-shape /
  horseshoe**: students seated around the U facing the center, the open end toward the
  board, and the teacher works the central action zone. This is the evidence-based choice
  for a questioning lesson and it pairs with the proximity/withitness layer (a central
  position reaches more of the U, so circulating and scanning are rewarded).
- Future scenarios should switch arrangement by task:
  - a **Classroom Management / independent-work** scenario -> **rows** (maximize on-task);
  - a **collaborative** scenario -> **clusters/pods** (and then the management challenge is
    the higher off-task risk that groups create).
- Implementation: `Overworld.SEATS` is a list of seat tiles defining the arrangement, and
  `ROSTER` maps students to seats; swapping the arrangement is just a different `SEATS`
  list. A later mechanic (ENVIRONMENT_MECHANICS.md, "seating-chart planning phase") lets the
  player choose the arrangement and seat individual students, making this an explicit
  pre-class decision with consequences.

## Sources

- Wannarka, R., & Ruhl, K. (2008). Seating arrangements that promote positive academic and
  behavioural outcomes: a review of empirical research. Support for Learning, 23(2), 89-93.
  https://nasenjournals.onlinelibrary.wiley.com/doi/abs/10.1111/j.1467-9604.2008.00375.x
- Marx, A., Fuhrer, U., & Hartig, T. (1999). Effects of classroom seating arrangements on
  children's question-asking. Learning Environments Research, 2, 249-263.
  https://link.springer.com/article/10.1023/A:1009901922191
- Rows vs. Pods: What Seating Research Says (and Doesn't Say). Learning & the Brain.
  https://www.learningandthebrain.com/blog/rows-vs-pods-what-seating-research-says-and-doesnt-say/
- Classroom Seating Arrangements. Yale Poorvu Center for Teaching and Learning.
  https://poorvucenter.yale.edu/teaching/teaching-resource-library/classroom-seating-arrangements

(Run refcheck before any publication-facing use.)
