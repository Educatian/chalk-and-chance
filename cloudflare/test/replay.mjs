// Replays every line the deployed Worker returned in the hosted checks through the current
// filters, in order, with the context the fixed Worker would see (its own previous lines).
// Used by replay.test.mjs; run directly to print the table: node cloudflare/test/replay.mjs
import { readFileSync } from "node:fs";
import { PERSONAS } from "../gamedata.js";
import { personaFor, validateCoach } from "../locale.js";
import { validateStudent, lastStudentLine, repeatCheckApplies } from "../turn.js";

const runs = JSON.parse(readFileSync(new URL("./fixtures/hosted_lines.json", import.meta.url), "utf8"));

export function replay() {
  const rows = [];
  for (const run of runs) {
    const ko = run.locale === "ko";
    const persona = personaFor(run.persona, PERSONAS[run.persona], ko);
    const tail = [];
    run.calls.forEach((c, i) => {
      const req = { move_history: run.calls.slice(0, i).map((p) => ({ tag: p.move })), dialogue_tail: tail.slice(-6),
        scenario_context: { active_student: { opening_line: c.opening_line } } };
      const verdict = { move_tags: [c.move] };
      const prev = repeatCheckApplies(req, verdict) ? lastStudentLine(req) : "";
      let student = "-";
      if (c.student_source === "model") {
        const [ok, why, soft] = validateStudent(c.student, persona, false, String(persona.grade_band || ""), ko, prev);
        student = ok ? "pass" : (soft ? "soft (retry, then kept)" : "HARD: " + why);
      }
      let coach = "-";
      if (c.coach_source === "model") {
        const [ok, why, hard] = validateCoach(c.coach, ko, c.move);
        coach = ok ? "pass" : (hard ? "HARD: " + why : "soft (retry, then kept): " + why);
      }
      rows.push({ set: run.set, persona: run.persona, turn: c.turn, move: c.move, text: c.student, src: c.student_source, prev, student, coach_src: c.coach_source, coach });
      tail.push({ speaker: "teacher", text: c.move });
      if (c.student_source === "model") tail.push({ speaker: persona.display_name || "student", text: c.student });
    });
  }
  return rows;
}

if (import.meta.url === `file:///${process.argv[1].replace(/\\/g, "/")}`) {
  for (const r of replay()) console.log([r.set, r.persona, r.turn, r.move, r.src, r.student, r.coach_src, r.coach, r.text].join(" | "));
}
