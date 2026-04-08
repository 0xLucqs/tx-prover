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

// Max lines to keep in memory / display. Caps SwiftUI Text layer height and memory use.
private let maxDisplayLines = 500

struct ContentView: View {
    @State private var lines: [String] = []
    @State private var isRunning = false
    @State private var exitCode: Int32?
    @State private var copied = false
    @State private var startTime: Date?
    @State private var elapsed: TimeInterval = 0
    @State private var finalElapsed: TimeInterval?

    private var output: String { lines.joined(separator: "\n") }

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private func formatElapsed(_ t: TimeInterval) -> String {
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        let tenths = Int((t - floor(t)) * 10)
        if minutes > 0 {
            return String(format: "%dm %02d.%ds", minutes, seconds, tenths)
        } else {
            return String(format: "%d.%ds", seconds, tenths)
        }
    }

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

            if isRunning || finalElapsed != nil {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text(formatElapsed(isRunning ? elapsed : (finalElapsed ?? 0)))
                        .font(.system(.title3, design: .monospaced))
                }
                .foregroundStyle(isRunning ? .blue : .secondary)
            }

            HStack {
                if let code = exitCode {
                    Text(code == 0 ? "SUCCESS" : "FAILED (code \(code))")
                        .font(.headline)
                        .foregroundStyle(code == 0 ? .green : .red)
                }
                Spacer()
                if !lines.isEmpty {
                    Text("\(lines.count) lines")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                .onChange(of: lines.count) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .padding()
        .onReceive(timer) { _ in
            if let start = startTime, isRunning {
                elapsed = Date().timeIntervalSince(start)
            }
        }
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
        lines = []
        finalElapsed = nil
        elapsed = 0
        let start = Date()
        startTime = start

        DispatchQueue.global(qos: .userInitiated).async {
            globalLogHandler = { msg in
                DispatchQueue.main.async {
                    lines.append(msg)
                    // Cap the buffer to avoid unbounded SwiftUI Text growth.
                    if lines.count > maxDisplayLines {
                        lines.removeFirst(lines.count - maxDisplayLines)
                    }
                }
            }

            let code = prove_privacy_demo(logCallbackC)

            globalLogHandler = nil

            let total = Date().timeIntervalSince(start)
            DispatchQueue.main.async {
                exitCode = code
                finalElapsed = total
                isRunning = false
            }
        }
    }
}

