// Bridges the kit's Playwright import to the skill-local install.
import { createRequire } from "node:module";
import { homedir } from "node:os";
const pw = createRequire(`${process.env.VE_NM}/package.json`)("playwright-core");
const executablePath = process.env.CHROME || `${homedir()}/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome`;
export const chromium = Object.create(pw.chromium, {
  launch: { value: (o = {}) => pw.chromium.launch({ executablePath, args: ["--no-sandbox"], ...o }) },
});
