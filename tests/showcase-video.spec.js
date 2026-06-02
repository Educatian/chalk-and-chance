const { test } = require("playwright/test");

const scenes = [
  [".hero", "Start here: Chalk & Chance is a short teaching rehearsal. Your goal is to keep students thinking, engaged, and supported.", 4800],
  ["#play", "On the first screen, choose Play demo to begin immediately. Sign in / Join is only for class accounts that save progress.", 5600],
  ["#play", "Skip sign in plays as a guest. The class code, name, and password fields are for assigned classroom use.", 5000],
  ["#screens", "In the Mission Hub, pick the row marked START HERE first. Locked missions tell you which badge you need before trying them.", 5600],
  ["#screens", "Use Import a lesson plan to turn your own lesson text into a scenario. Use Settings for sound, larger text, reduced motion, and dialogue speed.", 5600],
  ["#screens", "During a lesson, move with arrow keys or WASD. Press Z, Enter, or Space when facing a student to talk with them.", 5400],
  ["#screens", "The objective checklist is the learning target for the activity: attention, composure, wait time, participation, and disruptions.", 5600],
  ["#screens", "Encounter buttons are teaching moves. Elicit asks for reasoning, Extend presses deeper, Revoice restates, and Wait gives thinking time.", 6200],
  ["#screens", "Connect links to a student asset, Praise names useful effort, Redirect handles off-task behavior, and Tell gives the answer directly.", 6200],
  ["#screens", "Read the result chips as feedback: they show how your move changed understanding, engagement, rapport, and classroom order.", 6000],
  ["#qa", "The activity is not about guessing the right button. It is deliberate practice: each move gives evidence about a teaching competency.", 6200],
  ["#qa", "At the debrief, choose what you noticed, read the missed-objective tip, and replay with one specific teaching focus.", 4800],
];

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

test.use({
  viewport: { width: 1280, height: 720 },
  deviceScaleFactor: 1,
  video: "on",
});

test("record player-facing showcase walkthrough", async ({ page }) => {
  await page.goto(process.env.SHOWCASE_URL || "http://127.0.0.1:8877/showcase.html", {
    waitUntil: "networkidle",
    timeout: 60000,
  });

  await page.addStyleTag({
    content: `
      html { scroll-behavior: auto !important; }
      #recording-caption {
        position: fixed;
        left: 50%;
        bottom: 28px;
        transform: translateX(-50%);
        z-index: 999999;
        width: min(1040px, calc(100vw - 48px));
        padding: 16px 20px;
        border: 1px solid rgba(255,255,255,.22);
        border-radius: 10px;
        background: rgba(5, 8, 18, .88);
        color: #f5f1dc;
        font: 800 24px/1.35 Inter, system-ui, sans-serif;
        text-align: center;
        text-shadow: 0 2px 3px rgba(0,0,0,.85);
        box-shadow: 0 12px 34px rgba(0,0,0,.36);
      }
      #recording-label {
        position: fixed;
        right: 18px;
        top: 18px;
        z-index: 999999;
        padding: 8px 10px;
        border-radius: 999px;
        background: rgba(98,195,111,.94);
        color: #05150a;
        font: 900 12px/1 Inter, system-ui, sans-serif;
        letter-spacing: .08em;
      }
    `,
  });
  await page.evaluate(() => {
    const caption = document.createElement("div");
    caption.id = "recording-caption";
    caption.textContent = "";
    const label = document.createElement("div");
    label.id = "recording-label";
    label.textContent = "PLAYER GUIDE";
    document.body.append(caption, label);
  });

  for (const [selector, caption, ms] of scenes) {
    await page.locator(selector).scrollIntoViewIfNeeded();
    await page.evaluate((text) => {
      document.querySelector("#recording-caption").textContent = text;
    }, caption);
    await sleep(ms);
  }

  await page.evaluate(() => {
    document.querySelector("#recording-caption").textContent = "Start with the demo, try one teaching move at a time, and use the debrief to turn play into practice.";
    window.scrollTo({ top: 0, behavior: "auto" });
  });
  await sleep(3600);
});
