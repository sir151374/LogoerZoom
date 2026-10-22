import AppKit
import CoreGraphics
import ScreenCaptureKit

let imageURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Containers/com.lihaoyun6.Logoer/Data/Documents/user.png")
final class SharpLogoView: NSView {
    var liveBackground: CGImage? { didSet { needsDisplay = true } }
    let redLogo: CGImage?
    let imageRect: CGRect
    let background: [[Double]]
    let sourceTop: CGFloat
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
        return context.makeImage()
    }
    init(frame: CGRect, image: NSImage, imageRect: CGRect, sourceTop: CGFloat) {
        self.redLogo = Self.redOnly(image)
        self.imageRect = imageRect
        self.sourceTop = sourceTop
        let url = Bundle.main.url(forResource: "background", withExtension: "json")!
        self.background = (try? JSONSerialization.jsonObject(with: Data(contentsOf: url))) as? [[Double]] ?? []
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        guard let graphics = NSGraphicsContext.current else { return }
        let context = graphics.cgContext
        context.saveGState()
        if let liveBackground {
            context.interpolationQuality = .none
            context.draw(liveBackground, in: bounds)
            context.interpolationQuality = .high
            if let redLogo { context.draw(redLogo, in: imageRect) }
            context.restoreGState()
            return
        }
        // Fill every pixel opaquely before compositing the isolated red emblem.
        context.setShouldAntialias(false)
        let scale: CGFloat = window?.backingScaleFactor ?? 2
        for row in 0..<Int(bounds.height*scale) {
            let y = CGFloat(row)/scale
            let sample = Int(((sourceTop+bounds.height-y-0.5/scale)*2).rounded(.down))
            let rgb = background.isEmpty ? [0.5, 0.75, 0.9] : background[min(max(0, sample), background.count-1)]
            context.setFillColor(NSColor(srgbRed: rgb[0], green: rgb[1], blue: rgb[2], alpha: 1).cgColor)
            context.fill(CGRect(x: 0, y: y, width: bounds.width, height: 1/scale))
        }
        context.interpolationQuality = .high
        context.setShouldAntialias(true)
        if let redLogo { context.draw(redLogo, in: imageRect) }
        context.restoreGState()
    }
}
final class Delegate: NSObject, NSApplicationDelegate {
    var windows: [NSPanel] = []
    var timer: Timer?
    var cachedImage: NSImage?
    var modified: Date?
    var sampling = false
    var lastSample = Date.distantPast
    var captureContent: SCShareableContent?
    var contentDate = Date.distantPast
    let statusURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Logoer-size-adjustment/capture-status.txt")
    func applicationDidFinishLaunching(_ note: Notification) {
        if !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }
        sync()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.sync() }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    func sync() {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        guard let primary = NSScreen.screens.first else { return }
        let targets: [CGRect] = info.compactMap { w in
            guard w[kCGWindowOwnerName as String] as? String == "Logoer",
                  (w[kCGWindowAlpha as String] as? Double ?? 1) > 0.01,
                  let b = w[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: b),
                  abs(r.width - 24) < 0.1, abs(r.height - 24) < 0.1 else { return nil }
            return CGRect(x: r.minX, y: primary.frame.maxY-r.maxY, width: 24, height: 24)
        }
        let stamp = (try? FileManager.default.attributesOfItem(atPath: imageURL.path)[.modificationDate]) as? Date
        if cachedImage == nil || stamp != modified {
            cachedImage = NSImage(contentsOf: imageURL) ?? Bundle.main.url(forResource: "logo", withExtension: "png").flatMap { NSImage(contentsOf: $0) }
            modified = stamp
            windows.forEach { $0.orderOut(nil) }
            windows = []
        }
        guard let image = cachedImage else { return }
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
                // Match Logoer's existing center and notch offset; increase both dimensions by exactly 25%.
                let y: CGFloat = (screen?.safeAreaInsets.top ?? 0) > 0 ? 1 : -0.5
                let scale = screen?.backingScaleFactor ?? 2
                // Align both image edges to Retina pixels: 22.5 points = 45 pixels.
                // Draw the original directly, avoiding a second composited blur/shadow.
                let rect = CGRect(x: (0.75*scale).rounded()/scale,
                                  y: ((0.75+y)*scale).rounded(.down)/scale,
                                  width: 22.5, height: 22.5)
                let view = SharpLogoView(frame: CGRect(origin: .zero, size: frame.size), image: image, imageRect: rect, sourceTop: primary.frame.maxY-frame.maxY)
                panel.contentView = view
                panel.setFrame(frame, display: false)
                return panel
            }
        }
        for (window, frame) in zip(windows, targets) {
            if window.frame != frame { window.setFrame(frame, display: false) }
            if !window.isVisible { window.orderFrontRegardless() }
        }
        sampleBackground(targets: targets, primaryHeight: primary.frame.maxY)
    }
    func sampleBackground(targets: [CGRect], primaryHeight: CGFloat) {
        guard !sampling, !targets.isEmpty, Date().timeIntervalSince(lastSample) >= 1 else { return }
        guard CGPreflightScreenCaptureAccess() else {
            try? "waiting-for-screen-recording-permission".write(to: statusURL, atomically: true, encoding: .utf8)
            return
        }
        sampling = true
        lastSample = Date()
        Task { @MainActor in
            defer { sampling = false }
            do {
                for target in targets {
                    guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(target) }) else { continue }
                    let scale = screen.backingScaleFactor
                    let top = primaryHeight-target.maxY
                    let source = CGRect(x: target.minX-8, y: top-4, width: target.width+16, height: target.height+8)
                    // Read the actual final compositor, including menu bar / window
                    // shadows. Only clean strips outside our own bounds are sampled.
                    let capture = try await SCScreenshotManager.captureImage(in: source)
                    if let background = Self.background(from: capture, scale: scale),
                       let panel = windows.first(where: { $0.frame == target }),
                       let view = panel.contentView as? SharpLogoView { view.liveBackground = background }
                }
                try? "live-composited-background-active; crop-only; clean-side-strips".write(to: statusURL, atomically: true, encoding: .utf8)
            } catch {
                captureContent = nil
                try? "capture-error: \(error.localizedDescription)".write(to: statusURL, atomically: true, encoding: .utf8)
            }
        }
    }
    static func background(from image: CGImage, scale: CGFloat) -> CGImage? {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let flags = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let input = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width*4, space: colorSpace, bitmapInfo: flags), let inputData = input.data else { return nil }
        input.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let w = Int(24*scale), h = Int(24*scale)
        guard let output = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: w*4, space: colorSpace, bitmapInfo: flags), let outputData = output.data else { return nil }
        let src = inputData.bindMemory(to: UInt8.self, capacity: image.width*image.height*4)
        let dst = outputData.bindMemory(to: UInt8.self, capacity: w*h*4)
        // The Apple glyph remains in the underlying menu bar. Reconstruct only its
        // smooth backdrop from clean strips immediately to either side, per row.
        for y in 0..<h {
            let sy = min(image.height-1, Int(4*scale)+y)
            for x in 0..<w {
                let fraction = (8*scale+CGFloat(x)-1)/(CGFloat(image.width)-3)
                for channel in 0..<3 {
                    let left = (0..<3).reduce(0.0) { $0+Double(src[(sy*image.width+$1)*4+channel])/3 }
                    let right = (0..<3).reduce(0.0) { $0+Double(src[(sy*image.width+image.width-1-$1)*4+channel])/3 }
                    dst[(y*w+x)*4+channel] = UInt8(max(0, min(255, left+(right-left)*fraction)).rounded())
                }
                dst[(y*w+x)*4+3] = 255
            }
        }
        return output.makeImage()
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = Delegate()
app.delegate = delegate
app.run()
