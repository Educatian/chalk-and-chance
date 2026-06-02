const { chromium } = require("playwright");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..");
const videoDir = path.join(repoRoot, "dist_web", "videos");
const output = path.join(videoDir, "chalk-and-chance-showcase.webm");
const url = process.argv[2] || "http://127.0.0.1:8877/showcase.html";

const scenes = [
  [".hero", "Step 1: Start the rehearsal. You see a classroom, not a menu puzzle. Study the room as a practice space. Feel that mistakes are expected data.", 8200],
  ["#play", "Step 2: Open the demo gate. The public taste demo keeps spoken student lines silent, while voice-enabled review sessions use a passcode.", 8200],
  ["#play", "Step 3: Read the first screen calmly. Class sign-in is for assigned courses. Settings explains whether voice is protected, unavailable, or enabled.", 8200],
  ["#screens", "Step 4: Use the Mission Hub as a learning map. You see START HERE, badges, and locked missions. Study badges as practice goals, not prizes only.", 8400],
  ["#screens", "Step 5: Before playing, notice Settings and Import. Settings show sound effects, voice status, text size, motion, and dialogue speed.", 8600],
  ["#screens", "Step 6: In the classroom, look at students and the objective checklist. Study attention, composure, participation, wait time, and disruptions as live teaching signals.", 8600],
  ["#screens", "Step 7: Move near students and press Z, Enter, or Space. You are not collecting points; you are deciding when to enter a student thinking moment.", 8000],
  ["#screens", "Step 8: In an Encounter, read the student's words first. Study the hidden need: confusion, dominance, avoidance, anxiety, or off-task behavior.", 8000],
  ["#screens", "Step 9: Choose a teaching move. Elicit asks for reasoning, Extend presses deeper, Revoice clarifies, and Wait protects thinking time.", 8000],
  ["#screens", "Step 10: Use social moves carefully. Connect draws on student assets, Praise names useful effort, Redirect protects order, and Tell gives an answer but reduces practice.", 8600],
  ["#screens", "Step 11: After each move, read the result chip. Study what changed: understanding, engagement, rapport, and order. Feel the classroom respond to your decision.", 8600],
  ["#qa", "Step 12: At the debrief, do not just check pass or miss. Study the missed-objective tip and name what you noticed before replaying.", 8200],
  ["#qa", "Step 13: Treat replay as deliberate practice. Pick one focus, such as wait time or reaching quiet students, then try again with a clearer teaching intention.", 8200],
];

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    deviceScaleFactor: 1,
    recordVideo: {
      dir: videoDir,
      size: { width: 1280, height: 720 },
    },
  });
  const page = await context.newPage();
  await page.goto(url, { waitUntil: "networkidle", timeout: 60000 });
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
    document.querySelector("#recording-caption").textContent = "The point is to see the classroom, study your choices, and feel how teaching moves change student thinking.";
    window.scrollTo({ top: 0, behavior: "auto" });
  });
  await sleep(5200);

  const video = page.video();
  await page.close();
  if (video) {
    await video.saveAs(output);
  }
  await context.close();
  await browser.close();
  console.log(output);
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
