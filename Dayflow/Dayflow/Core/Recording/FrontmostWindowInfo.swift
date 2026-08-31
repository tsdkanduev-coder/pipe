import AppKit
import CoreGraphics

enum FrontmostWindowInfo {
  struct Snapshot: Equatable {
    let app: String?
    let windowTitle: String?
  }

  static func capture() -> Snapshot {
    let application = NSWorkspace.shared.frontmostApplication
    let appName = application?.localizedName
    let pid = application?.processIdentifier
    return Snapshot(app: appName, windowTitle: windowTitle(for: pid))
  }

  private static func windowTitle(for pid: pid_t?) -> String? {
    guard let pid else { return nil }
    guard
      let info = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
      ) as? [[String: Any]]
    else { return nil }

    for window in info {
      let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t
      guard ownerPID == pid else { continue }
      let layer = window[kCGWindowLayer as String] as? Int ?? 0
      guard layer == 0 else { continue }
      if let title = window[kCGWindowName as String] as? String,
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      {
        return title
      }
    }
    return nil
  }
}
