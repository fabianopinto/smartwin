import AppKit
import Foundation

final class MonitorManager: @unchecked Sendable {
    static let shared = MonitorManager()

    /// Detect all monitors and return their geometry information
    nonisolated func detectMonitors() -> [MonitorInfo] {
        let screens = NSScreen.screens
        var monitors: [MonitorInfo] = []

        for (index, screen) in screens.enumerated() {
            let frame = screen.frame
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
