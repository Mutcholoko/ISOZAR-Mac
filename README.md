# ISO to ZAR for macOS

A small native SwiftUI app that converts one Xbox 360 `.iso` image to a `.zar` archive using the conversion engine from [XGDTool](https://github.com/wiredopposite/XGDTool).

## Build

Requirements: macOS 13+, Xcode Command Line Tools, CMake, and XGDTool's native dependencies (LZ4, Zstandard, OpenSSL, cURL). The upstream project uses CMake and fetches its CLI-only header dependencies during configuration.

```sh
./Scripts/build-app.sh
```

The first build clones XGDTool and its submodules, builds the CLI with `--zar` support, and packages it inside `outputs/ISO to ZAR.app`. Open the app by double-clicking it.

The interface selects an ISO, defaults the output beside it with a `.zar` extension, and runs the equivalent of:

```sh
XGDTool --zar --offline /path/to/game.iso /path/to/output-folder
```

Online metadata lookup is disabled for this focused converter. XGDTool's output naming and archive behavior remain upstream-defined.

## License

XGDTool is GPL-3.0. See its upstream repository and include its license and attribution when distributing a build. This app's wrapper source is provided in this repository.
