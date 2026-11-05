import AppKit

/// Native-looking radial menu: blurred vibrancy ring + center hub, accent-colored selection.
/// Geometry scales with bounds, so it's reused for the live preview in Settings.
final class RadialMenuView: NSView {
    struct Geometry {
        let center: NSPoint
        let outer: CGFloat
        let inner: CGFloat
        var hub: CGFloat { inner - 6 }
    }

    var options: [MenuOption] = [] { didSet { overlay.needsDisplay = true } }
    var selectedIndex: Int? { didSet { if oldValue != selectedIndex { overlay.needsDisplay = true } } }

    private let effect = NSVisualEffectView()
    private let overlay = RadialOverlayView()

    init(blendingMode: NSVisualEffectView.BlendingMode) {
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 300))
        wantsLayer = true
        effect.material = .menu
        effect.blendingMode = blendingMode
        effect.state = .active
        overlay.host = self
        addSubview(effect)
        addSubview(overlay)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var geometry: Geometry {
        let outer = min(bounds.width, bounds.height) / 2 - 12 // margin for the window shadow
        return Geometry(center: NSPoint(x: bounds.midX, y: bounds.midY), outer: outer, inner: outer * 0.34)
    }

    override func layout() {
        super.layout()
        effect.frame = bounds
        overlay.frame = bounds
        effect.maskImage = Self.maskImage(size: bounds.size, geometry: geometry)
    }

    /// `dx`/`dy` are relative to the center with +y pointing up.
    static func index(dx: CGFloat, dy: CGFloat, count: Int, deadZone: CGFloat) -> Int? {
        guard count > 0, hypot(dx, dy) >= deadZone else { return nil }
        let step = 360 / CGFloat(count)
        let angle = atan2(dy, dx) * 180 / .pi
        let raw = Int(((90 - angle) / step).rounded())
        return ((raw % count) + count) % count
    }

    private static func maskImage(size: NSSize, geometry g: Geometry) -> NSImage {
        NSImage(size: size, flipped: false) { _ in
            let ring = NSBezierPath(ovalIn: circleRect(g.center, g.outer))
            ring.append(NSBezierPath(ovalIn: circleRect(g.center, g.inner)))
            ring.windingRule = .evenOdd
            ring.append(NSBezierPath(ovalIn: circleRect(g.center, g.hub)))
            NSColor.black.setFill()
            ring.fill()
            return true
        }
    }
}

func circleRect(_ c: NSPoint, _ r: CGFloat) -> NSRect {
    NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
}

private final class RadialOverlayView: NSView {
    weak var host: RadialMenuView?

    override func draw(_ dirtyRect: NSRect) {
        guard let host else { return }
        let g = host.geometry
        let options = host.options
        let count = options.count

        drawRims(g)
        guard count > 0 else { return }
        let step = 360 / CGFloat(count)

        if let selected = host.selectedIndex, selected < count {
            drawHighlight(g, mid: 90 - CGFloat(selected) * step, step: step, fullRing: count == 1)
        }
        if count > 1 {
            drawSeparators(g, step: step, skipNear: host.selectedIndex)
        }
        for (i, option) in options.enumerated() {
            let mid = (90 - CGFloat(i) * step) * .pi / 180
            let radius = (g.inner + g.outer) / 2
            let point = NSPoint(x: g.center.x + cos(mid) * radius, y: g.center.y + sin(mid) * radius)
            drawLabel(option, at: point, ringWidth: g.outer - g.inner, selected: i == host.selectedIndex)
        }
        drawHub(g, hasSelection: host.selectedIndex != nil)
    }

    private func drawRims(_ g: RadialMenuView.Geometry) {
        let rim = NSColor.white.withAlphaComponent(effectiveAppearance.isDark ? 0.14 : 0.5)
        rim.setStroke()
        for r in [g.outer - 0.5, g.inner + 0.5, g.hub - 0.5] {
            let p = NSBezierPath(ovalIn: circleRect(g.center, r))
            p.lineWidth = 1
            p.stroke()
        }
        NSColor.black.withAlphaComponent(effectiveAppearance.isDark ? 0.5 : 0.12).setStroke()
        let outline = NSBezierPath(ovalIn: circleRect(g.center, g.outer))
        outline.lineWidth = 0.5
        outline.stroke()
    }

