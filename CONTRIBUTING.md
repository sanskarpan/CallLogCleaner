# Contributing to CallLogCleaner

Thank you for taking the time to contribute. This document covers everything you need to get your development environment set up, understand the code conventions, and get a pull request merged.

---

## Table of Contents
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Code Style](#code-style)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)
- [Reporting Bugs](#reporting-bugs)
- [Requesting Features](#requesting-features)

---

## Getting Started

### Prerequisites
- macOS 13.0 or later
- Xcode 15.0 or later
- An encrypted iPhone backup to test against (see [README](README.md#usage))

### Setup

```bash
# 1. Fork the repo on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/CallLogCleaner.git
cd CallLogCleaner

# 2. Open in Xcode
open CallLogCleaner.xcodeproj

# 3. Build (Cmd+B) — no dependencies to resolve
```

### Quick type-check (no Xcode needed)

```bash
SDK=$(xcrun --sdk macosx --show-sdk-path)
xcrun swiftc -typecheck -sdk "$SDK" -target arm64-apple-macosx13.0 \
  CallLogCleaner/**/*.swift CallLogCleaner/*.swift
```

Zero errors means the project compiles cleanly.

---

## Project Structure

```
CallLogCleaner/
├── Models/        Pure value types — no I/O, no UI imports
├── Utilities/     Low-level, reusable primitives (SQLite, Crypto)
├── Services/      Stateful objects that do I/O
├── Components/    Reusable SwiftUI components, design-system-aware
└── Views/         Full SwiftUI views, backed by AppViewModel
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full layer diagram and dependency rules.

---

## Code Style

### Swift
- Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- No `var` where `let` works
- Prefer `guard` over nested `if` for early returns
- Mark everything `private` or `internal` by default; promote to `public` only if needed
- `@MainActor` on anything that touches `AppViewModel` or SwiftUI state

### Design system
- **Never** use raw numeric literals for spacing, radius, or colour in views — use `Spacing.*`, `Radius.*`, `Color.app*` from `DesignSystem.swift`
- New reusable components go in `Components/` with no business logic

### macOS version compatibility
- Deployment target is **macOS 13.0** — do not use any API introduced after 13.0 without an `if #available(macOS 14, *)` guard
- In practice: `SectorMark` (Swift Charts pie chart) requires macOS 14 — use `DonutChartView` instead

### File header
No copyright headers or `//  Created by` lines. The git history is the authoritative record of authorship.

---

## Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>

[optional body]

[optional footer: Closes #N]
```

**Types:**
| Type | When to use |
|------|-------------|
| `feat` | New feature or behaviour |
| `fix` | Bug fix |
| `refactor` | Code restructuring without behaviour change |
| `docs` | Documentation only |
| `chore` | Build system, CI, tooling |
| `test` | Adding or updating tests |
| `perf` | Performance improvement |

**Scopes (use the directory name):**
`models`, `utilities`, `services`, `components`, `views`, `viewmodel`, `xcode`, `website`, `docs`

**Examples:**
```
feat(services): add progress reporting to BackupModifier
fix(utilities): handle empty WPKY tag in BackupKeyBag TLV parser
docs(encryption): add RFC 3394 unwrap error code table
```

Keep the summary under 72 characters. If you need more, use the body.

---

## Pull Request Process

1. **Create an issue first** for anything non-trivial so the approach can be discussed before you invest time coding
2. **Branch from `main`** using the naming convention: `feat/<short-description>`, `fix/<short-description>`, `docs/<short-description>`
3. **One concern per PR** — keep PRs focused; a large PR covering multiple unrelated changes will be asked to split
4. **Reference the issue** — include `Closes #N` in the PR description or commit message
5. **Self-review** — read your own diff before requesting review; check for debug prints, hardcoded paths, and leftover TODOs
6. **Type-check** — run the `swiftc -typecheck` command above and confirm zero errors before opening the PR

### PR description template
```markdown
## Summary
- Bullet-point summary of what changed and why

## Test plan
- [ ] Step 1
- [ ] Step 2
```

---

## Reporting Bugs

Open a GitHub issue with:
- macOS version
- iOS version of the backup you tested against
- Steps to reproduce
- Expected behaviour vs actual behaviour
- Any error messages or console output

For crashes, include the crash log from `Console.app` → Crash Reports.

---

## Requesting Features

Open a GitHub issue describing:
- The user problem you're trying to solve (not just the solution)
- Whether you're willing to implement it

---

## Questions?

Open a GitHub Discussion — don't use issues for general questions.
