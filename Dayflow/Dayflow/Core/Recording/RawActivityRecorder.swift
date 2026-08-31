import Foundation

/// Writes raw timeline rows into the existing Dayflow SQLite store so capture
/// and the loopback API work when the local LLM is down. Stop does not delete rows.
enum RawActivityRecorder {
  static let rawCategory = "Activity"
  static let rawMetadataMarker = "\"isRawCapture\":true"

  static func recordCapture(at date: Date, app: String?, windowTitle: String?) {
    StorageManager.shared.upsertRawActivity(
      at: date,
      app: app,
      windowTitle: windowTitle
    )
  }

  /// Close the open raw session without deleting SQLite rows.
  static func closeOpenSession(at date: Date = Date()) {
    StorageManager.shared.closeOpenRawActivity(at: date)
  }
}
