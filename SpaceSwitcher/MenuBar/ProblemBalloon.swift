import AppKit
import SwiftUI

/// The balloon under the menu bar item when a problem starts (#23). Stays until its X (or a fix button)
/// is clicked, on every desktop.
///
/// A custom panel rather than `NSPopover`: macOS closes popovers on any Space change (observed), and a
/// `.transient` popover of an inactive agent app closes the moment it opens.
final class ProblemBalloon {
    private var panel: NSPanel?

    struct Actions {
        let openPermissions: () -> Void
        let restartDock: () -> Void
        let openKeyboardSettings: () -> Void
        let muteShortcuts: () -> Void
    }

    func show(_ notice: ProblemNotices.Notice, from button: NSStatusBarButton, actions: Actions) {
        close()
        guard let buttonWindow = button.window else { return }
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))

        let close: () -> Void = { [weak self] in self?.close() }
        let hosting = NSHostingView(rootView: ProblemBalloonView(notice: notice, actions: actions, close: close))
        let size = hosting.fittingSize

        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.contentView = hosting

        // Tail under the status item, body kept on the screen that holds the menu bar.
        let screen = (buttonWindow.screen ?? NSScreen.screens.first)?.visibleFrame ?? .zero
        let x = min(max(anchor.midX - size.width / 2, screen.minX + 8), screen.maxX - size.width - 8)
        panel.setFrame(CGRect(x: x, y: anchor.minY - size.height - 2, width: size.width, height: size.height), display: true)
        hosting.rootView = ProblemBalloonView(notice: notice, actions: actions, close: close, tailX: anchor.midX - x)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct ProblemBalloonView: View {
    let notice: ProblemNotices.Notice
    let actions: ProblemBalloon.Actions
    let close: () -> Void
    /// Horizontal position of the tail inside the balloon (points from the left edge).
    var tailX: CGFloat = 170

    private static let width: CGFloat = 340
    private static let tail: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(.regularMaterial)
                .frame(width: Self.tail * 2, height: Self.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: min(max(tailX - Self.tail, 14), Self.width - 14 - Self.tail * 2))
            content
                .background(RoundedRectangle(cornerRadius: 10).fill(.regularMaterial))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08)))
        }
        .frame(width: Self.width)
    }

    private var content: some View {
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
                Spacer(minLength: 0)
                Button(action: close) {
                    Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("닫기")
            }
            HStack {
                if case .shortcutsOff = notice {
                    Button("다시 보지 않기") { actions.muteShortcuts(); close() }
                }
                Spacer()
                Button(primaryTitle) { primaryAction(); close() }
            }
        }
        .padding(14)
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

/// Upward-pointing tail.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
