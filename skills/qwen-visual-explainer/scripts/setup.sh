#!/usr/bin/env bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
npm install --prefix "$SKILL_DIR" --no-save playwright-core
npx --yes --prefix "$SKILL_DIR" playwright install chromium
