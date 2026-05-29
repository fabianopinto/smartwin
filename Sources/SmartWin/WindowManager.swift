import AppKit
import ApplicationServices
import Foundation

final class WindowManager: @unchecked Sendable {
    static let shared = WindowManager()

    /// Detect all windows from running applications
    nonisolated func detectWindows() -> [ApplicationWindowsGroup] {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        var groups: [ApplicationWindowsGroup] = []

        for app in runningApps {
            guard let appName = app.localizedName else { continue }
            let windows = getWindowsForApplication(app)

            if !windows.isEmpty {
                groups.append(ApplicationWindowsGroup(applicationName: appName, windows: windows))
            }
        }

        return groups.sorted { $0.applicationName < $1.applicationName }
    }

    /// Get windows for a specific application
    nonisolated func getWindowsForApplication(_ app: NSRunningApplication) -> [WindowInfo] {
        guard let appName = app.localizedName else { return [] }

        var windows: [WindowInfo] = []

        guard let windowElements = getAXWindowsForApplication(app) else {
            return windows
        }

        for windowElement in windowElements {
            if let windowInfo = createWindowInfo(from: windowElement, applicationName: appName) {
                windows.append(windowInfo)
            }
        }

        return windows
    }

    /// Get windows for application by name
    nonisolated func getWindowsForApplication(byName appName: String) -> [WindowInfo] {
        let workspace = NSWorkspace.shared
        guard let app = workspace.runningApplications.first(where: { $0.localizedName == appName })
        else {
            return []
        }
        return getWindowsForApplication(app)
    }

    /// Reposition and resize a window
    nonisolated func repositionWindow(
        applicationName: String, windowTitle: String, x: Int, y: Int, width: Int? = nil,
        height: Int? = nil
    ) throws {
        let workspace = NSWorkspace.shared
        guard
            let app = workspace.runningApplications.first(where: {
                $0.localizedName == applicationName
            })
        else {
            throw WindowError.applicationNotFound(applicationName)
        }

        guard let windowElements = getAXWindowsForApplication(app) else {
            throw WindowError.noAccessibility
        }

        var found = false
        for windowElement in windowElements {
            if let title = try getAXAttribute(windowElement, attribute: kAXTitleAttribute)
                as? String,
                title == windowTitle
            {
                try setWindowPosition(windowElement, x: x, y: y, width: width, height: height)
                found = true
                break
            }
        }

        if !found {
            throw WindowError.windowNotFound(windowTitle)
        }
    }

    /// Reposition and resize a window by application name (first window of the app)
    nonisolated func repositionWindow(
        applicationName: String, x: Int, y: Int, width: Int? = nil, height: Int? = nil
    ) throws {
        let workspace = NSWorkspace.shared
        guard
            let app = workspace.runningApplications.first(where: {
                $0.localizedName == applicationName
            })
        else {
            throw WindowError.applicationNotFound(applicationName)
        }

        guard let windowElements = getAXWindowsForApplication(app) else {
            throw WindowError.noAccessibility
        }

        guard let firstWindow = windowElements.first else {
            throw WindowError.noWindows(applicationName)
        }

        try setWindowPosition(firstWindow, x: x, y: y, width: width, height: height)
    }

    // MARK: - Private Helpers

    private nonisolated func getAXWindowsForApplication(_ app: NSRunningApplication)
        -> [AXUIElement]?
    {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var windowsValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            appElement, kAXWindowsAttribute as CFString, &windowsValue)

        guard result == .success, let windows = windowsValue as? [AXUIElement] else {
            return nil
        }

