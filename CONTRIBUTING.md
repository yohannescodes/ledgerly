# Contributing to ledgerly

ledgerly is an MIT-licensed, offline-first SwiftUI personal finance app. Every contribution helps the community keep budgeting, net-worth tracking, and portfolio monitoring on-device. This guide explains how to collaborate effectively while keeping ledgerly's privacy-first mission intact.

## Ground Rules & Code of Conduct
- Be respectful and constructive in issues, pull requests (PRs), and discussions.
- ledgerly stays MIT-licensed. By contributing you confirm you have the right to share your work and you agree it will be distributed under the MIT License found in `LICENSE`.
- Privacy comes first: never include real personal data in issues, fixtures, or screenshots.
- Keep the app offline-friendly. New features should not force a network dependency, and any optional networking (e.g., CoinGecko refreshes) must fail gracefully.

## How You Can Help
- **Bug reports:** Provide reproduction steps, expected vs. actual behavior, and device/iOS information.
- **Feature ideas:** Tie requests to user value (budgets, wallets, manual assets, analytics) and describe the offline story.
- **Design & UX:** Share SwiftUI mockups, screenshots, or accessibility feedback for wallets, dashboards, onboarding, etc.
- **Docs & Guides:** Improve README sections, add how-tos under `docs/`, or expand the architecture notes.
- **Code contributions:** Polish existing flows (transactions, budgets, goals), add dashboards/widgets, or extend Core Data stores.

Before opening a new issue, search the tracker and skim the `docs/phase*.md` plans so proposals align with the existing roadmap.

## Development Environment
1. Fork the repository and create a feature branch (`git checkout -b feature/my-awesome-change`).
2. Open `ledgerly.xcodeproj` in Xcode 15.4+ (iOS 17 target). Swift 5.9+ is assumed. Install any missing command-line tools via Xcode.
3. Run the app on an iOS 17 simulator to verify onboarding, dashboard widgets, and CRUD flows.
4. Keep Core Data migrations in sync. If you touch `ledgerly.xcdatamodeld`, document the change in your PR description.

## Coding Standards
- Favor small, composable SwiftUI views located under `Views/`, with shared logic extracted to `ViewModels/` or `Services/`.
- Use the existing store pattern (`AppSettingsStore`, `WalletsStore`, etc.) instead of adding singletons.
- Keep derived values and heavy work off the main thread; stores should publish sanitized snapshots to the UI.
- Follow Swift naming conventions (camelCase functions, PascalCase types) and prefer explicit access control.
- Add succinct comments only when intent is non-obvious (e.g., tricky Core Data fetch configurations).
- Localize strings via `LocalizedStringKey` where user-facing text is introduced.

## Testing & Validation
- Use Xcode previews or the static snapshot helpers inside `Models/` to validate states without touching production data.
- Manually exercise flows that touch financial math: wallet transfers, budget progress, goal projections, and manual entries.
- If you add background services (notifications, price refresh), include unit tests or at least describable steps reviewers can follow.
- Run `Product > Clean Build Folder` before final verification to catch missing files or assets.

## Submitting a Pull Request
1. Rebase on `main` and resolve conflicts locally.
2. Ensure `git status` is clean—do not include unrelated changes or generated files.
3. Update docs (README, `docs/phase*.md`, screenshots) whenever behavior changes.
4. Fill out the PR template (or include the following):
   - What & why summary
   - Screenshots or screen recordings for UI changes
   - Testing evidence (simulators/devices, iOS versions)
   - Follow-up work or known gaps
5. Request review from a maintainer and stay responsive to feedback. Squash or amend commits as needed so history remains meaningful.

## Security, Privacy & Data Integrity
- Never commit secrets, API keys, or production datasets. Use `.gitignore` for local artifacts.
- Treat backups/exports carefully. Ensure new export formats remain backwards compatible.
- Report vulnerabilities privately by emailing the maintainer or opening a security advisory draft instead of a public issue.

## License Notes
ledgerly uses the MIT License (`LICENSE`). Contribution implies consent to publish your work under the same license. Include third-party notices when adding external assets or source files, and ensure dependencies are MIT-compatible.

Thanks for keeping ledgerly delightful, local, and secure!
