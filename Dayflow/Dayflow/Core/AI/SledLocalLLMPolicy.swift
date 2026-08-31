import Foundation

enum SledLocalLLMPolicy {
  static let allowedProvider: LLMProviderID = .local
  static let defaultOllamaURL = SledIdentity.ollamaBaseURL
  static let defaultLMStudioURL = SledIdentity.lmStudioBaseURL
  static let defaultVisionModel = SledIdentity.defaultVisionModel

  static let lockedRouting = LLMProviderRouting(primary: .local, secondary: nil)

  static func enforce(_ routing: LLMProviderRouting) -> LLMProviderRouting {
    lockedRouting
  }

  static func rejectCloudProvider(_ providerID: LLMProviderID) throws {
    guard providerID == .local else {
      throw cloudRejectedError(providerID)
    }
  }

  static func cloudRejectedError(_ providerID: LLMProviderID = .gemini) -> NSError {
    NSError(
      domain: "SledLocalLLMPolicy",
      code: 1,
      userInfo: [
        NSLocalizedDescriptionKey:
          "Sled uses local models only. Cloud providers are disabled. Install or start Ollama (127.0.0.1:11434) or LM Studio (127.0.0.1:1234)."
      ]
    )
  }

  static func isAllowedLoopbackURL(_ raw: String) -> Bool {
    guard let components = URLComponents(string: raw) else { return false }
    let host = (components.host ?? "").lowercased()
    guard host == "127.0.0.1" || host == "localhost" else { return false }
    guard let port = components.port else {
      return raw.hasPrefix(defaultOllamaURL) || raw.hasPrefix(defaultLMStudioURL)
        || raw.hasPrefix("http://localhost:11434") || raw.hasPrefix("http://localhost:1234")
    }
    return port == SledIdentity.ollamaPort || port == SledIdentity.lmStudioPort
  }

  static func resolvedEndpoint(
    engine: LocalEngine,
    storedBaseURL: String?
  ) -> String {
    switch engine {
    case .lmstudio:
      return defaultLMStudioURL
    case .ollama, .custom:
      let trimmed = storedBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      if !trimmed.isEmpty, isAllowedLoopbackURL(trimmed) {
        return normalizedLoopback(trimmed)
      }
      return defaultOllamaURL
    }
  }

  static func normalizedLoopback(_ raw: String) -> String {
    raw.replacingOccurrences(of: "http://localhost", with: "http://127.0.0.1")
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }

  static func defaultModelId(for engine: LocalEngine) -> String {
    switch engine {
    case .lmstudio:
      return defaultVisionModel
    case .ollama, .custom:
      return defaultVisionModel
    }
  }
}
