# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

SpaceSwitcher is a macOS menu-bar agent app (`LSUIElement`, no Dock icon). It lets you name desktops (Spaces) and switch between them with an IntelliJ-style switcher (`Option+E`). It's written in Swift with AppKit and SwiftUI, has no external dependencies, and targets macOS 14+ as a universal binary.

**Answer the user in Korean.** This directory is its own git repo (`unh6unh6/SpaceSwitcher`, branch `main`). It is separate from any parent workspace.

## Start of every session

1. Skim the docs that apply to the task (see the table below).
2. Check the current state:
   - `git status -sb`. Unpushed commits are normal; they wait for the next release.
   - `gh issue list --milestone <next version>`, or plain `gh issue list`.
3. If you'll build or run the app, check the environment. `security find-identity -v -p codesigning` must list `SpaceSwitcher Signing`, and `xcodebuild -version` must work. If either fails, follow `docs/DEVELOPMENT.md` §1–2.

| Doc | Read when |
|-----|-----------|
| `SPEC.md` (Korean) | Original product spec: behavior (§3), structure (§4), manual checklist (§7). |
| `docs/DECISIONS.md` | **Overrides SPEC.** Every deviation: distribution, signing, initial selection, autorepeat, and more. Add new decisions here. |
| `docs/DEVELOPMENT.md` | New-Mac setup, the signing cert, the build/test/run loop, known noise and pitfalls, where data lives. |
| `docs/RELEASING.md` | Releasing, the Homebrew tap, recovering from a failed release. |
| `docs/MANUAL_TESTS.md` | After any change to permissions, hotkeys, Spaces, or UI. Pick the relevant items for the user to check. |
| `docs/phase0-findings.md` | Verified macOS behavior behind the private-API approach, including the stuck-Ctrl finding. Re-verify with `spike/` on a new macOS. |
| `TODO.md` | Historical MVP checklist (Phase S–7, all done). No new items. |

## Workflow: GitHub issues → milestone → release

- The MVP is shipped as v0.1.0 (GitHub Releases plus the Homebrew tap). All further work is **one GitHub issue per unit of work**.
  - If an issue doesn't exist yet, file one first: `gh issue create --label enhancement|bug`.
  - The body covers the goal, approach, risks, a checklist, and an estimate.
- A **milestone is a release** (e.g. `v0.2.0`).
  - Work through its issues on `main`.
  - Commit locally at sensible checkpoints without asking.
  - Commit messages end with `Closes #N` plus the `Co-Authored-By` trailer.
- **Don't push mid-milestone.** When the milestone is done, the user runs `./scripts/release.sh <x.y.z>`. That pushes (which auto-closes the issues), publishes the Release, and updates the tap (`docs/RELEASING.md`).
- **Confirm with the user before anything outward-facing:** push, release, creating or deleting repos, creating issues they didn't ask for, editing published releases.
- If a platform assumption from SPEC §2 or phase0-findings turns out wrong, stop, report it, and ask. Don't work around it silently.

## Communicating with the user

The user asked for an ADHD-friendly style and is new to macOS app distribution.

- Lead with the next action. Use numbered steps, one action each, with concrete time estimates ("약 10분").
- Restate progress every turn (e.g. "#1: 3/5 done"). Make wins visible: say what works now and how to try it.
- No preamble, no recap, no closing pleasantries. Ask one question at a time. For real choices, use AskUserQuestion with the recommended option first.
- When the user must run a command, suggest `! <command>`. `sudo` can't prompt there, so point them to Terminal.app for anything that needs it.
- Don't use the `⚠︎` symbol in chat; their terminal renders it broken.
- Physical checks (permissions, reboot, real key presses) are the user's job. List exactly what to press and what they should see.

## Commands

```sh
xcodegen generate                         # after adding/removing files; .xcodeproj is gitignored, never edit it
xcodebuild test -scheme SpaceSwitcher -destination 'platform=macOS' -derivedDataPath build/DerivedData
#   one test: append -only-testing:SpaceSwitcherTests/<Class>/<method>
xcodebuild -scheme SpaceSwitcher -configuration Debug -derivedDataPath build/DerivedData build
swift scripts/smoke.swift                 # running app: panel opens <100ms, Sticky, Esc (terminal needs Accessibility)
./scripts/install.sh                      # Release build → /Applications, relaunch
./scripts/release.sh x.y.z [--dry-run]    # user-run; see docs/RELEASING.md
```

