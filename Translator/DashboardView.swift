import SwiftUI

struct DashboardView: View {
    let user: AuthUser
    let recentManager: RecentRoomsManager
    let path: Binding<[Destination]>
    @State private var errorMessage: String?
    @State private var showingJoinSheet = false
    @State private var joinCode = ""
    private let repo = ApiRepository()

    var body: some View {
        VStack {
            Text("Welcome, \(user.displayName ?? user.name)!")
                .font(.title)
            
            List(recentManager.recentRooms) { room in
                Button(room.code) {
                    path.wrappedValue.append(.room(room.code))
                }
            }
            
            Button("Create Room") {
                Task {
                    do {
                        let response = try await repo.createRoom()
                        recentManager.addOrUpdate(response.roomCode)
                        path.wrappedValue.append(.room(response.roomCode))
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Join Room") {
                showingJoinSheet = true
            }

            Button("Profile") {
                path.wrappedValue.append(.profile)
            }
        }
        .navigationTitle("Dashboard")
        .sheet(isPresented: $showingJoinSheet) {
            VStack(spacing: 20) {
                Text("Join Room")
                    .font(.title)
                
                TextField("Room Code", text: $joinCode)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Button("Cancel") {
                        showingJoinSheet = false
                        joinCode = ""
                    }
                    
                    Button("Join") {
                        Task {
                            do {
                                let response = try await repo.joinRoom(code: joinCode)
                                recentManager.addOrUpdate(response.roomCode)
                                path.wrappedValue.append(.room(response.roomCode))
                                showingJoinSheet = false
                                joinCode = ""
                            } catch {
                                errorMessage = error.localizedDescription
                                showingJoinSheet = false
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }
}

#Preview {
    DashboardView(
        user: AuthUser(
            id: "",
            name: "",
            email: "",
            displayName: nil,
            language: "en",
            isGuest: false,
            preferences: nil
        ),
        recentManager: RecentRoomsManager(),
        path: .constant([])
    )
}
