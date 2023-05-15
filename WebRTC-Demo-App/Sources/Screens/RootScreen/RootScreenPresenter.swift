import SwiftUI

final class RootScreenPresenter {
    var vc: UIViewController?
    private let config = Config.default
    
    func openUIKit() {
        vc?.present(buildMainViewController(), animated: true)
    }
    
    func openSwiftUI() {
        vc?.present(MainScreenModule.initialize(), animated: true)
    }
    
    
    private func buildMainViewController() -> UIViewController {
        let webRTCClient = WebRTCClient(iceServers: config.webRTCIceServers)
        let signalClient = buildSignalingClient()
        
        let mainViewController = MainViewController(signalClient: signalClient, webRTCClient: webRTCClient)
        let navViewController = UINavigationController(rootViewController: mainViewController)
        navViewController.navigationBar.prefersLargeTitles = true
        
        return navViewController
    }
    
    private func buildSignalingClient() -> SignalingClient {
        let webSocketProvider = WebSocketIO(url: config.signalingServerUrl)
        return SignalingClient(webSocket: webSocketProvider)
    }
}
