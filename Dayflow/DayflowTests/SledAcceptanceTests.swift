import XCTest

@testable import Dayflow

final class SledAcceptanceTests: XCTestCase {
  func testLoopbackLimitDefaultsTo50AndCapsAt200() {
    XCTAssertEqual(LoopbackAPIQuery.clampedLimit(nil), 50)
    XCTAssertEqual(LoopbackAPIQuery.clampedLimit(0), 50)
    XCTAssertEqual(LoopbackAPIQuery.clampedLimit(-1), 50)
    XCTAssertEqual(LoopbackAPIQuery.clampedLimit(1), 1)
    XCTAssertEqual(LoopbackAPIQuery.clampedLimit(50), 50)
    XCTAssertEqual(LoopbackAPIQuery.clampedLimit(200), 200)
    XCTAssertEqual(LoopbackAPIQuery.clampedLimit(201), 200)
    XCTAssertEqual(LoopbackAPIQuery.clampedLimit(500), 200)
  }

  func testLoopbackPathParsing() throws {
    XCTAssertNil(LoopbackAPIQuery.parse(pathAndQuery: "/v1/other"))
    let empty = try XCTUnwrap(LoopbackAPIQuery.parse(pathAndQuery: "/v1/actions"))
    XCTAssertNil(empty.since)
    XCTAssertEqual(empty.limit, 50)

    let parsed = try XCTUnwrap(
      LoopbackAPIQuery.parse(pathAndQuery: "/v1/actions?since=2026-08-31T00:00:00Z&limit=80")
    )
    XCTAssertEqual(parsed.limit, 80)
    XCTAssertEqual(
      LoopbackAPIQuery.iso8601String(from: try XCTUnwrap(parsed.since)),
      "2026-08-31T00:00:00Z"
    )
  }

  func testLoopbackActionOmitsScreenshotBytes() throws {
    let action = LoopbackAction(
      id: 1,
      started_at: "2026-08-31T10:00:00Z",
      ended_at: "2026-08-31T10:15:00Z",
      app: "Xcode",
      window_title: "Sled",
      summary: nil
    )
    let data = try JSONEncoder().encode([action])
    let json = try XCTUnwrap(String(data: data, encoding: .utf8))
    XCTAssertFalse(json.contains("jpeg"))
    XCTAssertFalse(json.contains("file_path"))
    XCTAssertFalse(json.contains("screenshot"))
    XCTAssertTrue(json.contains("started_at"))
    XCTAssertTrue(json.contains("window_title"))
  }

  func testLocalPolicyForcesLocalAndRejectsCloud() {
    let enforced = SledLocalLLMPolicy.enforce(LLMProviderRouting(primary: .gemini, secondary: .claude))
    XCTAssertEqual(enforced.primary, .local)
    XCTAssertNil(enforced.secondary)

    XCTAssertTrue(SledLocalLLMPolicy.isAllowedLoopbackURL("http://127.0.0.1:11434"))
    XCTAssertTrue(SledLocalLLMPolicy.isAllowedLoopbackURL("http://127.0.0.1:1234"))
    XCTAssertTrue(SledLocalLLMPolicy.isAllowedLoopbackURL("http://localhost:11434"))
    XCTAssertFalse(SledLocalLLMPolicy.isAllowedLoopbackURL("https://generativelanguage.googleapis.com"))
    XCTAssertFalse(SledLocalLLMPolicy.isAllowedLoopbackURL("https://api.openai.com"))
    XCTAssertFalse(SledLocalLLMPolicy.isAllowedLoopbackURL("https://api.anthropic.com"))
    XCTAssertFalse(SledLocalLLMPolicy.isAllowedLoopbackURL("https://openrouter.ai/api/v1"))

    XCTAssertEqual(SledLocalLLMPolicy.defaultModelId(for: .ollama), "llama3.2-vision")
    XCTAssertThrowsError(try SledLocalLLMPolicy.rejectCloudProvider(.gemini))
    XCTAssertNoThrow(try SledLocalLLMPolicy.rejectCloudProvider(.local))
  }

  func testSqlitePathIsSledNotICloud() {
    XCTAssertEqual(SledStoragePaths.applicationSupportDirectoryName, "Sled")
    XCTAssertEqual(SledStoragePaths.databaseFileName, "sled.sqlite")
    let url = SledStoragePaths.databaseURL()
    XCTAssertTrue(url.path.contains("Application Support/Sled/sled.sqlite"))
    XCTAssertFalse(url.path.contains("Mobile Documents"))
    XCTAssertFalse(url.path.contains("iCloud"))
    XCTAssertFalse(url.lastPathComponent.contains("chunks.sqlite"))
  }

  func testRecordingStatusLabelsAreOnOff() {
    XCTAssertEqual(SledRecordingStatus.label(isRecording: true), "on")
    XCTAssertEqual(SledRecordingStatus.label(isRecording: false), "off")
  }

  func testIdentityHasNoDayflowOrScreenpipeMarks() {
    XCTAssertEqual(SledIdentity.productName, "Sled")
    XCTAssertEqual(SledIdentity.bundleIdentifier, "ru.kanduev.sled")
    XCTAssertFalse(SledIdentity.productName.lowercased().contains("dayflow"))
    XCTAssertFalse(SledIdentity.productName.lowercased().contains("screenpipe"))
    XCTAssertFalse(SledIdentity.loopbackActionsURL.contains("dayflow"))
  }

  func testFirstRunCompletionLocksLocalAndSkipsProCLI() throws {
    let suiteName = "sled.first-run.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    SledFirstRun.complete(defaults: defaults)

    XCTAssertTrue(defaults.bool(forKey: "didOnboard"))
    XCTAssertTrue(
      OnboardingStep.hasPassedScreenRecordingStep(
        rawValue: defaults.integer(forKey: "onboardingStep")
      )
    )
    let routing = try LLMProviderRoutingStore.load(from: defaults)
    XCTAssertEqual(routing.primary, .local)
    XCTAssertNil(routing.secondary)
  }

  func testTimelineFailureCopyDoesNotPitchProOrBackup() {
    let kinds: [TimelineFailureKind] = [
      .dayflowProRequired, .cliNotInstalled, .cliOutdated, .notConfigured,
      .apiKeyProblem, .usageLimitHit, .outOfCredits,
    ]
    for kind in kinds {
      let toast = TimelineFailureClassification(kind: kind, providerName: nil)
        .toastContent(fallbackProviderLabel: "local")
      let body = (toast?.body ?? "").lowercased()
      XCTAssertFalse(body.contains("dayflow pro"), "\(kind.rawValue) still mentions Dayflow Pro")
      XCTAssertFalse(body.contains("subscribe"), "\(kind.rawValue) still pitches subscribe")
      XCTAssertFalse(body.contains("backup provider"), "\(kind.rawValue) still pitches backup provider")
      XCTAssertFalse(body.contains("gemini"), "\(kind.rawValue) still pitches Gemini")
    }
  }

  func testShadcnThemeUsesNeutralWithPatchedSidebarPrimary() {
    XCTAssertEqual(SledShadcnTheme.darkSidebarPrimaryOKLCH, "oklch(0.922 0 0)")
    XCTAssertEqual(SledShadcnTheme.radiusPoints, 8)
    XCTAssertEqual(SledTimelineCopy.empty, "No actions yet. Start recording from the menu bar.")
    XCTAssertEqual(SledTimelineCopy.loading, "Building timeline…")
    XCTAssertEqual(SledTimelineCopy.disabled, "Grant Screen Recording first")
    XCTAssertEqual(SledTimelineCopy.noLocalModel, "No local model. Timeline still records.")
  }
}
