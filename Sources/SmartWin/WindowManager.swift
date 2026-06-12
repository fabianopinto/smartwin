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
        _ = try repositionWindow(
            applicationName: applicationName,
            windowIdentifier: nil,
            x: x,
            y: y,
            monitorIndex: 0,
            left: nil,
            top: nil,
            right: nil,
            bottom: nil,
            width: width,
            height: height
        )
    }

    /// Reposition and resize a window with optional monitor-relative coordinates
    nonisolated func repositionWindow(
        applicationName: String,
        windowIdentifier: String? = nil,
        x: Int? = nil,
        y: Int? = nil,
        monitorIndex: Int = 0,
        left: Int? = nil,
        top: Int? = nil,
        right: Int? = nil,
        bottom: Int? = nil,
        width: Int? = nil,
        height: Int? = nil
    ) throws -> String {
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

        guard !windowElements.isEmpty else {
            throw WindowError.noWindows(applicationName)
        }

        let windowElement: AXUIElement
        let resolvedTitle: String

        if let identifier = windowIdentifier {
            if let index = Int(identifier) {
                guard index >= 0 && index < windowElements.count else {
                    throw WindowError.windowNotFound(identifier)
                }
                windowElement = windowElements[index]
                resolvedTitle =
                    (try getAXAttribute(windowElement, attribute: kAXTitleAttribute) as? String)
                    ?? identifier
            } else {
                guard
                    let foundWindow = windowElements.first(where: {
                        (try? getAXAttribute($0, attribute: kAXTitleAttribute) as? String)
                            == identifier
                    })
                else {
                    throw WindowError.windowNotFound(identifier)
                }
                windowElement = foundWindow
                resolvedTitle = identifier
            }
        } else {
            windowElement = windowElements[0]
            resolvedTitle =
                (try getAXAttribute(windowElement, attribute: kAXTitleAttribute) as? String)
                ?? "<unknown>"
        }

        let position =
            getAXPosition(windowElement)
            ?? getAXFrame(windowElement).map { CGPoint(x: $0.origin.x, y: $0.origin.y) }
            ?? CGPoint.zero
        let size =
            getAXSize(windowElement)
            ?? getAXFrame(windowElement).map { CGSize(width: $0.width, height: $0.height) }
            ?? CGSize(width: 0, height: 0)

        let currentX = Int(position.x)
        let currentY = Int(position.y)
        let currentWidth = Int(size.width)
        let currentHeight = Int(size.height)

        var finalX = currentX
        var finalY = currentY
        let effectiveWidth = width ?? currentWidth
        let effectiveHeight = height ?? currentHeight

        if let x = x {
            finalX = x
        }
        if let y = y {
            finalY = y
        }

        if left != nil || right != nil || top != nil || bottom != nil {
            guard let monitor = MonitorManager.shared.getMonitor(id: monitorIndex) else {
                throw WindowError.monitorNotFound(monitorIndex)
            }

            if let left = left {
                finalX = monitor.x + left
            } else if let right = right {
                finalX = monitor.x + monitor.width - effectiveWidth - right
            }

            if let top = top {
                // Align to monitor's top border: offset downwards from monitor.y
                finalY = monitor.y + top
            } else if let bottom = bottom {
                // Align to monitor's bottom border: compute from top edge
                finalY = monitor.y + monitor.height - effectiveHeight - bottom
            }
        }

        try setWindowPosition(windowElement, x: finalX, y: finalY, width: width, height: height)
        return resolvedTitle
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
    case monitorNotFound(Int)
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
        case .monitorNotFound(let monitorIndex):
            return "Monitor not found: \(monitorIndex)"
        case .noAccessibility:
            return
                "Accessibility permissions denied. Enable in System Preferences > Security & Privacy > Accessibility"
        case .failedToRepositionWindow:
            return "Failed to reposition window"
        }
    }
}
