import SwiftUI
import ShadcnUI

/// Locked empty / loading / error / disabled / no-model copy. No new screens.
enum SledTimelineCopy {
  static let empty = "No actions yet. Start recording from the menu bar."
  static let loading = "Building timeline…"
  static let disabled = "Grant Screen Recording first"
  static let noLocalModel = "No local model. Timeline still records."
}

struct SledEmptyTimelineView: View {
  var body: some View {
    ContentUnavailableView {
      Label("No actions yet", systemImage: "record.circle")
    } description: {
      Text(SledTimelineCopy.empty)
    }
  }
}

struct SledTimelineLoadingView: View {
  var body: some View {
    VStack(spacing: Space.x3) {
      ProgressView()
      Text(SledTimelineCopy.loading)
        .font(.system(size: 13))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct SledRecordingDisabledView: View {
  var body: some View {
    ContentUnavailableView {
      Label(SledTimelineCopy.disabled, systemImage: "record.circle")
    } description: {
      Text("Open System Settings → Privacy & Security → Screen Recording and enable Sled.")
    }
  }
}

struct SledNoLocalModelBanner: View {
  @Environment(\.shadcnPalette) private var palette

  var body: some View {
    ShadcnAlert(variant: .primary, systemImage: "cpu") {
      ShadcnAlertTitle("Summaries paused")
      ShadcnAlertDescription(SledTimelineCopy.noLocalModel)
    }
  }
}