        return windows
    }

    private nonisolated func createWindowInfo(from element: AXUIElement, applicationName: String)
        -> WindowInfo?
    {
        guard let title = try? getAXAttribute(element, attribute: kAXTitleAttribute) as? String
        else {
            return nil
        }

        let position = getAXPosition(element)
        let size = getAXSize(element)
        let frame = getAXFrame(element)

        var x = 0
        var y = 0
        var width = 0
        var height = 0

        if let pos = position {
            x = Int(pos.x)
            y = Int(pos.y)
        } else if let rect = frame {
            x = Int(rect.origin.x)
            y = Int(rect.origin.y)
        }

        if let sz = size {
            width = Int(sz.width)
            height = Int(sz.height)
        } else if let rect = frame {
            width = Int(rect.size.width)
            height = Int(rect.size.height)
        }

        let windowID = try? getAXAttribute(element, attribute: "AXWindowNumber") as? NSNumber
        let id = windowID?.uint32Value

        return WindowInfo(
            applicationName: applicationName,
            windowTitle: title,
            windowID: id,
            x: x,
            y: y,
            width: width,
            height: height
        )
    }

    private nonisolated func getAXAttribute(_ element: AXUIElement, attribute: String) throws
        -> AnyObject?
    {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        if result != .success {
            return nil
        }
        return value
    }

    private nonisolated func getAXPosition(_ element: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXPositionAttribute as CFString,
            &value
        )
        guard result == .success, let value = value else {
            return nil
        }
        let axValue = unsafeDowncast(value, to: AXValue.self)

        var point = CGPoint.zero
        guard AXValueGetType(axValue) == .cgPoint,
            AXValueGetValue(axValue, .cgPoint, &point)
        else {
            return nil
        }

        return point
    }

    private nonisolated func getAXSize(_ element: AXUIElement) -> CGSize? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSizeAttribute as CFString,
            &value
        )
        guard result == .success, let value = value else {
            return nil
        }
        let axValue = unsafeDowncast(value, to: AXValue.self)

        var size = CGSize.zero
        guard AXValueGetType(axValue) == .cgSize,
            AXValueGetValue(axValue, .cgSize, &size)
        else {
            return nil
        }

        return size
    }

    private nonisolated func getAXFrame(_ element: AXUIElement) -> CGRect? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            element,
            "AXFrame" as CFString,
            &value
        )
        guard result == .success, let value = value else {
            return nil
        }
        let axValue = unsafeDowncast(value, to: AXValue.self)

        var rect = CGRect.zero
        guard AXValueGetType(axValue) == .cgRect,
            AXValueGetValue(axValue, .cgRect, &rect)
        else {
            return nil
        }

        return rect
    }

    private nonisolated func setWindowPosition(
        _ element: AXUIElement, x: Int, y: Int, width: Int?, height: Int?
    ) throws {
        var point = CGPoint(x: CGFloat(x), y: CGFloat(y))
        guard let positionAXValue = AXValueCreate(.cgPoint, &point) else {
            throw WindowError.failedToRepositionWindow
        }

        let posResult = AXUIElementSetAttributeValue(
            element,
            kAXPositionAttribute as CFString,
            positionAXValue
        )
        guard posResult == .success else {
            throw WindowError.failedToRepositionWindow
        }

        if let width = width, let height = height {
            var size = CGSize(width: CGFloat(width), height: CGFloat(height))
            guard let sizeAXValue = AXValueCreate(.cgSize, &size) else {
                throw WindowError.failedToRepositionWindow
            }

            let sizeResult = AXUIElementSetAttributeValue(
                element,
                kAXSizeAttribute as CFString,
                sizeAXValue
            )
            guard sizeResult == .success else {
                throw WindowError.failedToRepositionWindow
            }
        }
    }
}

enum WindowError: Error, CustomStringConvertible {
    case applicationNotFound(String)
    case windowNotFound(String)
    case noWindows(String)
    case noAccessibility
    case failedToRepositionWindow

    var description: String {
        switch self {
        case .applicationNotFound(let name):
            return "Application not found: \(name)"
        case .windowNotFound(let title):
            return "Window not found: \(title)"
        case .noWindows(let appName):
            return "No windows found for application: \(appName)"
        case .noAccessibility:
            return
                "Accessibility permissions denied. Enable in System Preferences > Security & Privacy > Accessibility"
        case .failedToRepositionWindow:
            return "Failed to reposition window"
        }
    }
}
