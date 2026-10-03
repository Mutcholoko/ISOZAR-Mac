import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ConverterModel: ObservableObject {
    @Published var inputURL: URL?
    @Published var outputURL: URL?
    @Published var isRunning = false
    @Published var output = ""
    @Published var errorMessage: String?
    var process: Process?
    var stagingDirectory: URL?

    var canConvert: Bool { inputURL != nil && outputURL != nil && !isRunning }

    func chooseInput() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "iso") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an Xbox 360 ISO image"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        inputURL = url
        outputURL = url.deletingPathExtension().appendingPathExtension("zar")
        errorMessage = nil
        output = ""
    }

    func chooseOutput() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "zar") ?? .data]
        panel.nameFieldStringValue = (inputURL?.deletingPathExtension().lastPathComponent ?? "XboxGame") + ".zar"
        panel.message = "Choose where to save the ZAR archive"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        outputURL = url.pathExtension.lowercased() == "zar" ? url : url.appendingPathExtension("zar")
        errorMessage = nil
    }

    func convert() {
        guard canConvert, let inputURL, outputURL != nil else { return }
        let executable = Bundle.main.url(forResource: "XGDTool", withExtension: nil)
            ?? URL(fileURLWithPath: "/opt/homebrew/bin/XGDTool")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            errorMessage = "XGDTool is not installed. Build it with Scripts/build-xgdtool.sh, then place the executable in the app’s Resources folder or install it at /opt/homebrew/bin/XGDTool."
            return
        }

        isRunning = true
        errorMessage = nil
        output = "Starting conversion…\n"

        let task = Process()
        task.executableURL = executable
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent("ISOtoZAR-\(UUID().uuidString)", isDirectory: true)
        do { try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true) }
        catch {
            isRunning = false
            errorMessage = "Could not prepare a temporary output folder: \(error.localizedDescription)"
            return
        }
        stagingDirectory = staging
        task.arguments = ["--zar", "--offline", inputURL.path, staging.path]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        process = task

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in self?.output += text }
        }
        task.terminationHandler = { [weak self] process in
            pipe.fileHandleForReading.readabilityHandler = nil
            let code = process.terminationStatus
            Task { @MainActor in
                guard let self else { return }
                self.isRunning = false
                self.process = nil
                if process.terminationReason == .uncaughtSignal {
                    self.output += "\nConversion cancelled."
                    if let staging = self.stagingDirectory { try? FileManager.default.removeItem(at: staging) }
                    self.stagingDirectory = nil
                    return
                }
                if code == 0 {
                    let files: [URL]
                    if let staging = self.stagingDirectory {
                        files = (try? FileManager.default.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil)) ?? []
                    } else {
                        files = []
                    }
                    let zar = files.first { $0.pathExtension.lowercased() == "zar" }
                    do {
                        guard let zar, let destination = self.outputURL else { throw CocoaError(.fileNoSuchFile) }
                        if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
                        try FileManager.default.moveItem(at: zar, to: destination)
                        self.output += "\nConversion complete: \(destination.lastPathComponent)"
                    } catch {
                        self.errorMessage = "XGDTool finished, but the ZAR archive could not be placed at the selected destination: \(error.localizedDescription)"
                    }
                    if let staging = self.stagingDirectory { try? FileManager.default.removeItem(at: staging) }
                    self.stagingDirectory = nil
                } else {
                    self.errorMessage = "Conversion failed (XGDTool exit code \(code)). See the log below for details."
                    if let staging = self.stagingDirectory { try? FileManager.default.removeItem(at: staging) }
                    self.stagingDirectory = nil
                }
            }
        }

        do { try task.run() }
        catch {
            isRunning = false
            process = nil
            errorMessage = "Could not start XGDTool: \(error.localizedDescription)"
        }
    }

    func cancel() {
        process?.terminate()
    }
}

struct ConverterView: View {
    @StateObject private var model = ConverterModel()

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "opticaldisc.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ISO to ZAR")
                            .font(.system(size: 25, weight: .semibold, design: .rounded))
                        Text("Xbox 360 game image converter")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 12)
                Text("Convert an Xbox 360 ISO into a compressed ZAR archive.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                fileRow(title: "Source ISO", subtitle: model.inputURL?.path ?? "Select an .iso game image", icon: "doc.zipper") {
                    model.chooseInput()
                }

                Image(systemName: "arrow.down")
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, -10)

                fileRow(title: "Destination ZAR", subtitle: model.outputURL?.path ?? "Choose output location", icon: "archivebox") {
                    model.chooseOutput()
                }

                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if model.isRunning {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Converting ISO to ZAR…")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Cancel", role: .cancel) { model.cancel() }
                    }
                    .padding(.top, 2)
                }

                if !model.output.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Conversion log")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ScrollView {
                            Text(model.output)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                        .frame(height: 104)
                        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(24)

            Spacer(minLength: 0)
            Divider()
            HStack {
                Text("Powered by XGDTool")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    model.convert()
                } label: {
                    Label(model.isRunning ? "Converting…" : "Convert to ZAR", systemImage: "arrow.trianglehead.2.clockwise")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canConvert)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(.background)
    }

    private func fileRow(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 19))
                    .foregroundStyle(.tint)
                    .frame(width: 42, height: 42)
                    .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Text(title == "Source ISO" && model.inputURL == nil ? "Browse…" : "Change…")
                    .font(.callout)
                    .foregroundStyle(.tint)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 1))
    }
}
