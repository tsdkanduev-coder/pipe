import Foundation

struct LoopbackAction: Codable, Equatable, Sendable {
  let id: Int64
  let started_at: String
  let ended_at: String
  let app: String?
  let window_title: String?
  let summary: String?
}

enum LoopbackAPIQuery {
  static let defaultLimit = 50
  static let maxLimit = 200

  static func clampedLimit(_ raw: Int?) -> Int {
    guard let raw else { return defaultLimit }
    if raw < 1 { return defaultLimit }
    return min(raw, maxLimit)
  }

  static func parse(pathAndQuery: String) -> ParsedRequest? {
    let parts = pathAndQuery.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
    let path = String(parts.first ?? "")
    guard path == "/v1/actions" else { return nil }

    var since: Date?
    var limit: Int?
    if parts.count == 2 {
      let items = String(parts[1]).split(separator: "&")
      for item in items {
        let pair = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        guard pair.count == 2 else { continue }
        let key = String(pair[0])
        let value = String(pair[1]).removingPercentEncoding ?? String(pair[1])
        if key == "since" {
          since = parseISO8601(value)
        } else if key == "limit" {
          limit = Int(value)
        }
      }
    }

    return ParsedRequest(since: since, limit: clampedLimit(limit))
  }

  static func parseISO8601(_ value: String) -> Date? {
    let withFractional = ISO8601DateFormatter()
    withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = withFractional.date(from: value) {
      return date
    }
    let basic = ISO8601DateFormatter()
    basic.formatOptions = [.withInternetDateTime]
    return basic.date(from: value)
  }

  static func iso8601String(from date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
  }

  struct ParsedRequest: Equatable {
    let since: Date?
    let limit: Int
  }
}
