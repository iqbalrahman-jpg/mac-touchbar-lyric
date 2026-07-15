@preconcurrency import AppKit
import Foundation

enum TextColorPreference {
    static let defaultsKey = "TouchBarLyrics.textColor"

    static func load(from defaults: UserDefaults = .standard) -> NSColor? {
        guard let components = defaults.array(forKey: defaultsKey) as? [NSNumber],
              components.count == 4 else {
            return nil
        }

        let values = components.map(\.doubleValue)
        guard values.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            return nil
        }

        return NSColor(
            srgbRed: values[0],
            green: values[1],
            blue: values[2],
            alpha: values[3]
        )
    }

    static func save(_ color: NSColor, to defaults: UserDefaults = .standard) {
        guard let color = color.usingColorSpace(.sRGB) else { return }
        defaults.set(
            [
                color.redComponent,
                color.greenComponent,
                color.blueComponent,
                color.alphaComponent
            ],
            forKey: defaultsKey
        )
    }

    static func reset(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: defaultsKey)
    }
}
