//
//  TimelineFailureClassifier.swift
//  Dayflow
//
//  Classifies timeline-generation failures into user-facing categories and
//  maps each actionable category to toast copy plus a settings destination.
//  Pattern tables are derived from 30 days of analysis_batch_failed events.
//

import Foundation

enum TimelineFailureKind: String {
  // Actionable: the user has to do something before timelines resume.
  case dayflowProRequired = "dayflow_pro_required"
  case providerLoginExpired = "provider_login_expired"
  case cliNotInstalled = "cli_not_installed"
  case cliOutdated = "cli_outdated"
  case localEngineOffline = "local_engine_offline"
  case localModelMissing = "local_model_missing"
  case apiKeyProblem = "api_key_problem"
  case usageLimitHit = "usage_limit_hit"
  case outOfCredits = "out_of_credits"
  case geoBlocked = "geo_blocked"
  case accountBlocked = "account_blocked"
  case modelMisconfigured = "model_misconfigured"
  case notConfigured = "not_configured"

  // Non-actionable: retrying usually resolves these without the user.
  case transient = "transient"
  case modelFlaky = "model_flaky"
  case unknown = "unknown"
}

enum TimelineFailureToastDestination: String {
  case providers
  case account
}

struct TimelineFailureToastContent {
  let title: String
  let body: String
  let destination: TimelineFailureToastDestination
}

struct TimelineFailureClassification {
  let kind: TimelineFailureKind

  /// Provider named by the error text itself, when it identifies one.
  /// More reliable than the configured provider: after a backup fallback,
  /// the failing provider isn't the primary one.
  let providerName: String?

  /// Toast copy for this failure, or nil when the failure isn't worth
  /// interrupting the user for (transient/flaky/unknown).
  func toastContent(fallbackProviderLabel: String?) -> TimelineFailureToastContent? {
    _ = fallbackProviderLabel
    _ = providerName

    switch kind {
    case .dayflowProRequired:
      return TimelineFailureToastContent(
        title: "Local model required",
        body:
          "Sled uses Ollama or LM Studio only. There is no cloud subscribe path. Install or start a local runtime, then use Retry on the failed cards. Your recordings are safe.",
        destination: .providers
      )

    case .providerLoginExpired:
      return TimelineFailureToastContent(
        title: "Local runtime needs a restart",
        body:
          "Sled does not use cloud logins. Restart Ollama or LM Studio and Retry the failed cards. Your recordings are safe in the meantime.",
        destination: .providers
      )

    case .cliNotInstalled:
      return TimelineFailureToastContent(
        title: "Local runtime is missing",
        body:
          "Sled does not use Codex or Claude CLI. Install Ollama (127.0.0.1:11434) or LM Studio (127.0.0.1:1234).",
        destination: .providers
      )

    case .cliOutdated:
      return TimelineFailureToastContent(
        title: "Local runtime is out of date",
        body:
          "Sled does not use the Codex CLI. Update Ollama or LM Studio, then Retry.",
        destination: .providers
      )

    case .localEngineOffline:
      return TimelineFailureToastContent(
        title: "Can't reach Ollama / LM Studio",
        body:
          "Install/start Ollama (or LM Studio). Capture and the raw timeline still work. There is no cloud fallback.",
        destination: .providers
      )

    case .localModelMissing:
      return TimelineFailureToastContent(
        title: "Your local model isn't loaded",
        body:
          "Open Ollama or LM Studio and check that your model is downloaded and loaded, or pick a different one in provider settings.",
        destination: .providers
      )

    case .apiKeyProblem:
      return TimelineFailureToastContent(
        title: "Local runtime isn't responding",
        body:
          "Sled has no API-key path. Confirm Ollama or LM Studio is running on loopback and that the vision model is loaded.",
        destination: .providers
      )

    case .usageLimitHit:
      return TimelineFailureToastContent(
        title: "Local model is overloaded",
        body:
          "New activity will process once the local runtime is free. Use Retry on any failed cards. There is no backup cloud provider.",
        destination: .providers
      )

    case .outOfCredits:
      return TimelineFailureToastContent(
        title: "Local model couldn't finish",
        body:
          "Sled has no billing or credit path. Restart Ollama or LM Studio, then Retry.",
        destination: .providers
      )

    case .geoBlocked:
      return TimelineFailureToastContent(
        title: "Local runtime isn't reachable",
        body:
          "Sled only talks to Ollama or LM Studio on this Mac. There is no regional cloud fallback.",
        destination: .providers
      )

    case .accountBlocked:
      return TimelineFailureToastContent(
        title: "Local runtime refused the request",
        body:
          "Sled has no cloud account. Restart Ollama or LM Studio and Retry.",
        destination: .providers
      )

    case .modelMisconfigured:
      return TimelineFailureToastContent(
        title: "Your selected model isn't available",
        body:
          "The local vision model isn't loaded. Open Ollama or LM Studio and confirm llama3.2-vision (or your chosen model) is available.",
        destination: .providers
      )

    case .notConfigured:
      return TimelineFailureToastContent(
        title: "No local model connected",
        body:
          "Recordings are saved, but nothing gets summarized until Ollama or LM Studio is running. There is no Gemini or Pro fallback.",
        destination: .providers
      )

    case .transient, .modelFlaky, .unknown:
      return nil
    }
  }
}

