import Foundation
import SocketIO
import Combine

enum WebSocketServiceCallback {
    case getData(Data)
    case isSocketConnected(Bool)
}

protocol WebSocketServiceProtocol: AnyObject {
    var servicesEventPublisher: AnyPublisher<WebSocketServiceCallback, Never> { get }
    
    func connect()
    func send(data: Data)
}

final class WebSocketService: WebSocketServiceProtocol {
    var servicesEventPublisher: AnyPublisher<WebSocketServiceCallback, Never> {
        serviceEventSubject.eraseToAnyPublisher()
    }
    
    private var socket: SocketIOClient?
    private let manager: SocketManager
    private let serviceEventSubject = PassthroughSubject<WebSocketServiceCallback, Never>()
    
    init(url: URL) {
        manager = SocketManager(
            socketURL: url,
            config: []
        )
    }

    func connect() {
        let socket = manager.defaultSocket

        socket.on(clientEvent: .connect) { [weak self] _, _ in
            self?.serviceEventSubject.send(.isSocketConnected(true))
        }
        
        socket.connect()

        self.socket = socket
        readMessage()
    }

    func send(data: Data) {
        socket?.emit("stream", data)
    }
}

// MARK: - Private

extension WebSocketService {
    private func readMessage() {
        socket?.on("stream") { [weak self] data, ack in
            guard let self = self, let data = data.first as? Data
            else { return }
            self.serviceEventSubject.send(.getData(data))
    
        }
    }
    
    private func disconnect() {
        socket?.disconnect()
        socket = nil
        serviceEventSubject.send(.isSocketConnected(false))
    }
}
