import Cocoa
import Quartz   // for CGEventTap, CGWarpMouseCursorPosition, etc.

// How many pixels from the TOP of the main screen to block
let blockedTopHeight: CGFloat = 15

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

// Track if cursor is in blocked area to warp only once on entry
var isInBlockedArea = false

// CGEventTap callback
let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
    let location = event.location
    let currentY = location.y
    
    // In Quartz coordinates, y=0 is at the TOP of the screen
    // Block top area means block when y < blockedTopHeight
    if currentY < blockedTopHeight {
        let clampedPoint = CGPoint(x: location.x, y: blockedTopHeight)
        
        // Warp cursor only once when first entering blocked area
        if !isInBlockedArea {
            CGWarpMouseCursorPosition(clampedPoint)
            isInBlockedArea = true
        }
        
        switch type {
        case .mouseMoved:
            // Modify event location to clamped position
            // No warping here to prevent blinking
            event.location = clampedPoint
            return Unmanaged.passUnretained(event)
            
        case .leftMouseDown, .rightMouseDown, .otherMouseDown,
             .leftMouseUp, .rightMouseUp, .otherMouseUp,
             .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            // Block all click and drag events in the blocked area
            print("🚫 Blocked mouse click/drag at y:\(currentY)")
            return nil  // Consume the event, don't pass it through
            
        default:
            // For other events, modify location to clamped position
            event.location = clampedPoint
            return Unmanaged.passUnretained(event)
        }
    } else {
        // Cursor is outside blocked area, reset flag
        isInBlockedArea = false
    }
    
    // Handle tap disabled events
    switch type {
    case .tapDisabledByUserInput, .tapDisabledByTimeout:
        print("⚠️ Event tap disabled, re-enabling…")
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    default:
        break
    }

    // Pass event through unchanged for events outside blocked area
    return Unmanaged.passUnretained(event)
}

// We need to pass the frame into callback via an UnsafeMutableRawPointer
var frameCopy = frame
let framePointer = UnsafeMutableRawPointer(&frameCopy)

// Listen to mouse move, drag, and click events
let moveMask: UInt64 = 1 << CGEventType.mouseMoved.rawValue
let leftDownMask: UInt64 = 1 << CGEventType.leftMouseDown.rawValue
let leftUpMask: UInt64 = 1 << CGEventType.leftMouseUp.rawValue
let rightDownMask: UInt64 = 1 << CGEventType.rightMouseDown.rawValue
let rightUpMask: UInt64 = 1 << CGEventType.rightMouseUp.rawValue
let otherDownMask: UInt64 = 1 << CGEventType.otherMouseDown.rawValue
let otherUpMask: UInt64 = 1 << CGEventType.otherMouseUp.rawValue
let leftDragMask: UInt64 = 1 << CGEventType.leftMouseDragged.rawValue
let rightDragMask: UInt64 = 1 << CGEventType.rightMouseDragged.rawValue
let otherDragMask: UInt64 = 1 << CGEventType.otherMouseDragged.rawValue
let eventMask: UInt64 = moveMask | leftDownMask | leftUpMask | rightDownMask | rightUpMask | otherDownMask | otherUpMask | leftDragMask | rightDragMask | otherDragMask

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
