import Foundation
import GRDB

extension StorageManager {
  func fetchLoopbackActions(since: Date?, limit: Int) -> [LoopbackAction] {
    let clamped = LoopbackAPIQuery.clampedLimit(limit)
    let sinceTs = since.map { Int($0.timeIntervalSince1970) }
    return
      (try? timedRead("fetchLoopbackActions") { db in
        let sql: String
        let arguments: StatementArguments
        if let sinceTs {
          sql = """
              SELECT id, start_ts, end_ts, app, window_title, title, summary, metadata
              FROM timeline_cards
              WHERE is_deleted = 0
                AND start_ts IS NOT NULL
                AND start_ts >= ?
              ORDER BY start_ts DESC
              LIMIT ?
            """
          arguments = [sinceTs, clamped]
        } else {
          sql = """
              SELECT id, start_ts, end_ts, app, window_title, title, summary, metadata
              FROM timeline_cards
              WHERE is_deleted = 0
                AND start_ts IS NOT NULL
              ORDER BY start_ts DESC
              LIMIT ?
            """
          arguments = [clamped]
        }

        return try Row.fetchAll(db, sql: sql, arguments: arguments).map { row in
          loopbackAction(from: row)
        }
      }) ?? []
  }

  func upsertRawActivity(at date: Date, app: String?, windowTitle: String?) {
    let timestamp = Int(date.timeIntervalSince1970)
    let clock = clockString(from: date)
    let (dayString, _, _) = date.getDayInfoFor4AMBoundary()
    let title = (windowTitle?.isEmpty == false ? windowTitle : app) ?? "Activity"
    let metadata = "{\"isRawCapture\":true}"

    try? timedWrite("upsertRawActivity") { db in
      if let open = try Row.fetchOne(
        db,
        sql: """
            SELECT id, app, window_title
            FROM timeline_cards
            WHERE is_deleted = 0
              AND batch_id IS NULL
              AND metadata LIKE '%isRawCapture%'
            ORDER BY start_ts DESC
            LIMIT 1
          """
      ) {
        let openApp: String? = open["app"]
        let openTitle: String? = open["window_title"]
        let sameSession = openApp == app && openTitle == windowTitle
        if sameSession {
          try db.execute(
            sql: """
                UPDATE timeline_cards
                SET end = ?, end_ts = ?
                WHERE id = ?
              """,
            arguments: [clock, timestamp, open["id"] as Int64]
          )
          return
        }
        try db.execute(
          sql: """
              UPDATE timeline_cards
              SET end = ?, end_ts = ?
              WHERE id = ?
            """,
          arguments: [clock, timestamp, open["id"] as Int64]
        )
      }

      try db.execute(
        sql: """
            INSERT INTO timeline_cards(
                batch_id, start, end, start_ts, end_ts, day, title,
                summary, category, subcategory, detailed_summary, metadata,
                app, window_title
            )
            VALUES (NULL, ?, ?, ?, ?, ?, ?, NULL, ?, NULL, NULL, ?, ?, ?)
          """,
        arguments: [
          clock, clock, timestamp, timestamp, dayString, title,
          RawActivityRecorder.rawCategory, metadata, app, windowTitle,
        ]
      )
    }
  }

  func closeOpenRawActivity(at date: Date) {
    let timestamp = Int(date.timeIntervalSince1970)
    let clock = clockString(from: date)
    try? timedWrite("closeOpenRawActivity") { db in
      try db.execute(
        sql: """
            UPDATE timeline_cards
            SET end = ?, end_ts = ?
            WHERE is_deleted = 0
              AND batch_id IS NULL
              AND metadata LIKE '%isRawCapture%'
              AND (end_ts IS NULL OR end_ts <= start_ts OR end_ts < ?)
          """,
        arguments: [clock, timestamp, timestamp]
      )
    }
  }

  func softDeleteOverlappingRawActivities(startTs: Int, endTs: Int) {
    try? timedWrite("softDeleteOverlappingRawActivities") { db in
      try db.execute(
        sql: """
            UPDATE timeline_cards
            SET is_deleted = 1
            WHERE is_deleted = 0
              AND batch_id IS NULL
              AND metadata LIKE '%isRawCapture%'
              AND start_ts IS NOT NULL
              AND end_ts IS NOT NULL
              AND start_ts < ?
              AND end_ts > ?
          """,
        arguments: [endTs, startTs]
      )
    }
  }

  private func loopbackAction(from row: Row) -> LoopbackAction {
    let id: Int64 = row["id"] ?? 0
    let startTs: Int = row["start_ts"] ?? 0
    let endTs: Int = row["end_ts"] ?? startTs
    var app: String? = row["app"]
    var windowTitle: String? = row["window_title"]
    let title: String? = row["title"]
    let summary: String? = row["summary"]
    let metadata: String? = row["metadata"]

    if (app == nil || app?.isEmpty == true), let metadata,
      let data = metadata.data(using: .utf8),
      let decoded = try? JSONDecoder().decode(TimelineMetadata.self, from: data)
    {
      app = decoded.appSites?.primary ?? decoded.appSites?.secondary
    }
    if windowTitle == nil || windowTitle?.isEmpty == true {
      windowTitle = title
    }

    return LoopbackAction(
      id: id,
      started_at: LoopbackAPIQuery.iso8601String(from: Date(timeIntervalSince1970: TimeInterval(startTs))),
      ended_at: LoopbackAPIQuery.iso8601String(from: Date(timeIntervalSince1970: TimeInterval(endTs))),
      app: app,
      window_title: windowTitle,
      summary: summary
    )
  }

  private func clockString(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: date)
  }
}
