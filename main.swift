import AppKit
import CoreGraphics

// Background calibrated once for this wallpaper. No screen pixels are read at runtime.
enum ThemeBackground {
    static let image = Bundle.main.url(forResource: "background", withExtension: "png").flatMap { NSImage(contentsOf: $0) }
    static let darkImage = Bundle.main.url(forResource: "background-dark", withExtension: "png").flatMap { NSImage(contentsOf: $0) }
    static func cachedImage(for appearance: NSAppearance) -> NSImage? {
        isDark(appearance) ? darkImage : image
    }
    static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
    static func color(dark: Bool) -> NSColor {
        NSColor(srgbRed: dark ? 0.12 : 0.94, green: dark ? 0.12 : 0.94,
                blue: dark ? 0.12 : 0.94, alpha: 1)
    }
}


// A zero-size child inherits the native menu bar appearance, including wallpaper
// contrast. App appearance alone can be dark while the menu bar remains light.
final class MenuBarAppearanceObserver: NSView {
    var changed: ((NSAppearance) -> Void)?
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        changed?(effectiveAppearance)
    }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class SharpLogoView: NSView {
    let redLogo: CGImage?
    let imageRect: CGRect
    override var isOpaque: Bool { true }
    static func redOnly(_ image: NSImage) -> CGImage? {
        guard let data = image.tiffRepresentation, let rep = NSBitmapImageRep(data: data) else { return nil }
        let w = rep.pixelsWide, h = rep.pixelsHigh
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: w*4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let memory = context.data else { return nil }
        let pixels = memory.bindMemory(to: UInt8.self, capacity: w*h*4)
        let matte = rep.colorAt(x: w/2, y: h*40/512)!.usingColorSpace(.sRGB)!
        let red = rep.colorAt(x: w*230/512, y: h*170/512)!.usingColorSpace(.sRGB)!
        for y in 0..<h {
            autoreleasepool {
                for x in 0..<w {
                    guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                    let coverage = max(0, min(1, (matte.greenComponent-c.greenComponent) / max(0.01, matte.greenComponent-red.greenComponent))) * c.alphaComponent
                    let i = (y*w+x)*4
                    pixels[i] = UInt8((red.redComponent*coverage*255).rounded())
                    pixels[i+1] = UInt8((red.greenComponent*coverage*255).rounded())
                    pixels[i+2] = UInt8((red.blueComponent*coverage*255).rounded())
                    pixels[i+3] = UInt8((coverage*255).rounded())
                }
                }
        }
        return context.makeImage()
    }
    init(frame: CGRect, image: NSImage, imageRect: CGRect) {
        self.redLogo = Self.redOnly(image)
        self.imageRect = imageRect
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        if let image = ThemeBackground.cachedImage(for: effectiveAppearance) {
            image.draw(in: bounds, from: .zero, operation: .copy, fraction: 1)
        } else {
            ThemeBackground.color(dark: ThemeBackground.isDark(effectiveAppearance)).setFill()
            bounds.fill()
        }
        context.interpolationQuality = .high
        if let redLogo { context.draw(redLogo, in: imageRect) }
    }
}

final class Delegate: NSObject, NSApplicationDelegate {
    var windows: [NSPanel] = []
    var appearanceItem: NSStatusItem!
    var pendingSync: DispatchWorkItem?
    var image: NSImage?
    var asleep = false
    var lastDiagnostic = ""
    let supportURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Logoer-size-adjustment")

