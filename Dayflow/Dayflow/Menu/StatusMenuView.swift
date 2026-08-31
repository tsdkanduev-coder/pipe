import AppKit
import SwiftUI

@MainActor
struct StatusMenuView: View {
  let dismissMenu: () -> Void
  @ObservedObject private var appState = AppState.shared
  @ObservedObject private var pauseManager = PauseManager.shared
  @Environment(\.sledChrome) private var chrome

  private var controlMode: RecordingControlMode {
    RecordingControl.currentMode(appState: appState, pauseManager: pauseManager)
  }

  var body: some View {
    VStack(spacing: SledChrome.Space.row) {
      Text(
        SledRecordingStatus.displayText(
          isRecording: controlMode == .active,
          permissionGranted: ScreenRecordingPermissionNotice.isGranted
        )
      )
      .font(SledChrome.TypeRamp.status)
      .foregroundStyle(controlMode == .active ? chrome.accent : chrome.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, SledChrome.Space.tight)

      if !LocalLLMRuntimeStatus.current().isReady {
        Text(LocalLLMRuntimeStatus.offline.userMessage)
          .font(SledChrome.TypeRamp.caption)
          .foregroundStyle(chrome.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, SledChrome.Space.tight)
      }

      // Pause/Resume section
      if controlMode == .active {
        PauseSection(onPause: pauseRecording)
      } else {
        PausedSection(onResume: resumeRecording)
      }

      MenuDivider()

      MenuRow(title: "Open Sled", action: openDayflow)
      MenuRow(title: "Open Recordings", action: openRecordingsFolder)

      MenuDivider()

      MenuRow(title: "Quit Completely", systemImage: "power", accent: .red, action: quitDayflow)
    }
    .padding(.vertical, SledChrome.Space.inset)
    .padding(.horizontal, SledChrome.Space.inset)
    .frame(minWidth: 200, maxWidth: 210)
    .background(chrome.background)
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(chrome.hairline, lineWidth: 1)
    )
  }

  private func pauseRecording(duration: PauseDuration) {
    pauseManager.pause(for: duration, source: .menuBar)
  }

  private func resumeRecording() {
    if pauseManager.isPaused {
      pauseManager.resume(source: .userClickedMenuBar)
    } else {
      RecordingControl.start(reason: "user_menu_bar")
    }
  }

  private func openDayflow() {
    performAfterMenuDismiss {
      let showDockIcon = UserDefaults.standard.object(forKey: "showDockIcon") as? Bool ?? true
      if showDockIcon {
        NSApp.setActivationPolicy(.regular)
      }

      NSApp.unhide(nil)
      MainWindowController.shared.showMainWindow()
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  private func openRecordingsFolder() {
    performAfterMenuDismiss {
      let directory = StorageManager.shared.recordingsRoot
      NSWorkspace.shared.open(directory)
    }
  }

  private func quitDayflow() {
    performAfterMenuDismiss {
      AppDelegate.allowTermination = true
      NSApp.terminate(nil)
    }
  }

  private func performAfterMenuDismiss(_ action: @escaping () -> Void) {
    dismissMenu()

    DispatchQueue.main.async {
      DispatchQueue.main.async {
        action()
      }
    }
  }
}

// MARK: - Pause Section (Not Paused State)

private struct PauseSection: View {
  let onPause: (PauseDuration) -> Void
  @Environment(\.sledChrome) private var chrome

  var body: some View {
    VStack(alignment: .leading, spacing: SledChrome.Space.row) {
      Text("Pause Sled")
        .font(SledChrome.TypeRamp.body)
        .foregroundStyle(chrome.secondary)
        .padding(.horizontal, SledChrome.Space.tight)

      // Duration picker
      DurationPicker(onSelect: onPause)
    }
  }
}

// MARK: - Duration Picker

private struct DurationPicker: View {
  let onSelect: (PauseDuration) -> Void

  private let options: [(label: String, duration: PauseDuration)] = [
    ("15 Min", .minutes15),
    ("30 Min", .minutes30),
    ("1 Hour", .hour1),
    ("∞", .indefinite),
  ]

  @Environment(\.sledChrome) private var chrome

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Array(options.enumerated()), id: \.offset) { index, option in
        DurationOption(
          label: option.label,
          isFirst: index == 0,
          isLast: index == options.count - 1,
          onTap: { onSelect(option.duration) }
        )

        if index < options.count - 1 {
          Rectangle()
            .fill(chrome.hairline)
            .frame(width: 1, height: 16)
        }
      }
    }
    .background(chrome.surface)
    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .strokeBorder(chrome.hairline, lineWidth: 0.5)
    )
  }
}

