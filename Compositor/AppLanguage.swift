import AppKit
import SwiftUI

extension String {
    /// Looks up text that isn't a literal where it's shown, such as an enum's raw value that is also saved in
    /// projects. The compiler can't extract these, so their keys are added to Localizable.xcstrings by hand.
    nonisolated var localized: String { Bundle.main.localizedString(forKey: self, value: self, table: nil) }

    /// The English text this was translated from, or itself. Lets search match the English names too.
    nonisolated var inEnglish: String { englishByTranslation[self] ?? self }
}

nonisolated private let englishByTranslation: [String: String] = {
    guard let path = Bundle.main.path(forResource: "Localizable", ofType: "strings"),
          let table = NSDictionary(contentsOfFile: path) as? [String: String] else { return [:] }
    return Dictionary(table.map { ($0.value, $0.key) }, uniquingKeysWith: { first, _ in first })
}()

/// The interface language chosen in Compositor > Language. It takes effect the next time the app opens,
/// because macOS picks a bundle's language once at launch.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, simplifiedChinese = "zh-Hans", english = "en"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: String(localized: "Follow System")
        // Each language is named in itself, so it can be found whatever the current one is.
        case .simplifiedChinese: "简体中文"
        case .english: "English"
        }
    }

    private static let defaultsKey = "InterfaceLanguage"
    /// This edition opens in Chinese until another language is chosen.
    static let fallback = AppLanguage.simplifiedChinese

    static var current: AppLanguage {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(AppLanguage.init(rawValue:)) ?? fallback
    }

    /// Writes the choice where macOS reads it at launch. Called as early as possible, before anything looks
    /// up a localized string.
    static func applyAtLaunch() {
        let defaults = UserDefaults.standard
        // Tests check English names ("Layer 1"), so the test host always runs in English.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            defaults.set(["en"], forKey: "AppleLanguages")
            return
        }
        switch current {
        case .system: defaults.removeObject(forKey: "AppleLanguages")
        case let language: defaults.set([language.rawValue], forKey: "AppleLanguages")
        }
    }

    static func choose(_ language: AppLanguage) {
        guard language != current else { return }
        UserDefaults.standard.set(language.rawValue, forKey: defaultsKey)
        applyAtLaunch()
        let alert = NSAlert()
        alert.messageText = String(localized: "The new language takes effect the next time Compositor opens.")
        alert.addButton(withTitle: String(localized: "Quit Now"))
        alert.addButton(withTitle: String(localized: "Later"))
        if alert.runModal() == .alertFirstButtonReturn { NSApp.terminate(nil) }
    }
}

struct LanguageMenu: View {
    @State private var selection = AppLanguage.current

    var body: some View {
        Picker("Language", selection: Binding(get: { selection }, set: { language in
            selection = language
            AppLanguage.choose(language)
        })) {
            ForEach(AppLanguage.allCases) { language in
                Text(language.title).tag(language)
                if language == .system { Divider() }
            }
        }
    }
}