    func applicationDidFinishLaunching(_ note: Notification) {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: "local.philip.LogoerZoom")
            .filter { $0.processIdentifier != getpid() }
        if !others.isEmpty { NSApp.terminate(nil); return }
        try? FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        appearanceItem = NSStatusBar.system.statusItem(withLength: 0)
        let appearanceObserver = MenuBarAppearanceObserver(frame: .zero)
        appearanceObserver.changed = { [weak self] appearance in
            guard let self else { return }
            for window in self.windows { window.contentView?.appearance = appearance }
            self.writeDiagnostics()
        }
        appearanceItem.button?.addSubview(appearanceObserver)
        // Load the bundled image once. No other app's container is monitored.
        image = Bundle.main.url(forResource: "logo", withExtension: "png").flatMap { NSImage(contentsOf: $0) }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.didDeactivateApplicationNotification,
                     NSWorkspace.activeSpaceDidChangeNotification] {
            workspace.addObserver(self, selector: #selector(scheduleSync), name: name, object: nil)
        }
        workspace.addObserver(self, selector: #selector(sleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(wake), name: NSWorkspace.screensDidWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(scheduleSync),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(scheduleSync),
            name: .init("AppleInterfaceThemeChangedNotification"), object: nil)
        try? FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        let legacyStatus = supportURL.appendingPathComponent("capture-status.txt")
        if FileManager.default.fileExists(atPath: legacyStatus.path) {
            try? "screen-capture-removed; see status.json".write(to: legacyStatus, atomically: true, encoding: .utf8)
        }
        sync()
        scheduleSync()
    }
    @objc func scheduleSync() {
        guard !asleep else { return }
        pendingSync?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.sync() }
        pendingSync = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
    @objc func sleep() {
        asleep = true
        pendingSync?.cancel()
        windows.forEach { $0.orderOut(nil) }
    }
    @objc func wake() { asleep = false; sync(); scheduleSync() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        sync(); scheduleSync(); return false
    }
    func applicationWillTerminate(_ notification: Notification) {
        pendingSync?.cancel()
        windows.forEach { $0.orderOut(nil) }
        if let appearanceItem { NSStatusBar.system.removeStatusItem(appearanceItem) }
    }
    func sync() {
        guard !asleep, let image, let primary = NSScreen.screens.first else { return }
        // Read window geometry on notifications only, never window pixel content.
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let targets: [CGRect] = info.compactMap { w in
            guard w[kCGWindowOwnerName as String] as? String == "Logoer",
                  (w[kCGWindowAlpha as String] as? Double ?? 1) > 0.01,
                  let b = w[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: b),
                  abs(r.width - 24) < 0.1, abs(r.height - 24) < 0.1 else { return nil }
            return CGRect(x: r.minX, y: primary.frame.maxY-r.maxY, width: 24, height: 24)
        }
        if windows.count != targets.count {
            windows.forEach { $0.orderOut(nil) }
            windows = targets.map { frame in
                let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                panel.level = .init(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
                panel.backgroundColor = .clear
                panel.colorSpace = .sRGB
                panel.isOpaque = false
                panel.hasShadow = false
                panel.hidesOnDeactivate = false
                panel.ignoresMouseEvents = true
                panel.isReleasedWhenClosed = false
                panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
                let screen = NSScreen.screens.first { $0.frame.intersects(frame) }
                let y: CGFloat = (screen?.safeAreaInsets.top ?? 0) > 0 ? 1 : -0.5
                let scale = screen?.backingScaleFactor ?? 2
                let rect = CGRect(x: (0.75*scale).rounded()/scale,
                                  y: ((0.75+y)*scale).rounded(.down)/scale,
                                  width: 22.5, height: 22.5)
                panel.contentView = SharpLogoView(frame: CGRect(origin: .zero, size: frame.size), image: image, imageRect: rect)
                panel.contentView?.appearance = appearanceItem.button?.effectiveAppearance
                panel.setFrame(frame, display: false)
                return panel
            }
        }
        for (window, frame) in zip(windows, targets) {
            if window.frame != frame { window.setFrame(frame, display: false) }
            if !window.isVisible { window.orderFrontRegardless() }
        }
        writeDiagnostics()
    }
    func writeDiagnostics() {
        let state: [String: Any] = ["pid": getpid(), "screenCapture": false,
            "periodicWindowPolling": false, "appearanceMode": "native-menu-bar",
            "backgroundSource": ThemeBackground.cachedImage(for: appearanceItem.button?.effectiveAppearance ?? NSApp.effectiveAppearance) == nil ? "fallback" : "bundled-calibration",
            "appearance": ThemeBackground.isDark(appearanceItem.button?.effectiveAppearance ?? NSApp.effectiveAppearance) ? "dark" : "light",
            "backgroundState": "cached-static-background", "windowCount": windows.count]
        guard let data = try? JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8), text != lastDiagnostic else { return }
        try? data.write(to: supportURL.appendingPathComponent("status.json"), options: .atomic)
        lastDiagnostic = text
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = Delegate()
app.delegate = delegate
app.run()
