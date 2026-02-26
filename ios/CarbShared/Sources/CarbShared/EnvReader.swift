import Foundation

public struct EnvReader {
    public static func apiKey() -> String? {
        // Direct .env in bundle (works on watchOS and iOS debug)
        if let path = Bundle.main.path(forResource: ".env", ofType: nil) {
            return parseKey(from: path)
        }
        // Alternate name without leading dot
        if let path = Bundle.main.path(forResource: "env", ofType: nil) {
            return parseKey(from: path)
        }
        #if os(iOS)
        // Flutter assets path (iOS debug)
        if let path = Bundle.main.path(forResource: "flutter_assets/.env", ofType: nil) {
            return parseKey(from: path)
        }
        // Inside App.framework for iOS release builds
        if let path = Bundle.main.path(forResource: "Frameworks/App.framework/flutter_assets/.env", ofType: nil) {
            return parseKey(from: path)
        }
        #endif
        return nil
    }

    private static func parseKey(from path: String) -> String? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("PERPLEXITY_API_KEY=") {
                return String(trimmed.dropFirst("PERPLEXITY_API_KEY=".count))
            }
        }
        return nil
    }
}
