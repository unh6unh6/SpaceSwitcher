// Spike for #27: live-preview editing inside the memo overlay's non-activating panel.
//
//   swift spike/livetext.swift
//
// Checks, with synthetic clicks and keys (the terminal needs Accessibility):
//   1. a click in an NSTextView inside a .nonactivatingPanel places the caret and typing goes in,
//      (a) without activating the app, (b) activating it on mouseDown (FocusReturner style)
//   2. TextKit 1 can hide syntax characters entirely (null glyphs take no width)
//   3. the clicked character index maps back to the source line (checkbox hit testing)
// Moves the mouse pointer briefly and puts it back; re-activates the app that was in front.
import AppKit

final class HidingDelegate: NSObject, NSLayoutManagerDelegate {
    static let hidden = NSAttributedString.Key("spikeHidden")

    func layoutManager(_ layoutManager: NSLayoutManager, shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
                       properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
                       characterIndexes charIndexes: UnsafePointer<Int>, font aFont: NSFont,
                       forGlyphRange glyphRange: NSRange) -> Int {
        guard let storage = layoutManager.textStorage else { return 0 }
        var newProps = Array(UnsafeBufferPointer(start: props, count: glyphRange.length))
        var changed = false
        for i in 0..<glyphRange.length where storage.attribute(Self.hidden, at: charIndexes[i], effectiveRange: nil) != nil {
            newProps[i] = .null
            changed = true
        }
        guard changed else { return 0 }
        layoutManager.setGlyphs(glyphs, properties: newProps, characterIndexes: charIndexes, font: aFont, forGlyphRange: glyphRange)
        return glyphRange.length
    }
}

final class ActivatingTextView: NSTextView {
    var activateOnClick = false
    override func mouseDown(with event: NSEvent) {
        if activateOnClick {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKey()
        }
        super.mouseDown(with: event)
    }
}

func makeTextView(frame: CGRect, delegate: HidingDelegate) -> ActivatingTextView {
    let storage = NSTextStorage()
    let layout = NSLayoutManager()
    layout.delegate = delegate
    storage.addLayoutManager(layout)
    let container = NSTextContainer(size: CGSize(width: frame.width, height: .greatestFiniteMagnitude))
    container.widthTracksTextView = true
    layout.addTextContainer(container)
    let view = ActivatingTextView(frame: frame, textContainer: container)
    view.font = .systemFont(ofSize: 14)
    view.isRichText = false
    return view
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let previousApp = NSWorkspace.shared.frontmostApplication
let savedMouse = NSEvent.mouseLocation

let delegate = HidingDelegate()
let screen = NSScreen.screens[0].frame
let panel = NSPanel(contentRect: CGRect(x: 200, y: screen.height - 500, width: 400, height: 300),
                    styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
panel.level = .statusBar
panel.collectionBehavior = [.canJoinAllSpaces]
let textView = makeTextView(frame: CGRect(x: 0, y: 0, width: 400, height: 300), delegate: delegate)
textView.string = "first line\nsecond line"
panel.contentView = textView
panel.orderFrontRegardless()

// Hidden-glyph measurement view (off-screen is fine for layout).
let measure = makeTextView(frame: CGRect(x: 0, y: 0, width: 400, height: 100), delegate: delegate)
func width(_ text: String, hidePrefix: Int) -> CGFloat {
    measure.textStorage!.setAttributedString(NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 14)]))
    if hidePrefix > 0 { measure.textStorage!.addAttribute(HidingDelegate.hidden, value: true, range: NSRange(location: 0, length: hidePrefix)) }
    measure.layoutManager!.ensureLayout(for: measure.textContainer!)
    return measure.layoutManager!.usedRect(for: measure.textContainer!).width
}