enum TimelineFailureClassifier {
  static func classify(_ error: Error) -> TimelineFailureClassification {
    let lower = error.localizedDescription.lowercased()
    return TimelineFailureClassification(
      kind: kind(for: lower),
      providerName: providerName(in: lower)
    )
  }

  private static func kind(for lower: String) -> TimelineFailureKind {
    let trimmed = lower.trimmingCharacters(in: .whitespacesAndNewlines)

    // Raw model output sometimes ends up as the error message (truncated
    // JSON, stray brackets, empty strings) — all symptoms of a flaky reply.
    if trimmed.isEmpty || trimmed.hasPrefix("[") || trimmed.hasPrefix("{")
      || trimmed.hasPrefix("]") || trimmed.hasPrefix("`")
    {
      return .modelFlaky
    }

    for rule in rules where rule.patterns.contains(where: lower.contains) {
      return rule.kind
    }
    return .unknown
  }

  /// Ordered: first matching rule wins, so specific/actionable rules must
  /// stay above the broad transient and model-flaky catch-alls.
  private static let rules: [(kind: TimelineFailureKind, patterns: [String])] = [
    (.dayflowProRequired, ["dayflow pro is required"]),
    (
      .providerLoginExpired,
      [
        "could not be refreshed", "log out and sign in", "please run /login",
        "sso session", "aws sso login",
      ]
    ),
    (.cliNotInstalled, ["cli not found", "enoent"]),
    (.cliOutdated, ["requires a newer version of codex"]),
    (.localEngineOffline, ["ollama/lmstudio is running"]),
    (
      .localModelMissing,
      [
        "ollama api request failed with status 404", "no models loaded",
        "context size has been exceeded",
      ]
    ),
    (
      .usageLimitHit,
      ["hit your usage limit", "hit your limit", "accountquotaexceeded", "usage quota"]
    ),
    (
      .outOfCredits,
      [
        "prepayment credits", "insufficient balance", "spending cap", "dunning",
        "payment required", "out of credits",
      ]
    ),
    (
      .apiKeyProblem,
      [
        "api key not found", "api key expired", "has been suspended",
        "api key not valid", "invalid api key",
      ]
    ),
    (.geoBlocked, ["location is not supported"]),
    (.accountBlocked, ["denied access"]),
    (.notConfigured, ["no llm provider configured"]),
    (.modelMisconfigured, ["is not found for api version", "not_found_error"]),
    (
      .transient,
      [
        "timed out", "reconnecting", "network connection", "internet connection",
        "tls error", "ssl error", "could not connect", "unable to connect",
        "connection refused", "econnreset", "socket", "hostname", "502",
        "upstream", "service unavailable", "internal error", "high demand",
        "at capacity", "quota exceeded", "too many requests", "overloaded",
        "message too long", "cancelled",
      ]
    ),
    (
      .modelFlaky,
      [
        "failed to decode", "be read because", "failed to parse", "empty title",
        "last segment", "segment end time", "segment out of bounds",
        "missing coverage", "gap detected", "reading additional input",
        "failed to load",
      ]
    ),
  ]

  private static func providerName(in lower: String) -> String? {
    if lower.contains("codex") || lower.contains("chatgpt")
      || lower.contains("could not be refreshed")
    {
      return "ChatGPT"
    }
    // Claude via Bedrock: the expired session is AWS's, and the fix is
    // 'aws sso login' — not 'claude login'. Must be checked before Claude.
    if lower.contains("aws sso") || lower.contains("sso session") {
      return "AWS"
    }
    if lower.contains("claude") || lower.contains("please run /login") {
      return "Claude"
    }
    if lower.contains("ollama") || lower.contains("lmstudio") || lower.contains("lm studio") {
      return "Ollama/LM Studio"
    }
    if lower.contains("gemini") || lower.contains("ai studio") || lower.contains("ai.studio")
      || lower.contains("generativelanguage") || lower.contains("api key")
      || lower.contains("lightning dunning")
    {
      return "Gemini"
    }
    return nil
  }
}
