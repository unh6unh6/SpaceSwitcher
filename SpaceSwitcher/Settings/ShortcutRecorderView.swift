import AppKit
import SwiftUI

/// Click, press a combination, done. Esc cancels. Invalid combos show why and keep listening.
struct ShortcutRecorderView: View {
    /// Pauses/resumes the switcher's event tap so the current shortcut reaches the recorder too.
    let setSuspended: (Bool) -> Void

    @State private var shortcut = Shortcut.stored()
    @State private var recording = false
    @State private var message: String?
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: toggle) {
                    Text(recording ? "새 단축키를 누르세요… (Esc 취소)" : shortcut.displayString)
                        .frame(minWidth: 180)
                        .font(.system(.body, design: recording ? .default : .rounded).weight(.medium))
                }
                .controlSize(.large)

                Button("기본값(⌥E)으로 복원") {
                    stop()
                    Shortcut.reset()
                    shortcut = Shortcut.stored()
                    message = nil
                }
                .disabled(shortcut == .default)
            }
            if let message {
                Text(message).font(.callout).foregroundStyle(.orange)
            }
        }
        .onDisappear(perform: stop)
    }

    private func toggle() {
        recording ? stop() : start()
    }

    private func start() {
        message = nil
        recording = true
        setSuspended(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil  // don't let the keystroke do anything else in Settings
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { setSuspended(false) }
        recording = false
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        if event.keyCode == KeyCode.escape && flags.isEmpty {
            stop()
            return
        }
        // NSEvent and CGEvent use the same bits for these four modifiers.
        let candidate = Shortcut(keyCode: event.keyCode, modifiers: UInt64(flags.rawValue))
        switch candidate.problem {
        case .needsModifier:
            message = "Control, Option, Command 중 하나 이상과 함께 눌러 주세요."
        case .modifierOnly:
            message = "수식키와 함께 일반 키 하나를 눌러 주세요."
        case .reservedKey:
            message = "Esc, Return, ↑/↓, R, 1–9는 스위처 창에서 쓰는 키라 사용할 수 없어요."
        case nil:
            candidate.store()
            shortcut = candidate
            message = nil
            stop()
        }
    }
}
