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
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let jsonData = try encoder.encode(groups)
                    print(String(data: jsonData, encoding: .utf8) ?? "")
                } else {
                    for group in groups {
                        print("▸ \(group)")
                        for window in group.windows {
                            print("  ├─ \(window)")
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

    @Argument(help: "Application name")
    var application: String

    @Option(name: .short, help: "Window title (if not specified, uses first window)")
    var window: String?

    @Option(name: .short, help: "X coordinate")
    var x: Int

    @Option(name: .short, help: "Y coordinate")
    var y: Int

    @Option(help: "Window width")
    var width: Int

    @Option(help: "Window height")
    var height: Int

    mutating func run() throws {
        let windowManager = WindowManager.shared

        if let windowTitle = window {
            try windowManager.repositionWindow(
                applicationName: application,
                windowTitle: windowTitle,
                x: x,
                y: y,
                width: width,
                height: height
            )
            print("✓ Repositioned window '\(windowTitle)' in \(application)")
        } else {
            try windowManager.repositionWindow(
                applicationName: application,
                x: x,
                y: y,
                width: width,
                height: height
            )
            print("✓ Repositioned first window of \(application)")
        }
    }
}
