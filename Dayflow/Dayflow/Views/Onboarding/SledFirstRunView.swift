import AppKit
import ScreenCaptureKit
import SwiftUI

/// Completes first-run without Pro, CLI, referral, or cloud sign-in.
enum SledFirstRun {
  static func complete(defaults: UserDefaults = .standard) {
    try? LLMProviderRoutingStore.save(SledLocalLLMPolicy.lockedRouting, to: defaults)
    defaults.set(OnboardingStep.completion.rawValue, forKey: "onboardingStep")
    defaults.set(true, forKey: "didOnboard")
  }
}

/// Single first-run screen: Screen Recording permission, start, and local LLM.
/// The Dayflow intro video, referral, Pro sign-in, and CLI gate are not on this path.
struct SledFirstRunView: View {
  @AppStorage("didOnboard") private var didOnboard: Bool = false
  @AppStorage("onboardingStep") private var persistedStepRaw: Int = 0
  @ObservedObject private var appState = AppState.shared
  @Environment(\.sledChrome) private var chrome

  @State private var hasPermission = false
  @State private var isRequestingPermission = false
  @State private var localRuntime = LocalLLMRuntimeStatus.offline

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Sled")
        .font(.system(size: 28, weight: .semibold))
        .foregroundStyle(chrome.foreground)

      Text("Screen recording stays on this Mac. Activity is stored in local SQLite. Timeline analysis uses Ollama or LM Studio only — no cloud sign-in.")
        .font(SledChrome.TypeRamp.body)
        .foregroundStyle(chrome.secondary)
        .fixedSize(horizontal: false, vertical: true)

      permissionRow
      startRow
      localLLMRow

      Spacer(minLength: 8)

      Button(action: finishFirstRun) {
        Text("Continue")
          .font(SledChrome.TypeRamp.body)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
      }
      .buttonStyle(.plain)
      .foregroundStyle(chrome.onAccent)
      .background(chrome.accent)
      .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
    .padding(28)
    .frame(minWidth: 480, minHeight: 420)
    .background(chrome.background)
    .onAppear {
      refreshPermission()
      localRuntime = LocalLLMRuntimeStatus.current()
    }
  }

  private var permissionRow: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Screen Recording")
        .font(SledChrome.TypeRamp.title)
        .foregroundStyle(chrome.foreground)
      Text(
        hasPermission
          ? "Permission granted. Sled can capture this display."
          : "macOS must allow Screen Recording before capture can start."
      )
      .font(SledChrome.TypeRamp.body)
      .foregroundStyle(chrome.secondary)
      if !hasPermission {
        Button(action: requestPermission) {
          Text(isRequestingPermission ? "Waiting for System Settings…" : "Grant Screen Recording")
            .font(SledChrome.TypeRamp.body)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(chrome.onAccent)
        .background(chrome.accent)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .disabled(isRequestingPermission)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(chrome.surface)
    .overlay(Rectangle().stroke(chrome.hairline, lineWidth: 1))
  }

  private var startRow: some View {
    let recording = appState.isRecording && hasPermission
    return VStack(alignment: .leading, spacing: 8) {
      Text("Start")
        .font(SledChrome.TypeRamp.title)
        .foregroundStyle(chrome.foreground)
      Text(
        SledRecordingStatus.displayText(
          isRecording: recording,
          permissionGranted: hasPermission
        )
      )
      .font(SledChrome.TypeRamp.body)
      .foregroundStyle(chrome.secondary)
      Button(action: startRecording) {
        Text(recording ? "Recording" : "Start recording")
          .font(SledChrome.TypeRamp.body)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
      }
      .buttonStyle(.plain)
      .foregroundStyle(recording || !hasPermission ? chrome.secondary : chrome.onAccent)
      .background(recording || !hasPermission ? chrome.background : chrome.accent)
      .overlay(Rectangle().stroke(chrome.hairline, lineWidth: recording || !hasPermission ? 1 : 0))
      .disabled(recording || !hasPermission)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(chrome.surface)
    .overlay(Rectangle().stroke(chrome.hairline, lineWidth: 1))
  }

  private var localLLMRow: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Local LLM")
        .font(SledChrome.TypeRamp.title)
        .foregroundStyle(chrome.foreground)
      Text(localLLMCopy)
        .font(SledChrome.TypeRamp.body)
        .foregroundStyle(chrome.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(chrome.surface)
    .overlay(Rectangle().stroke(chrome.hairline, lineWidth: 1))
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
    isRequestingPermission = true
    if CGPreflightScreenCaptureAccess() {
      hasPermission = true
      isRequestingPermission = false
      return
    }
    CGRequestScreenCaptureAccess()
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
      NSWorkspace.shared.open(url)
    }
    // TCC takes effect after relaunch — same pattern as the old permission step.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      NSApplication.shared.terminate(nil)
    }
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
