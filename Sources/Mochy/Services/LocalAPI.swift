import Foundation
import Network

final class LocalAPI {
    private var listener: NWListener?
    private weak var model: AppModel?
    private let queue = DispatchQueue(label: "dev.mochy.api")

    init(model: AppModel) {
        self.model = model
    }

    @MainActor
    func start() {
        guard let model, model.apiEnabled else { return }
        let port = model.apiPort
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) ?? 9999
            listener = try NWListener(using: params, on: nwPort)
            listener?.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener?.start(queue: queue)
        } catch {
            DispatchQueue.main.async {
                self.model?.showIsland(title: "Local API", message: "Couldn’t listen on port \(model.apiPort)", symbol: "network", tint: "red")
            }
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, _ in
            guard let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            let response = self?.handle(request) ?? Self.http(401, "{\"error\":\"unauthorized\"}")
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func handle(_ raw: String) -> Data {
        let lines = raw.components(separatedBy: "\r\n")
        let head = lines.first ?? ""
        let parts = head.split(separator: " ")
        let method = parts.first.map(String.init) ?? ""
        let path = parts.dropFirst().first.map(String.init) ?? "/"
        let token = lines.first(where: { $0.lowercased().hasPrefix("x-mochy-token:") })?
            .drop { $0 != ":" }.dropFirst().trimmingCharacters(in: .whitespaces)
        let expected = DispatchQueue.main.sync { model?.apiToken }
        guard token == expected else {
            return Self.http(401, "{\"error\":\"token required\"}")
        }
        if method == "GET", path == "/status" {
            let json = DispatchQueue.main.sync { () -> String in
                let playing = model?.nowPlaying.title ?? ""
                let battery = model?.battery.percent ?? 0
                return "{\"app\":\"Mochy\",\"battery\":\(battery),\"nowPlaying\":\"\(Self.escape(playing))\"}"
            }
            return Self.http(200, json)
        }
        if method == "POST", path == "/expand" {
            DispatchQueue.main.async { self.model?.expand() }
            return Self.http(200, "{\"ok\":true}")
        }
        if method == "POST", path.hasPrefix("/show") {
            let body = raw.components(separatedBy: "\r\n\r\n").last ?? ""
            let json = (try? JSONSerialization.jsonObject(with: Data(body.utf8))) as? [String: Any]
            let title = json?["title"] as? String ?? "Mochy"
            let message = json?["message"] as? String ?? ""
            let duration = json?["duration"] as? Double ?? 3
            DispatchQueue.main.async {
                self.model?.showIsland(title: title, message: message, symbol: "bell.fill", duration: duration)
            }
            return Self.http(200, "{\"ok\":true}")
        }
        return Self.http(404, "{\"error\":\"unknown\"}")
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func http(_ code: Int, _ body: String) -> Data {
        let payload = Data(body.utf8)
        let header = "HTTP/1.1 \(code) OK\r\nContent-Type: application/json\r\nContent-Length: \(payload.count)\r\nConnection: close\r\n\r\n"
        return Data(header.utf8) + payload
    }
}
