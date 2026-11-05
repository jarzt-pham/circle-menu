import AppKit
import CoreGraphics

protocol MouseChordDelegate: AnyObject {
    func chordBegan(at point: CGPoint)
    func chordMoved(to point: CGPoint)
    func chordEnded(at point: CGPoint)
}

/// Detects "left + right button held together" via a global event tap.
///
/// The first button-down is held back for `chordWindow` seconds. If the other button goes
/// down in that window it's a chord and both clicks are swallowed; otherwise the held-back
/// event is replayed so normal clicks/drags keep working.
final class MouseChordMonitor {
    weak var delegate: MouseChordDelegate?
    private var chordWindow: TimeInterval { ConfigStore.shared.config.chordDelay }

    private static let syntheticMarker: Int64 = 0x434D_454E
    private enum Button { case left, right }
    private enum State {
        case idle
        case pending(down: CGEvent, button: Button, generation: Int)
        case chord(held: Set<Button>)
        case draining(held: Set<Button>)
    }

    private var state = State.idle
    private var generation = 0
    private var tap: CFMachPort?

    func start() -> Bool {
        if tap != nil { return true }
        let types: [CGEventType] = [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
                                    .leftMouseDragged, .rightMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let monitor = Unmanaged<MouseChordMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            return monitor.handle(type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .defaultTap, eventsOfInterest: mask,
                                          callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            return false
        }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMarker {
            return Unmanaged.passUnretained(event)
        }

        let pass = Unmanaged.passUnretained(event)
        let location = event.location

        switch state {
        case .idle:
            guard ConfigStore.shared.config.enabled, let button = Self.downButton(type) else { return pass }
            generation += 1
            let gen = generation
            state = .pending(down: event.copy() ?? event, button: button, generation: gen)
            DispatchQueue.main.asyncAfter(deadline: .now() + chordWindow) { [weak self] in
                self?.pendingExpired(generation: gen)
            }
            return nil

        case let .pending(down, button, _):
            if let other = Self.downButton(type), other != button {
                state = .chord(held: [.left, .right])
                delegate?.chordBegan(at: location)
                return nil
            }
            if Self.upButton(type) == button {
                // Quick click: replay down + up in order.
                state = .idle
                replay(down)
                replay(event)
                return nil
            }
            return nil // swallow tiny drags while deciding

        case var .chord(held):
            if type == .leftMouseDragged || type == .rightMouseDragged {
                delegate?.chordMoved(to: location)
            } else if let up = Self.upButton(type) {
                held.remove(up)
                state = held.isEmpty ? .idle : .draining(held: held)
                delegate?.chordEnded(at: location)
            }
            return nil

        case var .draining(held):
            if let up = Self.upButton(type) {
                held.remove(up)
                state = held.isEmpty ? .idle : .draining(held: held)
            }
            return nil
        }
    }

    private func pendingExpired(generation gen: Int) {
        guard case let .pending(down, _, g) = state, g == gen else { return }
        state = .idle
        replay(down)
    }

    private func replay(_ event: CGEvent) {
        guard let copy = event.copy() else { return }
        copy.setIntegerValueField(.eventSourceUserData, value: Self.syntheticMarker)
        copy.post(tap: .cgSessionEventTap)
    }

    private static func downButton(_ type: CGEventType) -> Button? {
        switch type {
        case .leftMouseDown: return .left
        case .rightMouseDown: return .right
        default: return nil
        }
    }

    private static func upButton(_ type: CGEventType) -> Button? {
        switch type {
        case .leftMouseUp: return .left
        case .rightMouseUp: return .right
        default: return nil
        }
    }
}
