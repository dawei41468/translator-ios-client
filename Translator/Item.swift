//
//  Item.swift
//  Translator
//
//  Created by David Wang on 1/19/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
