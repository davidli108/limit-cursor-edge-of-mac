import Cocoa
import Quartz   // for CGEventTap, CGWarpMouseCursorPosition, etc.

// How many pixels from the TOP of the main screen to block
let blockedTopHeight: CGFloat = 20

// Get main screen frame
guard let screen = NSScreen.main else {
    print("❌ No main screen found")
    exit(1)
}

let frame = screen.frame
print("=== MouseLimiter with CGEventTap started ===")
print("Main screen frame: \(frame)")
print("Blocking top \(blockedTopHeight) px (Quartz coords: y < \(blockedTopHeight) will be clamped)\n")

// Keep strong references so they're not deallocated
var eventTap: CFMachPort?
var runLoopSource: CFRunLoopSource?

// CGEventTap callback
let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
    // We only care about mouse movement / drag events
    switch type {
    case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
        let location = event.location

        // Raw position log
        print("🐭 Mouse at x:\(location.x), y:\(location.y)")

        // In Quartz coordinates, y=0 is at the TOP of the screen
        // Block top 80px means block when y < blockedTopHeight
        if location.y < blockedTopHeight {
            print("➡ Clamping from y:\(location.y) to y:\(blockedTopHeight)")
            let clampedPoint = CGPoint(x: location.x, y: blockedTopHeight)
            CGWarpMouseCursorPosition(clampedPoint)
        }

    case .tapDisabledByUserInput, .tapDisabledByTimeout:
        print("⚠️ Event tap disabled, re-enabling…")
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }

    default:
        break
    }

    // Pass event through unchanged
    return Unmanaged.passUnretained(event)
}

// We need to pass the frame into callback via an UnsafeMutableRawPointer
var frameCopy = frame
let framePointer = UnsafeMutableRawPointer(&frameCopy)

// Listen to mouse move & drag events
let eventMask = (
    (1 << CGEventType.mouseMoved.rawValue) |
    (1 << CGEventType.leftMouseDragged.rawValue) |
    (1 << CGEventType.rightMouseDragged.rawValue) |
    (1 << CGEventType.otherMouseDragged.rawValue)
)

guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(eventMask),
    callback: callback,
    userInfo: framePointer
) else {
    print("❌ Failed to create event tap. Do you have Accessibility permission?")
    exit(1)
}

eventTap = tap

// Create run loop source and start listening
runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("✅ Event tap created, entering run loop. Move your mouse around to see logs.\n")

CFRunLoopRun()
