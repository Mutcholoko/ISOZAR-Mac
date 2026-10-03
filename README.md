# ISO to ZAR for macOS

A small native SwiftUI app that converts one Xbox 360 `.iso` image to a `.zar` archive using the conversion engine from [XGDTool](https://github.com/wiredopposite/XGDTool).

<img width="970" height="678" style="width:50%" alt="image" src="https://github.com/user-attachments/assets/578ad0fa-ae0d-49e0-bc4c-2f5e72c4e766" />

## Build

Requirements: macOS 13+, Xcode Command Line Tools, CMake, and XGDTool's native dependencies (LZ4, Zstandard, OpenSSL, cURL). The upstream project uses CMake and fetches its CLI-only header dependencies during configuration.

```sh
./Scripts/build-app.sh
```

The first build clones XGDTool and its submodules, builds the CLI with `--zar` support, and packages it inside `outputs/ISO to ZAR.app`. Open the app by double-clicking it.

## Using the GitHub release

This app is distributed without an Apple Developer ID signature. When downloaded from GitHub, macOS may warn that **“ISO to ZAR” is damaged and can’t be opened**. To use the distributed file, you need to:

1. Download the app archive from **Releases** and unzip it.
2. If macOS says the app is damaged or from an unidentified developer, open **System Settings → Privacy & Security**, scroll to the Security section, and choose **Open Anyway** for ISO to ZAR if that option appears. Authenticate if macOS asks.
3. Open the Terminal and run:

```sh
cd Downloads
xattr -dr com.apple.quarantine "ISO to ZAR.app"
```

This removes Gatekeeper's downloaded-file quarantine check for that copy. Alternatively, you can simply Build the app yourself, and the generated output file won't have any warnings.

The interface selects an ISO, defaults the output beside it with a `.zar` extension.

## License

XGDTool is GPL-3.0. See its upstream repository and include its license and attribution when distributing a build. This app's wrapper source is provided in this repository.
