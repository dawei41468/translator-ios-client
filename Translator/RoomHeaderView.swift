import SwiftUI

struct RoomHeaderView: View {
    let participants: [Participant]
    let roomCode: String
    
    var body: some View {
        HStack {
            Text("Room: \(roomCode)")
                .font(.headline)
            
            Spacer()
            
            Text("\(participants.count) participants")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

#Preview {
    RoomHeaderView(participants: [
        Participant(id: "1", name: "Alice", language: "en"),
        Participant(id: "2", name: "Bob", language: "zh")
    ], roomCode: "ABC123")
}