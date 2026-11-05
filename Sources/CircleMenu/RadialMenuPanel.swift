import AppKit
import QuartzCore

final class RadialMenuPanel: NSPanel {
    private static let size: CGFloat = 300
    private let menuView = RadialMenuView(blendingMode: .behindWindow)
    private var centerCG = CGPoint.zero
    private var showToken = 0
    private(set) var options: [MenuOption] = []

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: Self.size, height: Self.size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        contentView = menuView
    }

    /// `point` is in CoreGraphics global coordinates (top-left origin).
    func show(at point: CGPoint, options: [MenuOption]) {
        showToken += 1
        self.options = options
        centerCG = point
        menuView.options = options
        menuView.selectedIndex = nil

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        setFrameOrigin(NSPoint(x: point.x - Self.size / 2, y: primaryHeight - point.y - Self.size / 2))
        alphaValue = 0
        orderFrontRegardless()
        menuView.layoutSubtreeIfNeeded()
        menuView.display()
        invalidateShadow()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
        let c = Self.size / 2
        let scale = CABasicAnimation(keyPath: "transform")
        scale.fromValue = CATransform3DConcat(
            CATransform3DConcat(CATransform3DMakeTranslation(-c, -c, 0), CATransform3DMakeScale(0.86, 0.86, 1)),
            CATransform3DMakeTranslation(c, c, 0))
        scale.toValue = CATransform3DIdentity
        scale.duration = 0.2
        scale.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 1.3, 0.4, 1) // slight overshoot
        menuView.layer?.add(scale, forKey: "pop")
    }

    func hide() {
        let token = showToken
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.showToken == token else { return }
            self.orderOut(nil)
        })
    }

    @discardableResult
    func updateSelection(for point: CGPoint) -> MenuOption? {
        let index = RadialMenuView.index(dx: point.x - centerCG.x, dy: centerCG.y - point.y,
                                         count: options.count, deadZone: menuView.geometry.inner)
        if index != menuView.selectedIndex {
            menuView.selectedIndex = index
            if index != nil {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
        }
        return index.map { options[$0] }
    }
}
