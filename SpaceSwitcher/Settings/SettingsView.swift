import AppKit
import SwiftUI

enum SettingsTab: Hashable {
    case general, shortcut, desktops, permissions
}

final class SettingsModel: ObservableObject {
    @Published var tab: SettingsTab = .general
    @Published private(set) var spaces: [Space] = []
    @Published private(set) var unusedNames = 0
    @Published private(set) var launchStatus = LaunchAtLogin.status
    @Published var launchError: String?
    @Published var initialSelection = InitialSelection.stored {
        didSet { InitialSelection.store(initialSelection) }
    }
    @Published var hud = SpaceHUDSettings.load() {
        didSet { hud.save() }
    }

    let names: NameStore
    let permissions: PermissionMonitor
    let setSwitcherSuspended: (Bool) -> Void

    init(names: NameStore, permissions: PermissionMonitor, setSwitcherSuspended: @escaping (Bool) -> Void) {
        self.names = names
        self.permissions = permissions
        self.setSwitcherSuspended = setSwitcherSuspended
        NotificationCenter.default.addObserver(forName: NameStore.didChange, object: names, queue: .main) { [weak self] _ in
            self?.reload()
        }
    }

    func reload() {
        spaces = SpaceProvider.spaces()
        unusedNames = names.unusedCount(keeping: Set(spaces.map(\.id)))
        launchStatus = LaunchAtLogin.status
    }

    func setLaunchAtLogin(_ on: Bool) {
        launchError = LaunchAtLogin.set(on)
        launchStatus = LaunchAtLogin.status
    }

    func removeUnusedNames() {
        names.removeUnused(keeping: Set(spaces.map(\.id)))
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        TabView(selection: $model.tab) {
            GeneralTab(model: model)
                .tabItem { Label("일반", systemImage: "gearshape") }.tag(SettingsTab.general)
            ShortcutTab(model: model)
                .tabItem { Label("단축키", systemImage: "keyboard") }.tag(SettingsTab.shortcut)
            DesktopsTab(model: model)
                .tabItem { Label("데스크탑", systemImage: "rectangle.3.group") }.tag(SettingsTab.desktops)
            PermissionsView(monitor: model.permissions, onClose: nil)
                .tabItem { Label("권한", systemImage: "lock.shield") }.tag(SettingsTab.permissions)
        }
        .padding(20)
        .frame(width: 520, height: 440)
        .onAppear(perform: model.reload)
    }
}

private struct GeneralTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Toggle("로그인 시 자동 실행", isOn: Binding(
                    get: { model.launchStatus != .disabled },
                    set: { model.setLaunchAtLogin($0) }))
                if model.launchStatus == .needsApproval {
                    HStack {
                        Text("시스템 설정 → 일반 → 로그인 항목에서 SpaceSwitcher를 허용해 주세요.")
                            .font(.callout).foregroundStyle(.orange)
                        Button("열기") { LaunchAtLogin.openLoginItemsSettings() }
                    }
                }
                if let error = model.launchError {
                    Text(error).font(.callout).foregroundStyle(.red)
                }
            }
            Section("데스크탑 이동 시 이름 표시") {
                Toggle("화면에 데스크탑 이름 잠깐 표시", isOn: $model.hud.isEnabled)
                Picker("표시 시간", selection: $model.hud.duration) {
                    Text("짧게").tag(SpaceHUDSettings.Duration.short)
                    Text("보통").tag(SpaceHUDSettings.Duration.normal)
                    Text("길게").tag(SpaceHUDSettings.Duration.long)
                }
                .pickerStyle(.segmented)
                .disabled(!model.hud.isEnabled)
                Picker("위치", selection: $model.hud.position) {
                    Text("가운데").tag(SpaceHUDSettings.Position.center)
                    Text("위쪽").tag(SpaceHUDSettings.Position.top)
                }
                .pickerStyle(.segmented)
                .disabled(!model.hud.isEnabled)
            }
            Section {
                Picker("스위처를 열 때 처음 선택", selection: $model.initialSelection) {
                    Text("현재 데스크탑").tag(InitialSelection.current)
                    Text("직전 데스크탑").tag(InitialSelection.previous)
                }
                .pickerStyle(.radioGroup)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShortcutTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("스위처 단축키").font(.headline)
            ShortcutRecorderView(setSuspended: model.setSwitcherSuspended)
            Text("버튼을 누른 뒤 새 조합을 누르면 바로 적용됩니다. 수식키(⌃ ⌥ ⌘) 1개 이상 + 일반 키 1개.\n"
                 + "수식키를 누른 채 키를 반복해서 누르면 순환 모드, 짧게 누르면 팝업 모드입니다.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

private struct DesktopsTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            List(model.spaces) { space in
                HStack {
                    Text("\(space.index)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                    NameField(space: space, names: model.names)
                    if space.isCurrent {
                        Text("현재").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            HStack {
                Text("Enter로 저장 · 비우면 이름 삭제 · 최대 \(NameStore.maxLength)자")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("사용하지 않는 이름 정리 (\(model.unusedNames)개)", action: model.removeUnusedNames)
                    .disabled(model.unusedNames == 0)
            }
        }
    }
}

/// Edits a draft and saves on Enter or when focus leaves.
private struct NameField: View {
    let space: Space
    let names: NameStore
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("데스크탑 \(space.index)", text: $draft)
            .textFieldStyle(.roundedBorder)
            .focused($focused)
            .onAppear { draft = names.name(for: space.id) ?? "" }
            .onSubmit(save)
            .onChange(of: focused) { _, isFocused in if !isFocused { save() } }
    }

    private func save() {
        if draft != (names.name(for: space.id) ?? "") { names.setName(draft, for: space.id) }
        draft = names.name(for: space.id) ?? ""
    }
}

/// Plain NSWindow: the SwiftUI `Settings` scene is awkward to open from an agent app's menu.
final class SettingsWindowController {
    private let model: SettingsModel
    private var window: NSWindow?

    init(model: SettingsModel) {
        self.model = model
    }

    func show(tab: SettingsTab? = nil) {
        if let tab { model.tab = tab }
        model.reload()
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = "SpaceSwitcher 설정"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
