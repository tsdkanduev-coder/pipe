import AppKit
import ScreenCaptureKit
import ShadcnUI
import SwiftUI

/// Completes first-run without Pro, CLI, referral, or cloud sign-in.
enum SledFirstRun {
  static let quitForPermissionCopy = "Sled will quit so the permission can apply."

  static func canContinue(hasPermission: Bool) -> Bool {
    hasPermission
  }

  static func complete(defaults: UserDefaults = .standard) {
    try? LLMProviderRoutingStore.save(SledLocalLLMPolicy.lockedRouting, to: defaults)
    defaults.set(OnboardingStep.completion.rawValue, forKey: "onboardingStep")
    defaults.set(true, forKey: "didOnboard")
  }
}

/// One screen: TCC + Start + Local. Pro and CLI stay off this path.
struct SledFirstRunView: View {
  @AppStorage("didOnboard") private var didOnboard: Bool = false
  @AppStorage("onboardingStep") private var persistedStepRaw: Int = 0
  @ObservedObject private var appState = AppState.shared
  @Environment(\.shadcnPalette) private var palette
  @Environment(\.shadcnTheme) private var theme

  @State private var hasPermission = false
  @State private var localRuntime = LocalLLMRuntimeStatus.offline
  @State private var isQuittingForPermission = false

  var body: some View {
    VStack(alignment: .leading, spacing: Space.x5) {
      Text("Sled")
        .font(theme.typography.sans(theme.typography.xl2, weight: .semibold))
        .foregroundStyle(palette.foreground)

      tccBlock
      startBlock
      localBlock

      Spacer(minLength: Space.x2)

      ShadcnButton("Continue", variant: .primary, fillsWidth: true, action: finishFirstRun)
        .disabled(!SledFirstRun.canContinue(hasPermission: hasPermission) || isQuittingForPermission)
    }
    .padding(Space.x8)
    .frame(minWidth: 480, minHeight: 420)
    .onAppear {
      refreshPermission()
      localRuntime = LocalLLMRuntimeStatus.current()
    }
  }

  @ViewBuilder
  private var tccBlock: some View {
    if hasPermission {
      ContentUnavailableView {
        Label("Screen Recording is on", systemImage: "checkmark.circle")
      } description: {
        Text("Relaunch Sled if capture does not start after granting access.")
      }
      .frame(maxHeight: 160)
    } else {
      ContentUnavailableView {
        Label("Screen Recording is off", systemImage: "record.circle")
      } description: {
        Text(
          isQuittingForPermission
            ? SledFirstRun.quitForPermissionCopy
            : "Sled needs Screen Recording before capture can start."
        )
      } actions: {
        if !isQuittingForPermission {
          ShadcnButton(
            "Open System Settings",
            systemImage: "gearshape",
            variant: .primary,
            action: requestPermission
          )
          ShadcnButton("Quit", variant: .outline, action: quitApp)
        }
      }
    }
  }

  private var startBlock: some View {
    let recording = appState.isRecording && hasPermission
    return ShadcnCard {
      ShadcnCardHeader {
        ShadcnCardTitle("Start")
        ShadcnCardDescription(
          SledRecordingStatus.displayText(
            isRecording: recording,
            permissionGranted: hasPermission
          )
        )
      }
      ShadcnCardFooter {
        ShadcnButton(
          recording ? "Recording" : "Start recording",
          systemImage: "record.circle",
          variant: recording ? .destructive : .primary,
          action: startRecording
        )
        .disabled(recording || !hasPermission)
      }
    }
  }

  private var localBlock: some View {
    ShadcnCard {
      ShadcnCardHeader {
        ShadcnCardTitle("Local LLM")
        ShadcnCardDescription(localLLMCopy)
      }
    }
  }

  private var localLLMCopy: String {
    switch localRuntime {
    case .ready(let engine, let model):
      let name = engine == .lmstudio ? "LM Studio" : "Ollama"
      return "\(name) is reachable. Vision model: \(model)."
    case .offline:
      return
        "\(LocalLLMRuntimeStatus.offline.userMessage). You can continue without a model. Capture still writes local rows; summaries stay empty until a runtime is up."
    }
  }

  private func refreshPermission() {
    hasPermission = CGPreflightScreenCaptureAccess()
  }

  private func requestPermission() {
    if CGPreflightScreenCaptureAccess() {
      hasPermission = true
      return
    }
    isQuittingForPermission = true
    CGRequestScreenCaptureAccess()
    if let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    ) {
      NSWorkspace.shared.open(url)
    }
    // Copy is on screen first. Real quit (not soft-hide) so TCC can apply.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
      AppDelegate.allowTermination = true
      NSApplication.shared.terminate(nil)
    }
  }

  private func quitApp() {
    AppDelegate.allowTermination = true
    NSApplication.shared.terminate(nil)
  }

  private func startRecording() {
    refreshPermission()
    guard hasPermission else { return }
    RecordingControl.start(reason: "first_run")
  }

  private func finishFirstRun() {
    SledFirstRun.complete()
    persistedStepRaw = OnboardingStep.completion.rawValue
    didOnboard = true
  }
}
