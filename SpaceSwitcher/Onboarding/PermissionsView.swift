import AppKit
import SwiftUI

struct PermissionsView: View {
    @ObservedObject var monitor: PermissionMonitor
    /// nil when embedded as the Settings "권한" tab (no title, no close button).
    let onClose: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if onClose != nil {
                Text("SpaceSwitcher 설정")
                    .font(.title2.bold())
            }

            step(done: monitor.isTrusted,
                 title: "1. 손쉬운 사용 권한",
                 detail: monitor.isTrusted
                    ? "허용됨. 데스크탑 전환과 단축키가 동작합니다."
                    : "데스크탑을 전환하려면 필요합니다. 목록에서 SpaceSwitcher를 켜 주세요.") {
                if !monitor.isTrusted {
                    Button("권한 요청") { monitor.requestAccessibility() }
                    Button("시스템 설정 열기") { SystemSettings.open(.accessibility) }
                }
            }

            let missing = monitor.desktopsWithoutShortcut
            step(done: missing.isEmpty,
                 title: "2. \"데스크탑 N으로 전환\" 단축키",
                 detail: missing.isEmpty
                    ? "켜져 있음. 바로 전환됩니다."
                    : "데스크탑 \(missing.map(String.init).joined(separator: ", "))번 단축키가 꺼져 있습니다. "
                      + "꺼져 있어도 Ctrl+←/→로 이동하지만 애니메이션만큼 느립니다.\n"
                      + "키보드 → 키보드 단축키… → Mission Control에서 켜 주세요.") {
                if !missing.isEmpty {
                    Button("시스템 설정 열기") { SystemSettings.open(.keyboard) }
                }
            }

            if monitor.dockIgnoresShortcuts {
                step(done: false,
                     title: "3. 데스크탑 전환 단축키가 응답하지 않음",
                     detail: "macOS Dock이 \"데스크탑 N으로 전환\"(Ctrl+숫자)에 반응하지 않는 상태예요. "
                        + "지금은 Ctrl+←/→로 대신 이동해서 느립니다. Dock을 다시 시작하면 돌아옵니다 "
                        + "(창과 데스크탑 배치는 그대로).") {
                    Button("Dock 다시 시작") { DockRestart.confirmAndRestart() }
                }
            }

            if let onClose {
                HStack {
                    Spacer()
                    Button(monitor.isTrusted ? "완료" : "나중에", action: onClose)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(onClose == nil ? 8 : 24)
        .frame(width: onClose == nil ? nil : 440)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func step<Buttons: View>(done: Bool, title: String, detail: String,
                                     @ViewBuilder buttons: () -> Buttons) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(done ? .green : .orange)
                .font(.title2)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack { buttons() }
            }
        }
    }
}

enum SystemSettings {
    enum Pane: String {
        case accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case keyboard = "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"
    }

    static func open(_ pane: Pane) {
        if let url = URL(string: pane.rawValue) { NSWorkspace.shared.open(url) }
    }
}

/// Hosts PermissionsView. Agent apps (LSUIElement) must activate explicitly for the window to come forward.
final class PermissionsWindowController {
    private var window: NSWindow?
    private let monitor: PermissionMonitor

    init(monitor: PermissionMonitor) {
        self.monitor = monitor
    }

    func show() {
        monitor.refresh()
        if window == nil {
            let hosting = NSHostingController(rootView: PermissionsView(monitor: monitor) { [weak self] in self?.close() })
            let window = NSWindow(contentViewController: hosting)
            window.title = "SpaceSwitcher"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }
}

/// One confirmation, then `killall Dock` (#22). Shared by the menu bar and the permissions view.
enum DockRestart {
    static func confirmAndRestart() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Dock을 다시 시작할까요?"
        alert.informativeText = "Dock이 1~2초 깜빡입니다. 열린 창과 데스크탑 배치는 그대로 유지됩니다."
        alert.addButton(withTitle: "다시 시작")
        alert.addButton(withTitle: "취소")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        DispatchQueue.global(qos: .userInitiated).async { SpaceSwitcherService.restartDock() }
    }
}
