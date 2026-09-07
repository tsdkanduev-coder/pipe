import Foundation

/// Makes the local Ollama model the default analysis path and pulls it if missing.
enum LocalModelBootstrap {
  private static let tagsURL = URL(string: "http://127.0.0.1:11434/api/tags")!
  private static let lastPullKey = "pipeLocalModelPullStartedAt"

  static func startIfNeeded() {
    preferLocalProvider()
    Task.detached(priority: .utility) {
      await ensureRecommendedModel()
    }
  }

  static func preferLocalProvider() {
    let defaults = UserDefaults.standard
    if defaults.bool(forKey: "pipeDidSetDefaultLocalProvider") { return }

    do {
      let current = try LLMProviderRoutingStore.load()
      if current.primary != .local {
        try LLMProviderRoutingStore.save(LLMProviderRouting(primary: .local))
      }
    } catch {
      try? LLMProviderRoutingStore.save(LLMProviderRouting(primary: .local))
    }

    if LocalModelPreferences.currentPreset() == nil {
      LocalModelPreferences.savePreset(.recommended)
    }
    defaults.set(true, forKey: "pipeDidSetDefaultLocalProvider")
  }

  private static func ensureRecommendedModel() async {
    guard await ollamaIsReachable() else {
      print("ℹ️ Pipe: Ollama is not reachable at 127.0.0.1:11434")
      return
    }

    let model = LocalModelPreset.recommended.modelId(for: .ollama)
    if await installedModels().contains(where: { $0 == model || $0.hasPrefix(model + ":") }) {
      print("ℹ️ Pipe: local model \(model) is already installed")
      return
    }

    let defaults = UserDefaults.standard
    if defaults.object(forKey: lastPullKey) != nil {
      print("ℹ️ Pipe: local model pull already started earlier")
      return
    }
    defaults.set(Date().timeIntervalSince1970, forKey: lastPullKey)

    print("ℹ️ Pipe: pulling local model \(model)")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ollama")
    if !FileManager.default.isExecutableFile(atPath: process.executableURL!.path) {
      process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ollama")
    }
    process.arguments = ["pull", model]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
    } catch {
      print("⚠️ Pipe: could not start ollama pull: \(error)")
      defaults.removeObject(forKey: lastPullKey)
    }
  }

  private static func ollamaIsReachable() async -> Bool {
    var request = URLRequest(url: tagsURL)
    request.timeoutInterval = 2
    do {
      let (_, response) = try await URLSession.shared.data(for: request)
      return (response as? HTTPURLResponse)?.statusCode == 200
    } catch {
      return false
    }
  }

  private static func installedModels() async -> [String] {
    var request = URLRequest(url: tagsURL)
    request.timeoutInterval = 3
    guard let (data, _) = try? await URLSession.shared.data(for: request),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let models = object["models"] as? [[String: Any]]
    else { return [] }
    return models.compactMap { $0["name"] as? String }
  }
}
