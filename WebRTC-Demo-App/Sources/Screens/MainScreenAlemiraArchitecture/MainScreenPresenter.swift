import Foundation
import SwiftUI
import Combine

enum MainScreenViewAction {
    case mute
    case muteSpeaker
    case sendMessage(String)
    case openVideo
    
    case sendOffer
    case sendAnswer
    
    case hideError
    case hideMessage
}



final class MainScreenPresenter: ObservableObject {
    @Published var state: MainScreenState
    
    private let services: MainServices
    private var cancellableBag = Set<AnyCancellable>()
    
    init(
        state: MainScreenState,
        services: MainServices
    ) {
        self.state = state
        self.services = services
        
        configureServices()
    }
    
    func dispatch(_ action: MainScreenViewAction) {
        state.mutateState(action)
        
        switch action {
            case .mute:
                services.dispatch(.muteAudio(state.audioIsMuted))
            case .muteSpeaker:
                services.dispatch(.muteSpeaker(state.speakerIsMuted))
            case .sendMessage:
                break
            case .openVideo:
                break
            case .sendOffer:
                services.dispatch(.offerDidTap)
            case .sendAnswer:
                services.dispatch(.answerDidTap)
            default:
                break
        }
    }
    
    func configureServices() {
        services.servicesEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] callback in
                self?.state.mutateState(callback) 
        }
        .store(in: &cancellableBag)
    }
}
