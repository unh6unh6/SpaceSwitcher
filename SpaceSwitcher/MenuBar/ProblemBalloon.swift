import AppKit
import SwiftUI

/// The balloon under the menu bar item when a problem starts (#23). Closes on any outside click.
///
/// Not `.transient`: an agent app is never active, and a transient popover of an inactive app closes the
/// moment it opens (observed). So the popover stays until closed, and a global click monitor closes it
/// on a click elsewhere — the same feel without needing to activate the app.
final class ProblemBalloon {
    private var popover: NSPopover?
    private var outsideClicks: Any?

    struct Actions {
        let openPermissions: () -> Void
        let restartDock: () -> Void
        let openKeyboardSettings: () -> Void
        let muteShortcuts: () -> Void
    }

    func show(_ notice: ProblemNotices.Notice, from button: NSStatusBarButton, actions: Actions) {
        popover?.close()
        let popover = NSPopover()
        popover.behavior = .applicationDefined
        popover.animates = true
        let close: () -> Void = { [weak self] in self?.close() }
        popover.contentViewController = NSHostingController(rootView: ProblemBalloonView(notice: notice, actions: actions, close: close))
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Stay put if the user switches desktops while the balloon is up.
        popover.contentViewController?.view.window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.popover = popover
        // Global monitors only see clicks in other apps, i.e. outside the balloon.
        outsideClicks = outsideClicks ?? NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    func close() {
        popover?.close()
        popover = nil
        if let outsideClicks { NSEvent.removeMonitor(outsideClicks) }
        outsideClicks = nil
    }
}

private struct ProblemBalloonView: View {
    let notice: ProblemNotices.Notice
    let actions: ProblemBalloon.Actions
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(message).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack {
                if case .shortcutsOff = notice {
                    Button("다시 보지 않기") { actions.muteShortcuts(); close() }
                }
                Spacer()
                Button("닫기", action: close)
                Button(primaryTitle) { primaryAction(); close() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 340)
    }

    private var title: String {
        switch notice {
        case .accessibility: return "손쉬운 사용 권한이 꺼져 있어요"
        case .dock: return "데스크탑 전환 단축키가 응답하지 않아요"
        case .shortcutsOff(let desktops): return "데스크탑 \(desktops.map(String.init).joined(separator: ", "))번 전환 단축키가 꺼져 있어요"
        }
    }

    private var message: String {
        switch notice {
        case .accessibility:
            return "Option+E와 데스크탑 이동이 동작하지 않습니다. 권한을 켜면 바로 돌아와요."
        case .dock:
            return "macOS Dock이 Ctrl+숫자를 무시하는 상태예요. 지금은 Ctrl+←/→로 대신 이동해 느립니다. Dock을 다시 시작하면 돌아옵니다 (창과 데스크탑 배치는 그대로)."
        case .shortcutsOff:
            return "이 데스크탑들은 옆으로 한 칸씩 넘어가며 이동해 느립니다. 시스템 설정 → 키보드 → 키보드 단축키 → Mission Control에서 켜 주세요."
        }
    }

    private var primaryTitle: String {
        switch notice {
        case .accessibility: return "권한 설정 열기"
        case .dock: return "Dock 다시 시작"
        case .shortcutsOff: return "시스템 설정 열기"
        }
    }

    private func primaryAction() {
        switch notice {
        case .accessibility: actions.openPermissions()
        case .dock: actions.restartDock()
        case .shortcutsOff: actions.openKeyboardSettings()
        }
    }
}
