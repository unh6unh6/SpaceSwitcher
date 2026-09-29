# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

SpaceSwitcher is a macOS menu-bar agent app (`LSUIElement`, no Dock icon) that lets you name desktops (Spaces) and switch between them with an IntelliJ-style switcher (`Option+E`). `SPEC.md` (Korean) is the full spec and the source of truth. Answer the user in Korean.

This directory has its **own git repo**, separate from the parent `vibecoding/` workspace. Run git commands from here.

## Status

Progress is tracked in `TODO.md` as checkboxes. Check items off as you finish them. Its "확정된 결정" table **overrides SPEC** on distribution: no paid Apple account, no notarization, one self-signed cert `SpaceSwitcher Signing` for all builds, bundle ID `io.github.unh6unh6.SpaceSwitcher`, and DMGs on public GitHub Releases. Only `SPEC.md` exists so far. Implement phase by phase per SPEC §6, starting with the **Phase 0 verification spike**. Each phase has a completion condition, and you don't move on until it's met. Phase 0 findings go in `docs/phase0-findings.md`. If they contradict the assumptions in SPEC §2, stop and discuss with the user.

## Commands

- Build: `xcodegen generate && xcodebuild -scheme SpaceSwitcher -configuration Debug build`
- Test: `xcodebuild test -scheme SpaceSwitcher -destination 'platform=macOS'`
- Single test: append `-only-testing:SpaceSwitcherTests/<TestClass>/<testMethod>` to the test command.
- `project.yml` (XcodeGen) is the source of truth. Re-run `xcodegen generate` after adding or removing files, and never edit `.xcodeproj` directly.

## Architecture (read SPEC §2 before touching Spaces/Hotkey code)

macOS has no public Spaces API, so the app combines three mechanisms:

1. **Reading Spaces:** private CGS/SkyLight functions (`CGSCopyManagedDisplaySpaces`, `CGSGetActiveSpace`), declared with `@_silgen_name` **only in `Spaces/CGSPrivate.swift`**. Keep only desktops with `type == 0`, taken from the main display. Their order gives "Desktop N". Names are keyed by the Space `uuid`, and an empty uuid (the first desktop) maps to `"__main__"`. Detect Space changes with `NSWorkspace.activeSpaceDidChangeNotification`. Add, delete, and reorder produce no notification, so re-query the Space list every time the menu or panel opens.
2. **Switching:** don't use the private set-space API. Instead, synthesize the system "Switch to Desktop N" shortcut with `CGEvent`. Read its keycode and modifiers from `com.apple.symbolichotkeys` (IDs 118–133) rather than hardcoding them. If that shortcut is disabled, or the target is desktop 17 or higher, fall back to repeated `Ctrl+←/→`. This requires the Accessibility permission.
3. **Global hotkey:** a `CGEventTap` on `keyDown` + `flagsChanged`, not Carbon `RegisterEventHotKey`. Carbon blocks Option-only combos on macOS 15, and cycle mode needs to detect when the modifier is released. The tap consumes matched `keyDown` events by returning `nil`; otherwise the `´` dead key gets typed. It re-enables itself on `tapDisabledByTimeout`/`tapDisabledByUserInput`, and it hands UI work to the main thread.

The switcher is a **pure state machine** (`Switcher/SwitcherStateMachine.swift`: event enum in, action enum out) with the states Idle, Holding, and Sticky, per SPEC §3.1. Releasing the modifier after one press enters Sticky (popup mode). Releasing it after two or more presses switches desktops (cycle mode). The list is displayed in desktop order, and only the *initial selection* is MRU-based (the previous desktop). The `EventTap` and `SwitcherPanel` (an `NSPanel` with `[.canJoinAllSpaces, .fullScreenAuxiliary, .transient]`) are thin adapters around it. Names persist in `~/Library/Application Support/SpaceSwitcher/names.json`. Names for uuids that no longer exist are kept, not pruned automatically.

## Rules (SPEC §5)

- Pure logic (the state machine, `NameStore`, `MRUTracker`) must not import AppKit. Write its tests first.
- Permissions, hotkeys, and Spaces behavior can't be verified automatically. When you change them, list the relevant items from the SPEC §7 manual checklist in your result so the user can check them.
- If an assumption from SPEC §2 turns out wrong, report back and ask. Don't work around it.
- The SPEC §8 open questions (bundle ID, etc.) are the user's call. Ask when you reach them.
- Commit after each phase: `phaseN: <summary>`.
- There are no external dependencies. Use SPM only if one is truly needed. App Sandbox stays disabled.
