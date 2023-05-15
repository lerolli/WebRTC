import Foundation
import WebRTC
import Combine

enum ReactiveWebRTCClientAction {
    case setLocalDescription(Signaling)
    case setRemoteDescription(RTCSessionDescription)
    
    case setCandidate(RTCIceCandidate)
    case audioIsMuted(Bool)
    case speakerIsMuted(Bool)
}

enum ReactiveWebRTCClientCallback {
    case sendLocalDescription(RTCSessionDescription)
    
    case didDiscoverLocalCandidate(RTCIceCandidate)
    case didChangeConnectionState(RTCIceConnectionState)
    case didReceiveData(Data)
    
    case catchError(Error)
}

enum Signaling {
    case offer
    case answer
}

protocol ReactiveWebRTCClientProtocol: AnyObject {
    var servicesEventPublisher: AnyPublisher<ReactiveWebRTCClientCallback, Never> { get }
    
    func dispatch(_ action: ReactiveWebRTCClientAction)
}

extension ReactiveWebRTCClient: ReactiveWebRTCClientProtocol {
    var servicesEventPublisher: AnyPublisher<ReactiveWebRTCClientCallback, Never> {
        serviceEventSubject.eraseToAnyPublisher()
    }
    
    func dispatch(_ action: ReactiveWebRTCClientAction) {
        switch action {
            case let .setLocalDescription(signaling):
                setLocalDescription(signaling)
            case let .setRemoteDescription(sessionDescription):
                setRemoteSessionDescription(sessionDescription)
            case let .setCandidate(candidate):
                setRemoteCandidate(candidate)
            case let .audioIsMuted(isMuted):
                setAudioEnabled(isMuted)
            case let .speakerIsMuted(isMuted):
                isMuted ? speakerOff() : speakerOn()
        }
    }
}

final class ReactiveWebRTCClient: NSObject {

    private let serviceEventSubject = PassthroughSubject<ReactiveWebRTCClientCallback, Never>()
    private var cancellableBag = Set<AnyCancellable>()
    
    private let factory: RTCPeerConnectionFactory
    
    private let peerConnection: RTCPeerConnection
    private let rtcAudioSession =  RTCAudioSession.sharedInstance()
    private let audioQueue = DispatchQueue(label: "audio")
    
    private let mediaConstrains = [
        kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
        kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
    ]
    
