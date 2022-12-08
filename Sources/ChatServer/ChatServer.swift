import Foundation
import Vapor

public class Server {
    private var env: Environment!
    private var app: Application!
    private var clientConnections = Set<WebSocket>()
    private let backgroundQueue = DispatchQueue(label: "background", qos: .background)

    private let serverName = "Server"
    private let serverID = UUID()
    
    public init() {}
    
    deinit {
        app.shutdown()
    }

    public func setupServer() {
        setupApp {
            self.app.webSocket("chat") { req, client in
                self.clientConnections.insert(client)

                client.onClose.whenComplete { _ in
                    self.clientConnections.remove(client)
                }

                client.onText { _, text in
                    do {
                        guard let data = text.data(using: .utf8) else {
                            return
                        }

                        let incomingMessage = try JSONDecoder().decode(ChatMessage.self, from: data)
                        let json = try JSONEncoder().encode(incomingMessage)

                        guard let jsonString = String(data: json, encoding: .utf8) else {
                            return
                        }

                        for connection in self.clientConnections {
                            connection.send(jsonString)
                        }

                        sleep(1)

                        let answer = ChatMessage(date: Date(), id: UUID(), message: "\(incomingMessage.message) to you!", user: self.serverName, userID: self.serverID)
                        let jsonAnswer = try JSONEncoder().encode(answer)
                        guard let answerString = String(data: jsonAnswer, encoding: .utf8) else {
                            return
                        }
                        for connection in self.clientConnections {
                            connection.send(answerString)
                        }
                    }
                    catch {
                        print(error)
                    }
                }
            }
        }
    }

    public func startServer(completion: @escaping () -> Void) {
        backgroundQueue.async {
            do {
                try self.app.start()
                completion()
            } catch {
                fatalError("Could not launch server")
            }
        }
    }
    
    private func setupApp(completion: @escaping () -> Void) {
        self.backgroundQueue.async {
            do {
                self.env = try Environment.detect()
            } catch {
                fatalError("Could not detect environment")
            }
            self.app = Application(self.env)
            completion()
        }
    }
}


extension WebSocket: Hashable {
    public static func == (lhs: WebSocket, rhs: WebSocket) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

public struct ChatMessage: Codable, Identifiable {
    public let date: Date
    public let id: UUID
    public let message: String
    public let user: String
    public let userID: UUID
    
    public init(date: Date, id: UUID, message: String, user: String, userID: UUID) {
        self.date = date
        self.id = id
        self.message = message
        self.user = user
        self.userID = userID
    }
}

