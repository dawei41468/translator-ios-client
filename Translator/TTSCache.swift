import Foundation
import CryptoKit

@MainActor
class TTSCache {
    private let cache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    init() {
        // Create cache directory in app's documents directory
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsDirectory.appendingPathComponent("tts_cache", isDirectory: true)

        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Configure memory cache limits
        cache.countLimit = 50 // Max 50 items in memory
        cache.totalCostLimit = 50 * 1024 * 1024 // Max 50MB in memory
    }

    func getAudio(for text: String, language: String) -> Data? {
        let key = generateCacheKey(text: text, language: language)

        // Check memory cache first
        if let cached = cache.object(forKey: key as NSString) {
            print("TTS Cache: Memory hit for key \(key)")
            return cached as Data
        }

        // Check disk cache
        let url = getCacheURL(for: key)
        if let data = try? Data(contentsOf: url) {
            // Load into memory cache for faster future access
            cache.setObject(data as NSData, forKey: key as NSString)
            print("TTS Cache: Disk hit for key \(key)")
            return data
        }

        print("TTS Cache: Miss for key \(key)")
        return nil
    }

    func setAudio(_ data: Data, for text: String, language: String) {
        let key = generateCacheKey(text: text, language: language)

        // Store in memory cache
        cache.setObject(data as NSData, forKey: key as NSString)

        // Store on disk asynchronously
        Task {
            let url = getCacheURL(for: key)
            do {
                try data.write(to: url)
                print("TTS Cache: Saved to disk for key \(key)")
            } catch {
                print("TTS Cache: Failed to save to disk for key \(key): \(error)")
            }
        }
    }

    func clearCache() {
        // Clear memory cache
        cache.removeAllObjects()

        // Clear disk cache
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        print("TTS Cache: Cleared all caches")
    }

    private func generateCacheKey(text: String, language: String) -> String {
        let input = "\(text)|\(language)".data(using: .utf8)!
        let hash = SHA256.hash(data: input)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func getCacheURL(for key: String) -> URL {
        return cacheDirectory.appendingPathComponent("\(key).mp3")
    }
}