import Foundation
import Combine
import SwiftUI

class RecentRoomsManager: ObservableObject {
    @Published private var rooms: [RecentRoom] = []
    
    private let defaults = UserDefaults.standard
    private let key = "recentRooms"
    
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
        }
        // Sort descending by lastUsedAt and keep max 5
        rooms.sort { $0.lastUsedAt > $1.lastUsedAt }
        rooms = Array(rooms.prefix(5))
        save()
    }
    
    private func load() {
        guard let rawString = defaults.string(forKey: key),
              let data = rawString.data(using: .utf8) else { return }
        rooms = (try? JSONDecoder().decode([RecentRoom].self, from: data)) ?? []
        rooms.sort { $0.lastUsedAt > $1.lastUsedAt }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(rooms),
           let rawString = String(data: data, encoding: .utf8) {
            defaults.set(rawString, forKey: key)
        }
    }
}
