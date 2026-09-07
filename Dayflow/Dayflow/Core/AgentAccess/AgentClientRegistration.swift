//
//  AgentClientRegistration.swift
//  PIP
//
//  Connects MCP clients to the bundled `pipe` binary. Cursor and MultiTool
//  get a config file we write ourselves. Claude Code / Desktop keep their
//  JSON files. Codex uses its own CLI.
//

import AppKit
import Foundation

enum AgentClient: String, CaseIterable, Identifiable {
  case multiTool
  case cursor
  case vsCode
  case claudeCode
  case claudeDesktop
  case codex

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .multiTool: return "MultiTool"
    case .cursor: return "Cursor"
    case .vsCode: return "VS Code"
    case .claudeCode: return "Claude Code"
    case .claudeDesktop: return "Claude Desktop"
    case .codex: return "Codex"
    }
  }
}

@MainActor
enum AgentClientRegistration {

  static var cliPath: String {
    let helpers = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers")
    let pipe = helpers.appendingPathComponent("pipe").path
    if FileManager.default.isExecutableFile(atPath: pipe) { return pipe }
    return helpers.appendingPathComponent("dayflow").path
  }

  static var manualConfigSnippet: String {
    """
    "\(PipeIdentity.mcpServerName)": {
      "command": "\(cliPath)",
      "args": ["mcp"]
    }
    """
  }

  private static var cursorConfigURL: URL {
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cursor/mcp.json")
  }

