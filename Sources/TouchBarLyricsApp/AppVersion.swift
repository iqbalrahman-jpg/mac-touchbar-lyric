import Foundation

enum AppVersion {
    static func menuTitle(infoDictionary: [String: Any]?) -> String {
        guard let version = nonEmptyString(
            infoDictionary?["CFBundleShortVersionString"]
        ) else {
            return "Version unknown"
        }

        guard let build = nonEmptyString(infoDictionary?["CFBundleVersion"]),
              build != version else {
            return "Version \(version)"
        }
        return "Version \(version) (\(build))"
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
