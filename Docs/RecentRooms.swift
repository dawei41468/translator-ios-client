import Foundation
import Observation

@Observable
class RecentRoomsManager {
    private var rooms: [RecentRoom] = []
    
    @AppStorage("recentRooms") private var rawRooms: String = "[]"
    
    var recentRooms: [RecentRoom] { rooms }
    
    init() {
        load()
    }
    
    func addOrUpdate(_ code: String) {
        let now = Date().timeIntervalSince1970
        if let index = rooms.firstIndex(where: { $0.code == code }) {
            rooms[index].lastUsedAt = now
        } else {
            rooms.insert(RecentRoom(code: code, lastUsedAt: now), at: 0)
            rooms = Array(rooms.prefix(5))  // Max 5
        }
        save()
    }
    
    private func load() {
        guard let data = rawRooms.data(using: .utf8) else { return }
        rooms = (try? JSONDecoder().decode([RecentRoom].self, from: data)) ?? []
        rooms.sort { $0.lastUsedAt > $1.lastUsedAt }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(rooms) {
            rawRooms = String(data: data, encoding: .utf8) ?? "[]"
        }
    }
}
