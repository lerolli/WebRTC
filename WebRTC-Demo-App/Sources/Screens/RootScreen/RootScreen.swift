import SwiftUI

struct RootScreenView: View {
    var output: RootScreenPresenter
    
    var body: some View {
        VStack {
            Text("Select Screen")
            
            Button("✅ UIKit via delegate") {
                output.openUIKit()
            }
            
            Button("❌ SwiftUI via alemira architecture ") {
                output.openSwiftUI()
            }
        }
    }
}
