// The Swift Programming Language
// https://docs.swift.org/swift-book
//
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser
import Foundation

@main
struct SmartWin: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "smartwin",
        abstract: "Manage desktop window positioning and resizing",
        subcommands: [
            DetectMonitors.self,
            DetectWindows.self,
            RepositionWindow.self,
        ]
    )
}

struct DetectMonitors: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "detect-monitors",
        abstract: "List all monitors with their geometry"
    )

    @Flag(name: .short, help: "Output as JSON")
    var json: Bool = false

    mutating func run() throws {
        let monitors = MonitorManager.shared.detectMonitors()

        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(monitors)
            print(String(data: jsonData, encoding: .utf8) ?? "")
        } else {
            if monitors.isEmpty {
                print("No monitors detected")
            } else {
                for monitor in monitors {
                    print(monitor)
                }
            }
        }
    }
}

// MARK: - Detect Windows Command

struct DetectWindows: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "detect-windows",
        abstract: "List all application windows with their positions and sizes"
    )

    @Option(name: .short, help: "Filter by application name")
    var application: String?

    @Flag(name: .short, help: "Output as JSON")
    var json: Bool = false

    mutating func run() throws {
        let windowManager = WindowManager.shared

        if let appName = application {
            let windows = windowManager.getWindowsForApplication(byName: appName)

            if windows.isEmpty {
                print("No windows found for application: \(appName)")
            } else {
                if json {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let jsonData = try encoder.encode(windows)
                    print(String(data: jsonData, encoding: .utf8) ?? "")
                } else {
                    for window in windows {
                        print(window)
                    }
                }
            }
        } else {
            let groups = windowManager.detectWindows()

            if groups.isEmpty {
                print("No windows detected")
            } else {
                if json {
                    struct JSONWindow: Codable {
                        let windowIndex: Int
                        let windowTitle: String
                        let windowID: UInt32?
                        let x: Int
                        let y: Int
                        let width: Int
                        let height: Int
                    }

                    struct JSONApp: Codable {
                        let appIndex: Int
                        let applicationName: String
                        let windows: [JSONWindow]
                    }

                    var output: [JSONApp] = []
                    for (i, group) in groups.enumerated() {
                        var wins: [JSONWindow] = []
                        for (j, w) in group.windows.enumerated() {
                            wins.append(
                                JSONWindow(
                                    windowIndex: j, windowTitle: w.windowTitle,
                                    windowID: w.windowID, x: w.x, y: w.y, width: w.width,
                                    height: w.height))
                        }
                        output.append(
                            JSONApp(
                                appIndex: i, applicationName: group.applicationName, windows: wins))
                    }

                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let jsonData = try encoder.encode(output)
                    print(String(data: jsonData, encoding: .utf8) ?? "")
                } else {
                    for (i, group) in groups.enumerated() {
                        print("\(i): ▸ \(group)")
                        for (j, window) in group.windows.enumerated() {
                            print("  ├─ [\(j)] \(window)")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Reposition Window Command

struct RepositionWindow: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reposition-window",
        abstract: "Move and resize an application window"
    )

    @Argument(help: "Application name or zero-based index")
    var application: String

    @Option(
        name: .short, parsing: .unconditional,
        help: "Window title or zero-based index (if not specified, uses first window)")
    var window: String?

    @Option(name: .short, parsing: .unconditional, help: "X coordinate (can be negative)")
    var x: Int

    @Option(name: .short, parsing: .unconditional, help: "Y coordinate (can be negative)")
    var y: Int

    @Option(parsing: .unconditional, help: "Window width (positive integer)")
    var width: Int?

    @Option(parsing: .unconditional, help: "Window height (positive integer)")
    var height: Int?

    func validate() throws {
        let isResizing = width != nil || height != nil
        if isResizing {
            guard let width = width, let height = height else {
                throw ValidationError("Both --width and --height must be provided together")
            }
            guard width > 0 && height > 0 else {
                throw ValidationError("Width and height must be positive")
            }
        }
    }

    mutating func run() throws {
        let windowManager = WindowManager.shared
        // Support numeric application index (zero-based) as alternative to name
        var targetAppName = application
        if let appIndex = Int(application) {
            let groups = windowManager.detectWindows()
            guard appIndex >= 0 && appIndex < groups.count else {
                throw ValidationError("Application index out of range: \(appIndex)")
            }
            targetAppName = groups[appIndex].applicationName
        }

        if let windowArg = window {
            // Support numeric window index (zero-based) as alternative to title
            if let winIndex = Int(windowArg) {
                let wins = windowManager.getWindowsForApplication(byName: targetAppName)
                guard winIndex >= 0 && winIndex < wins.count else {
                    throw ValidationError("Window index out of range: \(winIndex)")
                }
                let winTitle = wins[winIndex].windowTitle
                try windowManager.repositionWindow(
                    applicationName: targetAppName,
                    windowTitle: winTitle,
                    x: x,
                    y: y,
                    width: width,
                    height: height
                )
                print("✓ Repositioned window '\(winTitle)' in \(targetAppName)")
            } else {
                try windowManager.repositionWindow(
                    applicationName: targetAppName,
                    windowTitle: windowArg,
                    x: x,
                    y: y,
                    width: width,
                    height: height
                )
                print("✓ Repositioned window '\(windowArg)' in \(targetAppName)")
            }
        } else {
            try windowManager.repositionWindow(
                applicationName: targetAppName,
                x: x,
                y: y,
                width: width,
                height: height
            )
            print("✓ Repositioned first window of \(targetAppName)")
        }
    }
}
