# Qwen visual explainer

A weak-model wrapper for local LLMs, tuned on qwen3.8-27b, that turns structured content into a visual explainer. It uses the upstream visual-explainer renderer included alongside this skill.

## Install

From the repository root, run `skills/qwen-visual-explainer/scripts/setup.sh`. This installs Playwright locally and its Chromium browser; Node.js, npm, and Python 3 are required.

## Use

Copy `templates/content.json`, fill in the topic, then ask your model: “Use the qwen-visual-explainer skill to explain [topic]; save the output to [directory].” The runner accepts `scripts/make.sh <content-file> <out-dir>`.

## Results

Best version: v3, overall score 5.5. Critic-assessed scores (not benchmarks): v1 3.5, v2 5.2, v3 5.5. Scores are an AI critic's assessment, not benchmark results.

Example output: [B+ tree explainer](examples/bplus-tree.png) and [phone layout](examples/bplus-tree-phone.png), from the best attempt on concurrent B+ tree insertion. Both files are under 1 MB.

## License

The upstream repository's MIT license applies. This wrapper modifies the upstream skill's packaging and execution for local qwen3.8-27b models.

Usman Mustafa
