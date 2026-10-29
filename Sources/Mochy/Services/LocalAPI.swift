import Foundation
import Network
import SwiftUI

/// A tiny HTTP endpoint on the loopback interface so scripts can post alerts to the island.
@MainActor
final class LocalAPI {
    private static let maxRequestBytes = 64 * 1024

    private var listener: NWListener?
    private var runningPort: Int?
    private weak var model: AppModel?
    private let queue = DispatchQueue(label: "dev.mochy.api")

    init(model: AppModel) {
        self.model = model
    }

    /// Starts, stops or rebinds to match the current preferences.
    func sync() {
        guard let model, model.prefs.apiEnabled else {
            stop()
            return
        }
        guard runningPort != model.prefs.apiPort || listener == nil else { return }
        stop()
        let port = model.prefs.apiPort
        guard (1024 ... 65535).contains(port), let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            report("Port \(port) isn’t available. Choose a port from 1024 to 65535.")
            return
        }
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback
        params.allowLocalEndpointReuse = true
        do {
            let listener = try NWListener(using: params, on: endpointPort)
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.accept(connection) }
            }
            listener.stateUpdateHandler = { [weak self] state in
                guard case let .failed(error) = state else { return }
                Task { @MainActor in
                    self?.report("Couldn’t listen on port \(port): \(error.localizedDescription)")
                    self?.stop()
                }
            }
            listener.start(queue: queue)
            self.listener = listener
            runningPort = port
        } catch {
            report("Couldn’t listen on port \(port): \(error.localizedDescription)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        runningPort = nil
    }

    private func report(_ message: String) {
        model?.show(IslandAlert(symbol: "network", tint: .red, title: "Local API Stopped", subtitle: message, duration: 6))
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.maxRequestBytes) { [weak self] data, _, complete, error in
            var buffer = buffer
            if let data { buffer.append(data) }
            Task { @MainActor in
                guard let self else { return connection.cancel() }
                if buffer.count > Self.maxRequestBytes {
                    return self.reply(connection, 413, ["error": "request too large"])
                }
                switch HTTPRequest.parse(buffer) {
                case let .complete(request):
                    let (status, body) = self.respond(request)
                    self.reply(connection, status, body)
                case .incomplete where error == nil && !complete:
                    self.receive(on: connection, buffer: buffer)
                default:
                    self.reply(connection, 400, ["error": "malformed request"])
                }
            }
        }
    }

    private func respond(_ request: HTTPRequest) -> (Int, [String: Any]) {
        guard let model else { return (503, ["error": "unavailable"]) }
        guard request.headers["x-mochy-token"] == model.prefs.apiToken else {
            return (401, ["error": "missing or wrong X-Mochy-Token"])
        }
        switch (request.method, request.path) {
        case ("GET", "/status"):
            return (200, [
                "app": "Mochy",
                "expanded": model.isExpanded,
                "battery": model.battery.vitals.percent,
                "charging": model.battery.vitals.isCharging,
                "nowPlaying": ["title": model.nowPlaying.title, "artist": model.nowPlaying.artist, "app": model.nowPlaying.appName, "playing": model.nowPlaying.isPlaying],
                "timer": ["running": model.timer.isRunning, "display": model.timer.display],
                "caffeine": model.caffeine.isActive,
            ])
        case ("POST", "/expand"):
            let json = request.json
            let tab = (json?["tab"] as? String).flatMap(TabID.init(rawValue:))
            model.expand(tab: tab)
            return (200, ["ok": true])
        case ("POST", "/show"):
            guard let json = request.json, let title = json["title"] as? String, !title.isEmpty else {
                return (400, ["error": "body must be JSON with a title"])
            }
            model.show(IslandAlert(
                symbol: (json["symbol"] as? String) ?? "bell.fill",
                tint: (json["color"] as? String).flatMap(Color.init(hex:)) ?? .white,
                title: title,
                subtitle: (json["subtitle"] as? String) ?? "",
                duration: min(max((json["duration"] as? Double) ?? 4, 1), 30)
            ))
            return (200, ["ok": true])
        default:
            return (404, ["error": "unknown route"])
        }
    }

    private func reply(_ connection: NWConnection, _ status: Int, _ body: [String: Any]) {
        let payload = (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data("{}".utf8)
        let reason = HTTPURLResponse.localizedString(forStatusCode: status).capitalized
        let header = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: application/json\r\nContent-Length: \(payload.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(header.utf8) + payload, completion: .contentProcessed { _ in connection.cancel() })
    }
}

private struct HTTPRequest {
    enum Parse {
        case complete(HTTPRequest)
        case incomplete
        case malformed
    }

    let method: String
    let path: String
    let headers: [String: String]
    let body: Data

    var json: [String: Any]? {
        body.isEmpty ? nil : (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
    }

    static func parse(_ data: Data) -> Parse {
        guard let split = data.range(of: Data("\r\n\r\n".utf8)) else { return .incomplete }
        guard let head = String(data: data[..<split.lowerBound], encoding: .utf8) else { return .malformed }
        let lines = head.components(separatedBy: "\r\n")
        let requestLine = lines[0].split(separator: " ")
        guard requestLine.count >= 2 else { return .malformed }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { return .malformed }
            headers[line[..<colon].lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        var length = 0
        if let raw = headers["content-length"] {
            guard let value = Int(raw), value >= 0 else { return .malformed }
            length = value
        }
        let body = data[split.upperBound...]
        if body.count < length { return .incomplete }
        let path = String(requestLine[1]).split(separator: "?", maxSplits: 1).first.map(String.init) ?? "/"
        return .complete(HTTPRequest(method: String(requestLine[0]), path: path, headers: headers, body: Data(body.prefix(length))))
    }
}
