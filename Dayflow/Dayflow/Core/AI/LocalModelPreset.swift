import Foundation

struct LocalModelInstructionSet {
  let title: String
  let subtitle: String
  let bullets: [String]
  let commandTitle: String?
  let commandSubtitle: String?
  let command: String?
  let buttonTitle: String?
  let buttonURL: URL?
  let note: String?
}

enum LocalModelPreset: String, CaseIterable, Codable {
  case qwen35_4b = "qwen35_4b"
  case qwen3VL4B = "qwen3_vl_4b"
  case qwen25VL3B = "qwen25_vl_3b"

  static let recommended: LocalModelPreset = .qwen35_4b

  var displayName: String {
    switch self {
    case .qwen35_4b: return "Qwen 3.5 4B"
    case .qwen3VL4B: return "Qwen3-VL 4B"
    case .qwen25VL3B: return "Qwen2.5-VL 3B"
    }
  }

  var highlightBullets: [String] {
    switch self {
    case .qwen35_4b:
      return [
        "Native vision + text in one local model",
        "Fits a 16GB Apple Silicon Mac (~3.4GB)",
        "Default for PIP — no cloud key required",
      ]
    case .qwen3VL4B:
      return [
        "Previous Dayflow local default",
        "Vision-only specialist, slightly heavier",
      ]
    case .qwen25VL3B:
      return [
        "Legacy fallback",
        "Lower VRAM, weaker screen reading",
      ]
    }
  }

  func modelId(for engine: LocalEngine) -> String {
    switch (self, engine) {
    case (.qwen35_4b, .lmstudio):
      return "Qwen3.5-4B"
    case (.qwen3VL4B, .lmstudio):
      return "Qwen3-VL-4B-Instruct"
    case (.qwen25VL3B, .lmstudio):
      return "qwen2.5-vl-3b-instruct"
    case (.qwen35_4b, _):
      return "qwen3.5:4b"
    case (.qwen3VL4B, _):
      return "qwen3-vl:4b"
    case (.qwen25VL3B, _):
      return "qwen2.5vl:3b"
    }
  }

  func instructions(for engine: LocalEngine) -> LocalModelInstructionSet {
    switch engine {
    case .ollama, .custom:
      return LocalModelInstructionSet(
        title: "Install via Ollama",
        subtitle: "PIP uses a local vision model. Keep Ollama running in the background.",
        bullets: [
          "Open Terminal",
          "Run the pull command below (≈3.4GB download)",
          "Keep Ollama running while PIP records",
        ],
        commandTitle: "Run this command:",
        commandSubtitle: "Downloads \(displayName) for Ollama",
        command: ollamaPullCommand,
        buttonTitle: nil,
        buttonURL: nil,
        note: "On a 16GB Mac stay on the 4B model. 9B and larger will swap."
      )
    case .lmstudio:
      return LocalModelInstructionSet(
        title: "Install inside LM Studio",
        subtitle: "Download the Instruct / 4B build, then start Local Server.",
        bullets: [
          "Open LM Studio and click the Models tab",
          "Search for \"\(modelId(for: .lmstudio))\"",
          "Download it, then start Local Server",
        ],
        commandTitle: nil,
        commandSubtitle: nil,
        command: nil,
        buttonTitle: "Open LM Studio",
        buttonURL: URL(string: "https://lmstudio.ai"),
        note:
          "Enable \"Launch local server\" so PIP can talk to LM Studio at \(LocalEngine.lmstudio.defaultBaseURL)."
      )
    }
  }

  var ollamaPullCommand: String {
    switch self {
    case .qwen35_4b: return "ollama pull qwen3.5:4b"
    case .qwen3VL4B: return "ollama pull qwen3-vl:4b"
    case .qwen25VL3B: return "ollama pull qwen2.5vl:3b"
    }
  }
}

enum LocalModelPreferences {
  private static let presetKey = "llmLocalModelPreset"
  private static let upgradeDismissedKey = "llmLocalModelUpgradeDismissed"
  private static let defaults = UserDefaults.standard

  static func currentPreset() -> LocalModelPreset? {
    guard let raw = defaults.string(forKey: presetKey) else { return nil }
    return LocalModelPreset(rawValue: raw)
  }

  static func savePreset(_ preset: LocalModelPreset) {
    defaults.set(preset.rawValue, forKey: presetKey)
  }

  static func clearPreset() {
    defaults.removeObject(forKey: presetKey)
  }

  static func syncPreset(for engine: LocalEngine, modelId: String) {
    let normalized = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else {
      clearPreset()
      return
    }
    if let preset = LocalModelPreset.allCases.first(where: { $0.modelId(for: engine) == normalized }
    ) {
      savePreset(preset)
    } else {
      clearPreset()
    }
  }

  static func defaultModelId(for engine: LocalEngine) -> String {
    LocalModelPreset.recommended.modelId(for: engine)
  }

  static func shouldShowUpgradeBanner(engine: LocalEngine, modelId: String) -> Bool {
    if defaults.bool(forKey: upgradeDismissedKey) { return false }
    if currentPreset() == .qwen35_4b { return false }
    let normalized = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized == LocalModelPreset.qwen3VL4B.modelId(for: engine)
      || normalized == LocalModelPreset.qwen25VL3B.modelId(for: engine)
  }

  static func markUpgradeDismissed(_ dismissed: Bool) {
    defaults.set(dismissed, forKey: upgradeDismissedKey)
  }
}
