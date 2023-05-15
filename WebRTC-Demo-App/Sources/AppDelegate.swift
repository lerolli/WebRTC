import SwiftUI

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private let config = Config.default

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        
        let presenter = RootScreenPresenter()
        let view = RootScreenView(output: presenter)
        let vc = UIHostingController(rootView: view)
        
        presenter.vc = vc
        window.rootViewController = vc

        window.makeKeyAndVisible()
        self.window = window

        return true
    }
}
