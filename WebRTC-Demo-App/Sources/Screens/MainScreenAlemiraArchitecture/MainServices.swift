import Foundation
import SwiftUI
import Combine
import WebRTC

protocol MainServicesProtocol {
    var servicesEventPublisher: AnyPublisher<MainServicesCallback, Never> { get }
    
    func dispatch(_ action: MainServicesAction)
}

enum MainServicesAction {
    case offerDidTap
    case answerDidTap
    case muteAudio(Bool)
    case muteSpeaker(Bool)
}

enum MainServicesCallback {
    case isSocketConnected(Bool)
    
    case hasLocalSessionDescription
    case didDiscoverLocalCandidate
    
    case didReceiveSessionDescription
    case didReceiveIceCandidate
    case didReceiveMessage(Data)
    
    case changeConnectionState(RTCIceConnectionState)
    
    case showError(Error)
}

final class MainServices {
    private let webRTCClient: ReactiveWebRTCClientProtocol
    private let signalClient: ReactiveSignalClientProtocol
    
    private let serviceEventSubject = PassthroughSubject<MainServicesCallback, Never>()
    private var cancellableBag = Set<AnyCancellable>()
    
    init(
        webRTCClient: ReactiveWebRTCClientProtocol,
        signalingClient: ReactiveSignalClientProtocol
    ) {
        self.webRTCClient = webRTCClient
        self.signalClient = signalingClient
        
        configureService()
        
        signalClient.dispatch(.connect)
    }
}

extension MainServices: MainServicesProtocol {
    var servicesEventPublisher: AnyPublisher<MainServicesCallback, Never> {
        serviceEventSubject.eraseToAnyPublisher()
    }
    
    func dispatch(_ action: MainServicesAction) {
        switch action {
            case .offerDidTap:
                webRTCClient.dispatch(.setLocalDescription(.offer))
            case .answerDidTap:
                webRTCClient.dispatch(.setLocalDescription(.answer))
            case let .muteAudio(isMuted):
                webRTCClient.dispatch(.audioIsMuted(isMuted))
            case let .muteSpeaker(isMuted):
                webRTCClient.dispatch(.speakerIsMuted(isMuted))
        }
    }
}

// MARK: - Private

extension MainServices {
    private func configureService() {
        signalClient.servicesEventPublisher.sink { [weak self] callback in
            switch callback {
                case let .isSocketConnected(isConnected):
                    self?.serviceEventSubject.send(.isSocketConnected(isConnected))
                case let .didReceiveIceCandidate(candidate):
                    self?.serviceEventSubject.send(.didReceiveIceCandidate)
                    self?.webRTCClient.dispatch(.setCandidate(candidate))
                case let .didReceiveSessionDescription(sessionDescription):
                    self?.serviceEventSubject.send(.didReceiveSessionDescription)
                    self?.webRTCClient.dispatch(.setRemoteDescription(sessionDescription))
                case let .catchError(error):
                    self?.serviceEventSubject.send(.showError(error))
            }
        }
        .store(in: &cancellableBag)
        
        webRTCClient.servicesEventPublisher.sink { [weak self] callback in
            switch callback {
                case let .sendLocalDescription(localDescription):
                    self?.serviceEventSubject.send(.hasLocalSessionDescription)
                    self?.signalClient.dispatch(.sendSessionDescription(localDescription))

                case let .didReceiveData(data):
                    self?.serviceEventSubject.send(.didReceiveMessage(data))
                case .didDiscoverLocalCandidate(_):
                    self?.serviceEventSubject.send(.didDiscoverLocalCandidate)
                case let .didChangeConnectionState(state):
                    self?.serviceEventSubject.send(.changeConnectionState(state))
                case let .catchError(error):
                    self?.serviceEventSubject.send(.showError(error))
            }
        }
        .store(in: &cancellableBag)
    }
}
