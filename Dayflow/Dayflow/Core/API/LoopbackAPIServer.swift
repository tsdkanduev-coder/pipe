import Foundation
import Network

/// Local-only HTTP server. Binds 127.0.0.1. No cloud fallback if the process is down.
final class LoopbackAPIServer: @unchecked Sendable {
  static let shared = LoopbackAPIServer()

  let port: UInt16
  private var listener: NWListener?
  private let queue = DispatchQueue(label: "ru.kanduev.sled.loopback")

  init(port: UInt16 = SledIdentity.loopbackPort) {
    self.port = port
  }

  func start() {
    queue.async { [weak self] in
      self?.startLocked()
    }
  }

  func stop() {
    queue.sync {
      listener?.cancel()
      listener = nil
    }
  }

  private func startLocked() {
    guard listener == nil else { return }
    do {
      let parameters = NWParameters.tcp
      parameters.acceptLocalOnly = true
      parameters.allowLocalEndpointReuse = true
      let listener = try NWListener(
        using: parameters,
        on: NWEndpoint.Port(rawValue: port)!
      )
      listener.newConnectionHandler = { [weak self] connection in
        self?.handle(connection)
      }
      listener.stateUpdateHandler = { state in
        if case .failed(let error) = state {
          print("[Sled loopback] listener failed: \(error)")
        }
      }
      listener.start(queue: queue)
      self.listener = listener
      print("[Sled loopback] GET http://127.0.0.1:\(port)/v1/actions")
    } catch {
      print("[Sled loopback] failed to bind 127.0.0.1:\(port): \(error)")
    }
  }

  private func handle(_ connection: NWConnection) {
    connection.start(queue: queue)
    receive(on: connection, buffer: Data())
  }

  private func receive(on connection: NWConnection, buffer: Data) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, isComplete, error in
      guard let self else {
        connection.cancel()
        return
      }
      if let error {
        print("[Sled loopback] receive error: \(error)")
        connection.cancel()
        return
      }
      var next = buffer
      if let data {
        next.append(data)
      }
      if let headerEnd = next.range(of: Data("\r\n\r\n".utf8)) {
        let header = String(data: next.subdata(in: next.startIndex..<headerEnd.lowerBound), encoding: .utf8) ?? ""
        self.respond(to: header, on: connection)
        return
      }
      if isComplete {
        let header = String(data: next, encoding: .utf8) ?? ""
        self.respond(to: header, on: connection)
        return
      }
      if next.count > 32_768 {
        self.send(status: 413, body: Data("{\"error\":\"request too large\"}".utf8), on: connection)
        return
      }
      self.receive(on: connection, buffer: next)
    }
  }

  private func respond(to request: String, on connection: NWConnection) {
    let firstLine = request.split(separator: "\r\n", maxSplits: 1, omittingEmptySubsequences: false)
      .first
      .map(String.init) ?? ""
    let tokens = firstLine.split(separator: " ")
    guard tokens.count >= 2 else {
      send(status: 400, body: Data("{\"error\":\"bad request\"}".utf8), on: connection)
      return
    }
    let method = String(tokens[0])
    let target = String(tokens[1])
    guard method == "GET" else {
      send(status: 405, body: Data("{\"error\":\"method not allowed\"}".utf8), on: connection)
      return
    }
    guard let query = LoopbackAPIQuery.parse(pathAndQuery: target) else {
      send(status: 404, body: Data("{\"error\":\"not found\"}".utf8), on: connection)
      return
    }

    let actions = StorageManager.shared.fetchLoopbackActions(since: query.since, limit: query.limit)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let body = (try? encoder.encode(actions)) ?? Data("[]".utf8)
    send(status: 200, body: body, on: connection)
  }

  private func send(status: Int, body: Data, on connection: NWConnection) {
    let reason: String
    switch status {
    case 200: reason = "OK"
    case 400: reason = "Bad Request"
    case 404: reason = "Not Found"
    case 405: reason = "Method Not Allowed"
    case 413: reason = "Payload Too Large"
    default: reason = "Error"
    }
    var header = "HTTP/1.1 \(status) \(reason)\r\n"
    header += "Content-Type: application/json\r\n"
    header += "Content-Length: \(body.count)\r\n"
    header += "Connection: close\r\n"
    header += "\r\n"
    var payload = Data(header.utf8)
    payload.append(body)
    connection.send(content: payload, completion: .contentProcessed { _ in
      connection.cancel()
    })
  }
}
