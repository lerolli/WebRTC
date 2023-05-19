import SwiftUI

enum MainScreenModule {
    
    static func initialize(navigationController: UINavigationController?) -> UIViewController {
        let config = Config.default
        let webRTCClient = ReactiveWebRTCClient(
            iceServers: config.webRTCIceServers
        )
        
        let signalClient = buildSignalingClient()
        
        let presenter = MainScreenPresenter(
            state: MainScreenState(),
            services: MainServices(
                navigationController: navigationController,
                webRTCClient: webRTCClient,
                signalingClient: signalClient
            )
        )
        let vc = UIHostingController(rootView: MainScreen(output: presenter))

        return vc
    }
    
    private static func buildSignalingClient() -> ReactiveSignalingClient {
        let config = Config.default
        let webSocketService = WebSocketService(url: config.signalingServerUrl)
        return ReactiveSignalingClient(webSocketService: webSocketService)
    }
}
