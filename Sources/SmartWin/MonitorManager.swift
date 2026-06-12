import AppKit
import Foundation
import CoreGraphics

final class MonitorManager: @unchecked Sendable {
    static let shared = MonitorManager()

    /// Detect all monitors and return their geometry information
    nonisolated func detectMonitors() -> [MonitorInfo] {
        let screens = NSScreen.screens
        var monitors: [MonitorInfo] = []

        for (index, screen) in screens.enumerated() {
            // Prefer CoreGraphics display bounds (global coordinates) to align
            // with Accessibility / AX coordinates. Fall back to screen.visibleFrame.
            var frame = screen.visibleFrame
            if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                let displayID = CGDirectDisplayID(screenNumber.uint32Value)
                let bounds = CGDisplayBounds(displayID)
                frame = bounds
            }
            let screenName =
                if #available(macOS 10.15, *) {
                    screen.localizedName
                } else {
                    screen.description
                }

            let monitorInfo = MonitorInfo(
                id: index,
                name: screenName,
                x: Int(frame.origin.x),
                y: Int(frame.origin.y),
                width: Int(frame.width),
                height: Int(frame.height),
                isMain: screen == NSScreen.main
            )
            monitors.append(monitorInfo)
        }

        return monitors
    }

    /// Get monitor by ID
    nonisolated func getMonitor(id: Int) -> MonitorInfo? {
        let monitors = detectMonitors()
        return monitors.first { $0.id == id }
    }
}
