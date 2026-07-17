import Foundation

enum L10n {
    static func t(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    static func tf(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), locale: Locale.current, arguments: arguments)
    }

    /// Prefer the packaged `.app` bundle; fall back to SwiftPM `Bundle.module`.
    private static var bundle: Bundle {
        if Bundle.main.url(forResource: "Localizable", withExtension: "strings") != nil
            || Bundle.main.url(forResource: "en", withExtension: "lproj") != nil
            || Bundle.main.url(forResource: "fi", withExtension: "lproj") != nil {
            return .main
        }
        return .module
    }
}
