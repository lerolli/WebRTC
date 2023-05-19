import UIKit
import WebRTC

final class ReactiveVideoViewController: UIViewController {

    private var localVideoView = UIView()
    var webRTCClient: ReactiveWebRTCClientProtocol?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(localVideoView)
        localVideoView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            localVideoView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            localVideoView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            localVideoView.heightAnchor.constraint(equalToConstant: 100),
            localVideoView.widthAnchor.constraint(equalToConstant: 50)
        ])
        
        
        let localRenderer = RTCMTLVideoView(frame: self.localVideoView.frame)
        let remoteRenderer = RTCMTLVideoView(frame: self.view.frame)
        localRenderer.videoContentMode = .scaleAspectFill
        remoteRenderer.videoContentMode = .scaleAspectFill
        
        webRTCClient?.dispatch(.startCaptureLocalVideo(localRenderer))
        webRTCClient?.dispatch(.renderRemoteVideo(remoteRenderer))
        
        embedView(localRenderer, into: localVideoView)
        
        embedView(remoteRenderer, into: self.view)
        
        view.sendSubviewToBack(remoteRenderer)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        webRTCClient?.dispatch(.stopCaptureLocalVideo)
    }
    
    private func embedView(_ view: UIView, into containerView: UIView) {
        containerView.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addConstraints(
            NSLayoutConstraint.constraints(
                withVisualFormat: "H:|[view]|",
                options: [],
                metrics: nil,
                views: ["view":view]
            )
        )
        containerView.addConstraints(
            NSLayoutConstraint.constraints(
                withVisualFormat: "V:|[view]|",
                options: [],
                metrics: nil,
                views: ["view":view]
            )
        )
        containerView.layoutIfNeeded()
    }
    
    @IBAction private func backDidTap(_ sender: Any) {
        self.dismiss(animated: true)
    }
}
