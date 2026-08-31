import Foundation

enum SledRecordingStatus {
  static func label(isRecording: Bool) -> String {
    isRecording ? "on" : "off"
  }

  static func displayText(isRecording: Bool, permissionGranted: Bool) -> String {
    if !permissionGranted {
      return "Recording: off — Screen Recording permission required"
    }
    return "Recording: \(label(isRecording: isRecording))"
  }
}
