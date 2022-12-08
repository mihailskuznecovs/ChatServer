import Foundation
import Vapor

class Server {
    var env: Environment!
    var app: Application!
    var clientConnections = Set<WebSocket>()
    let backgroundQueue = DispatchQueue(label: "background", qos: .background)

    let serverName = "Server"
    let serverID = UUID()

    deinit {
        app.shutdown()
    }

    func setupApp(completion: @escaping () -> Void) {
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

    func setupServer() {
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

                        let incomingMessage = try JSONDecoder().decode(ServerSubmittedChatMessage.self, from: data)
                        let outgoingMessage = ServerReceivingChatMessage(
                            message: incomingMessage.message,
                            user: incomingMessage.user,
                            userID: incomingMessage.userID
                        )
                        let json = try JSONEncoder().encode(outgoingMessage)

                        guard let jsonString = String(data: json, encoding: .utf8) else {
                            return
                        }

                        for connection in self.clientConnections {
                            connection.send(jsonString)
                        }

                        sleep(1)

                        let answer = ServerReceivingChatMessage(message: "\(incomingMessage.message) too you!",
                                                                user: self.serverName,
                                                                userID: self.serverID)
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

    func runServer(completion: @escaping () -> Void) {
        backgroundQueue.async {
            do {
                try self.app.start()
                completion()
            } catch {
                fatalError("Could not launch server")
            }
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

struct ServerSubmittedChatMessage: Decodable {
    let message: String
    let user: String
    let userID: UUID
}
struct ServerReceivingChatMessage: Encodable, Identifiable {
    let date = Date()
    let id = UUID()
    let message: String
    let user: String
    let userID: UUID
}

