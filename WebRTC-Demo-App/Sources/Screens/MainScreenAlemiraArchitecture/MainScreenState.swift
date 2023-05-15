import Foundation

struct MainScreenState {
    var signalingStatus = "Not connected"
    private(set) var signalingConnected: Bool = false
    
    private(set) var hasLocalSessionDescription = false
    private(set) var localCandidates = 0
    
    private(set) var hasRemoteSessionDescription = false
    private(set) var remoteCandidates = 0
    
    private(set) var message: String = ""
    
    private(set) var audioIsMuted = false
    private(set) var speakerIsMuted = false
    private(set) var webRTCStatus = "New"
    
    private(set) var error: Error?
    
    var showError: Bool {
        error != nil
    }
    
    var showMessage: Bool {
        !message.isEmpty
    }
}

extension MainScreenState {
    mutating func mutateState(_ action: MainScreenViewAction) {
        switch action {
            case .hideError:
                error = nil
            case .hideMessage:
                message = ""
            case .mute:
                audioIsMuted.toggle()
            case .muteSpeaker:
                speakerIsMuted.toggle()
            default:
                break
        }
    }
    
    mutating func mutateState(_ action: MainServicesCallback) {
        switch action {
            case let .isSocketConnected(isConnected):
                signalingConnected = isConnected
            case let .changeConnectionState(state):
                webRTCStatus = state.description
            case .hasLocalSessionDescription:
                hasLocalSessionDescription = true
            case .didDiscoverLocalCandidate:
                localCandidates += 1
            case .didReceiveSessionDescription:
                hasRemoteSessionDescription = true
            case .didReceiveIceCandidate:
                remoteCandidates += 1
            case let .didReceiveMessage(data):
                message = String(data: data, encoding: .utf8) ?? "(Binary: \(data.count) bytes)"
            case let .showError(error):
                self.error = error
        }
    }
}
