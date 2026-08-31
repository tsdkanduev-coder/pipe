import Foundation

enum LocalLLMRuntimeStatus: Equatable {
  case ready(engine: LocalEngine, model: String)
  case offline

  var userMessage: String {
    switch self {
    case .ready:
      return "Local"
    case .offline:
      return "Install/start Ollama (or LM Studio)"
    }
  }

  var isReady: Bool {
    if case .ready = self { return true }
    return false
  }

  static func current(
    engine: LocalEngine = currentEngine(),
    modelId: String = currentModelId()
  ) -> LocalLLMRuntimeStatus {
    let endpoint = SledLocalLLMPolicy.resolvedEndpoint(
      engine: engine,
      storedBaseURL: UserDefaults.standard.string(forKey: "llmLocalBaseURL")
    )
    guard probe(endpoint: endpoint) else { return .offline }
    return .ready(engine: engine, model: modelId)
  }

  static func currentEngine() -> LocalEngine {
    let raw = UserDefaults.standard.string(forKey: "llmLocalEngine") ?? LocalEngine.ollama.rawValue
    let engine = LocalEngine(rawValue: raw) ?? .ollama
    return engine == .custom ? .ollama : engine
  }

  static func currentModelId() -> String {
    let stored = UserDefaults.standard.string(forKey: "llmLocalModelId")?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !stored.isEmpty { return stored }
    return SledLocalLLMPolicy.defaultModelId(for: currentEngine())
  }

  /// HEAD/GET tags without pulling a model.
  static func probe(endpoint: String) -> Bool {
    let base = SledLocalLLMPolicy.normalizedLoopback(endpoint)
    let candidates = [
      URL(string: base + "/api/tags"),
      URL(string: base + "/v1/models"),
    ].compactMap { $0 }

    for url in candidates {
      var request = URLRequest(url: url)
      request.httpMethod = "GET"
      request.timeoutInterval = 1.5
      request.cachePolicy = .reloadIgnoringLocalCacheData
      let semaphore = DispatchSemaphore(value: 0)
      var ok = false
      URLSession.shared.dataTask(with: request) { _, response, _ in
        if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
          ok = true
        }
        semaphore.signal()
      }.resume()
      _ = semaphore.wait(timeout: .now() + 1.6)
      if ok { return true }
    }
    return false
  }
}
