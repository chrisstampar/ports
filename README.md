# Ports

[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/platform-macOS%2013+-blue.svg)](https://developer.apple.com/macos/)

A lightweight **macOS menubar app** (SwiftUI) that lists listening **localhost TCP ports**, tries to infer **project names** from manifests and working directories, shows simple **health** indicators, and offers quick actions (open in browser, copy URL, kill process, labels).

## Features

- **Port scanning** — Uses `lsof` on an interval you choose (default 5s); shell commands time out after 15s so a stuck `lsof` does not hang the app.
- **Project detection** — Process CWD, then executable path, then parent CWD; reads `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, or `.git` folder name.
- **Health** — TCP connect to `127.0.0.1:port` (green / red / yellow for slow).
- **Actions** — Open in browser, copy `localhost:PORT`, kill (SIGTERM then SIGKILL after a short delay), custom labels.
- **Notifications** — Optional when a tracked port stops listening.
- **Launch at login** — Via `SMAppService`.
- **Dark UI** — Popover uses a dark appearance.

## Requirements

- macOS **13** or later
- **Xcode** or Swift toolchain (`swift` on the PATH)

## Clone and build

From the directory that contains `Package.swift` and `build.sh`:

```bash
git clone <YOUR_REPO_URL>
cd ports   # or your checkout folder name
chmod +x build.sh
./build.sh
```

`./build.sh` runs the test suite, builds release, bundles `Ports.app`, and embeds `assets/AppIcon.png` as the app icon when that file is present.

Install to `/Applications`:

```bash
./build.sh --install
```

Run locally:

```bash
open Ports.app
```

Click the network icon in the menu bar to open the port list.

**Gatekeeper:** If macOS blocks the app, right-click `Ports.app` → **Open**, or allow it under **System Settings → Privacy & Security**.

## Tests

```bash
swift test
swift test --verbose   # more detail
swift test --quiet     # CI / build script style
```

The project ships with an XCTest suite (see `Tests/PortsTests/`).

## How it works

1. Periodically runs `lsof -iTCP -sTCP:LISTEN -n -P` to discover listeners.
2. Filters common system ports (e.g. AirPlay ranges) and a small set of system process names.
3. Resolves each PID to a display name using CWD / executable / parent, then optional health check.
4. Renders results in a `MenuBarExtra` popover (`.window` style).

Settings persist in **UserDefaults** for bundle id `dev.ports.menubar` (see `Info.plist`).

## Project layout

| Path | Role |
|------|------|
| `Sources/PortsLib/` | Library: models, services, views, utilities |
| `Sources/Ports/main.swift` | Executable entry → `PortsApp.main()` |
| `Tests/PortsTests/` | Unit / integration tests |
| `build.sh` | Test, release build, `.app` bundle, ad-hoc codesign |
| `assets/AppIcon.png` | Optional; used to build `AppIcon.icns` in the bundle |

## Contributing

Issues and pull requests are welcome. Please run `swift test` before submitting changes. Match existing Swift style and keep diffs focused.

Continuous integration (`.github/workflows/ci.yml`) runs `swift test --quiet` on **macOS** for pushes and pull requests to `main` or `master`.

## Security

Ports runs **locally** and does not send port or process data to remote servers. It executes `/bin/sh -c` for `lsof` / `ps` only. Do not commit secrets, API keys, or personal machine paths into the repository.

## License

This project is licensed under the [MIT License](LICENSE).

## Troubleshooting

**No ports listed** — Start a dev server (e.g. `python3 -m http.server 8765`). Ports in the default excluded set (including many ephemeral ranges) are hidden; adjust **Settings → Excluded ports**.

**Notifications** — Enable in Settings and allow **Ports** under **System Settings → Notifications**.

**Xcode** — `open Package.swift` to open the package in Xcode for debugging.