    private func drawSeparators(_ g: RadialMenuView.Geometry, step: CGFloat, skipNear selected: Int?) {
        NSColor.separatorColor.setStroke()
        let count = Int((360 / step).rounded())
        for i in 0..<count {
            // Boundaries of the selected slice are covered by the highlight.
            if let selected, i == selected || i == (selected + 1) % count { continue }
            let angle = (90 - (CGFloat(i) - 0.5) * step) * .pi / 180
            let p = NSBezierPath()
            p.move(to: NSPoint(x: g.center.x + cos(angle) * (g.inner + 8), y: g.center.y + sin(angle) * (g.inner + 8)))
            p.line(to: NSPoint(x: g.center.x + cos(angle) * (g.outer - 8), y: g.center.y + sin(angle) * (g.outer - 8)))
            p.lineWidth = 1
            p.stroke()
        }
    }

    /// Rounded annular sector: build it inset by gap+corner, then fill + stroke with round joins.
    private func drawHighlight(_ g: RadialMenuView.Geometry, mid: CGFloat, step: CGFloat, fullRing: Bool) {
        let gap: CGFloat = 4, corner: CGFloat = 6
        let inset = gap + corner
        let outerR = g.outer - inset, innerR = g.inner + inset
        let path = NSBezierPath()
        if fullRing {
            path.appendOval(in: circleRect(g.center, g.outer - gap))
            path.appendOval(in: circleRect(g.center, g.inner + gap))
            path.windingRule = .evenOdd
            NSColor.controlAccentColor.setFill()
            path.fill()
            return
        }
        let deg = 180 / CGFloat.pi
        let outerDelta = (inset / outerR) * deg, innerDelta = (inset / innerR) * deg
        path.appendArc(withCenter: g.center, radius: outerR,
                       startAngle: mid - step / 2 + outerDelta, endAngle: mid + step / 2 - outerDelta)
        path.appendArc(withCenter: g.center, radius: innerR,
                       startAngle: mid + step / 2 - innerDelta, endAngle: mid - step / 2 + innerDelta, clockwise: true)
        path.close()
        path.lineJoinStyle = .round
        path.lineWidth = corner * 2
        NSColor.controlAccentColor.setFill()
        NSColor.controlAccentColor.setStroke()
        path.fill()
        path.stroke()
    }

    private func drawLabel(_ option: MenuOption, at point: NSPoint, ringWidth: CGFloat, selected: Bool) {
        let iconColor: NSColor = selected ? .white : .labelColor
        let textColor: NSColor = selected ? .white.withAlphaComponent(0.92) : .secondaryLabelColor
        let config = NSImage.SymbolConfiguration(pointSize: max(12, ringWidth * 0.24), weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [iconColor]))
        let title = NSAttributedString(string: option.title, attributes: [
            .font: NSFont.systemFont(ofSize: max(8, ringWidth * 0.115), weight: .medium),
            .foregroundColor: textColor,
        ])
        let titleSize = title.size()
        let image = (NSImage(systemSymbolName: option.symbol, accessibilityDescription: option.title)
            ?? NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: nil))?
            .withSymbolConfiguration(config)
        let imageSize = image?.size ?? .zero
        let spacing: CGFloat = 3
        let total = imageSize.height + spacing + titleSize.height
        let top = point.y + total / 2
        image?.draw(in: NSRect(x: point.x - imageSize.width / 2, y: top - imageSize.height,
                               width: imageSize.width, height: imageSize.height))
        title.draw(at: NSPoint(x: point.x - titleSize.width / 2, y: top - total))
    }

    private func drawHub(_ g: RadialMenuView.Geometry, hasSelection: Bool) {
        let color: NSColor = hasSelection ? .tertiaryLabelColor : .secondaryLabelColor
        let config = NSImage.SymbolConfiguration(pointSize: max(9, g.hub * 0.38), weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        guard let image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Cancel")?
            .withSymbolConfiguration(config) else { return }
        let s = image.size
        image.draw(in: NSRect(x: g.center.x - s.width / 2, y: g.center.y - s.height / 2, width: s.width, height: s.height))
    }
}

private extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
}
