import Foundation

enum PipeIdentity {
  static let productName = "PIP"
  static let productNameLatin = "PIP"
  static let bundleIdentifier = "app.pip.macos"
  static let applicationSupportFolder = "PIP"
  static let urlScheme = "pipe"
  static let cliCommand = "pipe"
  static let mcpServerName = "pipe"
  static let defaultsSuite = "app.pip.macos"
  static let httpHost = "127.0.0.1"
  static let httpPort: UInt16 = 8787

  static var httpBaseURL: String {
    "http://\(httpHost):\(httpPort)"
  }
}

enum PipePaths {
  static var applicationSupport: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(PipeIdentity.applicationSupportFolder, isDirectory: true)
  }

  static var database: URL {
    applicationSupport.appendingPathComponent("chunks.sqlite")
  }

  static var agentSocket: URL {
    applicationSupport.appendingPathComponent("agent.sock")
  }
}
