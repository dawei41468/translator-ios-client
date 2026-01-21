import SwiftUI

enum Destination: Hashable {
    case room(String)
    case profile
}

struct SplashView: View {
    @StateObject private var authVM = AuthViewModel()
    @State private var path = [Destination]()
    @StateObject private var recentManager = RecentRoomsManager()
    
    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if authVM.isLoading {
                    ProgressView("Checking auth...")
                } else if let user = authVM.currentUser {
                    DashboardView(user: user, recentManager: recentManager, path: $path)
                        .navigationDestination(for: Destination.self) { dest in
                            switch dest {
                            case .room(let roomCode):
                                ConversationView(roomCode: roomCode, authVM: authVM)
                            case .profile:
                                ProfileView(user: user)
                            }
                        }
                } else {
                    LoginView()
                }
            }
            .task { await authVM.checkAuth() }
            .onChange(of: authVM.currentUser) { oldValue, newValue in
                if newValue == nil {
                    path = []
                    authVM.errorMessage = nil
                }
            }
        }
        .environmentObject(authVM)
    }
}
