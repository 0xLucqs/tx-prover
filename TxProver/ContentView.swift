import SwiftUI

// Global log handler — C function pointers cannot capture context,
// so we bridge through a file-level variable.
private nonisolated(unsafe) var globalLogHandler: ((String) -> Void)?

// Top-level C-compatible callback forwarding to globalLogHandler.
private func logCallbackC(message: UnsafePointer<CChar>?) {
    guard let message else { return }
    let str = String(cString: message)
    globalLogHandler?(str)
}

struct ContentView: View {
    @State private var output = ""
    @State private var isRunning = false
    @State private var exitCode: Int32?
    @State private var copied = false

    var body: some View {
        VStack(spacing: 16) {
            Button(action: runProver) {
                Label(
                    isRunning ? "Proving..." : "Prove Transaction",
                    systemImage: isRunning ? "hourglass" : "play.fill"
                )
                .font(.title2)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
            }
            .disabled(isRunning)
            .buttonStyle(.borderedProminent)
            .tint(exitCode.map { $0 == 0 ? .green : .red } ?? .blue)

            HStack {
                if let code = exitCode {
                    Text(code == 0 ? "SUCCESS" : "FAILED (code \(code))")
                        .font(.headline)
                        .foregroundStyle(code == 0 ? .green : .red)
                }
                Spacer()
                if !output.isEmpty {
                    Button(copied ? "Saved!" : "Save Logs") {
                        saveLogs()
                    }
                    .buttonStyle(.bordered)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(output)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .id("bottom")
                }
                .onChange(of: output) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .padding()
    }

    private func saveLogs() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent("prover_logs.txt")
        try? output.write(to: url, atomically: true, encoding: .utf8)
        // Print path so it's visible in Xcode console / system log
        print("Logs written to: \(url.path)")
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }

    private func runProver() {
        isRunning = true
        exitCode = nil
        output = ""

        DispatchQueue.global(qos: .userInitiated).async {
            globalLogHandler = { msg in
                DispatchQueue.main.async {
                    output += msg + "\n"
                }
            }

            let code = prove_privacy_demo(logCallbackC)

            globalLogHandler = nil

            DispatchQueue.main.async {
                exitCode = code
                isRunning = false
            }
        }
    }
}

