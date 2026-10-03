import SwiftUI

@main
struct ZARConverterApp: App {
    var body: some Scene {
        WindowGroup {
            ConverterView()
                .frame(minWidth: 620, minHeight: 520)
        }
        .windowResizability(.contentSize)
    }
}
