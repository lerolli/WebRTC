import Foundation
import WebRTC
import Combine

enum ReactiveSignalClientError: Error {
    case couldNotEncodeMessage
    case couldNotDecodeMessage
}


enum ReactiveSignalClientAction {
    case connect
    case sendSessionDescription(RTCSessionDescription)
    case sendIceCandidate(RTCIceCandidate)
}

enum ReactiveSignalClientCallback {
    case isSocketConnected(Bool)
    case didReceiveIceCandidate(RTCIceCandidate)
    case didReceiveSessionDescription(RTCSessionDescription)
    
    case catchError(Error)
}


protocol ReactiveSignalClientProtocol: AnyObject {
    var servicesEventPublisher: AnyPublisher<ReactiveSignalClientCallback, Never> { get }
    
    func dispatch(_ action: ReactiveSignalClientAction)
}

final class ReactiveSignalingClient: ReactiveSignalClientProtocol {
    var servicesEventPublisher: AnyPublisher<ReactiveSignalClientCallback, Never> {
        serviceEventSubject.eraseToAnyPublisher()
    }

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private let webSocketService: WebSocketServiceProtocol
    
    private let serviceEventSubject = PassthroughSubject<ReactiveSignalClientCallback, Never>()
    private var cancellableBag = Set<AnyCancellable>()
    

    init(webSocketService: WebSocketServiceProtocol) {
        self.webSocketService = webSocketService
    }
    
    func dispatch(_ action: ReactiveSignalClientAction) {
        switch action {
            case .connect:
                connect()
            case let .sendSessionDescription(sessionDescription):
                let message = Message.sdp(SessionDescription(from: sessionDescription))
                send(message: message)
            case let .sendIceCandidate(iceCandidate):
                let message = Message.candidate(IceCandidate(from: iceCandidate))
                send(message: message)
        }
    }
}


// MARK: - Private

extension ReactiveSignalingClient {
    private func connect() {
        webSocketService.servicesEventPublisher.sink(receiveValue: { [weak self] callback in
            switch callback {
                case let .isSocketConnected(isConnected):
                    self?.serviceEventSubject.send(.isSocketConnected(isConnected))
                    
                    if !isConnected {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
                            self?.webSocketService.connect()
                        }
                    }
                case let .getData(data):
                    self?.didReceiveData(data: data)
            }
        }).store(in: &cancellableBag)
        
        webSocketService.connect()
    }
    
    private func send(message: Message) {
        do {
            let dataMessage = try encoder.encode(message)
            webSocketService.send(data: dataMessage)
        }
        catch {
            serviceEventSubject.send(
                .catchError(ReactiveSignalClientError.couldNotEncodeMessage as Error)
            )
        }
    }
    
    
    private func didReceiveData(data: Data) {
        let message: Message
        do {
            message = try self.decoder.decode(Message.self, from: data)
        }
        catch {
            serviceEventSubject.send(
                .catchError(ReactiveSignalClientError.couldNotDecodeMessage as Error)
            )
            return
        }
        
        switch message {
            case let .candidate(iceCandidate):
                serviceEventSubject.send(.didReceiveIceCandidate(iceCandidate.rtcIceCandidate))
            case let .sdp(sessionDescription):
                serviceEventSubject.send(.didReceiveSessionDescription(sessionDescription.rtcSessionDescription))
        }

    }
}
