import Foundation

// MARK: - Data Models

struct MonitorInfo: Codable, CustomStringConvertible {
    let id: Int
    let name: String
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    let isMain: Bool

    var description: String {
        let mainLabel = isMain ? " [Main]" : ""
        return "Monitor #\(id): \(name)\(mainLabel) @ (\(x), \(y)) \(width)x\(height)"
    }
}

struct WindowInfo: Codable, CustomStringConvertible {
    let applicationName: String
    let windowTitle: String
    let windowID: UInt32?
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    var description: String {
        let idStr = windowID.map { "ID:\($0) " } ?? ""
        return "\(applicationName) - \(windowTitle) [\(idStr)@ (\(x), \(y)) \(width)x\(height)]"
    }
}

struct ApplicationWindowsGroup: Codable, CustomStringConvertible {
    let applicationName: String
    let windows: [WindowInfo]

    var description: String {
        let count = windows.count
        let windowsLabel = count == 1 ? "window" : "windows"
        return "\(applicationName) (\(count) \(windowsLabel))"
    }
}