Editor diagnostics such as `No such module 'XCTest'` or `Cannot find type …` are SourceKit noise. Trust xcodebuild.

## Architecture (read SPEC §2 and phase0-findings before touching Spaces/Hotkey)

macOS has no public Spaces API, so the app combines three mechanisms.

1. **Reading Spaces** (`Spaces/`):
   - Private CGS functions, declared with `@_silgen_name` **only in `CGSPrivate.swift`**. `SpaceProvider` calls them.
   - `SpaceParser` (pure, tested) keeps the `type == 0` desktops of the main display:
     - `index` is the N in "Desktop N".
     - `position` is the slot among *all* Spaces, fullscreen ones included. The arrow fallback counts with it.
     - `id` is the `uuid`; an empty uuid becomes `__main__`.
     - Never persist `ManagedSpaceID`: it changes on reboot.
   - Changes arrive via `NSWorkspace.activeSpaceDidChangeNotification`. Add, remove, and reorder have no notification, so re-query whenever a menu or the panel opens.
2. **Switching**:
   - `SymbolicHotKeys` reads the "Switch to Desktop N" shortcuts from `com.apple.symbolichotkeys`. IDs are 118+N−1, and 79/81 for Ctrl+←/→. A missing entry means off.
   - `SwitchPlanner` (pure) picks direct, arrows×n, or none.
   - `SpaceSwitcherService` posts the `CGEvent`s, then posts modifier key-ups via `ModifierRelease`. Without them, synthesized Ctrl sticks and the next Option+E beeps.
   - Needs Accessibility. Without it, the events are dropped silently.
3. **Global hotkey** (`Hotkey/`):
   - `EventTap` is a session `CGEventTap` on `keyDown` + `flagsChanged`, running on the main run loop. It re-enables itself after timeouts and on wake. (Carbon hotkeys can't do Option-only combos on macOS 15+ and can't see a modifier being released.)
   - `KeyMapper` (pure) maps keys to switcher events and decides pass or consume. It ignores autorepeat of the shortcut key.
   - `Shortcut` handles validation, the UserDefaults key `switcherShortcut`, and a `didChange` notification.

**Switcher** (`Switcher/`):
- `SwitcherStateMachine` (pure; event in, action out) moves Idle → Holding → Sticky / Renaming per SPEC §3.1.
  - Releasing the modifier after 1 press enters Sticky (popup mode).
  - Releasing it after ≥ 2 presses switches (cycle mode).
- `SwitcherController` wires the tap, machine, `SwitcherPanel`, and stores together.
  - It decides consumption synchronously in the tap callback and renders asynchronously.
  - Keys stay on the tap even in Sticky. Only inline rename activates the app.
- `SwitcherPanel` is a non-activating `NSPanel` at `.popUpMenu` level with `[.canJoinAllSpaces, .fullScreenAuxiliary, .transient]`.
- The initial selection comes from `InitialSelection` in `Store/MRUTracker.swift`: the current desktop by default, or the MRU previous one.

**Other components:**
- `Store/NameStore` persists `names.json`: 30-character cap, an empty value deletes, unknown ids are kept.
- `MenuBar/StatusItemController` shows the name and the menu, with a warning prefix when Accessibility is missing.
- `Onboarding/PermissionMonitor` polls AX trust and missing desktop shortcuts every 1 s.
- `Settings/` is a plain `NSWindow`, not the SwiftUI `Settings` scene. Tabs: General, Shortcut (the recorder suspends the tap), Desktops, Permissions.
- `App/AppDelegate` assembles everything. It skips the tap and onboarding when hosting unit tests.

## Rules

- Pure logic (state machine, parsers, planners, `KeyMapper`, `NameStore`, `MRUTracker`, `Shortcut`) must not import AppKit. **Write its tests first.**
- `project.yml` is the source of truth. Private API declarations stay in `Spaces/CGSPrivate.swift` only.
- Don't add external dependencies unless truly needed (SPM only). Keep App Sandbox off.
- Keep signing with `SpaceSwitcher Signing`. Changing the identity forces every user to re-grant Accessibility.
- After changing permissions, hotkeys, Spaces, or UI:
  1. Run `scripts/smoke.swift` if it applies.
  2. Give the user the relevant `docs/MANUAL_TESTS.md` items.
  3. For a bug fix, add a regression item there.
