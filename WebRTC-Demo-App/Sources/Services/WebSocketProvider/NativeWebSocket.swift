import Foundation
import SocketIO

final class WebSocketIO: WebSocketProvider {
    weak var delegate: WebSocketProviderDelegate?
    
    private var socket: SocketIOClient?
    private let manager: SocketManager
    
    init(url: URL) {
        manager = SocketManager(
            socketURL: url,
            config: [.log(true), .compress]
        )
    }

    func connect() {
        let socket = manager.defaultSocket

        socket.on(clientEvent: .connect) { data, ack in
            self.delegate?.webSocketDidConnect(self)
            print("socket connected")
        }
        
        socket.connect()

        self.socket = socket
        readMessage()
    }

    func send(data: Data) {
        socket?.emit("stream", data)
        
    }
    
    private func readMessage() {
        socket?.on("stream") { [weak self] data, ack in
            guard let self = self else { return }
            
            self.delegate?.webSocket(
                self,
                didReceiveData: data.first as! Data
            )
        }
    }
    
    private func disconnect() {
        socket?.disconnect()
        socket = nil
        delegate?.webSocketDidDisconnect(self)
    }
}
