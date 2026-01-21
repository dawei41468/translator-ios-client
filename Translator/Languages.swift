import Foundation

struct LanguageOption: Identifiable, Hashable {
    let id = UUID()
    let code: String  // "en"
    let flag: String
    let nativeName: String
    let bcp47: String  // Web pillars: "en-US"
}

let LANGUAGES: [LanguageOption] = [
    LanguageOption(code: "en", flag: "🇺🇸", nativeName: "English", bcp47: "en-US"),
    LanguageOption(code: "zh", flag: "🇨🇳", nativeName: "中文", bcp47: "zh-CN"),  // cmn-CN alt?
    LanguageOption(code: "ko", flag: "🇰🇷", nativeName: "한국어", bcp47: "ko-KR"),
    LanguageOption(code: "es", flag: "🇪🇸", nativeName: "Español", bcp47: "es-ES"),
    LanguageOption(code: "ja", flag: "🇯🇵", nativeName: "日本語", bcp47: "ja-JP"),
    LanguageOption(code: "it", flag: "🇮🇹", nativeName: "Italiano", bcp47: "it-IT"),
    LanguageOption(code: "de", flag: "🇩🇪", nativeName: "Deutsch", bcp47: "de-DE"),
    LanguageOption(code: "nl", flag: "🇳🇱", nativeName: "Nederlands", bcp47: "nl-NL")
]

extension LanguageOption {
    var displayName: String { "\(flag) \(nativeName)" }
}
