import SwiftUI

struct DashboardView: View {
    let user: AuthUser
    let recentManager: RecentRoomsManager
    
    var body: some View {
        VStack {
            Text("Welcome, \(user.displayName ?? user.name)!")
                .font(.title)
            
            List(recentManager.recentRooms) { room in
                Button(room.code) {
                    // Navigate to Conversation
                }
            }
            
            Button("Create Room") {
                // POST /rooms → nav
            }
            .buttonStyle(.borderedProminent)
            
            Button("Join Room") {
                // Sheet code input → POST join
            }
        }
        .navigationTitle("Dashboard")
    }
}

#Preview {
    DashboardView(user: AuthUser(id: "", name: "", email: "", language: "en"), recentManager: RecentRoomsManager())
}