private struct DurationOption: View {
  let label: String
  let isFirst: Bool
  let isLast: Bool
  let onTap: () -> Void

  @State private var isHovering = false
  @Environment(\.sledChrome) private var chrome

  var body: some View {
    Button(action: onTap) {
      Text(label)
        .font(SledChrome.TypeRamp.caption)
        .foregroundStyle(isHovering ? chrome.onAccent : chrome.foreground)
        .padding(.horizontal, SledChrome.Space.stack)
        .padding(.vertical, 5)
        .background(
          Group {
            if isHovering {
              RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(chrome.accent)
            }
          }
        )
    }
    .buttonStyle(.plain)
    .pointingHandCursor()
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.15)) {
        isHovering = hovering
      }
    }
  }
}

// MARK: - Paused Section (Active Pause State)

private struct PausedSection: View {
  let onResume: () -> Void
  @ObservedObject private var pauseManager = PauseManager.shared

  var body: some View {
    VStack(spacing: SledChrome.Space.row) {
      // Countdown badge (only shown for timed pause)
      if let timeString = pauseManager.remainingTimeFormatted {
        CountdownBadge(remainingTime: timeString)
      }

      // Resume button
      MenuRow(
        title: "Resume Sled",
        systemImage: "play.circle",
        accent: SledChrome.accent,
        action: onResume
      )
    }
  }
}

// MARK: - Countdown Badge

private struct CountdownBadge: View {
  let remainingTime: String
  @Environment(\.sledChrome) private var chrome

  var body: some View {
    HStack(spacing: 0) {
      Text("Sled paused for ")
        .font(SledChrome.TypeRamp.caption)
      Text(remainingTime)
        .font(SledChrome.TypeRamp.status.monospacedDigit())
    }
    .foregroundStyle(chrome.onAccent)
    .padding(.horizontal, 12)
    .padding(.vertical, SledChrome.Space.row)
    .frame(maxWidth: .infinity)
    .background(chrome.accent)
    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
  }
}

// MARK: - Menu Row

private struct MenuRow: View {
  let title: String
  var systemImage: String? = nil
  var assetImage: String? = nil
  var accent: Color = .primary
  var keepsMenuOpen: Bool = false
  var action: () -> Void

  @State private var hovering = false
  @Environment(\.sledChrome) private var chrome

  var body: some View {
    Button(action: handleTap) {
      HStack(spacing: 7) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(accent)
            .frame(width: 17)
        } else if let assetImage {
          Image(assetImage)
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)
            .frame(width: 17)
        } else {
          // Empty spacer to align text with rows that have icons
          Color.clear.frame(width: 17)
        }

        Text(title)
          .font(SledChrome.TypeRamp.body)
          .foregroundStyle(chrome.foreground)
          .lineLimit(1)

        Spacer(minLength: 0)
      }
      .padding(.vertical, SledChrome.Space.tight)
      .padding(.horizontal, SledChrome.Space.tight)
      .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .background(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(hovering ? chrome.surface : Color.clear)
      )
    }
    .buttonStyle(.plain)
    .pointingHandCursor()
    .onHover { hovering = $0 }
  }

  private func handleTap() {
    action()
  }
}

// MARK: - Menu Divider

private struct MenuDivider: View {
  @Environment(\.sledChrome) private var chrome

  var body: some View {
    Rectangle()
      .fill(chrome.hairline)
      .frame(height: 1)
      .padding(.horizontal, SledChrome.Space.tight)
      .padding(.vertical, 2)
  }
}