    private var videoCapturer: RTCVideoCapturer?
    private var localVideoTrack: RTCVideoTrack?
    private var remoteVideoTrack: RTCVideoTrack?
    private var localDataChannel: RTCDataChannel?
    private var remoteDataChannel: RTCDataChannel?

   
    init(iceServers: [String]) {
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: iceServers)]
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue]
        )
        
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
            
        factory = RTCPeerConnectionFactory(
            encoderFactory: videoEncoderFactory,
            decoderFactory: videoDecoderFactory
        )
        
        guard let peerConnection = factory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: nil
        ) else {
            fatalError("Could not create new RTCPeerConnection")
        }
        
        self.peerConnection = peerConnection
        
        super.init()
        
        createMediaSenders()
        configureAudioSession()
        peerConnection.delegate = self
    }
    
    // MARK: - Signaling
    
    private func setLocalDescription(_ signaling: Signaling) {
        let completion: (RTCSessionDescription?, Error?) -> Void = { [weak self] localDescription, error in
            if let error {
                self?.serviceEventSubject.send(.catchError(error))
                return
            }
            
            guard let localDescription else { return }
            
            
            self?.peerConnection.setLocalDescription(localDescription) { [weak self] error in
                if let error {
                    self?.serviceEventSubject.send(.catchError(error))
                } else {
                    self?.serviceEventSubject.send(.sendLocalDescription(localDescription))
                }
            }
        }
        
        let constrains = RTCMediaConstraints(
            mandatoryConstraints: mediaConstrains,
            optionalConstraints: nil
        )
        
        switch signaling {
            case .offer:
                peerConnection.offer(for: constrains) {(localDescription, error) in
                    completion(localDescription, error)
                }
            case .answer:
                peerConnection.answer(for: constrains) {(localDescription, error) in
                    completion(localDescription, error)
                }
        }
    }
    
    func setRemoteSessionDescription(_ sessionDescription: RTCSessionDescription) {
        peerConnection.setRemoteDescription(sessionDescription) { [weak self] error in
            if let error {
                self?.serviceEventSubject.send(.catchError(error))
            }
            
        }
    }
    
    func setRemoteCandidate(_ candidate: RTCIceCandidate) {
        peerConnection.add(candidate) { [weak self] error in
            if let error {
                self?.serviceEventSubject.send(.catchError(error))
            }
        }
    }
    
    func startCaptureLocalVideo(renderer: RTCVideoRenderer) {
        guard let capturer = self.videoCapturer as? RTCCameraVideoCapturer else {
            return
        }

        guard let frontCamera = (RTCCameraVideoCapturer.captureDevices().first { $0.position == .front }),
        
            // choose highest res
            let format = (RTCCameraVideoCapturer.supportedFormats(for: frontCamera).sorted { (f1, f2) -> Bool in
                let width1 = CMVideoFormatDescriptionGetDimensions(f1.formatDescription).width
                let width2 = CMVideoFormatDescriptionGetDimensions(f2.formatDescription).width
                return width1 < width2
            }).last,
        
            // choose highest fps
            let fps = (format.videoSupportedFrameRateRanges.sorted { return $0.maxFrameRate < $1.maxFrameRate }.last) else {
            return
        }

        capturer.startCapture(with: frontCamera,
                              format: format,
                              fps: Int(fps.maxFrameRate))
        
        self.localVideoTrack?.add(renderer)
    }
    
    func renderRemoteVideo(to renderer: RTCVideoRenderer) {
        remoteVideoTrack?.add(renderer)
    }
    
    private func configureAudioSession() {
        rtcAudioSession.lockForConfiguration()
        do {
            try rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
            try rtcAudioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
        } catch let error {
            debugPrint("Error changing AVAudioSession category: \(error)")
        }
        rtcAudioSession.unlockForConfiguration()
    }
    
    private func createMediaSenders() {
        let streamId = "stream"
        
        // Cоздание аудиоканала
        let audioTrack = createAudioTrack()
        peerConnection.add(audioTrack, streamIds: [streamId])
        
        // Cоздание видеоканала
        let videoTrack = createVideoTrack()
        localVideoTrack = videoTrack
        peerConnection.add(videoTrack, streamIds: [streamId])
        remoteVideoTrack = peerConnection.transceivers
            .first { $0.mediaType == .video }?
            .receiver.track as? RTCVideoTrack
        
        // Cоздание data канала, например, для отправки сообщения
        if let dataChannel = createDataChannel() {
            dataChannel.delegate = self
            localDataChannel = dataChannel
        }
    }
    
    private func createAudioTrack() -> RTCAudioTrack {
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = factory.audioSource(with: audioConstrains)
        let audioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
        return audioTrack
    }
    
    private func createVideoTrack() -> RTCVideoTrack {
        let videoSource = factory.videoSource()
        
        #if targetEnvironment(simulator)
        videoCapturer = RTCFileVideoCapturer(delegate: videoSource)
        #else
        videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        #endif
        
        let videoTrack = factory.videoTrack(with: videoSource, trackId: "video0")
        return videoTrack
    }
    
    // MARK: Data Channels
    private func createDataChannel() -> RTCDataChannel? {
        let config = RTCDataChannelConfiguration()
        guard let dataChannel = self.peerConnection.dataChannel(forLabel: "WebRTCData", configuration: config) else {
            debugPrint("Warning: Couldn't create data channel.")
            return nil
        }
        return dataChannel
    }
    
    func sendData(_ data: Data) {
        let buffer = RTCDataBuffer(data: data, isBinary: true)
        self.remoteDataChannel?.sendData(buffer)
    }
}

extension ReactiveWebRTCClient: RTCPeerConnectionDelegate {
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        serviceEventSubject.send(.didChangeConnectionState(newState))
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        remoteDataChannel = dataChannel
    }
}


extension ReactiveWebRTCClient {
    private func setTrackEnabled<T: RTCMediaStreamTrack>(_ type: T.Type, isEnabled: Bool) {
        peerConnection.transceivers
            .compactMap { return $0.sender.track as? T }
            .forEach { $0.isEnabled = isEnabled }
    }
}

// MARK: - Video control
extension ReactiveWebRTCClient {
    func hideVideo() {
        self.setVideoEnabled(false)
    }
    func showVideo() {
        self.setVideoEnabled(true)
    }
    private func setVideoEnabled(_ isEnabled: Bool) {
        setTrackEnabled(RTCVideoTrack.self, isEnabled: isEnabled)
    }
}
// MARK: - Audio control
extension ReactiveWebRTCClient {
    
    // Fallback to the default playing device: headphones/bluetooth/ear speaker
    func speakerOff() {
        self.audioQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            self.rtcAudioSession.lockForConfiguration()
            do {
                try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
                try self.rtcAudioSession.overrideOutputAudioPort(.none)
            } catch let error {
                debugPrint("Error setting AVAudioSession category: \(error)")
            }
            self.rtcAudioSession.unlockForConfiguration()
        }
    }
    
    // Force speaker
    func speakerOn() {
        self.audioQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            self.rtcAudioSession.lockForConfiguration()
            do {
                try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
                try self.rtcAudioSession.overrideOutputAudioPort(.speaker)
                try self.rtcAudioSession.setActive(true)
            } catch let error {
                debugPrint("Couldn't force audio to speaker: \(error)")
            }
            self.rtcAudioSession.unlockForConfiguration()
        }
    }
    
    private func setAudioEnabled(_ isEnabled: Bool) {
        setTrackEnabled(RTCAudioTrack.self, isEnabled: isEnabled)
    }
}

extension ReactiveWebRTCClient: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {}
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        serviceEventSubject.send(.didReceiveData(buffer.data))
    }
}