func click(at p: CGPoint) {   // p in Cocoa screen coordinates
    let q = CGPoint(x: p.x, y: screen.height - p.y)
    for type in [CGEventType.leftMouseDown, .leftMouseUp] {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: q, mouseButton: .left)!.post(tap: .cghidEventTap)
        usleep(40_000)
    }
}
func type(_ keys: [CGKeyCode]) {
    for k in keys {
        for down in [true, false] { CGEvent(keyboardEventSource: nil, virtualKey: k, keyDown: down)!.post(tap: .cghidEventTap) }
        usleep(40_000)
    }
}
func pointAfter(line: Int, in view: NSTextView) -> CGPoint {
    // End of the given line, in screen coordinates.
    let ns = view.string as NSString
    var start = 0
    for _ in 0..<line { start = NSMaxRange(ns.lineRange(for: NSRange(location: start, length: 0))) }
    let lineRange = ns.lineRange(for: NSRange(location: start, length: 0))
    let glyphs = view.layoutManager!.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
    let rect = view.layoutManager!.boundingRect(forGlyphRange: glyphs, in: view.textContainer!)
    let inView = CGPoint(x: min(rect.maxX + 5, view.bounds.width - 10), y: rect.midY + view.textContainerOrigin.y)
    return view.window!.convertPoint(toScreen: view.convert(inView, to: nil))
}

// Put a harmless app in front so stray keys never land in the terminal, and so the panel's app
// starts inactive like the real overlay.
NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.finder" }?.activate()
DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
    // 1a. no activation
    textView.activateOnClick = false
    let p0 = pointAfter(line: 0, in: textView)
    print("panel=\(panel.frame) click=\(p0) active-before=\(NSApp.isActive)")
    click(at: p0)
    usleep(150_000)
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    print("   after click: sel=\(textView.selectedRange()) first=\(type(of: panel.firstResponder!)) key=\(panel.isKeyWindow)")
    type([0, 11])            // a b
    RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    let a = textView.string
    print("1a 활성화 없이: active=\(NSApp.isActive) key=\(panel.isKeyWindow) text=\(a.debugDescription)")

    // 1b. activate on mouseDown
    textView.activateOnClick = true
    click(at: pointAfter(line: 1, in: textView))
    usleep(300_000)
    type([8, 2])             // c d
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        let b = textView.string
        print("1b 클릭 시 활성화: active=\(NSApp.isActive) key=\(panel.isKeyWindow) text=\(b.debugDescription)")

        // 2. hidden glyphs
        let full = width("## Heading", hidePrefix: 0), hid = width("## Heading", hidePrefix: 3), bare = width("Heading", hidePrefix: 0)
        print("2 숨김: '## Heading'=\(Int(full)) 숨김=\(Int(hid)) 'Heading'=\(Int(bare)) → \(abs(hid - bare) < 1 ? "OK 자리까지 사라짐" : "FAIL")")

        // 3. index → line
        measure.textStorage!.setAttributedString(NSAttributedString(string: "- [ ] one\n- [x] two", attributes: [.font: NSFont.systemFont(ofSize: 14)]))
        let lm = measure.layoutManager!
        lm.ensureLayout(for: measure.textContainer!)
        let secondLineRect = lm.lineFragmentRect(forGlyphAt: lm.glyphIndexForCharacter(at: 12), effectiveRange: nil)
        let idx = lm.characterIndex(for: CGPoint(x: 20, y: secondLineRect.midY), in: measure.textContainer!, fractionOfDistanceBetweenInsertionPoints: nil)
        let line = (measure.string as NSString).substring(to: idx).components(separatedBy: "\n").count - 1
        print("3 클릭 위치→줄: index=\(idx) line=\(line) → \(line == 1 ? "OK" : "FAIL")")

        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                mouseCursorPosition: CGPoint(x: savedMouse.x, y: screen.height - savedMouse.y), mouseButton: .left)!.post(tap: .cghidEventTap)
        previousApp?.activate()
        usleep(200_000)
        exit(0)
    }
}
app.run()
