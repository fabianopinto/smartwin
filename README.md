# SmartWin - Desktop Window Manager

A powerful command-line tool to manage desktop window positioning and resizing on macOS. Monitor multiple displays, detect application windows, and automatically reposition/resize them.

## Features

- 🖥️ **Detect Multiple Monitors** - List all connected monitors with their geometry (ID, position, size)
- 🪟 **Detect Application Windows** - Enumerate all open windows with their positions and sizes
- 📍 **Reposition Windows** - Move and resize any application window to specific coordinates and dimensions
- 📊 **JSON Output** - All commands support JSON output for easy scripting and automation
- 🔄 **Multiple Windows** - Handle multiple windows of the same application

## Installation

### Build from Source

```bash
git clone https://github.com/yourusername/SmartWin.git
cd SmartWin
swift build -c release
# Executable will be at .build/release/SmartWin
```

### Install to System

```bash
cp .build/release/SmartWin /usr/local/bin/
```

## Usage

### Detect Monitors

List all monitors with their geometry information:

```bash
smartwin detect-monitors
```

Output:
```
Monitor #0: Built-in Retina Display [Main] @ (0, 0) 1728x1117
Monitor #1: LG Display @ (1728, 0) 2560x1440
```

**JSON Output:**
```bash
smartwin detect-monitors -j
```

Output:
```json
[
  {
    "id": 0,
    "name": "Built-in Retina Display",
    "x": 0,
    "y": 0,
    "width": 1728,
    "height": 1117,
    "isMain": true
  }
]
```

### Detect Windows

List all open application windows:

```bash
smartwin detect-windows
```

**Filter by Application:**
```bash
smartwin detect-windows -a "Safari"
```

**JSON Output:**
```bash
smartwin detect-windows -j
```

Output:
```json
[
  {
    "applicationName": "Safari",
    "windows": [
      {
        "windowTitle": "GitHub",
        "windowID": 1234,
        "x": 100,
        "y": 100,
        "width": 800,
        "height": 600
      }
    ]
  }
]
```

### Reposition Window

Move and resize an application window:

```bash
smartwin reposition-window "Safari" -x 0 -y 0 --width 1728 --height 1117
```

**Reposition Specific Window:**
```bash
smartwin reposition-window "Safari" -w "GitHub" -x 100 -y 100 --width 800 --height 600
```

## Command Reference

### detect-monitors

List all monitors with their geometry.

```
USAGE: smartwin detect-monitors [-j]

OPTIONS:
  -j                      Output as JSON
  -h, --help              Show help information.
```

### detect-windows

List all application windows with their positions and sizes.

```
USAGE: smartwin detect-windows [-a <a>] [-j]

OPTIONS:
  -a <a>                  Filter by application name
  -j                      Output as JSON
  -h, --help              Show help information.
```

### reposition-window

Move and resize an application window.

```
USAGE: smartwin reposition-window <application> [-w <w>] -x <x> -y <y> --width <width> --height <height>

ARGUMENTS:
  <application>           Application name

OPTIONS:
  -w <w>                  Window title (if not specified, uses first window)
  -x <x>                  X coordinate
  -y <y>                  Y coordinate
  --width <width>         Window width
  --height <height>       Window height
  -h, --help              Show help information.
```

## Examples

### Example 1: Center a Window on Main Monitor

```bash
# Get monitor dimensions
smartwin detect-monitors -j | jq '.[0]'

# Calculate center position and move window
smartwin reposition-window "Terminal" -x 464 -y 258 --width 800 --height 600
```

### Example 2: Organize Multiple Applications

```bash
# Position Safari in top-left quadrant
smartwin reposition-window "Safari" -x 0 -y 0 --width 864 --height 558

# Position VS Code in top-right quadrant
smartwin reposition-window "Visual Studio Code" -x 864 -y 0 --width 864 --height 558

# Position Terminal in bottom-left
smartwin reposition-window "Terminal" -x 0 -y 558 --width 864 --height 559
```

### Example 3: Get Window Details in JSON

```bash
smartwin detect-windows -a "Firefox" -j | jq '.[] | .windows[]'
```

## Requirements

- macOS 10.14 or later
- Swift 6.0 or later (for building)
- Accessibility permissions enabled (for window manipulation)

### Enable Accessibility Permissions

To use window positioning features:
1. Open System Preferences → Security & Privacy → Accessibility
2. Add the terminal application you use (Terminal, iTerm2, etc.)
3. Restart your terminal application

## Architecture

The project is organized into modular components:

- **Models.swift** - Data structures for monitors and windows
- **MonitorManager.swift** - Monitor detection using NSScreen
- **WindowManager.swift** - Window detection and manipulation using Accessibility API
- **SmartWin.swift** - Command-line interface using ArgumentParser

## Limitations

- Requires Accessibility permissions for window manipulation
- Some applications may restrict window access
- Window positioning may not work with full-screen applications
- Some applications may not report window dimensions accurately

## Troubleshooting

### "No windows detected"
This usually means Accessibility permissions are not granted. Enable them in System Preferences → Security & Privacy → Accessibility.

### "Accessibility permissions denied"
The application needs permission to access window information. Grant access in System Preferences.

### Window doesn't move
Some applications (especially Apple's) may have restrictions. Try with other applications first to verify the tool works.

## License

MIT License

## Contributing

Contributions are welcome! Please submit pull requests or open issues for bugs and feature requests.
