import AppKit
import Combine
import SwiftUI

/// Menu bar extra. Native NSMenu so ShadKit overlays cannot fight the status item.
@MainActor
final class StatusBarController: NSObject {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private var cancellable: AnyCancellable?
  private var pauseCancellable: AnyCancellable?

  override init() {
    super.init()

    if let button = statusItem.button {
      button.imageScaling = .scaleProportionallyDown
      button.imagePosition = .imageOnly
    }

    rebuildMenu()
    updateIcon(isRecording: AppState.shared.isRecording)

    cancellable = AppState.shared.$isRecording
      .removeDuplicates()
      .sink { [weak self] isRecording in
        self?.updateIcon(isRecording: isRecording)
        self?.rebuildMenu()
      }
    pauseCancellable = PauseManager.shared.objectWillChange
      .sink { [weak self] _ in
        self?.rebuildMenu()
      }
  }

  private func updateIcon(isRecording: Bool) {
    let symbol = isRecording ? "record.circle.fill" : "circle"
    let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Sled")
    image?.isTemplate = !isRecording
    if isRecording {
      let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
      statusItem.button?.image = image?.withSymbolConfiguration(config)
    } else {
      statusItem.button?.image = image
    }
  }

  private func rebuildMenu() {
    let menu = NSMenu()
    menu.autoenablesItems = false

    let mode = RecordingControl.currentMode()
    let permission = ScreenRecordingPermissionNotice.isGranted
    let recording = mode == .active

    let status = NSMenuItem(
      title: SledRecordingStatus.displayText(isRecording: recording, permissionGranted: permission),
      action: nil,
      keyEquivalent: ""
    )
    status.isEnabled = false
    menu.addItem(status)

    if !LocalLLMRuntimeStatus.current().isReady {
      let offline = NSMenuItem(
        title: SledTimelineCopy.noLocalModel,
        action: nil,
        keyEquivalent: ""
      )
      offline.isEnabled = false
      menu.addItem(offline)
    }

    menu.addItem(.separator())

    if recording {
      let pause15 = NSMenuItem(
        title: "Pause Sled for 15 minutes",
        action: #selector(pause15),
        keyEquivalent: ""
      )
      pause15.target = self
      menu.addItem(pause15)
      let pause30 = NSMenuItem(
        title: "Pause Sled for 30 minutes",
        action: #selector(pause30),
        keyEquivalent: ""
      )
      pause30.target = self
      menu.addItem(pause30)
      let pauseHour = NSMenuItem(
        title: "Pause Sled for 1 hour",
        action: #selector(pauseHour),
        keyEquivalent: ""
      )
      pauseHour.target = self
      menu.addItem(pauseHour)
      let pauseIndefinite = NSMenuItem(
        title: "Pause Sled",
        action: #selector(pauseIndefinite),
        keyEquivalent: ""
      )
      pauseIndefinite.target = self
      menu.addItem(pauseIndefinite)
    } else {
      let resume = NSMenuItem(
        title: "Start recording",
        action: #selector(resumeRecording),
        keyEquivalent: ""
      )
      resume.target = self
      resume.isEnabled = permission
      menu.addItem(resume)
    }

    menu.addItem(.separator())

    let openSled = NSMenuItem(title: "Open Sled", action: #selector(openSled), keyEquivalent: "")
    openSled.target = self
    menu.addItem(openSled)

    let openRecordings = NSMenuItem(
      title: "Open Recordings",
      action: #selector(openRecordings),
      keyEquivalent: ""
    )
    openRecordings.target = self
    menu.addItem(openRecordings)

    menu.addItem(.separator())

    let quit = NSMenuItem(title: "Quit Sled", action: #selector(quitSled), keyEquivalent: "q")
    quit.target = self
    menu.addItem(quit)

    statusItem.menu = menu
  }

  @objc private func pause15() {
    PauseManager.shared.pause(for: .minutes15, source: .menuBar)
  }

  @objc private func pause30() {
    PauseManager.shared.pause(for: .minutes30, source: .menuBar)
  }

  @objc private func pauseHour() {
    PauseManager.shared.pause(for: .hour1, source: .menuBar)
  }

  @objc private func pauseIndefinite() {
    PauseManager.shared.pause(for: .indefinite, source: .menuBar)
  }

  @objc private func resumeRecording() {
    if PauseManager.shared.isPaused {
      PauseManager.shared.resume(source: .userClickedMenuBar)
    } else {
      RecordingControl.start(reason: "user_menu_bar")
    }
  }

  @objc private func openSled() {
    let showDockIcon = UserDefaults.standard.object(forKey: "showDockIcon") as? Bool ?? true
    if showDockIcon {
      NSApp.setActivationPolicy(.regular)
    }
    NSApp.unhide(nil)
    MainWindowController.shared.showMainWindow()
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc private func openRecordings() {
    NSWorkspace.shared.open(StorageManager.shared.recordingsRoot)
  }

  @objc private func quitSled() {
    AppDelegate.allowTermination = true
    NSApp.terminate(nil)
  }
}
