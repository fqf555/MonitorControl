import Cocoa

/// App-owned HUD: Control Center's private OSD ignores externally supplied levels.
/// Never changes focus or intercepts input, including in full-screen Spaces.
final class ModernHUD {
  static let shared = ModernHUD()

  private final class Presentation {
    let panel: NSPanel
    var dismissal: DispatchWorkItem?

    init() {
      self.panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
      self.panel.isOpaque = false
      self.panel.backgroundColor = .clear
      self.panel.hasShadow = true
      self.panel.level = .statusBar
      self.panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
      self.panel.ignoresMouseEvents = true
      self.panel.hidesOnDeactivate = false
      self.panel.isReleasedWhenClosed = false
    }
  }

  private var presentations: [CGDirectDisplayID: Presentation] = [:]

  static func normalizedLevel(_ value: Float, maximum: Float) -> Double {
    guard value.isFinite, maximum.isFinite, maximum > 0 else { return 0 }
    return min(1, max(0, Double(value / maximum)))
  }

  static func frame(on screen: NSRect, visibleFrame: NSRect) -> NSRect {
    let width = min(CGFloat(294), max(0, screen.width - 24))
    return NSRect(x: screen.maxX - width - 12, y: min(screen.maxY - 32, visibleFrame.maxY) - 74, width: width, height: 64)
  }

  func show(displayID: CGDirectDisplayID, title: String, symbol: String, level: Double, unavailable: Bool = false) {
    guard Thread.isMainThread else {
      DispatchQueue.main.async { self.show(displayID: displayID, title: title, symbol: symbol, level: level, unavailable: unavailable) }
      return
    }
    let screens = NSScreen.screens
    let ids = Set(screens.compactMap { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value })
    for id in Array(self.presentations.keys) where !ids.contains(id) {
      self.presentations[id]?.dismissal?.cancel()
      self.presentations.removeValue(forKey: id)?.panel.orderOut(nil)
    }
    guard let screen = screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID }) else { return }
    let presentation = self.presentations[displayID] ?? Presentation()
    self.presentations[displayID] = presentation
    presentation.dismissal?.cancel()
    let panel = presentation.panel
    panel.setFrame(Self.frame(on: screen.frame, visibleFrame: screen.visibleFrame), display: false)
    // Keep a transparent root between the window and the effect. Using an effect
    // view as the window's root can leave a rectangular backing outside its corners.
    let root = NSView(frame: NSRect(origin: .zero, size: panel.frame.size))
    root.wantsLayer = true
    root.layer?.backgroundColor = NSColor.clear.cgColor
    root.layer?.cornerRadius = 22
    root.layer?.masksToBounds = true
    let content = HUDView(title: title, symbol: symbol, level: level, unavailable: unavailable)
    if #available(macOS 26.0, *) {
      let glass = NSGlassEffectView(frame: root.bounds)
      glass.style = .regular
      glass.cornerRadius = 22
      glass.contentView = content
      glass.autoresizingMask = [.width, .height]
      root.addSubview(glass)
    }
    panel.contentView = root
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.invalidateShadow()
    panel.orderFrontRegardless()
    let dismissal = DispatchWorkItem { [weak presentation] in presentation?.panel.orderOut(nil) }
    presentation.dismissal = dismissal
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: dismissal)
  }
}

private final class HUDView: NSView {
  private let track = NSView()
  private let fill = NSView()

  init(title: String, symbol: String, level: Double, unavailable: Bool) {
    super.init(frame: .zero)
    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: 12, weight: .semibold)
    label.lineBreakMode = .byTruncatingTail
    label.translatesAutoresizingMaskIntoConstraints = false
    self.addSubview(label)
    let image = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: title) ?? NSImage())
    image.contentTintColor = .labelColor
    image.translatesAutoresizingMaskIntoConstraints = false
    self.addSubview(image)
    let value = NSTextField(labelWithString: unavailable ? "—" : "\(Int((level * 100).rounded()))%")
    value.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
    value.alignment = .right
    value.translatesAutoresizingMaskIntoConstraints = false
    self.addSubview(value)
    track.wantsLayer = true
    track.layer?.cornerRadius = 2
    track.translatesAutoresizingMaskIntoConstraints = false
    self.addSubview(track)
    fill.wantsLayer = true
    fill.layer?.cornerRadius = 2
    fill.translatesAutoresizingMaskIntoConstraints = false
    track.addSubview(fill)
    NSLayoutConstraint.activate([
      track.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 10),
      track.trailingAnchor.constraint(equalTo: value.leadingAnchor, constant: -8),
      track.centerYAnchor.constraint(equalTo: image.centerYAnchor),
      track.heightAnchor.constraint(equalToConstant: 4),
      fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
      fill.topAnchor.constraint(equalTo: track.topAnchor),
      fill.heightAnchor.constraint(equalTo: track.heightAnchor),
      fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: unavailable ? 0 : level),
      label.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
      label.topAnchor.constraint(equalTo: self.topAnchor, constant: 10),
      label.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
      image.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
      image.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -12),
      image.widthAnchor.constraint(equalToConstant: 18), image.heightAnchor.constraint(equalToConstant: 18),
      value.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
      value.centerYAnchor.constraint(equalTo: image.centerYAnchor), value.widthAnchor.constraint(equalToConstant: 40),
    ])
    self.setAccessibilityElement(true)
    self.setAccessibilityLabel("\(title), \(unavailable ? NSLocalizedString("Unavailable", comment: "HUD unavailable control") : value.stringValue)")
    self.updateBarColors()
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    self.updateBarColors()
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    self.updateBarColors()
  }

  private func updateBarColors() {
    // CALayer stores a fixed CGColor, not a dynamic NSColor. Resolve after the
    // HUD inherits its window's appearance, and refresh when that changes.
    let isDark = self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    let foreground: NSColor = isDark ? .white : .black
    self.fill.layer?.backgroundColor = foreground.cgColor
    self.track.layer?.backgroundColor = foreground.withAlphaComponent(0.2).cgColor
  }
}
