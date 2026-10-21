---
name: qwen-visual-explainer
description: Make a polished single-page HTML visual explainer and PNG for a technical concept. Use for visual explanations, process diagrams, or system overviews.
---
# Qwen visual explainer
The script draws one diagram from your JSON and lays it out itself. You write content only: never positions, sizes, or directions.
1. Copy `templates/content.json` and fill it: `title`; `claim` (one sentence, the caption); 2–6 `groups` (subsystems, stages, or parallel parts) with 6–16 `nodes` in total; `links` between nodes.
2. Draw every relationship as a link with a short verb. A link that closes a loop is drawn dotted as feedback. Two links out of one node show a branch (`accept` / `reject`). Link across groups to show how the parts interact.
3. Put numbers, symbols, and equations in a node's `note`; there is no other prose.
4. Run `scripts/make.sh <content-file> <out-dir>`. Each `FIX:` line names one problem and its fix; edit the JSON and rerun until it prints `"ok": true`.
5. Open `explainer.png` and `explainer-phone.png`. Check that each part of the topic and each relationship is drawn and correct.
