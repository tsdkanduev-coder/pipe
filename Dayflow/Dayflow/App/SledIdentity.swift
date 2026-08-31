import Foundation

enum SledIdentity {
  static let productName = "Sled"
  static let bundleIdentifier = "ru.kanduev.sled"
  static let loopbackHost = "127.0.0.1"
  static let loopbackPort: UInt16 = 18_741
  static let applicationSupportDirectoryName = "Sled"
  static let databaseFileName = "sled.sqlite"
  static let defaultVisionModel = "llama3.2-vision"
  static let ollamaPort = 11_434
  static let lmStudioPort = 1_234

  static var loopbackActionsURL: String {
    "http://\(loopbackHost):\(loopbackPort)/v1/actions"
  }

  static var ollamaBaseURL: String {
    "http://\(loopbackHost):\(ollamaPort)"
  }

  static var lmStudioBaseURL: String {
    "http://\(loopbackHost):\(lmStudioPort)"
  }
}