  private static var multiToolConfigURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".config/gigatool/opencode.json")
  }

  private static var claudeCodeConfigURL: URL {
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
  }

  private static var claudeDesktopConfigURL: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Claude/claude_desktop_config.json")
  }

  // MARK: - Detection

  static func isInstalled(_ client: AgentClient) -> Bool {
    let fileManager = FileManager.default
    switch client {
    case .multiTool:
      return fileManager.fileExists(atPath: "/Applications/MultiTool.app")
        || fileManager.fileExists(atPath: "/Applications/GigaTool.app")
    case .codex:
      return CodexExecutableResolver.shared.resolve() != nil
    case .claudeCode:
      return fileManager.fileExists(atPath: claudeCodeConfigURL.path)
    case .claudeDesktop:
      return fileManager.fileExists(
        atPath: claudeDesktopConfigURL.deletingLastPathComponent().path)
    case .cursor:
      return fileManager.fileExists(atPath: "/Applications/Cursor.app")
    case .vsCode:
      return fileManager.fileExists(atPath: "/Applications/Visual Studio Code.app")
    }
  }

  static func isConnected(_ client: AgentClient) -> Bool {
    switch client {
    case .codex:
      return CodexMCPRegistration(cliPath: cliPath).status() == .connected
    case .claudeCode:
      return mcpEntry(inConfigAt: claudeCodeConfigURL, rootKey: "mcpServers") != nil
    case .claudeDesktop:
      return mcpEntry(inConfigAt: claudeDesktopConfigURL, rootKey: "mcpServers") != nil
    case .cursor:
      return mcpEntry(inConfigAt: cursorConfigURL, rootKey: "mcpServers") != nil
    case .multiTool:
      return mcpEntry(inConfigAt: multiToolConfigURL, rootKey: "mcp") != nil
    case .vsCode:
      return false
    }
  }

  // MARK: - Connect

  enum RegistrationResult {
    case connected
    case openedInstaller
    case failed(String)
  }

  static var preferredClients: [AgentClient] { [.multiTool, .codex, .cursor] }

  @discardableResult
  static func connectPreferredClients() -> [AgentClient] {
    preferredClients.compactMap { client in
      if client != .cursor, !isInstalled(client) { return nil }
      if case .connected = connect(client) { return client }
      return nil
    }
  }

  static func connectedPreferredNames() -> [String] {
    preferredClients.filter { isConnected($0) }.map(\.displayName)
  }

  static func connect(_ client: AgentClient) -> RegistrationResult {
    switch client {
    case .codex:
      switch CodexMCPRegistration(cliPath: cliPath).connect() {
      case .connected: return .connected
      case .notInstalled: return .failed("Codex isn't installed on this Mac.")
      case .disconnected: return .failed("Codex didn't keep the PIP connection.")
      case .failed(let message): return .failed(message)
      }
    case .claudeCode:
      return writeStdioEntry(configAt: claudeCodeConfigURL, rootKey: "mcpServers", includeType: true)
    case .claudeDesktop:
      return writeStdioEntry(
        configAt: claudeDesktopConfigURL, rootKey: "mcpServers", includeType: true)
    case .cursor:
      return writeStdioEntry(configAt: cursorConfigURL, rootKey: "mcpServers", includeType: false)
    case .multiTool:
      return writeMultiToolEntry()
    case .vsCode:
      let config: [String: Any] = [
        "name": PipeIdentity.mcpServerName, "command": cliPath, "args": ["mcp"],
      ]
      guard let data = try? JSONSerialization.data(withJSONObject: config),
        let encoded = String(data: data, encoding: .utf8)?.addingPercentEncoding(
          withAllowedCharacters: .alphanumerics),
        let url = URL(string: "vscode:mcp/install?\(encoded)")
      else { return .failed("Could not build the VS Code install link.") }
      NSWorkspace.shared.open(url)
      return .openedInstaller
    }
  }

  static func disconnect(_ client: AgentClient) {
    switch client {
    case .codex:
      _ = CodexMCPRegistration(cliPath: cliPath).disconnect()
    case .claudeCode:
      removeEntry(configAt: claudeCodeConfigURL, rootKey: "mcpServers")
    case .claudeDesktop:
      removeEntry(configAt: claudeDesktopConfigURL, rootKey: "mcpServers")
    case .cursor:
      removeEntry(configAt: cursorConfigURL, rootKey: "mcpServers")
    case .multiTool:
      removeEntry(configAt: multiToolConfigURL, rootKey: "mcp")
    case .vsCode:
      break
    }
  }

  // MARK: - Config file editing

  private static func mcpEntry(inConfigAt url: URL, rootKey: String) -> [String: Any]? {
    guard let data = try? Data(contentsOf: url),
      let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let servers = config[rootKey] as? [String: Any]
    else { return nil }
    return servers[PipeIdentity.mcpServerName] as? [String: Any]
  }

  private static func writeStdioEntry(
    configAt url: URL,
    rootKey: String,
    includeType: Bool
  ) -> RegistrationResult {
    var config: [String: Any] = [:]
    if let data = try? Data(contentsOf: url) {
      guard let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return .failed(
          "\(url.lastPathComponent) exists but isn't valid JSON — not touching it.")
      }
      config = existing
    }

    var servers = config[rootKey] as? [String: Any] ?? [:]
    var entry: [String: Any] = ["command": cliPath, "args": ["mcp"]]
    if includeType { entry["type"] = "stdio" }
    servers[PipeIdentity.mcpServerName] = entry
    config[rootKey] = servers

    return writeJSON(config, to: url)
  }

  private static func writeMultiToolEntry() -> RegistrationResult {
    let url = multiToolConfigURL
    var config: [String: Any] = [:]
    if let data = try? Data(contentsOf: url) {
      guard let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return .failed("opencode.json exists but isn't valid JSON — not touching it.")
      }
      config = existing
    }
    if config["$schema"] == nil {
      config["$schema"] = "./config-schema.json"
    }

    var servers = config["mcp"] as? [String: Any] ?? [:]
    servers[PipeIdentity.mcpServerName] = [
      "type": "local",
      "command": [cliPath, "mcp"],
      "enabled": true,
      "timeout": 15_000,
    ] as [String: Any]
    config["mcp"] = servers
    return writeJSON(config, to: url)
  }

  private static func writeJSON(_ config: [String: Any], to url: URL) -> RegistrationResult {
    do {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      let data = try JSONSerialization.data(
        withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
      try data.write(to: url, options: .atomic)
      return .connected
    } catch {
      return .failed("Could not update \(url.lastPathComponent): \(error.localizedDescription)")
    }
  }

  private static func removeEntry(configAt url: URL, rootKey: String) {
    guard let data = try? Data(contentsOf: url),
      var config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      var servers = config[rootKey] as? [String: Any],
      servers[PipeIdentity.mcpServerName] != nil
    else { return }
    servers.removeValue(forKey: PipeIdentity.mcpServerName)
    config[rootKey] = servers
    if let updated = try? JSONSerialization.data(
      withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
    {
      try? updated.write(to: url, options: .atomic)
    }
  }

  static func repairStaleRegistrations() {
    let owned: [(URL, String)] = [
      (claudeCodeConfigURL, "mcpServers"),
      (claudeDesktopConfigURL, "mcpServers"),
      (cursorConfigURL, "mcpServers"),
    ]
    for (url, rootKey) in owned {
      guard let entry = mcpEntry(inConfigAt: url, rootKey: rootKey) else { continue }
      if let recorded = entry["command"] as? String, recorded != cliPath {
        _ = writeStdioEntry(configAt: url, rootKey: rootKey, includeType: rootKey == "mcpServers")
      }
    }

    if let entry = mcpEntry(inConfigAt: multiToolConfigURL, rootKey: "mcp") {
      let recorded: String?
      if let command = entry["command"] as? String {
        recorded = command
      } else if let command = entry["command"] as? [String] {
        recorded = command.first
      } else {
        recorded = nil
      }
      if let recorded, recorded != cliPath {
        _ = writeMultiToolEntry()
      }
    }

    let codexRegistration = CodexMCPRegistration(cliPath: cliPath)
    Task.detached(priority: .utility) {
      codexRegistration.repairStaleRegistration()
    }
  }

  // MARK: - Terminal command

  static var manualTerminalInstallCommand: String {
    "sudo mkdir -p /usr/local/bin && sudo ln -sf \(LoginShellRunner.shellEscape(cliPath)) /usr/local/bin/\(PipeIdentity.cliCommand)"
  }

  static var terminalCommandInstalled: Bool {
    (try? FileManager.default.destinationOfSymbolicLink(
      atPath: "/usr/local/bin/\(PipeIdentity.cliCommand)")) == cliPath
  }

  static func installTerminalCommand() -> String? {
    let linkPath = "/usr/local/bin/\(PipeIdentity.cliCommand)"
    let fileManager = FileManager.default
    do {
      if fileManager.fileExists(atPath: linkPath) {
        try fileManager.removeItem(atPath: linkPath)
      }
      try fileManager.createSymbolicLink(atPath: linkPath, withDestinationPath: cliPath)
      return nil
    } catch {
      return
        "Automatic install failed because /usr/local/bin requires administrator access on this Mac. Copy the command below and run it in Terminal."
    }
  }
}
