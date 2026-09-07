import Darwin
import Foundation

func runHTTPServer(port: UInt16) -> Never {
  let fd = socket(AF_INET, SOCK_STREAM, 0)
  guard fd >= 0 else {
    fputs("Could not create a socket.\n", stderr)
    exit(1)
  }

  var reuse: Int32 = 1
  setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

  var address = sockaddr_in()
  address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
  address.sin_family = sa_family_t(AF_INET)
  address.sin_port = port.bigEndian
  address.sin_addr = in_addr(s_addr: inet_addr(PipeIdentity.httpHost))

  let bindResult = withUnsafePointer(to: &address) { pointer in
    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
      bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
    }
  }
  guard bindResult == 0, listen(fd, 16) == 0 else {
    fputs("Could not bind \(PipeIdentity.httpHost):\(port). Is another Pipe server running?\n", stderr)
    exit(1)
  }

  fputs(
    "\(PipeIdentity.productName) agent HTTP on \(PipeIdentity.httpBaseURL)\n",
    stderr
  )

  while true {
    let client = accept(fd, nil, nil)
    guard client >= 0 else { continue }
    DispatchQueue.global(qos: .userInitiated).async {
      handleHTTPClient(client)
    }
  }
}

private func handleHTTPClient(_ client: Int32) {
  defer { close(client) }

  var request = Data()
  var byte: UInt8 = 0
  while request.count < 64 * 1024, read(client, &byte, 1) == 1 {
    request.append(byte)
    if request.count >= 4,
      request.suffix(4) == Data([0x0D, 0x0A, 0x0D, 0x0A])
    {
      break
    }
  }

  guard let text = String(data: request, encoding: .utf8),
    let requestLine = text.split(separator: "\r\n", maxSplits: 1).first
  else {
    writeHTTP(client: client, status: 400, contentType: "application/json", body: #"{"error":"bad_request"}"#)
    return
  }

  let parts = requestLine.split(separator: " ")
  guard parts.count >= 2 else {
    writeHTTP(client: client, status: 400, contentType: "application/json", body: #"{"error":"bad_request"}"#)
    return
  }

  let method = String(parts[0])
  if method == "OPTIONS" {
    writeHTTP(client: client, status: 204, contentType: "text/plain", body: "")
    return
  }
  guard method == "GET" else {
    writeHTTP(client: client, status: 405, contentType: "application/json", body: #"{"error":"method_not_allowed"}"#)
    return
  }

  let rawPath = String(parts[1])
  let (path, query) = splitPathAndQuery(rawPath)
  let response = httpRoute(path: path, query: query)
  writeHTTP(
    client: client,
    status: response.status,
    contentType: response.contentType,
    body: response.body
  )
}

private func splitPathAndQuery(_ raw: String) -> (String, [String: String]) {
  let pieces = raw.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
  let path = String(pieces[0])
  var query: [String: String] = [:]
  if pieces.count > 1 {
    for pair in pieces[1].split(separator: "&") {
      let sides = pair.split(separator: "=", maxSplits: 1)
      let key = percentDecode(String(sides[0]))
      let value = sides.count > 1 ? percentDecode(String(sides[1])) : ""
      query[key] = value
    }
  }
  return (path, query)
}

private func percentDecode(_ value: String) -> String {
  value.removingPercentEncoding?.replacingOccurrences(of: "+", with: " ") ?? value
}

private func writeHTTP(client: Int32, status: Int, contentType: String, body: String) {
  let reason: String
  switch status {
  case 200: reason = "OK"
  case 204: reason = "No Content"
  case 400: reason = "Bad Request"
  case 404: reason = "Not Found"
  case 405: reason = "Method Not Allowed"
  default: reason = "Error"
  }
  let header = """
    HTTP/1.1 \(status) \(reason)\r
    Content-Type: \(contentType); charset=utf-8\r
    Content-Length: \(body.utf8.count)\r
    Access-Control-Allow-Origin: *\r
    Access-Control-Allow-Methods: GET, OPTIONS\r
    Access-Control-Allow-Headers: Content-Type\r
    Connection: close\r
    \r

    """
  let payload = Array(header.utf8) + Array(body.utf8)
  payload.withUnsafeBytes { buffer in
    _ = write(client, buffer.baseAddress, buffer.count)
  }
}

private struct HTTPResponse {
  let status: Int
  let contentType: String
  let body: String
}

private func jsonResponse(_ object: [String: Any], status: Int = 200) -> HTTPResponse {
  var payload = object
  payload["schema_version"] = schemaVersion
  let data =
    (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys, .prettyPrinted]))
    ?? Data("{}".utf8)
  return HTTPResponse(
    status: status,
    contentType: "application/json",
    body: String(data: data, encoding: .utf8) ?? "{}"
  )
}

private func httpRoute(path: String, query: [String: String]) -> HTTPResponse {
  do {
    switch path {
    case "/", "/v1":
      return jsonResponse([
        "product": PipeIdentity.productName,
        "mcp": "\(PipeIdentity.cliCommand) mcp",
        "endpoints": [
          "/v1/status",
          "/v1/guide",
          "/v1/context",
          "/v1/timeline?date=YYYY-MM-DD",
          "/v1/activities/{id}",
          "/v1/search?q=",
          "/v1/daily?date=YYYY-MM-DD",
          "/v1/weekly?date=YYYY-MM-DD",
          "/v1/breakdown?from=YYYY-MM-DD&to=YYYY-MM-DD",
          "/v1/categories",
        ],
      ])
    case "/health", "/v1/health":
      return jsonResponse(["ok": true])
    case "/v1/status":
      return try statusPayload()
    case "/v1/guide":
      if query["format"] == "md" || query["format"] == "markdown" {
        return HTTPResponse(status: 200, contentType: "text/markdown", body: AgentGuide.markdown)
      }
      return jsonResponse(AgentGuide.json)
    case "/v1/context":
      return try contextPayload(asJSON: query["format"] == "json")
    case "/v1/timeline":
      return try timelinePayload(date: query["date"])
    case "/v1/search":
      return try searchPayload(query: query["q"] ?? query["query"] ?? "")
    case "/v1/daily":
      return try dailyPayload(date: query["date"])
    case "/v1/weekly":
      return try weeklyPayload(date: query["date"])
    case "/v1/breakdown":
      return try breakdownPayload(from: query["from"], to: query["to"])
    case "/v1/categories":
      return jsonResponse([
        "categories": loadCategories().map {
          [
            "name": $0.name, "color_hex": $0.colorHex,
            "is_system": $0.isSystem, "is_idle": $0.isIdle,
          ] as [String: Any]
        }
      ])
    default:
      if path.hasPrefix("/v1/activities/") {
        let idText = String(path.dropFirst("/v1/activities/".count))
        return try activityPayload(idText: idText)
      }
      return jsonResponse(["error": "not_found", "path": path], status: 404)
    }
  } catch DatabaseError.notFound {
    return jsonResponse(
      ["error": "no_data", "message": "No Pipe data yet. Open Pipe and let it record."],
      status: 404
    )
  } catch {
    return jsonResponse(["error": "query_failed", "message": "\(error)"], status: 500)
  }
}

private func openDB() throws -> Database {
  try Database(path: Database.defaultPath())
}

private func statusPayload() throws -> HTTPResponse {
  let path = Database.defaultPath()
  let status = try fetchStatus(db: Database(path: path), path: path)
  var body: [String: Any] = [
    "today": status.today,
    "time_zone": TimeZone.current.identifier,
    "day_boundary_hour": 4,
    "pending_batches": status.pendingBatches,
    "edits_enabled": AgentBridge.editsEnabled,
    "app_running": AgentBridge.appIsListening,
    "http": PipeIdentity.httpBaseURL,
  ]
  if let lastCapture = status.lastCaptureAt {
    body["last_capture_at"] = isoFormatter.string(from: lastCapture)
  }
  return jsonResponse(body)
}

private func timelinePayload(date: String?) throws -> HTTPResponse {
  let window: DayWindow
  if let date {
    guard let resolved = dayWindow(forKey: date) else {
      return jsonResponse(["error": "invalid_date"], status: 400)
    }
    window = resolved
  } else {
    window = dayWindow(containing: Date())
  }
  let activities = try fetchActivities(db: openDB(), window: window)
  return jsonResponse(timelineEnvelope(activities, dayKey: window.dayKey, detailed: false))
}

private func activityPayload(idText: String) throws -> HTTPResponse {
  guard let recordId = Int(idText) else {
    return jsonResponse(["error": "invalid_id"], status: 400)
  }
  guard let activity = try fetchActivity(db: openDB(), recordId: recordId) else {
    return jsonResponse(["error": "not_found"], status: 404)
  }
  return jsonResponse(json(for: activity, detailed: true))
}

private func searchPayload(query: String) throws -> HTTPResponse {
  guard !query.isEmpty else {
    return jsonResponse(["error": "query_required"], status: 400)
  }
  let matches = try searchActivities(db: openDB(), text: query)
  return jsonResponse([
    "query": query,
    "matches": matches.map { json(for: $0, detailed: false) },
  ])
}

private func dailyPayload(date: String?) throws -> HTTPResponse {
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd"
  let key = date ?? formatter.string(from: Date())
  guard let standup = try fetchStandup(db: openDB(), day: key) else {
    return jsonResponse(["error": "not_found", "date": key], status: 404)
  }
  return jsonResponse([
    "date": standup.day,
    "highlights": standup.highlights,
    "tasks": standup.tasks,
    "blockers": standup.blockersBody,
  ])
}

private func weeklyPayload(date: String?) throws -> HTTPResponse {
  let anchor: Date
  if let date {
    guard let window = dayWindow(forKey: date) else {
      return jsonResponse(["error": "invalid_date"], status: 400)
    }
    anchor = window.start
  } else {
    anchor = Date()
  }
  let window = weekWindow(containing: anchor)
  let activities = try fetchActivities(db: openDB(), from: window.start, to: window.end)
  var totals: [String: Int] = [:]
  for activity in activities where activity.category != "System" {
    totals[activity.category, default: 0] += activity.durationMinutes
  }
  let tracked = totals.values.reduce(0, +)
  return jsonResponse([
    "week_start": isoFormatter.string(from: window.start),
    "week_end": isoFormatter.string(from: window.end),
    "tracked_minutes": tracked,
    "focus_minutes": totals.filter { $0.key != "Idle" }.values.reduce(0, +),
    "categories": totals.sorted { $0.value > $1.value }.map {
      [
        "name": $0.key, "minutes": $0.value,
        "share": tracked > 0 ? Double($0.value) / Double(tracked) : 0,
      ] as [String: Any]
    },
  ])
}

private func breakdownPayload(from: String?, to: String?) throws -> HTTPResponse {
  guard let from, let to,
    let fromWindow = dayWindow(forKey: from),
    let toWindow = dayWindow(forKey: to),
    fromWindow.start <= toWindow.start
  else {
    return jsonResponse(["error": "from_and_to_required"], status: 400)
  }
  let activities = try fetchActivities(db: openDB(), from: fromWindow.start, to: toWindow.end)
  var totals: [String: Int] = [:]
  for activity in activities where activity.category != "System" {
    totals[activity.category, default: 0] += activity.durationMinutes
  }
  let tracked = totals.values.reduce(0, +)
  return jsonResponse([
    "range": ["from": from, "to": to],
    "tracked_minutes": tracked,
    "categories": totals.sorted { $0.value > $1.value }.map {
      [
        "name": $0.key, "minutes": $0.value,
        "share": tracked > 0 ? Double($0.value) / Double(tracked) : 0,
      ] as [String: Any]
    },
  ])
}

private func contextPayload(asJSON: Bool) throws -> HTTPResponse {
  let built = try buildAgentContext()
  if asJSON {
    return jsonResponse(built.json)
  }
  return HTTPResponse(status: 200, contentType: "text/markdown", body: built.markdown)
}
