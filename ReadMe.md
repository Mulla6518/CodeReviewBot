# CodeReviewBot

A Swift Package for building a “code review bot” workflow in Swift — intended to automate review-style feedback (lint-like suggestions, heuristics, or AI-driven analysis) and integrate it into your development process.

> Repo status: early-stage (new package scaffold). Contributions and iteration welcome.

## Features

- ✅ Swift Package Manager (SPM) project structure
- ✅ MIT licensed
- ⏳ Bot engine (rules / analyzers) — extend in `Sources/CodeReviewBot`
- ⏳ Integrations (GitHub PR comments / CI) — add as needed

## Project Structure

- `Sources/CodeReviewBot/` — main library source (core bot logic) :contentReference[oaicite:1]{index=1}  
- `Package.swift` — Swift Package manifest (SPM) :contentReference[oaicite:2]{index=2}  
- `Package.resolved` — dependency lock file :contentReference[oaicite:3]{index=3}  
- `LICENSE` — MIT License :contentReference[oaicite:4]{index=4}  

## Requirements

- Swift 5.9+ (recommended)
- macOS or Linux (depending on how you run it)
- Xcode (optional, if you prefer IDE builds)

## Installation

### Add via Swift Package Manager

In your `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/Mulla6518/CodeReviewBot.git", from: "0.1.0")
],
targets: [
  .target(
    name: "YourTarget",
    dependencies: [
      .product(name: "CodeReviewBot", package: "CodeReviewBot")
    ]
  )
]
```

Or in Xcode:

- File → Add Packages…
- Paste: https://github.com/Mulla6518/CodeReviewBot
- Select a version / branch

## Usage
> Update the API examples below once your public interfaces are finalized.

### As a library
```swift
import CodeReviewBot

// Example (placeholder):
// let bot = CodeReviewBot()
// let report = try bot.review(diff: myDiffString)
// print(report.summary)
```

### As a CLI (optional)
If you plan to ship a CLI target, you can add a separate executable target (e.g. CodeReviewBotCLI)
and support a workflow like:

```bash
# Example (placeholder)
codereviewbot review --diff ./changes.diff --format markdown
```

## Configuration (optional)
If you integrate with GitHub / CI, you’ll typically configure via environment variables:

* GITHUB_TOKEN — GitHub token with permission to read PRs and post comments
* GITHUB_REPOSITORY — owner/repo
* PR_NUMBER — pull request number
* OPENAI_API_KEY / ANTHROPIC_API_KEY / etc. — if you add LLM-backed review

> Keep secrets in GitHub Actions Secrets (never hardcode them).

## GitHub Actions Example (optional)

If you want this repo to run on pull requests, you can add something like:

Create .github/workflows/code-review-bot.yml:
```yaml
name: CodeReviewBot

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write

    steps:
      - uses: actions/checkout@v4

      - name: Set up Swift
        uses: swift-actions/setup-swift@v2
        with:
          swift-version: "5.9"

      - name: Build
        run: swift build -c release

      # Replace with your executable target / invocation once implemented
      - name: Run bot (placeholder)
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          # OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
        run: |
          echo "TODO: Run CodeReviewBot against this PR"
```

## Development
### Build
```bash
swift build -c release
```

# Run against your project sources
```bash
./.build/release/codereview-bot /path/to/YourApp \
  --format md \
  --diff /path/to/last.diff
```

## Xcode integration (Build Phase)
Project → Target → Build Phases → + New Run Script Phase

```bash
BOT_PATH="${SRCROOT}/../CodeReviewBot/.build/release/codereview-bot"
SRC_PATH="${SRCROOT}"
REPORT_FORMAT="md"

if [ -f "$BOT_PATH" ]; then
  "$BOT_PATH" "$SRC_PATH" --format "$REPORT_FORMAT" > "$SRCROOT/CodeReviewBot.md"
  # Fail build on errors
  if grep -q "\[ERROR\]" "$SRCROOT/CodeReviewBot.md"; then
    echo "CodeReviewBot found errors. See CodeReviewBot.md"
    exit 1
  fi
else
  echo "CodeReviewBot not found. Build it first: swift build -c release"
fi
```

