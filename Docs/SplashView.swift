import SwiftUI

struct SplashView: View {
    @State private var authVM = AuthViewModel()
    @State private var path = NavigationPath()
    @State private var recentManager = RecentRoomsManager()
    
    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if authVM.isLoading {
                    ProgressView("Checking auth...")
                } else if let user = authVM.currentUser {
                    DashboardView(user: user, recentManager: recentManager)
                        .navigationDestination(for: String.self) { roomCode in
                            ConversationView(roomCode: roomCode)  // Stub
                        }
                } else {
                    LoginView()
                }
            }
            .task { await authVM.checkAuth() }
        }
    }
}
