# Contributing to enginedge-datalake

Thanks for your interest in contributing! We welcome improvements, bug fixes, tests, docs, and ideas. This document explains the preferred workflow and standards to make collaboration predictable and efficient.

## Table of contents

- Reporting bugs
- Proposing features
- Getting started (fork/clone)
- Development workflow (branching & commits)
- Pull request process
- Code style & tests
- Review checklist
- Code of Conduct & license

## Reporting bugs

1. Search existing issues to avoid duplicates.
2. If none exists, open an issue with these details:
   - Clear summary and steps to reproduce
   - Expected vs actual behavior
   - Minimal example or logs (if applicable)
   - Environment (OS, Docker, versions)

## Proposing features

Open an issue describing the problem and the proposed solution. If it's a non-trivial change, a brief design or proposed API helps reviewers move faster. Label suggestions (enhancement, discussion) are appreciated.

## Getting started

- Fork the repository on GitHub and clone your fork.
- Work on a branch per change.

Example (PowerShell):

```powershell
# fork via GitHub UI, then clone
git clone https://github.com/Chris-Alexander-Pop/enginedge-datalake.git
cd enginedge-datalake
# create a feature branch
git checkout -b feature/<issue-number>-short-description
```

If the repository README has a development or setup section, follow it to get local services running (Docker Compose, Airflow, Spark, Postgres, etc.). If anything is missing or unclear, open an issue so we can improve onboarding.

## Development workflow

- Branch naming: `feature/<id>-short-desc`, `fix/<id>-short-desc`, or `chore/<short-desc>`.
- Rebase or pull latest `main` before opening a PR to keep history linear.
- Keep changes focused: one logical change per PR.

Commit message guidance:

- Use concise, descriptive commit messages.
- Prefer the Conventional Commits style where helpful, e.g.:

  `feat(parser): add support for X`

  `fix(api): handle null response from Y`

This helps changelogs and reviewers.

## Pull Request process

1. Create a PR from your feature branch to `main` (or target branch specified in the issue).
2. In the PR description, include:
   - A short summary of the change
   - Related issue number (use `Fixes #123` to auto-close)
   - Any required setup to test the change
   - Notes on backward-incompatibility (if any)
3. Add reviewers and request changes if tests or CI fail.

PR checklist (used by maintainers and contributors):

- [ ] PR targets the correct branch (`main`)
- [ ] Linked issue (if applicable)
- [ ] Tests added or updated (unit/integration)
- [ ] Documentation updated (README, docs, comments)
- [ ] All tests pass locally and in CI
- [ ] No sensitive data or secrets included

## Code style & tests

We aim for clear, consistent code. Please run linters and tests before opening a PR. If this project uses language-specific tooling (ESLint, Prettier, flake8, black, scalafmt, etc.), try to follow those rules or add a small formatting commit.

Suggested steps (example):

```powershell
# install dependencies where applicable (see README/setup)
# run unit tests
npm test # or the project's test command
# run linters
npm run lint # or the project's lint command
```

If a change requires new dependencies, explain why and keep them minimal.

## Review checklist (for reviewers)

- Does the change match the issue/description?
- Is the code readable and maintainable?
- Are there tests covering the change or components?
- Are edge cases and error conditions handled?
- Any performance or security concerns addressed?
- Are docs/README updated if public behavior changed?

## Code of Conduct & license

Please follow the project's Code of Conduct. If a `CODE_OF_CONDUCT.md` is not present, contributors are expected to be respectful and collaborative.

This project is licensed under the MIT License — see the `LICENSE` file at the repository root.

## Questions or help

If you need help getting set up or have questions, open an issue with the `help wanted` or `discussion` label and maintainers will assist.

Thanks for contributing — we appreciate your time and effort!