## Pre‑commit hook (optional)
.git/hooks/pre-commit:
```bash
#!/bin/bash
set -e
BOT="./.build/release/codereview-bot"
[ -f "$BOT" ] || swift build -c release
$BOT "." --format md > CodeReviewBot.md
if grep -q "\[ERROR\]" CodeReviewBot.md; then
  echo "✗ Pre-commit blocked by CodeReviewBot findings."
  exit 1
fi
```

## GitHub Actions (CI)
.github/workflows/ci.yml:
```yaml
name: CodeReviewBot CI
on: [pull_request]
jobs:
  review:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build Bot
        run: swift build -c release
      - name: Run Bot
        run: ./.build/release/codereview-bot . --format md > CodeReviewBot.md
      - name: Annotate PR
        uses: marocchino/sticky-pull-request-comment@v2
        with:
          header: CodeReviewBot
          message: |
            **CodeReviewBot Report**
            ```
            ${{ steps.run-bot.outputs.report }}
            ```
```

## Extending rules
* _Static analyzers_: integrate SwiftLint / SwiftFormat by spawning subprocesses and converting their output to Finding.
* _Performance gates_: parse XCTest perf metrics (launch/scroll) and fail PRs on baseline drift.
* _Accessibility coverage_: extend the rule to scan SwiftUI .accessibilityHidden, .accessibilityHint, etc.
* _Security_: flag NSAllowsArbitraryLoads, plaintext http://, or weak ATS configs.
* _Size budgets_: integrate IPA size checks (e.g., xcodebuild -exportArchive) and warn on diffs > threshold.

## Optional LLM wiring
If you want true AI feedback, implement the HTTP call in OpenAIProvider (or Azure OpenAI) and set:
```bash
export AI_PROVIDER=openai
export OPENAI_API_KEY=sk-*****
export OPENAI_MODEL=gpt-4o-mini
```

## What is this main.swift does
### Arguments:
```bash
codereview-bot <source-root>
--format md|json, --out <path>, --diff <path>, --config <path>
Perf: --xcresult, --perf-current, --perf-baseline, --perf-test-filter, --perf-tol key=value …
Size: --ipa, --size-baseline <MB>, --size-abs <MB>, --size-diff <MB>, --size-pct <percent>
```

> Runs rules (file + project), gathers findings, computes perf + size gates, generates AI summary, prints a Markdown (or JSON) report.


### CI behavior: exits 1 if:

* any Finding has severity ERROR
* perf comparison fails tolerances
* size budget fails thresholds

## Quick usage examples

### Basic run
```bash
codereview-bot ./MyApp --format md
```

### With YAML/JSON config and PR diff
```bash
codereview-bot ./MyApp --config .github/code-review.yml --diff ./last.diff --out CodeReviewBot.md
```

### Perf compare (XCTest xcresult vs baseline CSV)
```bash
codereview-bot ./MyApp \
  --xcresult DerivedData/.../Test.xcresult \
  --perf-baseline perf-baseline.csv \
  --perf-tol launch.mean=5 cpu.mean=7 memory.mean=10
```

### Size budget gate
```bash
codereview-bot ./MyApp \
  --ipa build/export/MyApp.ipa \
  --size-baseline 246.8 \
  --size-abs 250 \
  --size-diff 3.0 \
  --size-pct 1.0 \
  --out CodeReviewBot.md
```

## Lint / Formatting (recommended)

* SwiftFormat
* SwiftLint

(If you add these, document the exact commands and config files here.)

### Roadmap

 * Define public CodeReviewBot API (inputs: diff/files; outputs: findings/report)
 * Add rule engine (style, correctness, performance, security checks)
 * Add GitHub PR integration (post comments / review summary)
 * Add optional LLM-backed reviewer (guardrails + cost controls)
 * Add sample project + end-to-end CI example

## Contributing

PRs are welcome.

## Suggested workflow:

* Fork the repo
* Create a feature branch: git checkout -b feature/my-change
* Commit changes
* Open a PR with a clear description + screenshots/logs if relevant

## License
MIT — see LICENSE