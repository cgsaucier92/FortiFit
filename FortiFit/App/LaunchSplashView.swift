import SwiftUI

struct LaunchSplashView: View {
    static let displayDuration: Double = 1.0
    static let fadeDuration: Double = 0.35

    var body: some View {
        ZStack {
            Color.black
            Image("LaunchImage")
        }
        .ignoresSafeArea()
    }
}
