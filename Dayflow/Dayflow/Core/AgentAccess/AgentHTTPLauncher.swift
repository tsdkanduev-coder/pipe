import Foundation

/// Keeps the local agent HTTP endpoint alive while Pipe is running.
final class AgentHTTPLauncher {
  static let shared = AgentHTTPLauncher()

  private var process: Process?

  func startIfNeeded() {
    guard process == nil || process?.isRunning == false else { return }

    let helpers = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers")
    let pipe = helpers.appendingPathComponent("pipe").path
    let fallback = helpers.appendingPathComponent("dayflow").path
    let cli = FileManager.default.isExecutableFile(atPath: pipe) ? pipe : fallback
    guard FileManager.default.isExecutableFile(atPath: cli) else {
      print("⚠️ Pipe: agent CLI is not bundled yet at \(cli)")
      return
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: cli)
    process.arguments = ["serve", "--port", String(PipeIdentity.httpPort)]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
      self.process = process
      print("ℹ️ Pipe: agent HTTP at \(PipeIdentity.httpBaseURL)")
    } catch {
      print("⚠️ Pipe: could not start agent HTTP: \(error)")
    }
  }

  func stop() {
    process?.terminate()
    process = nil
  }
}
