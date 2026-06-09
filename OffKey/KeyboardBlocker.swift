import Cocoa
import CoreGraphics

final class KeyboardBlocker {
    static let shared = KeyboardBlocker()

    private let stateLock = NSLock()
    private var eventTaps: [CFMachPort] = []
    private var runLoopSources: [CFRunLoopSource] = []
    private var tapThread: Thread?
    private var tapRunLoop: CFRunLoop?
    private var _isBlocked = false

    /// kCGEventSystemDefined = 14 — F1–F12, яркость, громкость на MacBook.
    private static let systemDefinedEvent = CGEventType(rawValue: 14)!

    private static let keyboardEventMask: CGEventMask = {
        var mask: UInt64 = 0
        let types: [CGEventType] = [
            .keyDown,
            .keyUp,
            .flagsChanged,
            systemDefinedEvent,
            .tapDisabledByTimeout,
            .tapDisabledByUserInput,
        ]
        for type in types {
            mask |= 1 << type.rawValue
        }
        return CGEventMask(mask)
    }()

    var isBlocked: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _isBlocked
    }

    private init() {}

    func startBlocking() -> Bool {
        stateLock.lock()
        if _isBlocked {
            stateLock.unlock()
            return true
        }
        stateLock.unlock()

        let ready = DispatchSemaphore(value: 0)
        var installed = false

        let thread = Thread { [weak self] in
            guard let self else {
                ready.signal()
                return
            }

            installed = self.installTapsOnCurrentRunLoop()
            ready.signal()

            guard installed else { return }

            CFRunLoopRun()
            self.cleanupTapsOnTapThread()
        }

        thread.name = "OffKey.EventTap"
        tapThread = thread
        thread.start()

        let waitResult = ready.wait(timeout: .now() + 5)
        guard waitResult == .success, installed else {
            tapThread = nil
            tapRunLoop = nil
            return false
        }

        stateLock.lock()
        _isBlocked = true
        stateLock.unlock()
        return true
    }

    func stopBlocking() {
        stateLock.lock()
        guard _isBlocked else {
            stateLock.unlock()
            return
        }
        _isBlocked = false
        stateLock.unlock()

        guard let runLoop = tapRunLoop else { return }

        let semaphore = DispatchSemaphore(value: 0)
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
            CFRunLoopStop(runLoop)
            semaphore.signal()
        }
        CFRunLoopWakeUp(runLoop)

        _ = semaphore.wait(timeout: .now() + 2)
        tapThread = nil
        tapRunLoop = nil
    }

    private static func shouldBlock(_ type: CGEventType) -> Bool {
        switch type {
        case .keyDown, .keyUp, .flagsChanged:
            return true
        case let value where value == systemDefinedEvent:
            return true
        default:
            return false
        }
    }

    private static let eventCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else {
            return Unmanaged.passUnretained(event)
        }

        let blocker = Unmanaged<KeyboardBlocker>
            .fromOpaque(refcon)
            .takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            for tap in blocker.eventTaps {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if blocker.isBlocked, shouldBlock(type) {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func installTapsOnCurrentRunLoop() -> Bool {
        let runLoop = CFRunLoopGetCurrent()
        tapRunLoop = runLoop

        // Session первым — стабильнее на чужих Mac; HID — для F1–F12.
        let locations: [CGEventTapLocation] = [.cgSessionEventTap, .cghidEventTap]
        var installedAny = false

        for location in locations {
            guard let tap = CGEvent.tapCreate(
                tap: location,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: Self.keyboardEventMask,
                callback: Self.eventCallback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            ) else {
                continue
            }

            guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
                continue
            }

            eventTaps.append(tap)
            runLoopSources.append(source)
            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            installedAny = true
        }

        return installedAny
    }

    private func cleanupTapsOnTapThread() {
        for tap in eventTaps {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        for source in runLoopSources {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTaps.removeAll()
        runLoopSources.removeAll()
    }
}
